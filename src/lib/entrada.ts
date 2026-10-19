import { createServiceClient } from "@/lib/supabase/server";

/** Formato aceito por registrar_lead (campos desconhecidos são ignorados pelo banco). */
export type LeadEntrada = {
  nome?: string;
  email?: string;
  telefone?: string;
  identificador_meta?: string;
  origem?: string;
  conversao?: string;
  midia?: string;
  campanha?: string;
  utm?: Record<string, unknown>;
  /** IDs (uuid) ou nomes de empreendimentos. */
  empreendimentos?: string[];
  tags?: string[];
  campos_adicionais?: Record<string, unknown>;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type ResultadoEntrada = { ok: true; leadId: number; novo: boolean; reativado: boolean } | { ok: false; erro: string };

/**
 * Grava o payload bruto no log e registra o lead (deduplicação, roleta etc. ficam no banco).
 * Nunca lança: a falha fica no log (status "erro") para reprocessar.
 */
export async function processarEntrada(fonte: string, bruto: unknown, lead: LeadEntrada): Promise<ResultadoEntrada> {
  const supabase = createServiceClient();
  const { data: log } = await supabase.from("entradas_leads").insert({ fonte, payload: bruto }).select("id").single();
  const finalizar = async (campos: Record<string, unknown>) => {
    if (log) await supabase.from("entradas_leads").update({ ...campos, processado_em: new Date().toISOString() }).eq("id", log.id);
  };

  try {
    const { empreendimentos: pedidos = [], ...resto } = lead;
    const ids = await resolverEmpreendimentos(supabase, pedidos);
    const { data, error } = await supabase.rpc("registrar_lead", { p: { ...resto, empreendimentos: ids } });
    if (error) throw new Error(error.message);
    const r = data as { id: number; novo: boolean; reativado: boolean };
    await finalizar({ status: "processado", lead_id: r.id });
    return { ok: true, leadId: r.id, novo: r.novo, reativado: r.reativado };
  } catch (e) {
    const erro = e instanceof Error ? e.message : String(e);
    await finalizar({ status: "erro", erro });
    return { ok: false, erro };
  }
}

async function resolverEmpreendimentos(supabase: ReturnType<typeof createServiceClient>, pedidos: string[]) {
  const ids = pedidos.filter((p) => UUID.test(p));
  const nomes = pedidos.filter((p) => !UUID.test(p)).map((n) => n.trim().toLowerCase());
  if (nomes.length) {
    const { data } = await supabase.from("empreendimentos").select("id, nome");
    for (const e of data ?? []) if (nomes.includes(String(e.nome).toLowerCase())) ids.push(e.id);
  }
  return ids;
}
