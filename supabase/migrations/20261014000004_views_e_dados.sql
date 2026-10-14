-- =====================================================================
-- LC CRM · views (respeitam o RLS de quem consulta) e dados iniciais
-- =====================================================================

-- Lista de leads já com nomes resolvidos, para as telas
create view v_leads with (security_invoker = true) as
select
  l.*,
  s.nome   as situacao_nome,
  s.cor    as situacao_cor,
  s.ordem  as situacao_ordem,
  s.flag_fim, s.flag_cancelado,
  o.nome   as origem_nome,
  e.nome   as equipe_nome,
  c.nome   as corretor_nome,
  g.nome   as gestor_nome,
  (select string_agg(em.nome, ', ' order by em.nome)
     from lead_empreendimentos le join empreendimentos em on em.id = le.empreendimento_id
    where le.lead_id = l.id) as empreendimentos,
  (select cv.nome from conversoes cv where cv.lead_id = l.id order by cv.created_at limit 1)      as conversao_original,
  (select cv.nome from conversoes cv where cv.lead_id = l.id order by cv.created_at desc limit 1) as conversao_ultima,
  (select count(*) from conversoes cv where cv.lead_id = l.id)                                    as total_conversoes,
  (select min(t.data) from tarefas t where t.lead_id = l.id and t.situacao in ('pendente', 'andamento')) as proxima_tarefa,
  (s.sla_horas is not null and not s.flag_fim and not s.flag_cancelado
     and now() > coalesce((select max(h.created_at) from lead_situacao_historico h where h.lead_id = l.id), l.created_at)
                 + make_interval(hours => s.sla_horas)) as sla_estourado
from leads l
join workflow_situacoes s on s.id = l.situacao_id
join origens o            on o.codigo = l.origem
left join equipes  e      on e.id = l.equipe_id
left join usuarios c      on c.id = l.corretor_id
left join usuarios g      on g.id = l.gestor_id;

-- Funil: quantidade de leads por situação
create view v_funil with (security_invoker = true) as
select s.id, s.ordem, s.nome, s.cor, s.flag_fim, s.flag_cancelado, count(l.id) as total
from workflow_situacoes s
left join leads l on l.situacao_id = s.id
where s.objeto = 'lead' and s.ativo
group by s.id
order by s.ordem;

-- Tempo que cada lead ficou em cada situação
create view v_tempo_situacao with (security_invoker = true) as
select
  h.lead_id,
  h.para_id as situacao_id,
  s.nome    as situacao,
  h.created_at as entrou_em,
  lead(h.created_at) over w as saiu_em,
  coalesce(lead(h.created_at) over w, now()) - h.created_at as duracao
from lead_situacao_historico h
join workflow_situacoes s on s.id = h.para_id
window w as (partition by h.lead_id order by h.created_at, h.id);

-- Tempo até o primeiro contato do corretor
create view v_primeiro_contato with (security_invoker = true) as
select
  l.id as lead_id, l.corretor_id, c.nome as corretor, l.equipe_id,
  l.data_associacao_corretor, l.data_primeira_interacao_corretor,
  l.data_primeira_interacao_corretor - l.data_associacao_corretor as tempo_resposta
from leads l
left join usuarios c on c.id = l.corretor_id
where l.corretor_id is not null;

-- ---------------------------------------------------------------------
-- Dados iniciais
-- ---------------------------------------------------------------------
insert into origens (codigo, nome) values
  ('FB', 'Facebook'), ('IG', 'Instagram'), ('WA', 'WhatsApp'), ('GO', 'Google'),
  ('SI', 'Site'), ('PO', 'Portais'), ('LI', 'Ligação'), ('EM', 'E-mail'),
  ('RF', 'Indicação'), ('MP', 'Mídia paga'), ('BO', 'Busca orgânica'),
  ('TT', 'TikTok'), ('LK', 'LinkedIn'), ('CH', 'Chat online'), ('CB', 'Chatbot'),
  ('TD', 'Tráfego direto'), ('RM', 'Remarketing'), ('PV', 'Plantão / PDV'),
  ('GE', 'Painel gestor'), ('CO', 'Painel corretor'), ('CV', 'Importado do CV'),
  ('OU', 'Outros'), ('ND', 'Não definido');

-- Funil espelhando as etapas usadas hoje no CV da LC
insert into workflow_situacoes (ordem, nome, cor, grupo, flag_inicio, flag_fim, flag_cancelado, automacao, sla_horas) values
  (10, 'Novo',                    '#94a3b8', 'Entrada',     true,  false, false, null,               1),
  (20, 'Aguardando atendimento',  '#ec4899', 'Entrada',     false, false, false, null,               2),
  (30, 'Em atendimento',          '#f97316', 'Atendimento', false, false, false, null,               72),
  (40, 'Visita agendada',         '#06b6d4', 'Visita',      false, false, false, 'visita_agendada',  null),
  (50, 'Visita realizada',        '#0891b2', 'Visita',      false, false, false, 'visita_realizada', 72),
  (60, 'Análise de crédito',      '#8b5cf6', 'Negociação',  false, false, false, null,               null),
  (70, 'Reserva',                 '#3b82f6', 'Negociação',  false, false, false, 'reserva',          null),
  (80, 'Venda realizada',         '#16a34a', 'Fim',         false, true,  false, null,               null),
  (90, 'Cancelado',               '#1f2937', 'Fim',         false, false, true,  null,               null);

insert into motivos_cancelamento (nome, exige_descricao) values
  ('Sem contato após tentativas', false),
  ('Sem interesse',               false),
  ('Sem renda / crédito',         false),
  ('Comprou com concorrente',     true),
  ('Localização não atende',      false),
  ('Valor acima do orçamento',    false),
  ('Contato inválido',            false),
  ('Duplicado',                   false),
  ('Outro',                       true);

insert into equipes (nome) values ('Winners'), ('Furiosos'), ('Select');
