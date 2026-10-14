"use server";

import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { createClient, createServiceClient } from "@/lib/supabase/server";
import { usuarioAtual } from "@/lib/sessao";
import type { Papel } from "@/lib/types";

export type Resultado = { erro?: string; ok?: string };

async function exigirGestor() {
  const eu = await usuarioAtual();
  if (eu.papel !== "gestor") throw new Error("Apenas gestores");
  return eu;
}

const txt = (f: FormData, k: string) => String(f.get(k) ?? "").trim() || null;

export async function convidarUsuario(_: Resultado, form: FormData): Promise<Resultado> {
  await exigirGestor();
  const email = txt(form, "email");
  const nome = txt(form, "nome");
  if (!email || !nome) return { erro: "Informe nome e e-mail." };

  const origem = (await headers()).get("origin") ?? "";
  const admin = createServiceClient();
  // O convite manda e-mail para a pessoa criar a própria senha.
  const { error } = await admin.auth.admin.inviteUserByEmail(email, {
    redirectTo: `${origem}/auth/callback?next=/auth/nova-senha`,
    data: {
      nome,
      papel: txt(form, "papel") ?? "corretor",
      equipe_id: txt(form, "equipe_id") ?? "",
      telefone: txt(form, "telefone") ?? "",
    },
  });
  if (error) {
    return { erro: error.message.includes("already") ? "Esse e-mail já tem acesso." : `Não foi possível convidar: ${error.message}` };
  }
  revalidatePath("/equipe");
  return { ok: `Convite enviado para ${email}.` };
}

export async function salvarUsuario(id: string, mudancas: { papel?: Papel; equipe_id?: string | null; ativo?: boolean }) {
  await exigirGestor();
  const supabase = await createClient();
  const { error } = await supabase.from("usuarios").update(mudancas).eq("id", id);
  revalidatePath("/equipe");
  return error ? { erro: error.message } : { ok: "Salvo" };
}

export async function criarEquipe(_: Resultado, form: FormData): Promise<Resultado> {
  await exigirGestor();
  const nome = txt(form, "nome");
  if (!nome) return { erro: "Dê um nome à equipe." };
  const supabase = await createClient();
  const { error } = await supabase.from("equipes").insert({ nome });
  revalidatePath("/equipe");
  return error ? { erro: error.code === "23505" ? "Já existe uma equipe com esse nome." : error.message } : { ok: "Equipe criada." };
}

export async function salvarEquipe(id: string, mudancas: { lider_id?: string | null; ativa?: boolean }) {
  await exigirGestor();
  const supabase = await createClient();
  const { error } = await supabase.from("equipes").update(mudancas).eq("id", id);
  revalidatePath("/equipe");
  return error ? { erro: error.message } : { ok: "Salvo" };
}
