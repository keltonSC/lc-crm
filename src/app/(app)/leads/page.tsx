import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { usuarioAtual, podeDistribuir } from "@/lib/sessao";
import type { LeadView, Motivo, Situacao, Usuario, Equipe } from "@/lib/types";
import { Kanban } from "@/components/kanban";
import { ListaLeads } from "@/components/lista-leads";

type Filtros = { q?: string; situacao?: string; equipe?: string; corretor?: string; ver?: string; arquivados?: string };

const LIMITE = 300;

export default async function LeadsPage({ searchParams }: { searchParams: Promise<Filtros> }) {
  const f = await searchParams;
  const eu = await usuarioAtual();
  const supabase = await createClient();
  const ver = f.ver === "lista" ? "lista" : "funil";

  let consulta = supabase.from("v_leads").select("*").order("created_at", { ascending: false }).limit(LIMITE);
  if (f.q) {
    const termo = f.q.replace(/[,()%]/g, " ").trim();
    const digitos = termo.replace(/\D/g, "");
    const ors = [`nome.ilike.%${termo}%`, `email.ilike.%${termo}%`];
    if (digitos.length >= 4) ors.push(`telefone.ilike.%${digitos}%`);
    consulta = consulta.or(ors.join(","));
  }
  if (f.situacao) consulta = consulta.eq("situacao_id", f.situacao);
  if (f.equipe) consulta = consulta.eq("equipe_id", f.equipe);
  if (f.corretor) consulta = consulta.eq("corretor_id", f.corretor);
  if (!f.arquivados && !f.situacao && !f.q) consulta = consulta.eq("flag_cancelado", false);

  const [{ data: leads, error }, { data: situacoes }, { data: equipes }, { data: corretores }, { data: motivos }] =
    await Promise.all([
      consulta,
      supabase.from("workflow_situacoes").select("*").eq("objeto", "lead").eq("ativo", true).order("ordem"),
      supabase.from("equipes").select("*").eq("ativa", true).order("nome"),
      supabase.from("usuarios").select("*").in("papel", ["corretor", "lider"]).eq("ativo", true).order("nome"),
      supabase.from("motivos_cancelamento").select("*").eq("ativo", true).order("nome"),
    ]);

  const lista = (leads ?? []) as LeadView[];
  const params = (extra: Record<string, string | undefined>) => {
    const p = new URLSearchParams();
    Object.entries({ ...f, ...extra }).forEach(([k, v]) => v && p.set(k, v));
    return `/leads?${p.toString()}`;
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="mr-auto text-xl font-semibold">
          {f.q ? `Resultado para “${f.q}”` : eu.papel === "corretor" ? "Meus leads" : "Leads"}
          <span className="ml-2 text-sm font-normal text-stone-500">
            {lista.length}
            {lista.length === LIMITE ? "+" : ""}
          </span>
        </h1>
        <div className="flex rounded-lg border border-stone-300 bg-white p-0.5 text-sm">
          <Link href={params({ ver: "funil" })} className={`rounded-md px-3 py-1 ${ver === "funil" ? "bg-stone-800 text-white" : ""}`}>
            Funil
          </Link>
          <Link href={params({ ver: "lista" })} className={`rounded-md px-3 py-1 ${ver === "lista" ? "bg-stone-800 text-white" : ""}`}>
            Lista
          </Link>
        </div>
        <Link href="/leads/novo" className="btn-primario hidden md:inline-flex">
          Novo lead
        </Link>
      </div>

      <form className="flex flex-wrap gap-2" action="/leads">
        <input type="hidden" name="ver" value={ver} />
        {f.q && <input type="hidden" name="q" value={f.q} />}
        <select name="situacao" defaultValue={f.situacao ?? ""} className="campo w-auto">
          <option value="">Todas as etapas</option>
          {(situacoes as Situacao[] | null)?.map((s) => (
            <option key={s.id} value={s.id}>{s.nome}</option>
          ))}
        </select>
        {podeDistribuir(eu) && (
          <>
            {eu.papel !== "lider" && (
              <select name="equipe" defaultValue={f.equipe ?? ""} className="campo w-auto">
                <option value="">Todas as equipes</option>
                {(equipes as Equipe[] | null)?.map((e) => (
                  <option key={e.id} value={e.id}>{e.nome}</option>
                ))}
              </select>
            )}
            <select name="corretor" defaultValue={f.corretor ?? ""} className="campo w-auto">
              <option value="">Todos os corretores</option>
              {(corretores as Usuario[] | null)
                ?.filter((c) => eu.papel !== "lider" || c.equipe_id === eu.equipe_id)
                .map((c) => (
                  <option key={c.id} value={c.id}>{c.nome}</option>
                ))}
            </select>
          </>
        )}
        <label className="flex items-center gap-2 px-1 text-sm text-stone-600">
          <input type="checkbox" name="arquivados" value="1" defaultChecked={!!f.arquivados} />
          Mostrar cancelados
        </label>
        <button className="btn-secundario">Filtrar</button>
        {(f.situacao || f.equipe || f.corretor || f.q || f.arquivados) && (
          <Link href={`/leads?ver=${ver}`} className="btn text-stone-500 hover:text-stone-800">
            Limpar
          </Link>
        )}
      </form>

      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">Erro ao carregar leads.</p>}

      {lista.length === 0 && !error ? (
        <div className="cartao p-10 text-center text-stone-500">
          {f.q ? "Nenhum lead encontrado com esse termo." : "Nenhum lead por aqui ainda."}
        </div>
      ) : ver === "funil" ? (
        <Kanban
          leads={lista}
          situacoes={(situacoes ?? []) as Situacao[]}
          motivos={(motivos ?? []) as Motivo[]}
        />
      ) : (
        <ListaLeads leads={lista} />
      )}
    </div>
  );
}
