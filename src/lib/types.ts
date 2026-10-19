export type Papel = "gestor" | "sdr" | "lider" | "corretor";

export const PAPEL_NOME: Record<Papel, string> = {
  gestor: "Gestor",
  sdr: "SDR",
  lider: "Líder de equipe",
  corretor: "Corretor",
};

export type Usuario = {
  id: string;
  nome: string;
  email: string;
  telefone: string | null;
  papel: Papel;
  equipe_id: string | null;
  creci: string | null;
  ativo: boolean;
  online: boolean;
};

export type Equipe = { id: string; nome: string; lider_id: string | null; ativa: boolean };

export type Situacao = {
  id: string;
  ordem: number;
  nome: string;
  cor: string;
  grupo: string | null;
  flag_inicio: boolean;
  flag_fim: boolean;
  flag_cancelado: boolean;
  automacao: string | null;
  sla_horas: number | null;
};

export type Motivo = { id: string; nome: string; exige_descricao: boolean };
export type Origem = { codigo: string; nome: string };
export type Empreendimento = { id: string; nome: string; bairro: string | null };

export type LeadView = {
  id: number;
  nome: string;
  email: string | null;
  telefone: string | null;
  origem: string;
  origem_nome: string;
  situacao_id: string;
  situacao_nome: string;
  situacao_cor: string;
  situacao_ordem: number;
  flag_fim: boolean;
  flag_cancelado: boolean;
  gestor_id: string | null;
  gestor_nome: string | null;
  equipe_id: string | null;
  equipe_nome: string | null;
  corretor_id: string | null;
  corretor_nome: string | null;
  possibilidade_venda: number | null;
  tags: string[];
  motivo_cancelamento_id: string | null;
  descricao_cancelamento: string | null;
  data_associacao_corretor: string | null;
  data_primeira_interacao_corretor: string | null;
  data_ultima_interacao: string | null;
  empreendimentos: string | null;
  conversao_original: string | null;
  conversao_ultima: string | null;
  total_conversoes: number;
  proxima_tarefa: string | null;
  sla_estourado: boolean;
  created_at: string;
};

export type Interacao = {
  id: number;
  tipo: "anotacao" | "ligacao" | "email" | "sms" | "whatsapp";
  resultado: "atendida" | "nao_atendida" | "nao_existe" | null;
  descricao: string;
  usuario_id: string | null;
  created_at: string;
};

export type Tarefa = {
  id: number;
  lead_id: number;
  tipo: "tarefa" | "visita";
  titulo: string;
  descricao: string | null;
  data: string;
  prioridade: "alta" | "normal" | "baixa";
  situacao: "pendente" | "andamento" | "concluida" | "cancelada";
  responsavel_id: string | null;
  empreendimento_id: string | null;
  visita_virtual: boolean;
};

export const TIPO_INTERACAO: Record<Interacao["tipo"], string> = {
  anotacao: "Anotação",
  ligacao: "Ligação",
  email: "E-mail",
  sms: "SMS",
  whatsapp: "WhatsApp",
};

export const RESULTADO_LIGACAO: Record<NonNullable<Interacao["resultado"]>, string> = {
  atendida: "Atendida",
  nao_atendida: "Não atendida",
  nao_existe: "Número não existe",
};
