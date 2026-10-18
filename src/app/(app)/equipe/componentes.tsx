"use client";

import { useActionState, useEffect, useRef, useState, useTransition } from "react";
import { PAPEL_NOME, type Equipe, type Papel, type Usuario } from "@/lib/types";
import { iniciais } from "@/lib/format";
import {
  convidarUsuario,
  criarEquipe,
  salvarEquipe,
  salvarUsuario,
  type Resultado,
  type ResultadoConvite,
} from "./actions";

const PAPEIS = Object.keys(PAPEL_NOME) as Papel[];

export function LinhaUsuario({ usuario: u, equipes, souEu }: { usuario: Usuario; equipes: Equipe[]; souEu: boolean }) {
  const [pendente, iniciar] = useTransition();
  const [erro, setErro] = useState<string>();
  const salvar = (m: Parameters<typeof salvarUsuario>[1]) =>
    iniciar(async () => setErro((await salvarUsuario(u.id, m)).erro));

  return (
    <div className={`flex flex-wrap items-center gap-3 p-3 ${!u.ativo ? "opacity-50" : ""} ${pendente ? "animate-pulse" : ""}`}>
      <span className="grid size-9 place-items-center rounded-full bg-stone-200 text-xs font-semibold">{iniciais(u.nome)}</span>
      <div className="min-w-40 flex-1">
        <p className="text-sm font-medium">{u.nome}</p>
        <p className="text-xs text-stone-500">{u.email}</p>
        {erro && <p className="text-xs text-red-600">{erro}</p>}
      </div>
      <select
        aria-label="Papel"
        className="campo w-auto"
        value={u.papel}
        disabled={souEu}
        onChange={(e) => salvar({ papel: e.target.value as Papel })}
      >
        {PAPEIS.map((p) => (
          <option key={p} value={p}>{PAPEL_NOME[p]}</option>
        ))}
      </select>
      <select
        aria-label="Equipe"
        className="campo w-auto"
        value={u.equipe_id ?? ""}
        onChange={(e) => salvar({ equipe_id: e.target.value || null })}
      >
        <option value="">Sem equipe</option>
        {equipes.map((e) => (
          <option key={e.id} value={e.id}>{e.nome}</option>
        ))}
      </select>
      {!souEu && (
        <button onClick={() => salvar({ ativo: !u.ativo })} className="text-xs text-stone-500 hover:text-stone-900">
          {u.ativo ? "Desativar" : "Reativar"}
        </button>
      )}
    </div>
  );
}

export function LinhaEquipe({ equipe, membros }: { equipe: Equipe; membros: Usuario[] }) {
  const [pendente, iniciar] = useTransition();
  return (
    <li className={`rounded-lg border border-stone-200 p-3 ${pendente ? "opacity-60" : ""} ${!equipe.ativa ? "opacity-50" : ""}`}>
      <div className="flex items-center gap-2">
        <p className="flex-1 text-sm font-medium">{equipe.nome}</p>
        <span className="text-xs text-stone-500">{membros.length} pessoas</span>
      </div>
      <label className="rotulo mt-2" htmlFor={`lider-${equipe.id}`}>Líder</label>
      <select
        id={`lider-${equipe.id}`}
        className="campo"
        value={equipe.lider_id ?? ""}
        onChange={(e) => iniciar(async () => void (await salvarEquipe(equipe.id, { lider_id: e.target.value || null })))}
      >
        <option value="">Sem líder</option>
        {membros.map((m) => (
          <option key={m.id} value={m.id}>{m.nome}</option>
        ))}
      </select>
    </li>
  );
}

export function FormConvite({ equipes }: { equipes: Equipe[] }) {
  const [estado, acao, enviando] = useActionState<ResultadoConvite, FormData>(convidarUsuario, {});
  const ref = useRef<HTMLFormElement>(null);
  useEffect(() => {
    if (estado.ok) ref.current?.reset();
  }, [estado]);
  return (
    <form ref={ref} action={acao} className="space-y-2">
      <input name="nome" placeholder="Nome" required className="campo" />
      <input name="email" type="email" placeholder="E-mail" required className="campo" />
      <input name="telefone" type="tel" placeholder="Telefone (opcional)" className="campo" />
      <div className="grid grid-cols-2 gap-2">
        <select name="papel" defaultValue="corretor" className="campo">
          {PAPEIS.map((p) => (
            <option key={p} value={p}>{PAPEL_NOME[p]}</option>
          ))}
        </select>
        <select name="equipe_id" defaultValue="" className="campo">
          <option value="">Sem equipe</option>
          {equipes.map((e) => (
            <option key={e.id} value={e.id}>{e.nome}</option>
          ))}
        </select>
      </div>
      {estado.erro && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{estado.erro}</p>}
      {estado.ok && (
        <div className="space-y-2 rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
          <p>{estado.ok} Agora mande o link para a pessoa:</p>
          {estado.whatsapp && (
            <a href={estado.whatsapp} target="_blank" rel="noopener" className="btn w-full bg-emerald-600 text-white hover:bg-emerald-700">
              Enviar pelo WhatsApp
            </a>
          )}
          {estado.link && <p className="break-all text-xs text-emerald-900">{estado.link}</p>}
        </div>
      )}
      <button className="btn-primario w-full" disabled={enviando}>{enviando ? "Criando…" : "Criar convite"}</button>
    </form>
  );
}

export function FormNovaEquipe() {
  const [estado, acao, salvando] = useActionState<Resultado, FormData>(criarEquipe, {});
  return (
    <form action={acao} className="flex gap-2 border-t border-stone-100 pt-3">
      <input name="nome" placeholder="Nova equipe" className="campo" />
      <button className="btn-secundario" disabled={salvando}>Criar</button>
      {estado.erro && <p className="text-xs text-red-600">{estado.erro}</p>}
    </form>
  );
}
