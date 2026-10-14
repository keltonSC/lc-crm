import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

async function salvar(form: FormData) {
  "use server";
  const senha = String(form.get("senha") ?? "");
  if (senha.length < 8) redirect("/auth/nova-senha?erro=curta");
  const supabase = await createClient();
  const { error } = await supabase.auth.updateUser({ password: senha });
  if (error) redirect("/auth/nova-senha?erro=falhou");
  redirect("/");
}

export default async function NovaSenha({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams;
  return (
    <main className="flex min-h-dvh items-center justify-center px-4">
      <form action={salvar} className="cartao w-full max-w-sm space-y-4 p-6">
        <h1 className="text-xl font-semibold">Criar nova senha</h1>
        {erro && (
          <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erro === "curta" ? "Use pelo menos 8 caracteres." : "Não foi possível salvar. Peça um novo link."}
          </p>
        )}
        <div>
          <label className="rotulo" htmlFor="senha">Nova senha</label>
          <input id="senha" name="senha" type="password" minLength={8} required className="campo" autoComplete="new-password" />
        </div>
        <button className="btn-primario w-full">Salvar e entrar</button>
      </form>
    </main>
  );
}
