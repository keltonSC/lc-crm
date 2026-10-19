# LC CRM — instruções para o Claude

CRM próprio da LC Imóveis (imobiliária em Fortaleza), construído a partir do mapeamento funcional do **CV CRM (Construtor de Vendas)**: mesma experiência de uso, arquitetura e funcionalidades do CV. O visual **não** precisa ser parecido com o do CV.

## Stack

- Next.js 15 (App Router, Server Actions) + React 19 + Tailwind 4, TypeScript.
- Supabase (Postgres + Auth). Deploy no Netlify (`netlify.toml`).
- Regras de negócio do lead (deduplicação, origem fixa, histórico de situação/responsável, permissões por papel) ficam **no banco** (migrations + RLS + funções), não no front.

## Estrutura

- `supabase/migrations/` — aplicadas em ordem; nunca editar uma migration já publicada, criar uma nova.
- `supabase/tests/` — testes SQL (`PGHOST=/tmp PGPORT=54322 ./supabase/tests/run.sh`). Toda regra nova no banco ganha teste.
- `src/app/(app)/` — telas: leads (lista, kanban, detalhe, novo), tarefas, equipe.
- `src/lib/supabase/` — clientes browser/server; a service role só no servidor.

## Domínio

Papéis: gestor, sdr, líder, corretor. Equipes com líder. Empreendimentos e unidades (disponível/reservada/vendida/bloqueada). Funil por `workflow_situacoes`, origens, motivos de cancelamento, conversões, interações (anotação, ligação, e-mail, SMS, WhatsApp) e tarefas/visitas. Acesso só por convite.

## Como trabalhar

- Português nas telas, mensagens de commit e nomes de domínio.
- Antes de criar uma funcionalidade, confira como o CV faz (fluxo e campos) e replique o comportamento.
- Rodar `npm run lint` e `npm run build` antes de cada commit; rodar os testes do banco quando mexer em SQL.
- Segredos só em variáveis de ambiente (`.env.local`, nunca commitado). O repo é público.

## Próximas frentes (backlog)

1. Distribuição automática de leads (roleta por equipe/corretor, respeitando `online`).
2. Integração de entrada de leads (Meta Lead Ads / webhook) chamando `registrar_lead`.
3. Importador do CV via API (leads, histórico, corretores) para migração.
4. Painel de indicadores (funil, tempo por situação, primeiro contato) a partir das views `v_*`.
5. Reservas/propostas sobre unidades.
