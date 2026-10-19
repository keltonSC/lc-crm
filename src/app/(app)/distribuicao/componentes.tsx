"use client";

import { useState, useTransition } from "react";
import { distribuirFilaAgora, participarCorretor, participarEquipe, salvarConfig } from "./actions";

function Chave({ ligada, onChange, rotulo, desabilitada }: { ligada: boolean; onChange: (v: boolean) => void; rotulo: string; desabilitada?: boolean }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={ligada}
      aria-label={rotulo}
      disabled={desabilitada}
      onClick={() => onChange(!ligada)}
      className={`h-5 w-9 shrink-0 rounded-full p-0.5 transition disabled:opacity-50 ${ligada ? "bg-emerald-500" : "bg-stone-300"}`}
    >
      <span className={`block size-4 rounded-full bg-white transition ${ligada ? "translate-x-4" : ""}`} />
    </button>
  );
}

export function Configuracao({ ativa, apenasOnline }: { ativa: boolean; apenasOnline: boolean }) {
  const [pendente, iniciar] = useTransition();
  const [erro, setErro] = useState<string>();
  const salvar = (m: Parameters<typeof salvarConfig>[0]) => iniciar(async () => setErro((await salvarConfig(m)).erro));
  return (
    <div className={`space-y-4 ${pendente ? "opacity-60" : ""}`}>
      <label className="flex items-start justify-between gap-4">
        <span>
          <span className="block text-sm font-medium">Distribuição automática</span>
          <span className="block text-xs text-stone-500">Todo lead novo sem corretor entra na roleta.</span>
        </span>
        <Chave ligada={ativa} onChange={(v) => salvar({ ativa: v })} rotulo="Distribuição automática" />
      </label>
      <label className="flex items-start justify-between gap-4">
        <span>
          <span className="block text-sm font-medium">Somente corretores online</span>
          <span className="block text-xs text-stone-500">Sem ninguém online, o lead espera na fila até alguém ficar online.</span>
        </span>
        <Chave ligada={apenasOnline} onChange={(v) => salvar({ apenas_online: v })} rotulo="Somente corretores online" />
      </label>
      {erro && <p className="text-xs text-red-600">{erro}</p>}
    </div>
  );
}

export function SwitchParticipa({ tipo, id, participa }: { tipo: "equipe" | "corretor"; id: string; participa: boolean }) {
  const [pendente, iniciar] = useTransition();
  const [erro, setErro] = useState<string>();
  const acao = tipo === "equipe" ? participarEquipe : participarCorretor;
  return (
    <span className="flex items-center gap-2">
      {erro && <span className="text-xs text-red-600">{erro}</span>}
      <Chave
        ligada={participa}
        desabilitada={pendente}
        rotulo={participa ? "Remover da roleta" : "Incluir na roleta"}
        onChange={(v) => iniciar(async () => setErro((await acao(id, v)).erro))}
      />
    </span>
  );
}

export function BotaoDistribuirFila({ naFila }: { naFila: number }) {
  const [pendente, iniciar] = useTransition();
  const [msg, setMsg] = useState<{ erro?: string; ok?: string }>();
  return (
    <div className="space-y-2">
      <button
        className="btn-primario w-full"
        disabled={pendente || naFila === 0}
        onClick={() => iniciar(async () => setMsg(await distribuirFilaAgora()))}
      >
        {pendente ? "Distribuindo…" : "Distribuir fila agora"}
      </button>
      {msg?.erro && <p className="text-xs text-red-600">{msg.erro}</p>}
      {msg?.ok && <p className="text-xs text-emerald-700">{msg.ok}</p>}
    </div>
  );
}
