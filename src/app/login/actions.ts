"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type EstadoLogin = { erro?: string; aviso?: string };

export async function entrar(_: EstadoLogin, form: FormData): Promise<EstadoLogin> {
  const email = String(form.get("email") ?? "").trim();
  const senha = String(form.get("senha") ?? "");
  const next = String(form.get("next") ?? "/") || "/";
  if (!email || !senha) return { erro: "Informe e-mail e senha." };

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password: senha });
  if (error) {
    return {
      erro: error.message.includes("Invalid login") ? "E-mail ou senha incorretos." : "Não foi possível entrar agora.",
    };
  }
  redirect(next.startsWith("/") ? next : "/");
}

export async function esqueciSenha(_: EstadoLogin, form: FormData): Promise<EstadoLogin> {
  const email = String(form.get("email") ?? "").trim();
  if (!email) return { erro: "Digite seu e-mail no campo acima." };
  const origem = (await headers()).get("origin") ?? "";
  const supabase = await createClient();
  await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${origem}/auth/callback?next=/auth/nova-senha` });
  // Mesma resposta exista ou não a conta, para não revelar e-mails cadastrados.
  return { aviso: "Se o e-mail estiver cadastrado, você vai receber um link para criar uma nova senha." };
}

/** Primeiro acesso: a pessoa convidada cria a própria senha. */
export async function primeiroAcesso(_: EstadoLogin, form: FormData): Promise<EstadoLogin> {
  const email = String(form.get("email") ?? "").trim().toLowerCase();
  const senha = String(form.get("senha") ?? "");
  if (!email) return { erro: "Informe o e-mail que recebeu o convite." };
  if (senha.length < 8) return { erro: "Crie uma senha com pelo menos 8 caracteres." };

  const origem = (await headers()).get("origin") ?? "";
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password: senha,
    options: { emailRedirectTo: `${origem}/auth/callback` },
  });
  if (error) {
    if (error.message.toLowerCase().includes("already")) return { erro: "Esse e-mail já tem senha. Use “Entrar”." };
    if (error.message.toLowerCase().includes("rate")) return { erro: "Muitas tentativas. Aguarde alguns minutos." };
    return { erro: "Não foi possível criar o acesso agora." };
  }
  // Com confirmação de e-mail desligada, a sessão já vem pronta.
  if (data.session) redirect("/");
  return { aviso: "Pronto! Enviamos um e-mail de confirmação. Toque no link e depois entre com sua senha." };
}

export async function entrarComGoogle() {
  const origem = (await headers()).get("origin") ?? "";
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: `${origem}/auth/callback` },
  });
  if (error || !data.url) redirect("/login?erro=google");
  redirect(data.url);
}

export async function sair() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
