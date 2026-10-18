"use server";

import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import { usuarioAtual } from "@/lib/sessao";
import type { Papel } from "@/lib/types";

export type Resultado = { erro?: string; ok?: string };

async function exigirGestor() {
  const eu = await usuarioAtual();
  if (eu.papel !== "gestor") throw new Error("Apenas gestores");
  return eu;
}

const txt = (f: FormData, k: string) => String(f.get(k) ?? "").trim() || null;

export type ResultadoConvite = Resultado & { link?: string; whatsapp?: string | null };

/**
 * O convite fica registrado no banco. A pessoa entra em /login, toca em
 * "Primeiro acesso" com o e-mail convidado e cria a própria senha.
 * Papel e equipe vêm do convite — nunca do que a pessoa digita.
 */
export async function convidarUsuario(_: ResultadoConvite, form: FormData): Promise<ResultadoConvite> {
  await exigirGestor();
  const email = txt(form, "email")?.toLowerCase();
  const nome = txt(form, "nome");
  if (!email || !nome) return { erro: "Informe nome e e-mail." };
  const telefone = txt(form, "telefone");

  const supabase = await createClient();
  const { data: existente } = await supabase.from("usuarios").select("id").eq("email", email).maybeSingle();
  if (existente) return { erro: "Esse e-mail já tem acesso. Ajuste o papel na lista ao lado." };

  const { error } = await supabase.from("convites").upsert({
    email,
    nome,
    papel: txt(form, "papel") ?? "corretor",
    equipe_id: txt(form, "equipe_id"),
    telefone,
    usado_em: null,
  });
  if (error) return { erro: `Não foi possível criar o convite: ${error.message}` };

  const origem = (await headers()).get("origin") ?? "";
  const link = `${origem}/login?primeiro=1&email=${encodeURIComponent(email)}`;
  const texto = `Oi, ${nome.split(" ")[0]}! Seu acesso ao CRM da LC está liberado. Entre em ${link} e crie sua senha com o e-mail ${email}.`;
  const digitos = (telefone ?? "").replace(/\D/g, "");
  const wa = digitos ? `https://wa.me/${digitos.length <= 11 ? "55" + digitos : digitos}?text=${encodeURIComponent(texto)}` : null;

  revalidatePath("/equipe");
  return { ok: `Convite criado para ${email}.`, link, whatsapp: wa ?? `https://wa.me/?text=${encodeURIComponent(texto)}` };
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
