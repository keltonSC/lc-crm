import { createHmac, timingSafeEqual } from "node:crypto";
import type { LeadEntrada } from "@/lib/entrada";

/** Confere o header X-Hub-Signature-256 ("sha256=<hmac do corpo bruto com o app secret>"). */
export function assinaturaMetaValida(corpo: string, header: string | null, segredo: string): boolean {
  if (!header?.startsWith("sha256=")) return false;
  const esperado = createHmac("sha256", segredo).update(corpo).digest();
  const recebido = Buffer.from(header.slice(7), "hex");
  return recebido.length === esperado.length && timingSafeEqual(recebido, esperado);
}

export type EventoLeadgen = { leadgen_id: string; form_id?: string; page_id?: string; ad_id?: string };

/** Extrai os leadgen_id do corpo do webhook (entry[].changes[] com field = "leadgen"). */
export function eventosLeadgen(corpo: unknown): EventoLeadgen[] {
  const entradas = (corpo as { entry?: { changes?: { field?: string; value?: EventoLeadgen }[] }[] })?.entry ?? [];
  return entradas.flatMap((e) =>
    (e.changes ?? []).filter((c) => c.field === "leadgen" && c.value?.leadgen_id).map((c) => c.value as EventoLeadgen),
  );
}

type LeadGraph = {
  id: string;
  field_data?: { name: string; values?: string[] }[];
  form_id?: string;
  ad_name?: string;
  campaign_name?: string;
  platform?: string;
  is_organic?: boolean;
};

/** Converte o lead da Graph API para o formato do registrar_lead. */
export function leadDaMeta(g: LeadGraph, nomeFormulario?: string): LeadEntrada {
  const campo = (...chaves: string[]) => {
    const f = g.field_data?.find((x) => chaves.includes(x.name.toLowerCase()));
    return f?.values?.[0]?.trim() || undefined;
  };
  const nome = campo("full_name", "nome", "nome_completo") ?? ([campo("first_name"), campo("last_name")].filter(Boolean).join(" ") || undefined);
  const conhecidos = ["full_name", "nome", "nome_completo", "first_name", "last_name", "email", "phone_number", "telefone", "celular"];
  const extras = Object.fromEntries(
    (g.field_data ?? []).filter((f) => !conhecidos.includes(f.name.toLowerCase())).map((f) => [f.name, f.values?.join(", ")]),
  );
  return {
    nome,
    email: campo("email"),
    telefone: campo("phone_number", "telefone", "celular"),
    identificador_meta: g.id,
    origem: g.platform?.toLowerCase() === "ig" ? "IG" : "FB",
    conversao: nomeFormulario ?? (g.form_id ? `Formulário Meta ${g.form_id}` : "Formulário Meta"),
    midia: g.ad_name,
    campanha: g.campaign_name,
    campos_adicionais: extras,
  };
}
