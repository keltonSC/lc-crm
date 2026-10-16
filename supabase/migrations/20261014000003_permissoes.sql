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
