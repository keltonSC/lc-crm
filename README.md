# LC CRM

CRM da LC Imóveis: leads, funil, agenda e equipes. Next.js 15 + Supabase.

## Rodar local

```bash
cp .env.example .env.local   # preencha com as chaves do projeto Supabase
npm install
npm run dev
```

## Banco

As migrations ficam em `supabase/migrations` e são aplicadas em ordem.
As regras do lead (deduplicação, origem fixa, histórico, permissões) vivem no banco.

Testes do banco num Postgres local:

```bash
PGHOST=/tmp PGPORT=54322 ./supabase/tests/run.sh
```

Acesso só por convite: o gestor cria o convite na tela **Equipe** (papel e equipe ficam no convite) e manda o link pelo WhatsApp. A pessoa abre **Primeiro acesso** no login e cria a própria senha. Quem se cadastrar sem convite entra inativo.

## Variáveis de ambiente

| Nome | Onde |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase › Project Settings › API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase › Project Settings › API |
| `NEXT_PUBLIC_LOGIN_GOOGLE` | `on` para mostrar o login com Google (configurar o provedor no Supabase antes) |
