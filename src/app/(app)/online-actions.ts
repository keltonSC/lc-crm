"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { usuarioAtual } from "@/lib/sessao";

/** O corretor liga/desliga o próprio "online". Online é o que habilita receber leads da roleta. */
export async function alternarOnline(online: boolean) {
  const eu = await usuarioAtual();
  const supabase = await createClient();
  const { error } = await supabase.from("usuarios").update({ online }).eq("id", eu.id);
  revalidatePath("/", "layout");
  return error ? { erro: error.message } : { ok: true };
}
