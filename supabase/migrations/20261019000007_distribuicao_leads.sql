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
