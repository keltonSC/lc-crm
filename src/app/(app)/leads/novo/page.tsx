import { createClient } from "@/lib/supabase/server";
import { usuarioAtual, podeDistribuir } from "@/lib/sessao";
import type { Empreendimento, Equipe, Origem, Usuario } from "@/lib/types";
import { FormNovoLead } from "./form";

export default async function NovoLead() {
  const eu = await usuarioAtual();
  const supabase = await createClient();
  const [{ data: origens }, { data: empreendimentos }, { data: equipes }, { data: corretores }] = await Promise.all([
    supabase.from("origens").select("*").order("nome"),
    supabase.from("empreendimentos").select("id, nome, bairro").eq("ativo", true).order("nome"),
    supabase.from("equipes").select("*").eq("ativa", true).order("nome"),
    supabase.from("usuarios").select("*").in("papel", ["corretor", "lider"]).eq("ativo", true).order("nome"),
  ]);

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="mb-1 text-xl font-semibold">Novo lead</h1>
      <p className="mb-6 text-sm text-stone-500">
        Se o telefone ou e-mail já existir, o lead não é duplicado: ele recebe uma nova conversão.
      </p>
      <FormNovoLead
        origens={(origens ?? []) as Origem[]}
        empreendimentos={(empreendimentos ?? []) as Empreendimento[]}
        equipes={podeDistribuir(eu) ? ((equipes ?? []) as Equipe[]) : []}
        corretores={
          podeDistribuir(eu)
            ? ((corretores ?? []) as Usuario[]).filter((c) => eu.papel !== "lider" || c.equipe_id === eu.equipe_id)
            : []
        }
        eu={eu}
      />
    </div>
  );
}
