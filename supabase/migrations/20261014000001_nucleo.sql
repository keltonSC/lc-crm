-- =====================================================================
-- LC CRM · núcleo: usuários, equipes, empreendimentos, funil e leads
-- =====================================================================
create extension if not exists citext;

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
  email       citext not null unique,
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
  email                            citext,
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
