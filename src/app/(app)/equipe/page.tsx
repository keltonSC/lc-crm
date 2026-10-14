import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { usuarioAtual } from "@/lib/sessao";
import type { Equipe, Usuario } from "@/lib/types";
import { FormConvite, FormNovaEquipe, LinhaEquipe, LinhaUsuario } from "./componentes";

export default async function EquipePage() {
  const eu = await usuarioAtual();
  if (eu.papel !== "gestor") redirect("/leads");
  const supabase = await createClient();
  const [{ data: equipes }, { data: usuarios }] = await Promise.all([
    supabase.from("equipes").select("*").order("nome"),
    supabase.from("usuarios").select("*").order("nome"),
  ]);
  const eqs = (equipes ?? []) as Equipe[];
  const usrs = (usuarios ?? []) as Usuario[];

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_360px]">
      <section className="space-y-3">
        <h1 className="text-xl font-semibold">Pessoas</h1>
        <div className="cartao divide-y divide-stone-100">
          {usrs.map((u) => (
            <LinhaUsuario key={u.id} usuario={u} equipes={eqs} souEu={u.id === eu.id} />
          ))}
        </div>
      </section>
      <aside className="space-y-6">
        <section className="cartao space-y-3 p-4">
          <h2 className="text-sm font-semibold">Convidar pessoa</h2>
          <FormConvite equipes={eqs} />
        </section>
        <section className="cartao space-y-3 p-4">
          <h2 className="text-sm font-semibold">Equipes</h2>
          <ul className="space-y-3">
            {eqs.map((e) => (
              <LinhaEquipe
                key={e.id}
                equipe={e}
                membros={usrs.filter((u) => u.equipe_id === e.id && u.ativo)}
              />
            ))}
          </ul>
          <FormNovaEquipe />
        </section>
      </aside>
    </div>
  );
}
