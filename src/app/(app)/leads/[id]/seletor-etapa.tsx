"use client";

import { useState, useTransition } from "react";
import type { Motivo, Situacao } from "@/lib/types";
import { mudarSituacao } from "../actions";
import { DialogoCancelar } from "@/components/dialogo-cancelar";

export function SeletorEtapa({
  lead,
  atual,
  situacoes,
  motivos,
}: {
  lead: { id: number; nome: string };
  atual: Situacao;
  situacoes: Situacao[];
  motivos: Motivo[];
}) {
  const [pendente, iniciar] = useTransition();
  const [erro, setErro] = useState<string>();
  const [cancelar, setCancelar] = useState(false);

  function escolher(s: Situacao) {
    if (s.id === atual.id) return;
    if (s.flag_cancelado) return setCancelar(true);
    iniciar(async () => setErro((await mudarSituacao(lead.id, s.id)).erro));
  }

  const ativas = situacoes.filter((s) => !s.flag_cancelado);
  const cancelado = situacoes.find((s) => s.flag_cancelado);

  return (
    <div className={pendente ? "opacity-60" : ""}>
      <ol className="space-y-1">
        {ativas.map((s) => {
          const passou = s.ordem < atual.ordem && !atual.flag_cancelado;
          const eh = s.id === atual.id;
          return (
            <li key={s.id}>
              <button
                onClick={() => escolher(s)}
                disabled={pendente}
                className={`flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm transition ${
                  eh ? "bg-marca-clara font-medium text-marca-escura" : "hover:bg-stone-100"
                } ${passou ? "text-stone-400" : ""}`}
              >
                <span className="size-2.5 rounded-full" style={{ background: passou || eh ? s.cor : "transparent", border: `2px solid ${s.cor}` }} />
                {s.nome}
              </button>
            </li>
          );
        })}
      </ol>
      {cancelado && !atual.flag_cancelado && (
        <button onClick={() => setCancelar(true)} className="mt-2 text-sm text-stone-500 hover:text-red-700">
          Cancelar lead…
        </button>
      )}
      {erro && <p className="mt-2 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erro}</p>}
      {cancelar && <DialogoCancelar lead={lead} motivos={motivos} aoFechar={() => setCancelar(false)} />}
    </div>
  );
}
