-- Testes das regras e permissões. Rodar após o shim e as migrations:
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/10_regras_test.sql
-- Cada bloco falha com exceção se a regra não se comportar como esperado.
\set QUIET on
set client_min_messages = warning;

create or replace function pg_temp.como(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', (select id::text from auth.users where email = p_email), false);
  execute 'set role authenticated';
end $$;
create or replace function pg_temp.admin() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', false);
end $$;

-- Usuários: o primeiro vira gestor
insert into auth.users (email, raw_user_meta_data) values
  ('gestor@lc.com', '{"nome":"Gestora"}'),
  ('lider.w@lc.com', jsonb_build_object('nome','Líder Winners','papel','lider','equipe_id',(select id from equipes where nome='Winners'))),
  ('ana@lc.com',     jsonb_build_object('nome','Ana','papel','corretor','equipe_id',(select id from equipes where nome='Winners'))),
  ('bruno@lc.com',   jsonb_build_object('nome','Bruno','papel','corretor','equipe_id',(select id from equipes where nome='Winners'))),
  ('caio@lc.com',    jsonb_build_object('nome','Caio','papel','corretor','equipe_id',(select id from equipes where nome='Furiosos')));

do $$ begin
  assert (select papel from usuarios where email='gestor@lc.com') = 'gestor', 'primeiro usuário deveria ser gestor';
  assert (select papel from usuarios where email='ana@lc.com') = 'corretor', 'ana deveria ser corretora';
end $$;
\echo ok 01 bootstrap de usuários

insert into empreendimentos (nome, bairro) values ('BM900', 'Meireles'), ('Uni Bangalôs', 'Aquiraz');

-- Gestor cadastra lead via registrar_lead
select pg_temp.como('gestor@lc.com') \g /dev/null
do $$
declare r jsonb;
begin
  r := registrar_lead(jsonb_build_object(
        'nome','Maria Souza','email','Maria@Email.com','telefone','(85) 99999-0001',
        'origem','FB','conversao','Form BM900 - Out','empreendimentos', jsonb_build_array((select id from empreendimentos where nome='BM900')),
        'corretor_id',(select id from usuarios where email='ana@lc.com')));
  assert (r->>'novo')::boolean, 'deveria ser novo';
  assert (select telefone from leads where id=(r->>'id')::bigint) = '5585999990001', 'telefone normalizado com DDI';
  assert (select email::text from leads where id=(r->>'id')::bigint) = 'maria@email.com', 'email minúsculo';
  assert (select equipe_id from leads where id=(r->>'id')::bigint) = (select id from equipes where nome='Winners'), 'equipe herdada do corretor';
  assert (select count(*) from lead_situacao_historico where lead_id=(r->>'id')::bigint) = 1, 'histórico de situação no cadastro';
  assert (select count(*) from lead_responsavel_historico where lead_id=(r->>'id')::bigint) = 2, 'histórico de equipe e corretor';
end $$;
\echo ok 02 cadastro com normalização, equipe e históricos

-- Deduplicação: mesmo telefone em outro formato vira conversão, não lead novo
do $$
declare r jsonb;
begin
  r := registrar_lead('{"nome":"Maria","telefone":"+55 85 99999-0001","origem":"IG","conversao":"Form IG"}');
  assert not (r->>'novo')::boolean, 'deveria deduplicar';
  assert (select count(*) from leads) = 1, 'só um lead';
  assert (select count(*) from conversoes where lead_id=(r->>'id')::bigint) = 2, 'duas conversões';
  assert (select origem from leads where id=(r->>'id')::bigint) = 'FB', 'origem original mantida';
end $$;
\echo ok 03 deduplicação por telefone vira conversão

-- Origem não muda
do $$ begin
  begin
    update leads set origem='GO';
    raise exception 'deveria ter bloqueado';
  exception when insufficient_privilege then null;
  end;
end $$;
\echo ok 04 origem imutável

select pg_temp.admin() \g /dev/null
insert into leads (nome, email, origem, corretor_id)
  values ('Lead do Caio', 'x@y.com', 'SI', (select id from usuarios where email='caio@lc.com'));

-- Corretor só vê os próprios leads
select pg_temp.como('ana@lc.com') \g /dev/null
do $$ begin
  assert (select count(*) from leads) = 1, 'ana vê só o lead dela';
  assert (select count(*) from v_leads) = 1, 'view respeita RLS';
end $$;
select pg_temp.como('bruno@lc.com') \g /dev/null
do $$ begin assert (select count(*) from leads) = 0, 'bruno não vê nada'; end $$;
select pg_temp.como('lider.w@lc.com') \g /dev/null
do $$ begin assert (select count(*) from leads) = 1, 'líder vê só a equipe'; end $$;
select pg_temp.como('caio@lc.com') \g /dev/null
do $$ begin assert (select count(*) from leads) = 1, 'caio vê o dele'; end $$;
\echo ok 05 visibilidade por papel

-- Corretor não troca responsável
select pg_temp.como('ana@lc.com') \g /dev/null
do $$ begin
  begin
    update leads set corretor_id = (select id from usuarios where email='bruno@lc.com');
    raise exception 'deveria ter bloqueado';
  exception when insufficient_privilege then null;
  end;
end $$;
\echo ok 06 corretor não troca responsável

-- Líder troca corretor dentro da equipe, mas não para outra equipe
select pg_temp.como('lider.w@lc.com') \g /dev/null
update leads set corretor_id = (select id from usuarios where email='bruno@lc.com') where email='maria@email.com';
do $$ begin
  begin
    update leads set corretor_id = (select id from usuarios where email='caio@lc.com') where email='maria@email.com';
    raise exception 'deveria ter bloqueado';
  exception when check_violation then null;
  end;
end $$;
\echo ok 07 líder redistribui só dentro da equipe

-- Primeiro contato do corretor
select pg_temp.como('bruno@lc.com') \g /dev/null
insert into interacoes (lead_id, tipo, resultado, descricao)
  select id, 'ligacao', 'atendida', 'Cliente quer visitar sábado' from leads;
do $$ begin
  assert (select data_primeira_interacao_corretor from leads) is not null, 'primeiro contato registrado';
  assert (select data_ultima_interacao from leads) is not null, 'última interação registrada';
end $$;
-- Não pode registrar em nome de outro
do $$ begin
  begin
    insert into interacoes (lead_id, tipo, descricao, usuario_id)
      select id, 'anotacao', 'x', (select id from usuarios where email='ana@lc.com') from leads;
    raise exception 'deveria ter bloqueado';
  exception when insufficient_privilege then null;
  end;
end $$;
\echo ok 08 interações e primeiro contato

-- Automação de visita
insert into tarefas (lead_id, tipo, titulo, data)
  select id, 'visita', 'Visita decorado', now() + interval '2 days' from leads;
do $$ begin
  assert (select s.automacao from leads l join workflow_situacoes s on s.id=l.situacao_id) = 'visita_agendada', 'foi para visita agendada';
end $$;
update tarefas set situacao='concluida';
do $$ begin
  assert (select s.automacao from leads l join workflow_situacoes s on s.id=l.situacao_id) = 'visita_realizada', 'foi para visita realizada';
  assert (select concluida_em from tarefas) is not null, 'concluida_em preenchido';
end $$;
\echo ok 09 automação de visita

-- Cancelamento exige motivo; motivo com descrição obrigatória
do $$ begin
  begin
    update leads set situacao_id = (select id from workflow_situacoes where flag_cancelado);
    raise exception 'deveria exigir motivo';
  exception when check_violation then null;
  end;
  begin
    update leads set situacao_id = (select id from workflow_situacoes where flag_cancelado),
                     motivo_cancelamento_id = (select id from motivos_cancelamento where nome='Outro');
    raise exception 'deveria exigir descrição';
  exception when check_violation then null;
  end;
end $$;
update leads set situacao_id = (select id from workflow_situacoes where flag_cancelado),
                 motivo_cancelamento_id = (select id from motivos_cancelamento where nome='Sem interesse');
\echo ok 10 cancelamento exige motivo

-- Reativação: lead cancelado que volta pelo formulário vai para o início
select pg_temp.como('gestor@lc.com') \g /dev/null
do $$
declare r jsonb;
begin
  r := registrar_lead('{"email":"MARIA@email.com","origem":"FB","conversao":"Form BM900 - Nov"}');
  assert (r->>'reativado')::boolean, 'deveria reativar';
  assert (select flag_inicio from leads l join workflow_situacoes s on s.id=l.situacao_id where l.id=(r->>'id')::bigint), 'voltou ao início';
  assert (select motivo_cancelamento_id from leads where id=(r->>'id')::bigint) is null, 'motivo limpo';
  assert (select count(*) from v_tempo_situacao where lead_id=(r->>'id')::bigint) = 5, 'histórico completo de situações';
end $$;
\echo ok 11 reativação

-- Corretor não se promove
select pg_temp.como('ana@lc.com') \g /dev/null
do $$ begin
  begin
    update usuarios set papel='gestor' where id=auth.uid();
    raise exception 'deveria bloquear';
  exception when insufficient_privilege then null;
  end;
end $$;
-- Corretor não cria funil nem equipe
do $$ begin
  begin
    insert into equipes (nome) values ('Hack');
    raise exception 'deveria bloquear';
  exception when insufficient_privilege then null;
  end;
end $$;
\echo ok 12 corretor não altera papel nem cadastros

-- Corretor cadastrando lead fica como responsável, mesmo se tentar outro
do $$
declare r jsonb;
begin
  r := registrar_lead(jsonb_build_object('nome','Indicação da Ana','telefone','85988887777','origem','RF',
         'corretor_id',(select id from usuarios where email='caio@lc.com')));
  assert (select corretor_id from leads where id=(r->>'id')::bigint) = auth.uid(), 'responsável é a própria corretora';
end $$;
\echo ok 13 corretor cadastra lead para si

-- Anônimo não lê nada
select pg_temp.admin() \g /dev/null
set role anon;
do $$ begin assert (select count(*) from leads) = 0, 'anônimo não vê leads'; end $$;
reset role;
\echo ok 14 anônimo bloqueado

\echo TODOS OS TESTES PASSARAM
