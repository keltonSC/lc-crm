-- Testes da distribuição automática (roleta). Rodar depois de 10_regras_test.sql,
-- que cria o gestor, a líder e os corretores Ana e Bruno (Winners) e Caio (Furiosos).
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
create or replace function pg_temp.lead(p_tel text, p_extra jsonb default '{}') returns bigint language sql as $$
  select (registrar_lead(jsonb_build_object('nome', 'Lead ' || p_tel, 'telefone', p_tel, 'origem', 'FB') || p_extra) ->> 'id')::bigint
$$;
create or replace function pg_temp.uid(p_email text) returns uuid language sql as $$
  select id from usuarios where email = p_email
$$;
create or replace function pg_temp.reset_roleta() returns void language plpgsql as $$
begin
  delete from roleta_equipes; delete from roleta_corretores;
  update usuarios set online = false;
end $$;

select pg_temp.admin() \g /dev/null
delete from leads;

-- 1. Desligada por padrão: nada muda
do $$
declare v bigint := pg_temp.lead('85911110001');
begin
  assert not (select ativa from distribuicao_config), 'roleta nasce desligada';
  assert (select corretor_id is null and not aguarda_distribuicao from leads where id = v), 'sem roleta, lead fica sem dono e fora da fila';
end $$;
\echo ok 01 roleta desligada não distribui

update distribuicao_config set ativa = true, apenas_online = true;
delete from leads;

-- 2. Ninguém online: lead espera na fila
do $$
declare v bigint := pg_temp.lead('85911110002');
begin
  assert (select corretor_id is null and aguarda_distribuicao from leads where id = v), 'lead deveria esperar na fila';
end $$;
\echo ok 02 sem corretor online o lead vai para a fila

-- 3. Corretor fica online: a fila anda, com histórico motivo "fila"
select pg_temp.como('ana@lc.com') \g /dev/null
update usuarios set online = true where id = auth.uid();
select pg_temp.admin() \g /dev/null
do $$
declare v bigint := (select id from leads where telefone = '5585911110002');
begin
  assert (select corretor_id = pg_temp.uid('ana@lc.com') and not aguarda_distribuicao from leads where id = v), 'Ana deveria receber o lead da fila';
  assert (select equipe_id from leads where id = v) = (select id from equipes where nome = 'Winners'), 'equipe da Ana';
  assert (select data_associacao_corretor is not null from leads where id = v), 'data de associação';
  assert exists (select 1 from lead_responsavel_historico where lead_id = v and papel = 'corretor' and motivo = 'fila'), 'histórico motivo fila';
end $$;
\echo ok 03 corretor online esvazia a fila

-- 4. Rodízio entre equipes e, dentro delas, entre corretores
select pg_temp.reset_roleta() \g /dev/null
delete from leads;
update usuarios set online = true where email in ('ana@lc.com', 'bruno@lc.com', 'caio@lc.com');
do $$
declare i int;
begin
  for i in 1..6 loop perform pg_temp.lead('8592000000' || i); end loop;
  -- Select não tem corretor elegível e fica de fora; Furiosos e Winners se alternam
  assert (select count(*) from leads where corretor_id = pg_temp.uid('caio@lc.com')) = 3, 'Caio (Furiosos) recebe metade';
  assert (select count(*) from leads where corretor_id = pg_temp.uid('ana@lc.com')) = 2, 'Ana recebe 2';
  assert (select count(*) from leads where corretor_id = pg_temp.uid('bruno@lc.com')) = 1, 'Bruno recebe 1';
  assert (select count(*) from leads where aguarda_distribuicao) = 0, 'ninguém na fila';
  assert (select count(distinct equipe_id) from leads) = 2, 'duas equipes atendidas';
end $$;
\echo ok 04 rodízio entre equipes e corretores

-- 5. Só online: Bruno offline não recebe
select pg_temp.reset_roleta() \g /dev/null
delete from leads;
update usuarios set online = true where email in ('ana@lc.com', 'caio@lc.com');
do $$
declare i int;
begin
  for i in 1..4 loop perform pg_temp.lead('8593000000' || i); end loop;
  assert (select count(*) from leads where corretor_id = pg_temp.uid('bruno@lc.com')) = 0, 'Bruno offline não recebe';
  assert (select count(*) from leads where corretor_id = pg_temp.uid('ana@lc.com')) = 2, 'Ana recebe 2';
end $$;
\echo ok 05 respeita quem está online

-- 6. Fora da roleta: corretor e equipe com participa = false
select pg_temp.reset_roleta() \g /dev/null
delete from leads;
update usuarios set online = true where email in ('ana@lc.com', 'bruno@lc.com', 'caio@lc.com');
insert into roleta_corretores (usuario_id, participa) values (pg_temp.uid('ana@lc.com'), false);
do $$
declare i int;
begin
  for i in 1..4 loop perform pg_temp.lead('8594000000' || i); end loop;
  assert (select count(*) from leads where corretor_id = pg_temp.uid('ana@lc.com')) = 0, 'Ana fora da roleta';
  assert (select count(*) from leads where corretor_id = pg_temp.uid('bruno@lc.com')) = 2, 'Bruno fica com a parte da Winners';
