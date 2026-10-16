-- Funções de trigger não precisam ser chamadas pela API.
-- (meu_papel, minha_equipe, ve_tudo, pode_ver_lead e situacao_inicio ficam
--  liberadas ao usuário logado de propósito: as policies de RLS dependem delas
--  e elas só devolvem dados do próprio usuário. registrar_lead é a entrada
--  oficial de leads.)
revoke execute on function
  handle_new_user(), usuarios_guarda(), leads_antes(), leads_depois(),
  interacoes_depois(), tarefas_antes(), tarefas_depois()
from public, anon, authenticated;
