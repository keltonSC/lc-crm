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
