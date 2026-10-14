"use client";

import { useActionState, useEffect, useRef, useState } from "react";
import { RESULTADO_LIGACAO, TIPO_INTERACAO, type Interacao } from "@/lib/types";
import { registrarInteracao, type Resultado } from "../actions";

const TIPOS = Object.keys(TIPO_INTERACAO) as Interacao["tipo"][];

export function FormInteracao({ leadId }: { leadId: number }) {
  const [estado, acao, salvando] = useActionState<Resultado, FormData>(registrarInteracao, {});
  const [tipo, setTipo] = useState<Interacao["tipo"]>("ligacao");
  const ref = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (estado.ok) ref.current?.reset();
  }, [estado]);

  return (
    <form ref={ref} action={acao} className="cartao space-y-3 p-4">
      <input type="hidden" name="lead_id" value={leadId} />
      <input type="hidden" name="tipo" value={tipo} />
      <div className="flex flex-wrap gap-1">
        {TIPOS.map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTipo(t)}
            className={`rounded-full px-3 py-1 text-sm ${tipo === t ? "bg-stone-800 text-white" : "bg-stone-100 text-stone-700 hover:bg-stone-200"}`}
          >
            {TIPO_INTERACAO[t]}
          </button>
        ))}
      </div>
      {tipo === "ligacao" && (
        <div className="flex flex-wrap gap-3 text-sm">
          {Object.entries(RESULTADO_LIGACAO).map(([v, n], i) => (
            <label key={v} className="flex items-center gap-1.5">
              <input type="radio" name="resultado" value={v} defaultChecked={i === 0} className="accent-marca" />
              {n}
            </label>
          ))}
        </div>
      )}
      <textarea
        name="descricao"
        rows={3}
        required
        placeholder={tipo === "ligacao" ? "Como foi a ligação?" : "O que aconteceu?"}
        className="campo"
      />
      {estado.erro && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{estado.erro}</p>}
      <div className="flex justify-end">
        <button className="btn-primario" disabled={salvando}>
          {salvando ? "Registrando…" : "Registrar"}
        </button>
      </div>
    </form>
  );
}
