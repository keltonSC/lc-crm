import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { usuarioAtual, podeDistribuir } from "@/lib/sessao";
import type { Empreendimento, Equipe, Interacao, LeadView, Motivo, Situacao, Tarefa, Usuario } from "@/lib/types";
import { RESULTADO_LIGACAO, TIPO_INTERACAO } from "@/lib/types";
import { dataHora, duracao, telefone, whatsappLink } from "@/lib/format";
import { Etapa } from "@/components/lista-leads";
import { SeletorEtapa } from "./seletor-etapa";
import { FormInteracao } from "./form-interacao";
import { FormTarefa, ListaTarefas } from "./tarefas";
import { FormAtribuir } from "./form-atribuir";
import { FormDados } from "./form-dados";

type Evento = { quando: string; tipo: string; titulo: string; texto?: string; autor?: string | null; destaque?: boolean };

export default async function FichaLead({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ duplicado?: string }>;
}) {
  const { id } = await params;
  const { duplicado } = await searchParams;
  const leadId = Number(id);
  if (!Number.isInteger(leadId)) notFound();

  const eu = await usuarioAtual();
  const supabase = await createClient();
  const { data: lead } = await supabase.from("v_leads").select("*").eq("id", leadId).maybeSingle();
  if (!lead) notFound();
  const l = lead as LeadView;

  const [sits, mots, ints, tars, hSit, hResp, convs, usrs, eqs, emps] = await Promise.all([
    supabase.from("workflow_situacoes").select("*").eq("objeto", "lead").eq("ativo", true).order("ordem"),
    supabase.from("motivos_cancelamento").select("*").eq("ativo", true).order("nome"),
    supabase.from("interacoes").select("*").eq("lead_id", leadId).order("created_at", { ascending: false }),
    supabase.from("tarefas").select("*").eq("lead_id", leadId).order("data"),
    supabase.from("lead_situacao_historico").select("*").eq("lead_id", leadId).order("created_at"),
    supabase.from("lead_responsavel_historico").select("*").eq("lead_id", leadId).order("created_at"),
    supabase.from("conversoes").select("*").eq("lead_id", leadId).order("created_at", { ascending: false }),
    supabase.from("usuarios").select("*").order("nome"),
    supabase.from("equipes").select("*").order("nome"),
    supabase.from("empreendimentos").select("id, nome, bairro").eq("ativo", true).order("nome"),
  ]);

  const situacoes = (sits.data ?? []) as Situacao[];
  const usuarios = (usrs.data ?? []) as Usuario[];
  const equipes = (eqs.data ?? []) as Equipe[];
  const nomeUsuario = (uid: string | null) => usuarios.find((u) => u.id === uid)?.nome ?? null;
  const nomeSit = (sid: string | null) => situacoes.find((s) => s.id === sid)?.nome ?? "—";
  const nomeEquipe = (eid: string | null) => equipes.find((e) => e.id === eid)?.nome ?? "ninguém";

  // Linha do tempo única: interações, mudanças de etapa, responsáveis e conversões
  const eventos: Evento[] = [
    ...((ints.data ?? []) as Interacao[]).map((i) => ({
      quando: i.created_at,
      tipo: i.tipo,
      titulo: TIPO_INTERACAO[i.tipo] + (i.resultado ? ` · ${RESULTADO_LIGACAO[i.resultado]}` : ""),
      texto: i.descricao,
      autor: nomeUsuario(i.usuario_id),
      destaque: true,
    })),
    ...(hSit.data ?? []).map((h) => ({
      quando: h.created_at,
      tipo: "etapa",
      titulo: h.de_id ? `${nomeSit(h.de_id)} → ${nomeSit(h.para_id)}` : `Entrou em ${nomeSit(h.para_id)}`,
      autor: nomeUsuario(h.usuario_id) ?? "Sistema",
    })),
    ...(hResp.data ?? []).map((h) => {
      const nome = (x: string | null) => (h.papel === "equipe" ? nomeEquipe(x) : (nomeUsuario(x) ?? "ninguém"));
      return {
        quando: h.created_at,
        tipo: "responsavel",
        titulo: `${h.papel === "equipe" ? "Equipe" : h.papel === "gestor" ? "Gestor" : "Corretor"}: ${h.de_id ? `${nome(h.de_id)} → ` : ""}${nome(h.para_id)}`,
        texto: h.motivo === "reativacao" ? "Reativação" : undefined,
        autor: nomeUsuario(h.usuario_id) ?? "Sistema",
      };
    }),
    ...(convs.data ?? []).map((c) => ({
      quando: c.created_at,
      tipo: "conversao",
      titulo: `Conversão: ${c.nome}`,
      texto: [c.midia, c.campanha].filter(Boolean).join(" · ") || undefined,
    })),
  ].sort((a, b) => b.quando.localeCompare(a.quando));

  const situacaoAtual = situacoes.find((s) => s.id === l.situacao_id)!;
  const motivoAtual = ((mots.data ?? []) as Motivo[]).find((m) => m.id === l.motivo_cancelamento_id);
  const wa = whatsappLink(l.telefone);
  const corretoresElegiveis = usuarios.filter(
    (u) => u.ativo && (u.papel === "corretor" || u.papel === "lider") && (eu.papel !== "lider" || u.equipe_id === eu.equipe_id),
  );

  return (
    <div className="space-y-4">
      <Link href="/leads" className="text-sm text-stone-500 hover:text-stone-800">← Leads</Link>

      {duplicado && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
          Esse contato já existia. Registramos uma nova conversão neste lead em vez de criar outro.
        </p>
      )}

      <header className="cartao flex flex-wrap items-center gap-4 p-4">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="truncate text-xl font-semibold">{l.nome}</h1>
            <Etapa nome={l.situacao_nome} cor={l.situacao_cor} />
            {l.sla_estourado && <span className="rounded bg-red-100 px-1.5 text-xs font-medium text-red-700">atrasado</span>}
          </div>
          <p className="mt-1 text-sm text-stone-500">
            #{l.id} · {telefone(l.telefone)} {l.email && `· ${l.email}`}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          {wa && (
            <a href={wa} target="_blank" rel="noopener" className="btn bg-emerald-600 text-white hover:bg-emerald-700">
              WhatsApp
            </a>
          )}
          {l.telefone && <a href={`tel:+${l.telefone}`} className="btn-secundario">Ligar</a>}
        </div>
      </header>

      <div className="grid gap-4 lg:grid-cols-[1fr_340px]">
        {/* Coluna principal */}
        <div className="space-y-4">
          <FormInteracao leadId={l.id} />

          <section className="cartao p-4">
            <h2 className="mb-3 text-sm font-semibold">Linha do tempo</h2>
            <ol className="space-y-4">
              {eventos.map((e, i) => (
                <li key={i} className="flex gap-3">
                  <span className={`mt-1.5 size-2 shrink-0 rounded-full ${e.destaque ? "bg-marca" : "bg-stone-300"}`} />
                  <div className="min-w-0 flex-1">
                    <p className={`text-sm ${e.destaque ? "font-medium" : "text-stone-600"}`}>{e.titulo}</p>
                    {e.texto && <p className="mt-0.5 text-sm whitespace-pre-wrap text-stone-700">{e.texto}</p>}
                    <p className="mt-0.5 text-xs text-stone-400">
                      {dataHora(e.quando)}
                      {e.autor && ` · ${e.autor}`}
                    </p>
                  </div>
                </li>
              ))}
            </ol>
          </section>
        </div>

        {/* Lateral */}
        <aside className="space-y-4">
          <section className="cartao space-y-3 p-4">
            <h2 className="text-sm font-semibold">Etapa</h2>
            <SeletorEtapa lead={{ id: l.id, nome: l.nome }} atual={situacaoAtual} situacoes={situacoes} motivos={(mots.data ?? []) as Motivo[]} />
            {situacaoAtual.flag_cancelado && motivoAtual && (
              <p className="text-sm text-stone-600">
                Motivo: {motivoAtual.nome}
                {l.descricao_cancelamento && ` — ${l.descricao_cancelamento}`}
              </p>
            )}
          </section>

          <section className="cartao space-y-3 p-4">
            <h2 className="text-sm font-semibold">Responsáveis</h2>
            {podeDistribuir(eu) ? (
              <FormAtribuir
                leadId={l.id}
                equipeId={l.equipe_id}
                corretorId={l.corretor_id}
                equipes={eu.papel === "lider" ? [] : equipes.filter((e) => e.ativa)}
                corretores={corretoresElegiveis}
              />
            ) : (
              <dl className="text-sm">
                <dt className="text-stone-500">Equipe</dt>
                <dd>{l.equipe_nome ?? "—"}</dd>
                <dt className="mt-2 text-stone-500">Corretor</dt>
                <dd>{l.corretor_nome ?? "—"}</dd>
              </dl>
            )}
            <p className="text-xs text-stone-500">
              Primeiro contato do corretor: {duracao(l.data_associacao_corretor, l.data_primeira_interacao_corretor)}
            </p>
          </section>

          <section className="cartao space-y-3 p-4">
            <h2 className="text-sm font-semibold">Agenda do lead</h2>
            <ListaTarefas tarefas={(tars.data ?? []) as Tarefa[]} usuarios={usuarios} />
            <FormTarefa leadId={l.id} empreendimentos={(emps.data ?? []) as Empreendimento[]} responsaveis={corretoresElegiveis} eu={eu} />
          </section>

          <section className="cartao p-4">
            <h2 className="mb-2 text-sm font-semibold">Origem</h2>
            <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
              <dt className="text-stone-500">Origem</dt>
              <dd>{l.origem_nome}</dd>
              <dt className="text-stone-500">1ª conversão</dt>
              <dd className="truncate">{l.conversao_original ?? "—"}</dd>
              <dt className="text-stone-500">Última</dt>
              <dd className="truncate">{l.conversao_ultima ?? "—"}</dd>
              <dt className="text-stone-500">Conversões</dt>
              <dd>{l.total_conversoes}</dd>
              <dt className="text-stone-500">Interesse</dt>
              <dd>{l.empreendimentos ?? "—"}</dd>
              <dt className="text-stone-500">Entrada</dt>
              <dd>{dataHora(l.created_at)}</dd>
            </dl>
          </section>

          <FormDados lead={l} />
        </aside>
      </div>
    </div>
  );
}
