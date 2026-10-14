"use client";

import { useActionState, useEffect, useRef, useState, useTransition } from "react";
import type { Empreendimento, Tarefa, Usuario } from "@/lib/types";
import { dataHora } from "@/lib/format";
import { criarTarefa, mudarTarefa, type Resultado } from "../actions";

export function ListaTarefas({ tarefas, usuarios }: { tarefas: Tarefa[]; usuarios: Usuario[] }) {
  const [pendente, iniciar] = useTransition();
  const abertas = tarefas.filter((t) => t.situacao === "pendente" || t.situacao === "andamento");
  const fechadas = tarefas.filter((t) => !abertas.includes(t));
  const nome = (id: string | null) => usuarios.find((u) => u.id === id)?.nome ?? "—";

  if (tarefas.length === 0) return <p className="text-sm text-stone-500">Nada agendado.</p>;

  return (
    <ul className={`space-y-2 ${pendente ? "opacity-60" : ""}`}>
      {abertas.map((t) => {
        const atrasada = new Date(t.data) < new Date();
        return (
          <li key={t.id} className="rounded-lg border border-stone-200 p-2.5">
            <div className="flex items-start gap-2">
              <span className={`mt-0.5 rounded px-1.5 text-[11px] font-medium ${t.tipo === "visita" ? "bg-cyan-100 text-cyan-800" : "bg-stone-100 text-stone-700"}`}>
                {t.tipo === "visita" ? "Visita" : "Tarefa"}
              </span>
              <p className="flex-1 text-sm font-medium">{t.titulo}</p>
            </div>
            <p className={`mt-1 text-xs ${atrasada ? "font-medium text-red-600" : "text-stone-500"}`}>
              {dataHora(t.data)} · {nome(t.responsavel_id)}
            </p>
            <div className="mt-2 flex gap-2">
              <button onClick={() => iniciar(async () => void (await mudarTarefa(t.id, "concluida")))} className="text-xs font-medium text-emerald-700 hover:underline">
                Concluir
              </button>
              <button onClick={() => iniciar(async () => void (await mudarTarefa(t.id, "cancelada")))} className="text-xs text-stone-500 hover:underline">
                Cancelar
              </button>
            </div>
          </li>
        );
      })}
      {fechadas.length > 0 && (
        <li className="pt-1 text-xs text-stone-500">
          {fechadas.length} concluída{fechadas.length > 1 ? "s" : ""} ou cancelada{fechadas.length > 1 ? "s" : ""}
        </li>
      )}
    </ul>
  );
}

export function FormTarefa({
  leadId,
  empreendimentos,
  responsaveis,
  eu,
}: {
  leadId: number;
  empreendimentos: Empreendimento[];
  responsaveis: Usuario[];
  eu: Usuario;
}) {
  const [aberto, setAberto] = useState(false);
  const [tipo, setTipo] = useState<"tarefa" | "visita">("tarefa");
  const [estado, acao, salvando] = useActionState<Resultado, FormData>(criarTarefa, {});
  const ref = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (estado.ok) {
      ref.current?.reset();
      setAberto(false);
    }
  }, [estado]);

  if (!aberto)
    return (
      <button onClick={() => setAberto(true)} className="btn-secundario w-full">
        Agendar tarefa ou visita
      </button>
    );

  return (
    <form ref={ref} action={acao} className="space-y-3 border-t border-stone-100 pt-3">
      <input type="hidden" name="lead_id" value={leadId} />
      <input type="hidden" name="tipo" value={tipo} />
      <div className="flex gap-1">
        {(["tarefa", "visita"] as const).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTipo(t)}
            className={`flex-1 rounded-md py-1 text-sm ${tipo === t ? "bg-stone-800 text-white" : "bg-stone-100"}`}
          >
            {t === "tarefa" ? "Tarefa" : "Visita"}
          </button>
        ))}
      </div>
      <input name="titulo" placeholder={tipo === "visita" ? "Visita ao decorado" : "Retornar contato"} className="campo" />
      <input name="data" type="datetime-local" required className="campo" />
      {tipo === "visita" && empreendimentos.length > 0 && (
        <select name="empreendimento_id" className="campo" defaultValue="">
          <option value="">Empreendimento (opcional)</option>
          {empreendimentos.map((e) => (
            <option key={e.id} value={e.id}>{e.nome}</option>
          ))}
        </select>
      )}
      <div className="grid grid-cols-2 gap-2">
        <select name="prioridade" className="campo" defaultValue="normal">
          <option value="alta">Prioridade alta</option>
          <option value="normal">Normal</option>
          <option value="baixa">Baixa</option>
        </select>
        {eu.papel !== "corretor" ? (
          <select name="responsavel_id" className="campo" defaultValue={eu.id}>
            <option value={eu.id}>Eu</option>
            {responsaveis
              .filter((r) => r.id !== eu.id)
              .map((r) => (
                <option key={r.id} value={r.id}>{r.nome}</option>
              ))}
          </select>
        ) : (
          tipo === "visita" && (
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="visita_virtual" className="accent-marca" /> Virtual
            </label>
          )
        )}
      </div>
      {estado.erro && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{estado.erro}</p>}
      <div className="flex gap-2">
        <button type="button" onClick={() => setAberto(false)} className="btn-secundario flex-1">Fechar</button>
        <button className="btn-primario flex-1" disabled={salvando}>{salvando ? "Salvando…" : "Agendar"}</button>
      </div>
    </form>
  );
}
