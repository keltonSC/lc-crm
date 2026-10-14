-- =====================================================================
-- LC CRM · regras de negócio do lead (triggers e funções)
-- As regras ficam no banco para valerem igual na tela, no formulário
-- e nas integrações.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Helpers de sessão
-- ---------------------------------------------------------------------
create or replace function meu_papel() returns papel_usuario
language sql stable security definer set search_path = public as $$
  select papel from usuarios where id = auth.uid() and ativo
$$;

create or replace function minha_equipe() returns uuid
language sql stable security definer set search_path = public as $$
  select equipe_id from usuarios where id = auth.uid() and ativo
$$;

create or replace function ve_tudo() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(meu_papel() in ('gestor', 'sdr'), false)
$$;

-- Telefone só com dígitos e DDI. Sem DDI, assume Brasil (+55), como o CV.
create or replace function normalizar_telefone(t text) returns text
language sql immutable as $$
  select case
    when t is null or regexp_replace(t, '\D', '', 'g') = '' then null
    when left(trim(t), 1) = '+' then regexp_replace(t, '\D', '', 'g')
    when length(regexp_replace(t, '\D', '', 'g')) in (10, 11) then '55' || regexp_replace(t, '\D', '', 'g')
    else regexp_replace(t, '\D', '', 'g')
  end
$$;

create or replace function situacao_inicio(p_objeto text default 'lead') returns uuid
language sql stable security definer set search_path = public as $$
  select id from workflow_situacoes where objeto = p_objeto and flag_inicio and ativo
$$;

-- ---------------------------------------------------------------------
-- Novo usuário do Auth → linha em usuarios.
-- O primeiro usuário do sistema vira gestor (bootstrap).
-- ---------------------------------------------------------------------
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
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
language plpgsql security definer set search_path = public as $$
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
language plpgsql security definer set search_path = public as $$
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
language plpgsql security definer set search_path = public as $$
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
language plpgsql security definer set search_path = public as $$
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
returns void language plpgsql security definer set search_path = public as $$
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
language plpgsql as $$
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
language plpgsql security definer set search_path = public as $$
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
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_email    citext := nullif(lower(trim(p ->> 'email')), '');
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
