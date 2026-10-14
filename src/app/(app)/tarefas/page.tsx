import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { usuarioAtual, podeDistribuir } from "@/lib/sessao";
import type { Tarefa } from "@/lib/types";
import { dataHora } from "@/lib/format";
import { BotoesTarefa } from "./botoes";

type Linha = Tarefa & { leads: { nome: string; telefone: string | null } | null; usuarios: { nome: string } | null };

const inicioDoDia = (d: Date) => {
  // Fortaleza = UTC-3 o ano todo
  const f = new Date(d.getTime() - 3 * 3600_000);
  return new Date(Date.UTC(f.getUTCFullYear(), f.getUTCMonth(), f.getUTCDate(), 3));
};

export default async function Agenda({ searchParams }: { searchParams: Promise<{ todos?: string }> }) {
  const { todos } = await searchParams;
  const eu = await usuarioAtual();
  const supabase = await createClient();
  const verTodos = podeDistribuir(eu) && todos === "1";

  let q = supabase
    .from("tarefas")
    .select("*, leads(nome, telefone), usuarios!tarefas_responsavel_id_fkey(nome)")
    .in("situacao", ["pendente", "andamento"])
    .order("data")
    .limit(300);
  if (!verTodos) q = q.eq("responsavel_id", eu.id);
  const { data, error } = await q;
  const tarefas = (data ?? []) as Linha[];

  const hoje = inicioDoDia(new Date());
  const amanha = new Date(hoje.getTime() + 86400_000);
  const grupos = [
    { nome: "Atrasadas", itens: tarefas.filter((t) => new Date(t.data) < new Date()), cor: "text-red-600" },
    { nome: "Hoje", itens: tarefas.filter((t) => new Date(t.data) >= new Date() && new Date(t.data) < amanha), cor: "" },
    { nome: "Próximas", itens: tarefas.filter((t) => new Date(t.data) >= amanha), cor: "" },
  ];

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="flex items-center gap-3">
        <h1 className="mr-auto text-xl font-semibold">Agenda</h1>
        {podeDistribuir(eu) && (
          <div className="flex rounded-lg border border-stone-300 bg-white p-0.5 text-sm">
            <Link href="/tarefas" className={`rounded-md px-3 py-1 ${!verTodos ? "bg-stone-800 text-white" : ""}`}>Minhas</Link>
            <Link href="/tarefas?todos=1" className={`rounded-md px-3 py-1 ${verTodos ? "bg-stone-800 text-white" : ""}`}>
              {eu.papel === "lider" ? "Da equipe" : "Todas"}
            </Link>
          </div>
        )}
      </div>
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">Erro ao carregar a agenda.</p>}
      {tarefas.length === 0 && <div className="cartao p-10 text-center text-stone-500">Nenhuma tarefa em aberto.</div>}
      {grupos
        .filter((g) => g.itens.length)
        .map((g) => (
          <section key={g.nome}>
            <h2 className={`mb-2 text-sm font-semibold ${g.cor}`}>
              {g.nome} <span className="font-normal text-stone-500">{g.itens.length}</span>
            </h2>
            <ul className="cartao divide-y divide-stone-100">
              {g.itens.map((t) => (
                <li key={t.id} className="flex flex-wrap items-center gap-3 p-3">
                  <span className={`rounded px-1.5 text-[11px] font-medium ${t.tipo === "visita" ? "bg-cyan-100 text-cyan-800" : "bg-stone-100 text-stone-700"}`}>
                    {t.tipo === "visita" ? "Visita" : "Tarefa"}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium">{t.titulo}</p>
                    <p className="text-xs text-stone-500">
                      {dataHora(t.data)} ·{" "}
                      <Link href={`/leads/${t.lead_id}`} className="text-marca hover:underline">
                        {t.leads?.nome ?? `Lead #${t.lead_id}`}
                      </Link>
                      {verTodos && t.usuarios && ` · ${t.usuarios.nome}`}
                    </p>
                  </div>
                  <BotoesTarefa id={t.id} telefone={t.leads?.telefone ?? null} />
                </li>
              ))}
            </ul>
          </section>
        ))}
    </div>
  );
}
