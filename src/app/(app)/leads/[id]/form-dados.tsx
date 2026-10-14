"use client";

import { useActionState } from "react";
import type { LeadView } from "@/lib/types";
import { salvarDados, type Resultado } from "../actions";

export function FormDados({ lead }: { lead: LeadView }) {
  const [estado, acao, salvando] = useActionState<Resultado, FormData>(salvarDados, {});
  return (
    <details className="cartao p-4">
      <summary className="cursor-pointer text-sm font-semibold">Dados do lead</summary>
      <form action={acao} className="mt-3 space-y-3">
        <input type="hidden" name="lead_id" value={lead.id} />
        <div>
          <label className="rotulo" htmlFor="d-nome">Nome</label>
          <input id="d-nome" name="nome" defaultValue={lead.nome} className="campo" />
        </div>
        <div>
          <label className="rotulo" htmlFor="d-tel">Telefone</label>
          <input id="d-tel" name="telefone" defaultValue={lead.telefone ? `+${lead.telefone}` : ""} className="campo" />
        </div>
        <div>
          <label className="rotulo" htmlFor="d-email">E-mail</label>
          <input id="d-email" name="email" type="email" defaultValue={lead.email ?? ""} className="campo" />
        </div>
        <div>
          <label className="rotulo" htmlFor="d-pv">Chance de compra</label>
          <select id="d-pv" name="possibilidade_venda" defaultValue={lead.possibilidade_venda ?? ""} className="campo">
            <option value="">Não avaliada</option>
            <option value="1">1 · muito baixa</option>
            <option value="2">2 · baixa</option>
            <option value="3">3 · média</option>
            <option value="4">4 · alta</option>
            <option value="5">5 · muito alta</option>
          </select>
        </div>
        <div>
          <label className="rotulo" htmlFor="d-tags">Etiquetas (separe por vírgula)</label>
          <input id="d-tags" name="tags" defaultValue={lead.tags.join(", ")} className="campo" />
        </div>
        {estado.erro && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{estado.erro}</p>}
        {estado.ok && <p className="text-sm text-emerald-700">Salvo.</p>}
        <button className="btn-secundario w-full" disabled={salvando}>
          {salvando ? "Salvando…" : "Salvar dados"}
        </button>
      </form>
    </details>
  );
}
