"use client";

import { useActionState, useEffect, useRef, useState } from "react";
import type { Motivo } from "@/lib/types";
import { cancelarLead, type Resultado } from "@/app/(app)/leads/actions";

export function DialogoCancelar({
  lead,
  motivos,
  aoFechar,
}: {
  lead: { id: number; nome: string };
  motivos: Motivo[];
  aoFechar: () => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const [estado, acao, salvando] = useActionState<Resultado, FormData>(cancelarLead, {});
  const [motivo, setMotivo] = useState("");
  const exige = motivos.find((m) => m.id === motivo)?.exige_descricao;

  useEffect(() => {
    ref.current?.showModal();
  }, []);
  useEffect(() => {
    if (estado.ok) aoFechar();
  }, [estado.ok, aoFechar]);

  return (
    <dialog ref={ref} onClose={aoFechar} className="m-auto w-full max-w-md rounded-xl p-0 backdrop:bg-black/40">
      <form action={acao} className="space-y-4 p-5">
        <input type="hidden" name="lead_id" value={lead.id} />
        <div>
          <h2 className="text-lg font-semibold">Cancelar lead</h2>
          <p className="text-sm text-stone-500">{lead.nome}</p>
        </div>
        <div>
          <label className="rotulo" htmlFor="motivo_id">Motivo</label>
          <select id="motivo_id" name="motivo_id" required className="campo" value={motivo} onChange={(e) => setMotivo(e.target.value)}>
            <option value="" disabled>Escolha o motivo</option>
            {motivos.map((m) => (
              <option key={m.id} value={m.id}>{m.nome}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="rotulo" htmlFor="descricao">Descrição {exige ? "(obrigatória)" : "(opcional)"}</label>
          <textarea id="descricao" name="descricao" rows={3} required={exige} className="campo" />
        </div>
        {estado.erro && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{estado.erro}</p>}
        <div className="flex justify-end gap-2">
          <button type="button" onClick={aoFechar} className="btn-secundario">Voltar</button>
          <button className="btn bg-stone-900 text-white hover:bg-black" disabled={salvando}>
            {salvando ? "Cancelando…" : "Cancelar lead"}
          </button>
        </div>
      </form>
    </dialog>
  );
}
