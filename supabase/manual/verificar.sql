-- Rode depois de aplicar-tudo.sql. Cada linha deve mostrar "ok = true".
select 'tabelas (esperado 19)' as item, count(*) = 19 as ok, count(*) as valor
  from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE'
union all select 'funil com 1 situação de início', count(*) = 1, count(*) from workflow_situacoes where flag_inicio and ativo
union all select 'origens (esperado 23)', count(*) = 23, count(*) from origens
union all select 'RLS ligada em todas as tabelas', count(*) = 0, count(*)
  from pg_tables where schemaname = 'public' and not rowsecurity
union all select 'roleta nasce desligada', not ativa, 0 from distribuicao_config
union all select 'função registrar_lead', count(*) = 1, count(*) from pg_proc where proname = 'registrar_lead'
union all select 'função distribuir_lead', count(*) = 1, count(*) from pg_proc where proname = 'distribuir_lead'
union all select 'trigger de novo usuário', count(*) = 1, count(*) from pg_trigger where tgname = 'on_auth_user_created';
