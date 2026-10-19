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

Distribuição automática: o gestor liga a roleta em **Distribuição**. Lead novo sem corretor vai para a equipe/corretor que está há mais tempo sem receber (só quem está online, se a opção estiver ligada); sem ninguém disponível ele espera na fila. A regra vive no banco (`distribuir_lead`, trigger em `leads`). Corretores marcam **Online** no menu do perfil.

## Entrada de leads por API

- `POST /api/leads/entrada` (header `Authorization: Bearer <LEADS_API_TOKEN>`, `?fonte=olx` opcional para identificar no log). Corpo JSON: `nome`, `email`, `telefone`, `origem` (código, ex.: `PO`), `conversao`, `midia`, `campanha`, `empreendimentos` (nomes ou ids), `tags`… Exige e-mail ou telefone. Responde `201` (lead novo) ou `200` (já existia: vira conversão).
- `GET/POST /api/webhooks/meta`: webhook do Meta Lead Ads. Verificação com `META_VERIFY_TOKEN`; o POST é validado pela assinatura (`META_APP_SECRET`) e os dados do lead são buscados na Graph API com `META_PAGE_TOKEN`. O `leadgen_id` vira `identificador_meta`, então reenvios não duplicam.
- Todo payload é gravado em `entradas_leads` (visível só ao gestor) com status `processado` ou `erro`.
- Depois de entrar, o lead passa pela deduplicação e pela roleta como qualquer outro.

## Variáveis de ambiente

| Nome | Onde |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase › Project Settings › API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase › Project Settings › API |
| `NEXT_PUBLIC_LOGIN_GOOGLE` | `on` para mostrar o login com Google (configurar o provedor no Supabase antes) |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase › Project Settings › API (só servidor, nunca `NEXT_PUBLIC_`) |
| `LEADS_API_TOKEN` | Token longo e aleatório que as integrações enviam como Bearer |
| `META_VERIFY_TOKEN`, `META_APP_SECRET`, `META_PAGE_TOKEN` | App da Meta (webhook de Lead Ads) |
