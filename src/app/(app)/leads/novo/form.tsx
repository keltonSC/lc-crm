"use client";

import { useActionState, useState } from "react";
import type { Empreendimento, Equipe, Origem, Usuario } from "@/lib/types";
import { criarLead, type Resultado } from "../actions";

export function FormNovoLead({
  origens,
  empreendimentos,
  equipes,
  corretores,
  eu,
}: {
  origens: Origem[];
  empreendimentos: Empreendimento[];
  equipes: Equipe[];
  corretores: Usuario[];
  eu: Usuario;
}) {
  const [estado, acao, salvando] = useActionState<Resultado, FormData>(criarLead, {});
  const [equipe, setEquipe] = useState(eu.papel === "lider" ? (eu.equipe_id ?? "") : "");
  const corretoresDaEquipe = equipe ? corretores.filter((c) => c.equipe_id === equipe) : corretores;

  return (
    <form action={acao} className="cartao space-y-5 p-5">
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="sm:col-span-2">
          <label className="rotulo" htmlFor="nome">Nome</label>
          <input id="nome" name="nome" className="campo" autoFocus />
        </div>
        <div>
          <label className="rotulo" htmlFor="telefone">Telefone / WhatsApp</label>
          <input id="telefone" name="telefone" type="tel" inputMode="tel" placeholder="(85) 99999-9999" className="campo" />
        </div>
        <div>
          <label className="rotulo" htmlFor="email">E-mail</label>
          <input id="email" name="email" type="email" className="campo" />
        </div>
        <div>
          <label className="rotulo" htmlFor="origem">Origem</label>
          <select id="origem" name="origem" className="campo" defaultValue={eu.papel === "corretor" ? "CO" : "GE"}>
            {origens.map((o) => (
              <option key={o.codigo} value={o.codigo}>{o.nome}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="rotulo" htmlFor="conversao">Campanha / formulário</label>
          <input id="conversao" name="conversao" placeholder="Ex.: Plantão BM900" className="campo" />
        </div>
      </div>

      {empreendimentos.length > 0 && (
        <fieldset>
          <legend className="rotulo">Empreendimentos de interesse</legend>
          <div className="flex flex-wrap gap-2">
            {empreendimentos.map((e) => (
              <label key={e.id} className="flex cursor-pointer items-center gap-2 rounded-full border border-stone-300 px-3 py-1 text-sm has-checked:border-marca has-checked:bg-marca-clara">
                <input type="checkbox" name="empreendimentos" value={e.id} className="accent-marca" />
                {e.nome}
              </label>
            ))}
          </div>
        </fieldset>
      )}

      {corretores.length > 0 && (
        <div className="grid gap-4 sm:grid-cols-2">
          {equipes.length > 0 && eu.papel !== "lider" && (
            <div>
              <label className="rotulo" htmlFor="equipe_id">Equipe</label>
              <select id="equipe_id" name="equipe_id" className="campo" value={equipe} onChange={(e) => setEquipe(e.target.value)}>
                <option value="">Sem equipe</option>
                {equipes.map((e) => (
                  <option key={e.id} value={e.id}>{e.nome}</option>
                ))}
              </select>
            </div>
          )}
          <div>
            <label className="rotulo" htmlFor="corretor_id">Corretor</label>
            <select id="corretor_id" name="corretor_id" className="campo" defaultValue="">
              <option value="">Sem corretor (distribuir depois)</option>
              {corretoresDaEquipe.map((c) => (
                <option key={c.id} value={c.id}>{c.nome}</option>
              ))}
            </select>
          </div>
        </div>
      )}

      <div>
        <label className="rotulo" htmlFor="observacao">Observação</label>
        <textarea id="observacao" name="observacao" rows={3} className="campo" placeholder="O que o cliente procura, melhor horário…" />
      </div>

      {estado.erro && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{estado.erro}</p>}
      <div className="flex justify-end">
        <button className="btn-primario" disabled={salvando}>
          {salvando ? "Salvando…" : "Cadastrar lead"}
        </button>
      </div>
    </form>
  );
}
