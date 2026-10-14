"use client";

import Link from "next/link";
import { useOptimistic, useState, useTransition } from "react";
import type { LeadView, Motivo, Situacao } from "@/lib/types";
import { relativo } from "@/lib/format";
import { mudarSituacao } from "@/app/(app)/leads/actions";
import { DialogoCancelar } from "./dialogo-cancelar";

const POR_COLUNA = 60;

export function Kanban({ leads, situacoes, motivos }: { leads: LeadView[]; situacoes: Situacao[]; motivos: Motivo[] }) {
  const [erro, setErro] = useState<string>();
  const [cancelando, setCancelando] = useState<LeadView | null>(null);
  const [arrastando, setArrastando] = useState<number | null>(null);
  const [sobre, setSobre] = useState<string | null>(null);
  const [, iniciar] = useTransition();
  const [otimista, mover] = useOptimistic(leads, (atual, { id, para }: { id: number; para: string }) =>
    atual.map((l) => (l.id === id ? { ...l, situacao_id: para } : l)),
  );

  function soltar(situacao: Situacao) {
    const lead = otimista.find((l) => l.id === arrastando);
    setArrastando(null);
    setSobre(null);
    if (!lead || lead.situacao_id === situacao.id) return;
    if (situacao.flag_cancelado) {
      setCancelando(lead);
      return;
    }
    iniciar(async () => {
      mover({ id: lead.id, para: situacao.id });
      const r = await mudarSituacao(lead.id, situacao.id);
      setErro(r.erro);
    });
  }

  return (
    <>
      {erro && (
        <p className="mb-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700" role="alert">
          {erro}
        </p>
      )}
      <div className="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-4">
        {situacoes.map((s) => {
          const daColuna = otimista.filter((l) => l.situacao_id === s.id);
          const recolhida = s.flag_cancelado && daColuna.length === 0;
          return (
            <section
              key={s.id}
              onDragOver={(e) => {
                e.preventDefault();
                setSobre(s.id);
              }}
              onDragLeave={() => setSobre((x) => (x === s.id ? null : x))}
              onDrop={() => soltar(s)}
              className={`flex w-72 shrink-0 snap-start flex-col rounded-xl bg-stone-100 transition ${
                sobre === s.id ? "ring-2 ring-marca" : ""
              } ${recolhida ? "w-44" : ""}`}
            >
              <header className="flex items-center gap-2 px-3 pt-3 pb-2">
                <span className="size-2.5 rounded-full" style={{ background: s.cor }} />
                <h2 className="truncate text-sm font-semibold">{s.nome}</h2>
                <span className="ml-auto text-xs text-stone-500">{daColuna.length}</span>
              </header>
              <ul className="flex min-h-24 flex-col gap-2 px-2 pb-2">
                {recolhida && (
                  <li className="rounded-lg border border-dashed border-stone-300 p-3 text-center text-xs text-stone-500">
                    Arraste aqui para cancelar
                  </li>
                )}
                {daColuna.slice(0, POR_COLUNA).map((l) => (
                  <li
                    key={l.id}
                    draggable
                    onDragStart={() => setArrastando(l.id)}
                    onDragEnd={() => setArrastando(null)}
                    className={`cartao cursor-grab p-3 shadow-sm active:cursor-grabbing ${arrastando === l.id ? "opacity-40" : ""}`}
                  >
                    <Link href={`/leads/${l.id}`} className="block" draggable={false}>
                      <div className="flex items-start gap-2">
                        <p className="flex-1 truncate text-sm font-medium">{l.nome}</p>
                        {l.sla_estourado && (
                          <span title="Passou do prazo nesta etapa" className="rounded bg-red-100 px-1.5 text-[11px] font-medium text-red-700">
                            atrasado
                          </span>
                        )}
                      </div>
                      <p className="mt-0.5 truncate text-xs text-stone-500">
                        {l.empreendimentos ?? l.conversao_ultima ?? l.origem_nome}
                      </p>
                      <div className="mt-2 flex items-center gap-2 text-[11px] text-stone-500">
                        <span className="truncate">{l.corretor_nome ?? "Sem corretor"}</span>
                        <span className="ml-auto shrink-0">{relativo(l.data_ultima_interacao ?? l.created_at)}</span>
                      </div>
                      {l.total_conversoes > 1 && (
                        <p className="mt-1 text-[11px] text-marca">{l.total_conversoes} conversões</p>
                      )}
                    </Link>
                  </li>
                ))}
                {daColuna.length > POR_COLUNA && (
                  <li className="px-1 text-xs text-stone-500">
                    +{daColuna.length - POR_COLUNA} — filtre ou use a lista para ver todos
                  </li>
                )}
              </ul>
            </section>
          );
        })}
      </div>
      {cancelando && <DialogoCancelar lead={cancelando} motivos={motivos} aoFechar={() => setCancelando(null)} />}
    </>
  );
}
