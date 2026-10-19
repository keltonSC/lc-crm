"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { usuarioAtual } from "@/lib/sessao";

async function exigirGestor() {
  const eu = await usuarioAtual();
  if (eu.papel !== "gestor") throw new Error("Apenas gestores");
  return eu;
}

type Retorno = { erro?: string; ok?: string };

export async function salvarConfig(mudancas: { ativa?: boolean; apenas_online?: boolean }): Promise<Retorno> {
  await exigirGestor();
  const supabase = await createClient();
  const { error } = await supabase.from("distribuicao_config").update(mudancas).eq("id", true);
  revalidatePath("/distribuicao");
  return error ? { erro: error.message } : { ok: "Salvo" };
}

export async function participarEquipe(equipeId: string, participa: boolean): Promise<Retorno> {
  await exigirGestor();
  const supabase = await createClient();
  const { error } = await supabase
    .from("roleta_equipes")
    .upsert({ equipe_id: equipeId, participa }, { onConflict: "equipe_id" });
  revalidatePath("/distribuicao");
  return error ? { erro: error.message } : { ok: "Salvo" };
}

export async function participarCorretor(usuarioId: string, participa: boolean): Promise<Retorno> {
  await exigirGestor();
  const supabase = await createClient();
  const { error } = await supabase
    .from("roleta_corretores")
    .upsert({ usuario_id: usuarioId, participa }, { onConflict: "usuario_id" });
  revalidatePath("/distribuicao");
  return error ? { erro: error.message } : { ok: "Salvo" };
}

export async function distribuirFilaAgora(): Promise<Retorno> {
  await exigirGestor();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("distribuir_fila_agora");
  revalidatePath("/distribuicao");
  if (error) return { erro: error.message };
  const n = Number(data ?? 0);
  return { ok: n === 0 ? "Ninguém disponível para receber agora." : `${n} ${n === 1 ? "lead distribuído" : "leads distribuídos"}.` };
}
