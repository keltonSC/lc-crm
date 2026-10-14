"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type Resultado = { erro?: string; ok?: boolean };

/** Erros do banco chegam com a mensagem da regra; repassamos ao usuário. */
function msg(e: { message: string; code?: string } | null): string | undefined {
  if (!e) return undefined;
  if (e.code === "42501" || e.code === "23514") return e.message;
  if (e.code === "23505") return "Já existe um lead com esse contato.";
  return "Não foi possível salvar. Tente de novo.";
}

const txt = (f: FormData, k: string) => {
  const v = f.get(k);
  return v == null ? null : String(v).trim() || null;
};

export async function criarLead(_: Resultado, form: FormData): Promise<Resultado> {
  const supabase = await createClient();
  const payload = {
    nome: txt(form, "nome"),
    email: txt(form, "email"),
    telefone: txt(form, "telefone"),
    origem: txt(form, "origem") ?? "GE",
    conversao: txt(form, "conversao") ?? "Cadastro manual",
    equipe_id: txt(form, "equipe_id"),
    corretor_id: txt(form, "corretor_id"),
    empreendimentos: form.getAll("empreendimentos").map(String).filter(Boolean),
  };
  if (!payload.email && !payload.telefone) return { erro: "Informe telefone ou e-mail." };

  const { data, error } = await supabase.rpc("registrar_lead", { p: payload });
  if (error) return { erro: msg(error) };

  const obs = txt(form, "observacao");
  if (obs) {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    await supabase.from("interacoes").insert({ lead_id: data.id, tipo: "anotacao", descricao: obs, usuario_id: user!.id });
  }
  revalidatePath("/leads");
  redirect(`/leads/${data.id}${data.novo ? "" : "?duplicado=1"}`);
}

export async function mudarSituacao(leadId: number, situacaoId: string): Promise<Resultado> {
  const supabase = await createClient();
  const { error } = await supabase.from("leads").update({ situacao_id: situacaoId }).eq("id", leadId);
  revalidatePath("/leads");
  revalidatePath(`/leads/${leadId}`);
  return error ? { erro: msg(error) } : { ok: true };
}

export async function cancelarLead(_: Resultado, form: FormData): Promise<Resultado> {
  const supabase = await createClient();
  const leadId = Number(form.get("lead_id"));
  const { data: sit } = await supabase.from("workflow_situacoes").select("id").eq("flag_cancelado", true).eq("ativo", true).single();
  const { error } = await supabase
    .from("leads")
    .update({
      situacao_id: sit?.id,
      motivo_cancelamento_id: txt(form, "motivo_id"),
      descricao_cancelamento: txt(form, "descricao"),
    })
    .eq("id", leadId);
  revalidatePath("/leads");
  revalidatePath(`/leads/${leadId}`);
  return error ? { erro: msg(error) } : { ok: true };
}

export async function atribuir(_: Resultado, form: FormData): Promise<Resultado> {
  const supabase = await createClient();
  const leadId = Number(form.get("lead_id"));
  const mudancas: Record<string, string | null> = {};
  if (form.has("equipe_id")) mudancas.equipe_id = txt(form, "equipe_id");
  if (form.has("corretor_id")) mudancas.corretor_id = txt(form, "corretor_id");
  const { error } = await supabase.from("leads").update(mudancas).eq("id", leadId);
  revalidatePath(`/leads/${leadId}`);
  revalidatePath("/leads");
  return error ? { erro: msg(error) } : { ok: true };
}

export async function salvarDados(_: Resultado, form: FormData): Promise<Resultado> {
  const supabase = await createClient();
  const leadId = Number(form.get("lead_id"));
  const pv = txt(form, "possibilidade_venda");
  const { error } = await supabase
    .from("leads")
    .update({
      nome: txt(form, "nome"),
      email: txt(form, "email"),
      telefone: txt(form, "telefone"),
      possibilidade_venda: pv ? Number(pv) : null,
      tags: (txt(form, "tags") ?? "")
        .split(",")
        .map((t) => t.trim())
        .filter(Boolean),
    })
    .eq("id", leadId);
  revalidatePath(`/leads/${leadId}`);
  return error ? { erro: msg(error) } : { ok: true };
}

export async function registrarInteracao(_: Resultado, form: FormData): Promise<Resultado> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const leadId = Number(form.get("lead_id"));
  const tipo = txt(form, "tipo") ?? "anotacao";
  const descricao = txt(form, "descricao");
  if (!descricao) return { erro: "Escreva o que aconteceu." };
  const { error } = await supabase.from("interacoes").insert({
    lead_id: leadId,
    tipo,
    resultado: tipo === "ligacao" ? txt(form, "resultado") : null,
    descricao,
    usuario_id: user!.id,
  });
  revalidatePath(`/leads/${leadId}`);
  return error ? { erro: msg(error) } : { ok: true };
}

export async function criarTarefa(_: Resultado, form: FormData): Promise<Resultado> {
  const supabase = await createClient();
  const leadId = Number(form.get("lead_id"));
  const dataLocal = txt(form, "data");
  if (!dataLocal) return { erro: "Escolha data e hora." };
  const tipo = txt(form, "tipo") ?? "tarefa";
  const { error } = await supabase.from("tarefas").insert({
    lead_id: leadId,
    tipo,
    titulo: txt(form, "titulo") ?? (tipo === "visita" ? "Visita" : "Retornar contato"),
    // Horário digitado é de Fortaleza (UTC-3, sem horário de verão)
    data: new Date(`${dataLocal}:00-03:00`).toISOString(),
    prioridade: txt(form, "prioridade") ?? "normal",
    responsavel_id: txt(form, "responsavel_id") ?? undefined,
    empreendimento_id: txt(form, "empreendimento_id"),
    visita_virtual: form.get("visita_virtual") === "on",
  });
  revalidatePath(`/leads/${leadId}`);
  revalidatePath("/tarefas");
  return error ? { erro: msg(error) } : { ok: true };
}

export async function mudarTarefa(id: number, situacao: "concluida" | "cancelada" | "pendente"): Promise<Resultado> {
  const supabase = await createClient();
  const { data, error } = await supabase.from("tarefas").update({ situacao }).eq("id", id).select("lead_id").single();
  revalidatePath("/tarefas");
  if (data) revalidatePath(`/leads/${data.lead_id}`);
  return error ? { erro: msg(error) } : { ok: true };
}
