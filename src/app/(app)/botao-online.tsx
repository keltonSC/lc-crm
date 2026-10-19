"use client";

import { useState, useTransition } from "react";
import { alternarOnline } from "./online-actions";

export function BotaoOnline({ inicial }: { inicial: boolean }) {
  const [online, setOnline] = useState(inicial);
  const [pendente, iniciar] = useTransition();
  const [erro, setErro] = useState<string>();
  const alternar = () =>
    iniciar(async () => {
      const novo = !online;
      const r = await alternarOnline(novo);
      if (r.erro) return setErro(r.erro);
      setErro(undefined);
      setOnline(novo);
    });
  return (
    <div className="px-2 py-1.5">
      <button
        onClick={alternar}
        disabled={pendente}
        role="switch"
        aria-checked={online}
        className="flex w-full items-center justify-between gap-2 text-sm"
      >
        <span>{online ? "Online · recebendo leads" : "Offline"}</span>
        <span className={`h-5 w-9 rounded-full p-0.5 transition ${online ? "bg-emerald-500" : "bg-stone-300"}`}>
          <span className={`block size-4 rounded-full bg-white transition ${online ? "translate-x-4" : ""}`} />
        </span>
      </button>
      {erro && <p className="text-xs text-red-600">{erro}</p>}
    </div>
  );
}