end $$;
insert into roleta_equipes (equipe_id, participa) values ((select id from equipes where nome = 'Furiosos'), false)
  on conflict (equipe_id) do update set participa = false;
do $$
begin
  perform pg_temp.lead('85940000099');
  assert (select corretor_id from leads where telefone = '5585940000099') = pg_temp.uid('bruno@lc.com'), 'Furiosos fora da roleta: só sobra a Winners';
end $$;
\echo ok 06 corretor ou equipe fora da roleta

-- 7. Lead que já vem com equipe fica nela; sem ninguém disponível não vaza para outra
select pg_temp.reset_roleta() \g /dev/null
delete from leads;
update usuarios set online = true where email in ('ana@lc.com', 'caio@lc.com');
do $$
declare v bigint; v_f uuid := (select id from equipes where nome = 'Furiosos');
begin
  v := pg_temp.lead('85950000001', jsonb_build_object('equipe_id', v_f));
  assert (select corretor_id = pg_temp.uid('caio@lc.com') from leads where id = v), 'lead da equipe Furiosos vai para o Caio';
  update usuarios set online = false where email = 'caio@lc.com';
  v := pg_temp.lead('85950000002', jsonb_build_object('equipe_id', v_f));
  assert (select corretor_id is null and aguarda_distribuicao from leads where id = v), 'Furiosos sem ninguém online: espera, não vai para a Winners';
end $$;
\echo ok 07 lead com equipe respeita a equipe

-- 8. Lead que já tem corretor não passa pela roleta nem gasta a vez
select pg_temp.reset_roleta() \g /dev/null
delete from leads;
update usuarios set online = true where email in ('ana@lc.com', 'caio@lc.com');
do $$
declare v bigint;
begin
  v := pg_temp.lead('85960000001', jsonb_build_object('corretor_id', pg_temp.uid('ana@lc.com')));
  assert (select corretor_id = pg_temp.uid('ana@lc.com') from leads where id = v), 'corretor informado é mantido';
  assert not exists (select 1 from roleta_corretores), 'roleta não andou';
  assert not exists (select 1 from lead_responsavel_historico where lead_id = v and motivo = 'fila'), 'sem histórico de fila';
end $$;
\echo ok 08 lead com corretor definido não passa pela roleta

-- 9. "Somente online" desligado inclui quem está offline
select pg_temp.reset_roleta() \g /dev/null
delete from leads;
update distribuicao_config set apenas_online = false;
do $$
begin
  perform pg_temp.lead('85970000001');
  assert (select corretor_id is not null from leads where telefone = '5585970000001'), 'distribui mesmo offline';
end $$;
update distribuicao_config set apenas_online = true;
\echo ok 09 opção de ignorar o status online

-- 10. Fila: lead cancelado não é distribuído; atribuição manual tira da fila
select pg_temp.reset_roleta() \g /dev/null
delete from leads;
do $$
declare a bigint := pg_temp.lead('85980000001'); b bigint := pg_temp.lead('85980000002'); c bigint := pg_temp.lead('85980000003');
begin
  assert (select count(*) from leads where aguarda_distribuicao) = 3, 'três na fila';
  update leads set situacao_id = (select id from workflow_situacoes where flag_cancelado and ativo limit 1),
         motivo_cancelamento_id = (select id from motivos_cancelamento where not exige_descricao limit 1)
   where id = a;
  update leads set corretor_id = pg_temp.uid('caio@lc.com') where id = b;
  assert not (select aguarda_distribuicao from leads where id = b), 'atribuir manualmente tira da fila';
  update usuarios set online = true where email = 'ana@lc.com';
  assert (select corretor_id is null and aguarda_distribuicao from leads where id = a), 'cancelado continua parado';
  assert (select corretor_id = pg_temp.uid('ana@lc.com') from leads where id = c), 'o restante da fila foi para a Ana';
end $$;
\echo ok 10 fila ignora cancelados e atribuições manuais

-- 11. Permissões
select pg_temp.como('ana@lc.com') \g /dev/null
do $$
begin
  update distribuicao_config set ativa = false;
  assert (select ativa from distribuicao_config), 'corretor não liga/desliga a roleta';
  update roleta_corretores set ultima_em = null;
  assert not exists (select 1 from roleta_corretores), 'corretor não enxerga nem altera a roleta';
  begin
    perform distribuir_fila_agora();
    raise exception 'deveria bloquear';
  exception when insufficient_privilege then null;
  end;
  begin
    perform distribuir_lead(1);
    raise exception 'deveria bloquear';
  exception when insufficient_privilege then null;
  end;
end $$;
select pg_temp.como('gestor@lc.com') \g /dev/null
do $$
begin
  update distribuicao_config set apenas_online = true;
  assert (select atualizado_por from distribuicao_config) = auth.uid(), 'registra quem alterou';
  assert distribuir_fila_agora() >= 0, 'gestor distribui a fila';
  assert (select count(*) from v_roleta_corretores) = 3, 'resumo lista os 3 corretores';
end $$;
select pg_temp.admin() \g /dev/null
set role anon;
do $$
begin
  begin
    perform distribuir_fila_agora();
    raise exception 'deveria bloquear';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
\echo ok 11 permissões da roleta

\echo TESTES DA DISTRIBUIÇÃO PASSARAM
