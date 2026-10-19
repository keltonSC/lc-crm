-- Log de entradas: só o gestor lê; ninguém logado escreve.
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

select pg_temp.admin() \g /dev/null
insert into entradas_leads (fonte, payload) values ('api', '{"nome":"Teste"}');

select pg_temp.como('gestor@lc.com') \g /dev/null
do $$ begin assert (select count(*) from entradas_leads) = 1, 'gestor lê o log'; end $$;

select pg_temp.como('ana@lc.com') \g /dev/null
do $$
begin
  assert (select count(*) from entradas_leads) = 0, 'corretor não lê o log';
  begin
    insert into entradas_leads (fonte, payload) values ('api', '{}');
    raise exception 'deveria bloquear';
  exception when insufficient_privilege then null;
  end;
end $$;

select pg_temp.como('gestor@lc.com') \g /dev/null
do $$
begin
  begin
    insert into entradas_leads (fonte, payload) values ('api', '{}');
    raise exception 'deveria bloquear';
  exception when insufficient_privilege then null;
  end;
end $$;

select pg_temp.admin() \g /dev/null
set role anon;
do $$ begin assert (select count(*) from entradas_leads) = 0, 'anônimo não lê'; end $$;
reset role;
\echo ok 01 log de entradas: leitura só do gestor, escrita só do servidor
\echo TESTES DAS ENTRADAS PASSARAM
