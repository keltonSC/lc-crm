-- LC CRM · todas as migrations em um único arquivo, para colar no SQL Editor do Supabase.
-- Gerado de supabase/migrations/*.sql (ordem alfabética). Use só num projeto NOVO e vazio.

-- >>>>>>>>>> 20261014000001_nucleo.sql
-- =====================================================================
-- LC CRM · núcleo: usuários, equipes, empreendimentos, funil e leads
-- =====================================================================
create extension if not exists citext with schema extensions;

-- ---------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------
create type papel_usuario as enum ('gestor', 'sdr', 'lider', 'corretor');
create type tipo_interacao as enum ('anotacao', 'ligacao', 'email', 'sms', 'whatsapp');
create type resultado_ligacao as enum ('atendida', 'nao_atendida', 'nao_existe');
create type tipo_tarefa as enum ('tarefa', 'visita');
create type situacao_tarefa as enum ('pendente', 'andamento', 'concluida', 'cancelada');
create type prioridade_tarefa as enum ('alta', 'normal', 'baixa');
create type situacao_unidade as enum ('disponivel', 'reservada', 'vendida', 'bloqueada');
create type papel_responsavel as enum ('gestor', 'equipe', 'corretor');

-- ---------------------------------------------------------------------
-- Equipes e usuários
-- ---------------------------------------------------------------------
create table equipes (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null unique,
  lider_id    uuid,
  ativa       boolean not null default true,
  created_at  timestamptz not null default now()
);

create table usuarios (
  id          uuid primary key references auth.users (id) on delete cascade,
  nome        text not null,
  email       extensions.citext not null unique,
  telefone    text,
  papel       papel_usuario not null default 'corretor',
  equipe_id   uuid references equipes (id) on delete set null,
  creci       text,
  ativo       boolean not null default true,
  online      boolean not null default false,
  created_at  timestamptz not null default now()
);

alter table equipes
  add constraint equipes_lider_fk foreign key (lider_id) references usuarios (id) on delete set null;

create index on usuarios (equipe_id);

-- ---------------------------------------------------------------------
-- Empreendimentos e unidades
-- ---------------------------------------------------------------------
create table empreendimentos (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null unique,
  tipo          text,                       -- apartamento, casa, lote, sala…
  bairro        text,
  cidade        text not null default 'Fortaleza',
  regiao        text,
  situacao_obra text,                       -- lançamento, em obras, pronto
  ativo         boolean not null default true,
  created_at    timestamptz not null default now()
);

create table unidades (
  id                uuid primary key default gen_random_uuid(),
  empreendimento_id uuid not null references empreendimentos (id) on delete cascade,
  bloco             text,
  andar             int,
  numero            text not null,
  tipologia         text,
  area_m2           numeric(10, 2),
  valor             numeric(14, 2),
  situacao          situacao_unidade not null default 'disponivel',
  created_at        timestamptz not null default now(),
  unique (empreendimento_id, bloco, numero)
);

-- ---------------------------------------------------------------------
-- Cadastros de apoio
-- ---------------------------------------------------------------------
create table origens (
  codigo text primary key,
  nome   text not null
);

create table motivos_cancelamento (
  id              uuid primary key default gen_random_uuid(),
  nome            text not null unique,
  exige_descricao boolean not null default false,
  ativo           boolean not null default true
);

-- Funil configurável. O sistema se guia pelas flags e pela automação,
-- nunca pelo nome da situação (mesma ideia do workflow do CV).
create table workflow_situacoes (
  id             uuid primary key default gen_random_uuid(),
  objeto         text not null default 'lead',
  ordem          int  not null,
  nome           text not null,
  cor            text not null default '#64748b',
  grupo          text,
  flag_inicio    boolean not null default false,
  flag_fim       boolean not null default false,
  flag_cancelado boolean not null default false,
  automacao      text check (automacao in ('visita_agendada', 'visita_realizada', 'reserva')),
  sla_horas      int,
  ativo          boolean not null default true,
  unique (objeto, nome)
);
create unique index workflow_um_inicio   on workflow_situacoes (objeto) where flag_inicio and ativo;
create unique index workflow_automacao_u on workflow_situacoes (objeto, automacao) where automacao is not null and ativo;

-- ---------------------------------------------------------------------
-- Leads
-- ---------------------------------------------------------------------
create table leads (
  id                               bigint generated always as identity primary key,
  nome                             text not null default 'Sem nome',
  email                            extensions.citext,
  telefone                         text,
  identificador_meta               text,
  origem                           text not null default 'ND' references origens (codigo),
  situacao_id                      uuid not null references workflow_situacoes (id),
  gestor_id                        uuid references usuarios (id) on delete set null,
  equipe_id                        uuid references equipes (id) on delete set null,
  corretor_id                      uuid references usuarios (id) on delete set null,
  data_associacao_corretor         timestamptz,
  possibilidade_venda              smallint check (possibilidade_venda between 1 and 5),
  tags                             text[] not null default '{}',
  motivo_cancelamento_id           uuid references motivos_cancelamento (id),
  descricao_cancelamento           text,
  data_cancelamento                timestamptz,
  data_vencimento                  timestamptz,
  data_primeira_interacao_corretor timestamptz,
  data_ultima_interacao            timestamptz,
  data_reativacao                  timestamptz,
  campos_adicionais                jsonb not null default '{}'::jsonb,
  created_by                       uuid references usuarios (id) on delete set null,
  created_at                       timestamptz not null default now(),
  updated_at                       timestamptz not null default now(),
  constraint lead_tem_contato check (email is not null or telefone is not null or identificador_meta is not null)
);
-- Regra do CV: nunca dois leads com o mesmo e-mail, telefone ou id da Meta.
create unique index leads_email_u    on leads (email)              where email is not null;
create unique index leads_telefone_u on leads (telefone)           where telefone is not null;
create unique index leads_meta_u     on leads (identificador_meta) where identificador_meta is not null;
create index on leads (situacao_id);
create index on leads (corretor_id);
create index on leads (equipe_id);
create index on leads (created_at desc);
create index leads_busca on leads using gin (to_tsvector('simple', coalesce(nome, '') || ' ' || coalesce(email::text, '') || ' ' || coalesce(telefone, '')));

create table lead_empreendimentos (
  lead_id           bigint not null references leads (id) on delete cascade,
  empreendimento_id uuid   not null references empreendimentos (id) on delete cascade,
  unidade_id        uuid references unidades (id) on delete set null,
  created_at        timestamptz not null default now(),
  primary key (lead_id, empreendimento_id)
);

-- Cada entrada do lead (o primeiro cadastro e cada retorno).
create table conversoes (
  id         bigint generated always as identity primary key,
  lead_id    bigint not null references leads (id) on delete cascade,
  nome       text   not null,                -- ex.: nome do formulário de anúncio
  origem     text   not null references origens (codigo),
  midia      text,
  campanha   text,
  utm        jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index on conversoes (lead_id, created_at);

create table lead_situacao_historico (
  id          bigint generated always as identity primary key,
  lead_id     bigint not null references leads (id) on delete cascade,
  de_id       uuid references workflow_situacoes (id),
  para_id     uuid not null references workflow_situacoes (id),
  usuario_id  uuid references usuarios (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index on lead_situacao_historico (lead_id, created_at);

create table lead_responsavel_historico (
  id          bigint generated always as identity primary key,
  lead_id     bigint not null references leads (id) on delete cascade,
  papel       papel_responsavel not null,
  de_id       uuid,
  para_id     uuid,
  motivo      text not null default 'manual',   -- manual, cadastro, reativacao, fila
  usuario_id  uuid references usuarios (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index on lead_responsavel_historico (lead_id, created_at);

create table interacoes (
  id          bigint generated always as identity primary key,
  lead_id     bigint not null references leads (id) on delete cascade,
  tipo        tipo_interacao not null,
  resultado   resultado_ligacao,
  descricao   text not null check (char_length(descricao) <= 32000),
  usuario_id  uuid references usuarios (id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  constraint resultado_so_em_ligacao check (resultado is null or tipo = 'ligacao')
);
create index on interacoes (lead_id, created_at desc);

create table tarefas (
  id                bigint generated always as identity primary key,
  lead_id           bigint not null references leads (id) on delete cascade,
  tipo              tipo_tarefa not null default 'tarefa',
  titulo            text not null,
  descricao         text,
  data              timestamptz not null,
  prioridade        prioridade_tarefa not null default 'normal',
  situacao          situacao_tarefa not null default 'pendente',
  responsavel_id    uuid references usuarios (id) on delete set null default auth.uid(),
  empreendimento_id uuid references empreendimentos (id) on delete set null,
  visita_virtual    boolean not null default false,
  lembrete          boolean not null default true,
  concluida_em      timestamptz,
  created_by        uuid references usuarios (id) on delete set null default auth.uid(),
  created_at        timestamptz not null default now()
);
create index on tarefas (responsavel_id, situacao, data);
create index on tarefas (lead_id);

-- >>>>>>>>>> 20261014000002_regras.sql
-- =====================================================================
-- LC CRM · regras de negócio do lead (triggers e funções)
-- As regras ficam no banco para valerem igual na tela, no formulário
-- e nas integrações.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Helpers de sessão
-- ---------------------------------------------------------------------
create or replace function meu_papel() returns papel_usuario
language sql stable security definer set search_path = public, extensions as $$
  select papel from usuarios where id = auth.uid() and ativo
$$;

create or replace function minha_equipe() returns uuid
language sql stable security definer set search_path = public, extensions as $$
  select equipe_id from usuarios where id = auth.uid() and ativo
$$;

create or replace function ve_tudo() returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select coalesce(meu_papel() in ('gestor', 'sdr'), false)
$$;

-- Telefone só com dígitos e DDI. Sem DDI, assume Brasil (+55), como o CV.
create or replace function normalizar_telefone(t text) returns text
language sql immutable set search_path = public as $$
  select case
    when t is null or regexp_replace(t, '\D', '', 'g') = '' then null
    when left(trim(t), 1) = '+' then regexp_replace(t, '\D', '', 'g')
    when length(regexp_replace(t, '\D', '', 'g')) in (10, 11) then '55' || regexp_replace(t, '\D', '', 'g')
    else regexp_replace(t, '\D', '', 'g')
  end
$$;

create or replace function situacao_inicio(p_objeto text default 'lead') returns uuid
language sql stable security definer set search_path = public, extensions as $$
  select id from workflow_situacoes where objeto = p_objeto and flag_inicio and ativo
$$;

-- ---------------------------------------------------------------------
-- Novo usuário do Auth → linha em usuarios.
-- O primeiro usuário do sistema vira gestor (bootstrap).
-- ---------------------------------------------------------------------
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_papel papel_usuario;
begin
  if not exists (select 1 from usuarios) then
    v_papel := 'gestor';
  else
    v_papel := coalesce((new.raw_user_meta_data ->> 'papel')::papel_usuario, 'corretor');
  end if;
  insert into usuarios (id, nome, email, papel, equipe_id, telefone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nome', split_part(new.email, '@', 1)),
    new.email,
    v_papel,
    nullif(new.raw_user_meta_data ->> 'equipe_id', '')::uuid,
    new.raw_user_meta_data ->> 'telefone'
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Ninguém muda o próprio papel ou equipe; só o gestor.
create or replace function usuarios_guarda() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  if auth.uid() is not null and coalesce(meu_papel()::text, '') <> 'gestor'
     and (new.papel is distinct from old.papel or new.equipe_id is distinct from old.equipe_id
          or new.ativo is distinct from old.ativo or new.email is distinct from old.email) then
    raise exception 'Só o gestor altera papel, equipe, e-mail ou status de um usuário'
      using errcode = '42501';
  end if;
  return new;
end $$;

create trigger usuarios_guarda before update on usuarios
  for each row execute function usuarios_guarda();

-- ---------------------------------------------------------------------
-- Leads · antes de gravar
-- ---------------------------------------------------------------------
create or replace function leads_antes() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_sit       workflow_situacoes;
  v_papel     papel_usuario := meu_papel();
  v_motivo    motivos_cancelamento;
  v_eq_corr   uuid;
  v_sistema   boolean := auth.uid() is null or current_setting('lc.sistema', true) = 'on';
begin
  -- Normalização dos contatos
  new.telefone := normalizar_telefone(new.telefone);
  new.email    := nullif(lower(trim(new.email::text)), '');
  new.nome     := coalesce(nullif(trim(new.nome), ''), 'Sem nome');

  if tg_op = 'INSERT' then
    new.situacao_id := coalesce(new.situacao_id, situacao_inicio('lead'));
    if new.situacao_id is null then
      raise exception 'Não existe situação de início ativa no funil';
    end if;
    new.created_by := coalesce(new.created_by, auth.uid());
    -- Corretor que cadastra fica como responsável do próprio lead;
    -- líder só cadastra para a própria equipe.
    if not v_sistema then
      if v_papel = 'corretor' then
        new.corretor_id := auth.uid();
        new.equipe_id   := minha_equipe();
        new.gestor_id   := null;
      elsif v_papel = 'lider' then
        new.equipe_id := minha_equipe();
        new.gestor_id := null;
      end if;
    end if;
  else
    -- Origem é gravada no cadastro e nunca muda
    if new.origem is distinct from old.origem then
      raise exception 'A origem do lead não pode ser alterada' using errcode = '42501';
    end if;
    -- Quem pode trocar responsáveis (regra do CV)
    if not v_sistema then
      if v_papel = 'corretor' and (new.gestor_id is distinct from old.gestor_id
           or new.equipe_id is distinct from old.equipe_id
           or new.corretor_id is distinct from old.corretor_id) then
        raise exception 'Corretor não pode trocar gestor, equipe ou corretor do lead' using errcode = '42501';
      end if;
      if v_papel = 'lider' and (new.gestor_id is distinct from old.gestor_id
           or new.equipe_id is distinct from old.equipe_id) then
        raise exception 'Líder não pode trocar gestor ou equipe do lead' using errcode = '42501';
      end if;
    end if;
    new.updated_at := now();
  end if;

  -- Corretor precisa pertencer à equipe do lead
  if new.corretor_id is not null then
    select equipe_id into v_eq_corr from usuarios where id = new.corretor_id;
    if new.equipe_id is null then
      new.equipe_id := v_eq_corr;
    elsif v_eq_corr is distinct from new.equipe_id then
      raise exception 'O corretor não pertence à equipe do lead' using errcode = '23514';
    end if;
    if tg_op = 'INSERT' or new.corretor_id is distinct from old.corretor_id then
      new.data_associacao_corretor := now();
    end if;
  end if;

  -- Cancelamento exige motivo (e descrição, se o motivo pedir)
  select * into v_sit from workflow_situacoes where id = new.situacao_id;
  if v_sit.flag_cancelado then
    if new.motivo_cancelamento_id is null then
      raise exception 'Informe o motivo para cancelar o lead' using errcode = '23514';
    end if;
    select * into v_motivo from motivos_cancelamento where id = new.motivo_cancelamento_id;
    if v_motivo.exige_descricao and coalesce(trim(new.descricao_cancelamento), '') = '' then
      raise exception 'Este motivo exige uma descrição' using errcode = '23514';
    end if;
    if tg_op = 'INSERT' or new.situacao_id is distinct from old.situacao_id then
      new.data_cancelamento := now();
    end if;
  elsif tg_op = 'UPDATE' and new.situacao_id is distinct from old.situacao_id then
    -- Saiu do cancelado: limpa o motivo atual (o histórico guarda o passado)
    new.motivo_cancelamento_id := null;
    new.descricao_cancelamento := null;
    new.data_cancelamento      := null;
  end if;

  return new;
end $$;

create trigger leads_antes before insert or update on leads
  for each row execute function leads_antes();

-- ---------------------------------------------------------------------
-- Leads · depois de gravar: históricos de situação e de responsáveis
-- ---------------------------------------------------------------------
create or replace function leads_depois() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_motivo text := coalesce(nullif(current_setting('lc.motivo_resp', true), ''),
                            case when tg_op = 'INSERT' then 'cadastro' else 'manual' end);
begin
  if tg_op = 'INSERT' then
    insert into lead_situacao_historico (lead_id, de_id, para_id, usuario_id)
    values (new.id, null, new.situacao_id, auth.uid());
  elsif new.situacao_id is distinct from old.situacao_id then
    insert into lead_situacao_historico (lead_id, de_id, para_id, usuario_id)
    values (new.id, old.situacao_id, new.situacao_id, auth.uid());
  end if;

  if new.gestor_id is distinct from (case when tg_op = 'INSERT' then null else old.gestor_id end) then
    insert into lead_responsavel_historico (lead_id, papel, de_id, para_id, motivo, usuario_id)
    values (new.id, 'gestor', case when tg_op = 'UPDATE' then old.gestor_id end, new.gestor_id, v_motivo, auth.uid());
  end if;
  if new.equipe_id is distinct from (case when tg_op = 'INSERT' then null else old.equipe_id end) then
    insert into lead_responsavel_historico (lead_id, papel, de_id, para_id, motivo, usuario_id)
    values (new.id, 'equipe', case when tg_op = 'UPDATE' then old.equipe_id end, new.equipe_id, v_motivo, auth.uid());
  end if;
  if new.corretor_id is distinct from (case when tg_op = 'INSERT' then null else old.corretor_id end) then
    insert into lead_responsavel_historico (lead_id, papel, de_id, para_id, motivo, usuario_id)
    values (new.id, 'corretor', case when tg_op = 'UPDATE' then old.corretor_id end, new.corretor_id, v_motivo, auth.uid());
  end if;
  return null;
end $$;

create trigger leads_depois after insert or update on leads
  for each row execute function leads_depois();

-- ---------------------------------------------------------------------
-- Interações: atualiza última interação e o primeiro contato do corretor
-- ---------------------------------------------------------------------
create or replace function interacoes_depois() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform set_config('lc.sistema', 'on', true);
  update leads l set
    data_ultima_interacao = new.created_at,
    data_primeira_interacao_corretor = case
      when l.data_primeira_interacao_corretor is null and l.corretor_id = new.usuario_id
      then new.created_at else l.data_primeira_interacao_corretor end
  where l.id = new.lead_id;
  perform set_config('lc.sistema', 'off', true);
  return null;
end $$;

create trigger interacoes_depois after insert on interacoes
  for each row execute function interacoes_depois();

-- ---------------------------------------------------------------------
-- Automação de visitas: move o lead para a etapa da visita,
-- só para frente e nunca tirando o lead de Fim ou Cancelado.
-- ---------------------------------------------------------------------
create or replace function mover_lead_por_automacao(p_lead bigint, p_automacao text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare
  v_alvo  workflow_situacoes;
  v_atual workflow_situacoes;
begin
  select * into v_alvo from workflow_situacoes
   where objeto = 'lead' and automacao = p_automacao and ativo;
  if not found then return; end if;
  select s.* into v_atual from leads l join workflow_situacoes s on s.id = l.situacao_id where l.id = p_lead;
  if v_atual.flag_fim or v_atual.flag_cancelado or v_atual.ordem >= v_alvo.ordem then
    return;
  end if;
  perform set_config('lc.sistema', 'on', true);
  update leads set situacao_id = v_alvo.id where id = p_lead;
  perform set_config('lc.sistema', 'off', true);
end $$;

create or replace function tarefas_antes() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.situacao = 'concluida' and (tg_op = 'INSERT' or old.situacao is distinct from 'concluida') then
    new.concluida_em := now();
  elsif new.situacao <> 'concluida' then
    new.concluida_em := null;
  end if;
  return new;
end $$;

create trigger tarefas_antes before insert or update on tarefas
  for each row execute function tarefas_antes();

create or replace function tarefas_depois() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  if new.tipo = 'visita' then
    if new.situacao in ('pendente', 'andamento') then
      perform mover_lead_por_automacao(new.lead_id, 'visita_agendada');
    elsif new.situacao = 'concluida' then
      perform mover_lead_por_automacao(new.lead_id, 'visita_realizada');
    end if;
  end if;
  return null;
end $$;

create trigger tarefas_depois after insert or update of situacao on tarefas
  for each row execute function tarefas_depois();

-- ---------------------------------------------------------------------
-- Entrada única de leads (tela, formulários, Meta, site).
-- Deduplica por e-mail, telefone ou id da Meta. Lead existente não é
-- duplicado: ganha uma conversão e, se estava cancelado, é reativado.
-- ---------------------------------------------------------------------
create or replace function registrar_lead(p jsonb)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_email    extensions.citext := nullif(lower(trim(p ->> 'email')), '');
  v_tel      text   := normalizar_telefone(p ->> 'telefone');
  v_meta     text   := nullif(trim(p ->> 'identificador_meta'), '');
  v_origem   text   := coalesce(nullif(p ->> 'origem', ''), 'ND');
  v_conv     text   := coalesce(nullif(p ->> 'conversao', ''), nullif(p ->> 'origem', ''), 'Cadastro manual');
  v_lead     leads;
  v_novo     boolean := false;
  v_reativ   boolean := false;
  v_sit      workflow_situacoes;
  v_emp      uuid;
begin
  if v_email is null and v_tel is null and v_meta is null then
    raise exception 'Informe e-mail, telefone ou identificador da Meta' using errcode = '23514';
  end if;
  if not exists (select 1 from origens where codigo = v_origem) then
    v_origem := 'ND';
  end if;

  select * into v_lead from leads
   where (v_email is not null and email = v_email)
      or (v_tel   is not null and telefone = v_tel)
      or (v_meta  is not null and identificador_meta = v_meta)
   order by created_at
   limit 1
   for update;

  if not found then
    v_novo := true;
    insert into leads (nome, email, telefone, identificador_meta, origem,
                       gestor_id, equipe_id, corretor_id, possibilidade_venda, tags, campos_adicionais)
    values (
      p ->> 'nome', v_email, v_tel, v_meta, v_origem,
      nullif(p ->> 'gestor_id', '')::uuid,
      nullif(p ->> 'equipe_id', '')::uuid,
      nullif(p ->> 'corretor_id', '')::uuid,
      nullif(p ->> 'possibilidade_venda', '')::smallint,
      coalesce((select array_agg(x) from jsonb_array_elements_text(p -> 'tags') x), '{}'),
      coalesce(p -> 'campos_adicionais', '{}'::jsonb)
    )
    returning * into v_lead;
  else
    perform set_config('lc.sistema', 'on', true);
    -- Completa contatos que faltavam
    update leads set
      email              = coalesce(email, v_email),
      telefone           = case when telefone is null and v_tel is not null
                                 and not exists (select 1 from leads where telefone = v_tel) then v_tel else telefone end,
      identificador_meta = case when identificador_meta is null and v_meta is not null
                                 and not exists (select 1 from leads where identificador_meta = v_meta) then v_meta else identificador_meta end,
      nome               = case when nome = 'Sem nome' then coalesce(nullif(p ->> 'nome', ''), nome) else nome end
    where id = v_lead.id
    returning * into v_lead;

    -- Reativação: lead cancelado volta para o início
    select * into v_sit from workflow_situacoes where id = v_lead.situacao_id;
    if v_sit.flag_cancelado and coalesce((p ->> 'reativar')::boolean, true) then
      v_reativ := true;
      perform set_config('lc.motivo_resp', 'reativacao', true);
      update leads set situacao_id = situacao_inicio('lead'), data_reativacao = now()
       where id = v_lead.id returning * into v_lead;
      perform set_config('lc.motivo_resp', '', true);
    end if;
    perform set_config('lc.sistema', 'off', true);
  end if;

  insert into conversoes (lead_id, nome, origem, midia, campanha, utm)
  values (v_lead.id, v_conv, v_origem, p ->> 'midia', p ->> 'campanha', coalesce(p -> 'utm', '{}'::jsonb));

  -- Empreendimentos de interesse
  for v_emp in select (jsonb_array_elements_text(coalesce(p -> 'empreendimentos', '[]'::jsonb)))::uuid loop
    insert into lead_empreendimentos (lead_id, empreendimento_id)
    values (v_lead.id, v_emp) on conflict do nothing;
  end loop;

  return jsonb_build_object('id', v_lead.id, 'novo', v_novo, 'reativado', v_reativ);
end $$;

revoke all on function registrar_lead(jsonb) from public, anon;
grant execute on function registrar_lead(jsonb) to authenticated, service_role;

-- >>>>>>>>>> 20261014000003_permissoes.sql
-- =====================================================================
-- LC CRM · permissões (RLS)
--   gestor / sdr → veem e editam tudo
--   líder        → leads da própria equipe
--   corretor     → só os próprios leads
-- =====================================================================

alter table equipes                    enable row level security;
alter table usuarios                   enable row level security;
alter table empreendimentos            enable row level security;
alter table unidades                   enable row level security;
alter table origens                    enable row level security;
alter table motivos_cancelamento       enable row level security;
alter table workflow_situacoes         enable row level security;
alter table leads                      enable row level security;
alter table lead_empreendimentos       enable row level security;
alter table conversoes                 enable row level security;
alter table lead_situacao_historico    enable row level security;
alter table lead_responsavel_historico enable row level security;
alter table interacoes                 enable row level security;
alter table tarefas                    enable row level security;

-- Cadastros: todos os usuários ativos leem; só o gestor escreve.
do $$
declare t text;
begin
  foreach t in array array['equipes', 'empreendimentos', 'unidades', 'origens',
                           'motivos_cancelamento', 'workflow_situacoes'] loop
    execute format('create policy %1$s_ler on %1$I for select to authenticated using (meu_papel() is not null)', t);
    execute format('create policy %1$s_gestor on %1$I for all to authenticated using (meu_papel() = ''gestor'') with check (meu_papel() = ''gestor'')', t);
  end loop;
end $$;

-- Usuários
create policy usuarios_ler on usuarios for select to authenticated
  using (id = auth.uid() or meu_papel() is not null);
create policy usuarios_editar_proprio on usuarios for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy usuarios_gestor on usuarios for all to authenticated
  using (meu_papel() = 'gestor') with check (meu_papel() = 'gestor');

-- Leads
create or replace function pode_ver_lead(l leads) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select case meu_papel()
    when 'gestor'   then true
    when 'sdr'      then true
    when 'lider'    then l.equipe_id is not null and l.equipe_id = minha_equipe()
    when 'corretor' then l.corretor_id = auth.uid()
    else false
  end
$$;

create policy leads_ler on leads for select to authenticated
  using (pode_ver_lead(leads));
create policy leads_criar on leads for insert to authenticated
  with check (meu_papel() is not null);
create policy leads_editar on leads for update to authenticated
  using (pode_ver_lead(leads)) with check (meu_papel() is not null);
create policy leads_excluir on leads for delete to authenticated
  using (meu_papel() = 'gestor');

-- Tabelas filhas: segue a visibilidade do lead.
do $$
declare t text;
begin
  foreach t in array array['lead_empreendimentos', 'conversoes', 'interacoes', 'tarefas',
                           'lead_situacao_historico', 'lead_responsavel_historico'] loop
    execute format('create policy %1$s_ler on %1$I for select to authenticated
                    using (exists (select 1 from leads l where l.id = lead_id))', t);
  end loop;
  foreach t in array array['lead_empreendimentos', 'tarefas'] loop
    execute format('create policy %1$s_criar on %1$I for insert to authenticated
                    with check (exists (select 1 from leads l where l.id = lead_id))', t);
  end loop;
end $$;

-- Interação é sempre registrada em nome de quem está logado.
create policy interacoes_criar on interacoes for insert to authenticated
  with check (usuario_id = auth.uid() and exists (select 1 from leads l where l.id = lead_id));

create policy lead_empreendimentos_excluir on lead_empreendimentos for delete to authenticated
  using (exists (select 1 from leads l where l.id = lead_id));

-- Interação: só o autor edita/apaga, ou o gestor.
create policy interacoes_editar on interacoes for update to authenticated
  using (usuario_id = auth.uid() or meu_papel() = 'gestor');
create policy interacoes_excluir on interacoes for delete to authenticated
  using (usuario_id = auth.uid() or meu_papel() = 'gestor');

-- Tarefas: quem vê o lead atualiza; apaga quem criou ou o gestor.
create policy tarefas_editar on tarefas for update to authenticated
  using (exists (select 1 from leads l where l.id = lead_id) or responsavel_id = auth.uid());
create policy tarefas_excluir on tarefas for delete to authenticated
  using (created_by = auth.uid() or meu_papel() = 'gestor');

-- Históricos e conversões são escritos só pelos triggers e pela
-- função registrar_lead (security definer): sem policy de escrita.

-- Funções auxiliares: fora do alcance do anônimo; a automação de visita
-- só roda por dentro dos triggers.
revoke execute on function meu_papel(), minha_equipe(), ve_tudo(), pode_ver_lead(leads),
  situacao_inicio(text) from public, anon;
grant execute on function meu_papel(), minha_equipe(), ve_tudo(), pode_ver_lead(leads),
  situacao_inicio(text) to authenticated, service_role;
revoke execute on function mover_lead_por_automacao(bigint, text) from public, anon, authenticated;

-- >>>>>>>>>> 20261014000004_views_e_dados.sql
-- =====================================================================
-- LC CRM · views (respeitam o RLS de quem consulta) e dados iniciais
-- =====================================================================

-- Lista de leads já com nomes resolvidos, para as telas
create view v_leads with (security_invoker = true) as
select
  l.*,
  s.nome   as situacao_nome,
  s.cor    as situacao_cor,
  s.ordem  as situacao_ordem,
  s.flag_fim, s.flag_cancelado,
  o.nome   as origem_nome,
  e.nome   as equipe_nome,
  c.nome   as corretor_nome,
  g.nome   as gestor_nome,
  (select string_agg(em.nome, ', ' order by em.nome)
     from lead_empreendimentos le join empreendimentos em on em.id = le.empreendimento_id
    where le.lead_id = l.id) as empreendimentos,
  (select cv.nome from conversoes cv where cv.lead_id = l.id order by cv.created_at limit 1)      as conversao_original,
  (select cv.nome from conversoes cv where cv.lead_id = l.id order by cv.created_at desc limit 1) as conversao_ultima,
  (select count(*) from conversoes cv where cv.lead_id = l.id)                                    as total_conversoes,
  (select min(t.data) from tarefas t where t.lead_id = l.id and t.situacao in ('pendente', 'andamento')) as proxima_tarefa,
  (s.sla_horas is not null and not s.flag_fim and not s.flag_cancelado
     and now() > coalesce((select max(h.created_at) from lead_situacao_historico h where h.lead_id = l.id), l.created_at)
                 + make_interval(hours => s.sla_horas)) as sla_estourado
from leads l
join workflow_situacoes s on s.id = l.situacao_id
join origens o            on o.codigo = l.origem
left join equipes  e      on e.id = l.equipe_id
left join usuarios c      on c.id = l.corretor_id
left join usuarios g      on g.id = l.gestor_id;

-- Funil: quantidade de leads por situação
create view v_funil with (security_invoker = true) as
select s.id, s.ordem, s.nome, s.cor, s.flag_fim, s.flag_cancelado, count(l.id) as total
from workflow_situacoes s
left join leads l on l.situacao_id = s.id
where s.objeto = 'lead' and s.ativo
group by s.id
order by s.ordem;

-- Tempo que cada lead ficou em cada situação
create view v_tempo_situacao with (security_invoker = true) as
select
  h.lead_id,
  h.para_id as situacao_id,
  s.nome    as situacao,
  h.created_at as entrou_em,
  lead(h.created_at) over w as saiu_em,
  coalesce(lead(h.created_at) over w, now()) - h.created_at as duracao
from lead_situacao_historico h
join workflow_situacoes s on s.id = h.para_id
window w as (partition by h.lead_id order by h.created_at, h.id);

-- Tempo até o primeiro contato do corretor
create view v_primeiro_contato with (security_invoker = true) as
select
  l.id as lead_id, l.corretor_id, c.nome as corretor, l.equipe_id,
  l.data_associacao_corretor, l.data_primeira_interacao_corretor,
  l.data_primeira_interacao_corretor - l.data_associacao_corretor as tempo_resposta
from leads l
left join usuarios c on c.id = l.corretor_id
where l.corretor_id is not null;

-- ---------------------------------------------------------------------
-- Dados iniciais
-- ---------------------------------------------------------------------
insert into origens (codigo, nome) values
  ('FB', 'Facebook'), ('IG', 'Instagram'), ('WA', 'WhatsApp'), ('GO', 'Google'),
  ('SI', 'Site'), ('PO', 'Portais'), ('LI', 'Ligação'), ('EM', 'E-mail'),
  ('RF', 'Indicação'), ('MP', 'Mídia paga'), ('BO', 'Busca orgânica'),
  ('TT', 'TikTok'), ('LK', 'LinkedIn'), ('CH', 'Chat online'), ('CB', 'Chatbot'),
  ('TD', 'Tráfego direto'), ('RM', 'Remarketing'), ('PV', 'Plantão / PDV'),
  ('GE', 'Painel gestor'), ('CO', 'Painel corretor'), ('CV', 'Importado do CV'),
  ('OU', 'Outros'), ('ND', 'Não definido');

-- Funil espelhando as etapas usadas hoje no CV da LC
insert into workflow_situacoes (ordem, nome, cor, grupo, flag_inicio, flag_fim, flag_cancelado, automacao, sla_horas) values
  (10, 'Novo',                    '#94a3b8', 'Entrada',     true,  false, false, null,               1),
  (20, 'Aguardando atendimento',  '#ec4899', 'Entrada',     false, false, false, null,               2),
  (30, 'Em atendimento',          '#f97316', 'Atendimento', false, false, false, null,               72),
  (40, 'Visita agendada',         '#06b6d4', 'Visita',      false, false, false, 'visita_agendada',  null),
  (50, 'Visita realizada',        '#0891b2', 'Visita',      false, false, false, 'visita_realizada', 72),
  (60, 'Análise de crédito',      '#8b5cf6', 'Negociação',  false, false, false, null,               null),
  (70, 'Reserva',                 '#3b82f6', 'Negociação',  false, false, false, 'reserva',          null),
  (80, 'Venda realizada',         '#16a34a', 'Fim',         false, true,  false, null,               null),
  (90, 'Cancelado',               '#1f2937', 'Fim',         false, false, true,  null,               null);

insert into motivos_cancelamento (nome, exige_descricao) values
  ('Sem contato após tentativas', false),
  ('Sem interesse',               false),
  ('Sem renda / crédito',         false),
  ('Comprou com concorrente',     true),
  ('Localização não atende',      false),
  ('Valor acima do orçamento',    false),
  ('Contato inválido',            false),
  ('Duplicado',                   false),
  ('Outro',                       true);

insert into equipes (nome) values ('Winners'), ('Furiosos'), ('Select');

-- >>>>>>>>>> 20261014000005_fechar_funcoes_trigger.sql
-- Funções de trigger não precisam ser chamadas pela API.
-- (meu_papel, minha_equipe, ve_tudo, pode_ver_lead e situacao_inicio ficam
--  liberadas ao usuário logado de propósito: as policies de RLS dependem delas
--  e elas só devolvem dados do próprio usuário. registrar_lead é a entrada
--  oficial de leads.)
revoke execute on function
  handle_new_user(), usuarios_guarda(), leads_antes(), leads_depois(),
  interacoes_depois(), tarefas_antes(), tarefas_depois()
from public, anon, authenticated;

-- >>>>>>>>>> 20261018000006_convites.sql
-- =====================================================================
-- LC CRM · convites
-- Antes, o papel vinha dos metadados do cadastro — qualquer pessoa que se
-- cadastrasse pela API pública poderia se declarar gestor. Agora o papel e a
-- equipe vêm só de um convite criado pelo gestor. Quem se cadastra sem
-- convite fica inativo (sem acesso a nada).
-- =====================================================================

create table convites (
  email      extensions.citext primary key,
  nome       text,
  papel      papel_usuario not null default 'corretor',
  equipe_id  uuid references equipes (id) on delete set null,
  telefone   text,
  criado_por uuid references usuarios (id) on delete set null default auth.uid(),
  usado_em   timestamptz,
  created_at timestamptz not null default now()
);

alter table convites enable row level security;
create policy convites_gestor on convites for all to authenticated
  using (meu_papel() = 'gestor') with check (meu_papel() = 'gestor');

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  c convites;
begin
  select * into c from convites where email = new.email and usado_em is null;
  insert into usuarios (id, nome, email, papel, equipe_id, telefone, ativo)
  values (
    new.id,
    coalesce(c.nome, new.raw_user_meta_data ->> 'nome', split_part(new.email, '@', 1)),
    new.email,
    coalesce(c.papel, 'corretor'),
    c.equipe_id,
    coalesce(c.telefone, new.raw_user_meta_data ->> 'telefone'),
    c.email is not null            -- sem convite: entra inativo
  );
  if c.email is not null then
    update convites set usado_em = now() where email = c.email;
  end if;
  return new;
end $$;

revoke execute on function handle_new_user() from public, anon, authenticated;

-- >>>>>>>>>> 20261019000007_distribuicao_leads.sql
-- =====================================================================
-- LC CRM · distribuição automática de leads (roleta)
--
-- Todo lead novo que entra sem corretor passa pela roleta:
--   1. escolhe a equipe que está há mais tempo sem receber lead
--      (se o lead já veio com equipe, fica nela);
--   2. dentro da equipe, escolhe o corretor que está há mais tempo sem receber;
--   3. só entram corretores ativos, que participam da roleta e — quando a
--      opção "somente online" está ligada — que estão online.
-- Sem ninguém disponível o lead espera na fila (aguarda_distribuicao) e é
-- distribuído quando um corretor fica online ou quando o gestor manda
-- "Distribuir fila agora". A regra vale igual para tela, formulários e
-- integrações porque roda em trigger.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Configuração (uma única linha) e estado da roleta
-- ---------------------------------------------------------------------
create table distribuicao_config (
  id             boolean primary key default true check (id),
  ativa          boolean not null default false,
  apenas_online  boolean not null default true,
  atualizado_em  timestamptz not null default now(),
  atualizado_por uuid references usuarios (id) on delete set null
);
insert into distribuicao_config default values;

-- Ausência de linha = participa. ultima_em é a vez da roleta.
create table roleta_equipes (
  equipe_id uuid primary key references equipes (id) on delete cascade,
  participa boolean not null default true,
  ultima_em timestamptz
);
create table roleta_corretores (
  usuario_id uuid primary key references usuarios (id) on delete cascade,
  participa  boolean not null default true,
  ultima_em  timestamptz
);

alter table leads add column aguarda_distribuicao boolean not null default false;
create index leads_fila on leads (created_at) where aguarda_distribuicao;

alter table distribuicao_config enable row level security;
alter table roleta_equipes      enable row level security;
alter table roleta_corretores   enable row level security;
create policy distribuicao_config_ler    on distribuicao_config for select to authenticated using (meu_papel() is not null);
create policy distribuicao_config_gestor on distribuicao_config for update to authenticated
  using (meu_papel() = 'gestor') with check (meu_papel() = 'gestor');
create policy roleta_equipes_gestor    on roleta_equipes    for all to authenticated
  using (meu_papel() = 'gestor') with check (meu_papel() = 'gestor');
create policy roleta_corretores_gestor on roleta_corretores for all to authenticated
  using (meu_papel() = 'gestor') with check (meu_papel() = 'gestor');

create or replace function distribuicao_config_antes() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  new.atualizado_em  := now();
  new.atualizado_por := auth.uid();
  return new;
end $$;
create trigger distribuicao_config_antes before update on distribuicao_config
  for each row execute function distribuicao_config_antes();

-- ---------------------------------------------------------------------
-- Quem pode receber lead agora, na ordem da roleta
-- ---------------------------------------------------------------------
create or replace function corretores_elegiveis(p_equipe uuid)
returns table (usuario_id uuid, ultima_em timestamptz)
language sql stable security definer set search_path = public, extensions as $$
  select u.id, rc.ultima_em
    from usuarios u
    left join roleta_corretores rc on rc.usuario_id = u.id
   where u.equipe_id = p_equipe
     and u.papel = 'corretor'
     and u.ativo
     and coalesce(rc.participa, true)
     and (u.online or not (select apenas_online from distribuicao_config))
   order by rc.ultima_em nulls first, u.nome, u.id
$$;

-- ---------------------------------------------------------------------
-- Distribui um lead sem corretor. Devolve {atribuido, ...}.
-- ---------------------------------------------------------------------
create or replace function distribuir_lead(p_lead bigint) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  cfg        distribuicao_config;
  v_lead     leads;
  v_equipe   uuid;
  v_corretor uuid;
  v_sistema  text := current_setting('lc.sistema', true);
  v_motivo   text := current_setting('lc.motivo_resp', true);
begin
  -- Um lead por vez: duas entradas simultâneas não podem escolher o mesmo corretor
  perform pg_advisory_xact_lock(hashtext('lc_roleta'));

  select * into cfg from distribuicao_config;
  if not cfg.ativa then
    return jsonb_build_object('atribuido', false, 'motivo', 'desativada');
  end if;

  select * into v_lead from leads where id = p_lead for update;
  if not found or v_lead.corretor_id is not null then
    return jsonb_build_object('atribuido', false, 'motivo', 'ja_atribuido');
  end if;

  v_equipe := v_lead.equipe_id;
  if v_equipe is null then
    select e.id into v_equipe
      from equipes e
      left join roleta_equipes re on re.equipe_id = e.id
     where e.ativa
       and coalesce(re.participa, true)
       and exists (select 1 from corretores_elegiveis(e.id))
     order by re.ultima_em nulls first, e.nome, e.id
     limit 1;
  elsif not exists (select 1 from equipes e left join roleta_equipes re on re.equipe_id = e.id
                     where e.id = v_equipe and e.ativa and coalesce(re.participa, true)) then
    v_equipe := null;
  end if;

  if v_equipe is not null then
    select usuario_id into v_corretor from corretores_elegiveis(v_equipe) limit 1;
  end if;

  if v_corretor is null then
    -- Ninguém disponível: espera na fila
    if not v_lead.aguarda_distribuicao then
      perform set_config('lc.sistema', 'on', true);
      update leads set aguarda_distribuicao = true where id = p_lead;
      perform set_config('lc.sistema', coalesce(v_sistema, 'off'), true);
    end if;
    return jsonb_build_object('atribuido', false, 'motivo', 'sem_corretor_disponivel');
  end if;

  perform set_config('lc.sistema', 'on', true);
  perform set_config('lc.motivo_resp', 'fila', true);
  update leads set corretor_id = v_corretor, equipe_id = v_equipe, aguarda_distribuicao = false
   where id = p_lead;
  perform set_config('lc.sistema', coalesce(v_sistema, 'off'), true);
  perform set_config('lc.motivo_resp', coalesce(v_motivo, ''), true);

  insert into roleta_equipes (equipe_id, ultima_em) values (v_equipe, clock_timestamp())
    on conflict (equipe_id) do update set ultima_em = excluded.ultima_em;
  insert into roleta_corretores (usuario_id, ultima_em) values (v_corretor, clock_timestamp())
    on conflict (usuario_id) do update set ultima_em = excluded.ultima_em;

  return jsonb_build_object('atribuido', true, 'equipe_id', v_equipe, 'corretor_id', v_corretor);
end $$;

-- Processa a fila (do mais antigo para o mais novo). Devolve quantos foram distribuídos.
create or replace function distribuir_fila(p_limite int default 50) returns int
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_id bigint;
  v_n  int := 0;
begin
  for v_id in
    select l.id from leads l
      join workflow_situacoes s on s.id = l.situacao_id
     where l.aguarda_distribuicao and l.corretor_id is null
       and not s.flag_fim and not s.flag_cancelado
     order by l.created_at, l.id
     limit p_limite
  loop
    if (distribuir_lead(v_id) ->> 'atribuido')::boolean then
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end $$;

-- Botão "Distribuir fila agora" da tela do gestor
create or replace function distribuir_fila_agora() returns int
language plpgsql security definer set search_path = public, extensions as $$
begin
  if coalesce(meu_papel()::text, '') <> 'gestor' then
    raise exception 'Só o gestor distribui a fila' using errcode = '42501';
  end if;
  return distribuir_fila(200);
end $$;

-- ---------------------------------------------------------------------
-- Gatilhos
-- ---------------------------------------------------------------------
-- Lead novo sem corretor entra na roleta.
create or replace function leads_distribuir_depois() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  if new.corretor_id is null then
    perform distribuir_lead(new.id);
  end if;
  return null;
end $$;
create trigger leads_distribuir after insert on leads
  for each row execute function leads_distribuir_depois();

-- Quem tem corretor definido (por qualquer meio) sai da fila.
create or replace function leads_fila_antes() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.corretor_id is not null then
    new.aguarda_distribuicao := false;
  end if;
  return new;
end $$;
create trigger leads_fila_antes before insert or update on leads
  for each row execute function leads_fila_antes();

-- Corretor ficou online: a fila anda.
create or replace function usuarios_online_depois() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  if new.online and not old.online and new.papel = 'corretor' and new.ativo then
    perform distribuir_fila(20);
  end if;
  return null;
end $$;
create trigger usuarios_online_depois after update of online on usuarios
  for each row execute function usuarios_online_depois();

-- ---------------------------------------------------------------------
-- Resumo para a tela de configuração (respeita o RLS de quem consulta)
-- ---------------------------------------------------------------------
create view v_roleta_corretores with (security_invoker = true) as
select
  u.id, u.nome, u.equipe_id, u.online,
  coalesce(rc.participa, true) as participa,
  rc.ultima_em,
  (select count(*) from lead_responsavel_historico h
    where h.papel = 'corretor' and h.motivo = 'fila' and h.para_id = u.id
      and h.created_at > now() - interval '30 days') as recebidos_30d
from usuarios u
left join roleta_corretores rc on rc.usuario_id = u.id
where u.papel = 'corretor' and u.ativo;

-- ---------------------------------------------------------------------
-- Permissões das funções
-- ---------------------------------------------------------------------
revoke execute on function
  distribuicao_config_antes(), corretores_elegiveis(uuid), distribuir_lead(bigint), distribuir_fila(int),
  leads_distribuir_depois(), leads_fila_antes(), usuarios_online_depois()
from public, anon, authenticated;
revoke execute on function distribuir_fila_agora() from public, anon;
grant execute on function distribuir_fila_agora() to authenticated, service_role;

-- >>>>>>>>>> 20261019000008_entradas_leads.sql
-- =====================================================================
-- LC CRM · log de entrada de leads por integração (API, Meta, portais)
-- Todo payload recebido é gravado antes de ser processado, para auditar
-- e reprocessar quando algo falhar. Escrita só pela service role.
-- =====================================================================

create table entradas_leads (
  id            bigint generated always as identity primary key,
  fonte         text not null,                      -- api, meta, olx, chaves_na_mao…
  payload       jsonb not null,
  status        text not null default 'recebido'
                  check (status in ('recebido', 'processado', 'erro', 'ignorado')),
  lead_id       bigint references leads (id) on delete set null,
  erro          text,
  created_at    timestamptz not null default now(),
  processado_em timestamptz
);
create index on entradas_leads (created_at desc);
create index on entradas_leads (status) where status in ('recebido', 'erro');

alter table entradas_leads enable row level security;
create policy entradas_leads_gestor on entradas_leads for select to authenticated
  using (meu_papel() = 'gestor');
-- Sem policy de escrita: só a service role grava.
