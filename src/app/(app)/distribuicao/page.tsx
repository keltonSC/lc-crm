import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { usuarioAtual } from "@/lib/sessao";
import { iniciais } from "@/lib/format";
import type { Equipe } from "@/lib/types";
import { BotaoDistribuirFila, Configuracao, SwitchParticipa } from "./componentes";

type LinhaCorretor = {
  id: string;
  nome: string;
  equipe_id: string | null;
  online: boolean;
  participa: boolean;
  ultima_em: string | null;
  recebidos_30d: number;
};

export default async function DistribuicaoPage() {
  const eu = await usuarioAtual();
  if (eu.papel !== "gestor") redirect("/leads");
  const supabase = await createClient();
  const [{ data: config }, { data: equipes }, { data: corretores }, { data: roletaEquipes }, { count: naFila }] =
    await Promise.all([
      supabase.from("distribuicao_config").select("*").single(),
      supabase.from("equipes").select("*").eq("ativa", true).order("nome"),
      supabase.from("v_roleta_corretores").select("*").order("nome"),
      supabase.from("roleta_equipes").select("*"),
      supabase.from("leads").select("id", { count: "exact", head: true }).eq("aguarda_distribuicao", true),
    ]);

  const eqs = (equipes ?? []) as Equipe[];
  const linhas = (corretores ?? []) as LinhaCorretor[];
  const participaEquipe = new Map((roletaEquipes ?? []).map((r) => [r.equipe_id as string, r.participa as boolean]));
  const hora = new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", timeZone: "America/Fortaleza" });

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_360px]">
      <section className="space-y-4">
        <h1 className="text-xl font-semibold">Distribuição de leads</h1>
        <p className="text-sm text-stone-600">
          A roleta escolhe a equipe que está há mais tempo sem receber lead e, dentro dela, o corretor que está há mais
          tempo sem receber. Corretores marcam <strong>Online</strong> no menu do perfil.
        </p>
        {eqs.map((e) => {
          const membros = linhas.filter((c) => c.equipe_id === e.id);
          const equipeParticipa = participaEquipe.get(e.id) ?? true;
          return (
            <div key={e.id} className="cartao divide-y divide-stone-100">
              <div className="flex items-center gap-3 p-3">
                <p className="flex-1 text-sm font-semibold">{e.nome}</p>
                <span className="text-xs text-stone-500">{equipeParticipa ? "Na roleta" : "Fora da roleta"}</span>
                <SwitchParticipa tipo="equipe" id={e.id} participa={equipeParticipa} />
              </div>
              {membros.length === 0 && <p className="p-3 text-xs text-stone-500">Nenhum corretor ativo nesta equipe.</p>}
              {membros.map((c) => (
                <div key={c.id} className={`flex flex-wrap items-center gap-3 p-3 ${!equipeParticipa ? "opacity-50" : ""}`}>
                  <span className="grid size-9 place-items-center rounded-full bg-stone-200 text-xs font-semibold">{iniciais(c.nome)}</span>
                  <div className="min-w-40 flex-1">
                    <p className="text-sm font-medium">{c.nome}</p>
                    <p className="text-xs text-stone-500">
                      {c.ultima_em ? `Último lead em ${hora.format(new Date(c.ultima_em))}` : "Ainda não recebeu lead"} ·{" "}
                      {c.recebidos_30d} em 30 dias
                    </p>
                  </div>
                  <span className={`rounded-full px-2 py-0.5 text-xs ${c.online ? "bg-emerald-100 text-emerald-800" : "bg-stone-100 text-stone-500"}`}>
                    {c.online ? "Online" : "Offline"}
                  </span>
                  <SwitchParticipa tipo="corretor" id={c.id} participa={c.participa} />
                </div>
              ))}
            </div>
          );
        })}
      </section>
      <aside className="space-y-6">
        <section className="cartao space-y-4 p-4">
          <h2 className="text-sm font-semibold">Configuração</h2>
          <Configuracao ativa={config?.ativa ?? false} apenasOnline={config?.apenas_online ?? true} />
        </section>
        <section className="cartao space-y-3 p-4">
          <h2 className="text-sm font-semibold">Fila de espera</h2>
          <p className="text-sm text-stone-600">
            {naFila ? (
              <>
                <Link href="/leads" className="font-medium underline">{naFila} {naFila === 1 ? "lead aguarda" : "leads aguardam"}</Link>{" "}
                um corretor disponível.
              </>
            ) : (
              "Nenhum lead esperando."
            )}
          </p>
          <BotaoDistribuirFila naFila={naFila ?? 0} />
        </section>
      </aside>
    </div>
  );
}
