"use client";

import { useActionState, useState } from "react";
import type { Equipe, Usuario } from "@/lib/types";
import { atribuir, type Resultado } from "../actions";

export function FormAtribuir({
  leadId,
  equipeId,
  corretorId,
  equipes,
  corretores,
}: {
  leadId: number;
  equipeId: string | null;
  corretorId: string | null;
  equipes: Equipe[];
  corretores: Usuario[];
}) {
  const [estado, acao, salvando] = useActionState<Resultado, FormData>(atribuir, {});
  const [equipe, setEquipe] = useState(equipeId ?? "");
  const [corretor, setCorretor] = useState(corretorId ?? "");
  const lista = equipe ? corretores.filter((c) => c.equipe_id === equipe) : corretores;
  const mudou = equipe !== (equipeId ?? "") || corretor !== (corretorId ?? "");

  return (
    <form action={acao} className="space-y-2">
      <input type="hidden" name="lead_id" value={leadId} />
      {equipes.length > 0 && (
        <div>
          <label className="rotulo" htmlFor="equipe_id">Equipe</label>
          <select
            id="equipe_id"
            name="equipe_id"
            className="campo"
            value={equipe}
            onChange={(e) => {
              setEquipe(e.target.value);
              setCorretor("");
            }}
          >
            <option value="">Sem equipe</option>
            {equipes.map((e) => (
              <option key={e.id} value={e.id}>{e.nome}</option>
            ))}
          </select>
        </div>
      )}
      <div>
        <label className="rotulo" htmlFor="corretor_id">Corretor</label>
        <select id="corretor_id" name="corretor_id" className="campo" value={corretor} onChange={(e) => setCorretor(e.target.value)}>
          <option value="">Sem corretor</option>
          {lista.map((c) => (
            <option key={c.id} value={c.id}>{c.nome}</option>
          ))}
        </select>
      </div>
      {estado.erro && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{estado.erro}</p>}
      {mudou && (
        <button className="btn-primario w-full" disabled={salvando}>
          {salvando ? "Salvando…" : "Salvar responsáveis"}
        </button>
      )}
    </form>
  );
}
