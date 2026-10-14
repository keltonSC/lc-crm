import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Usuario } from "@/lib/types";

/** Usuário logado com o perfil do CRM. Redireciona para o login se não houver. */
export const usuarioAtual = cache(async (): Promise<Usuario> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const { data } = await supabase.from("usuarios").select("*").eq("id", user.id).single();
  if (!data || !data.ativo) redirect("/login?erro=inativo");
  return data as Usuario;
});

export const podeVerTudo = (u: Usuario) => u.papel === "gestor" || u.papel === "sdr";
export const podeDistribuir = (u: Usuario) => u.papel !== "corretor";
