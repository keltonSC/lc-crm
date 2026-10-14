"use client";

import { useTransition } from "react";
import { mudarTarefa } from "@/app/(app)/leads/actions";
import { whatsappLink } from "@/lib/format";

export function BotoesTarefa({ id, telefone }: { id: number; telefone: string | null }) {
  const [pendente, iniciar] = useTransition();
  const wa = whatsappLink(telefone);
  return (
    <div className={`flex gap-2 ${pendente ? "opacity-50" : ""}`}>
      {wa && (
        <a href={wa} target="_blank" rel="noopener" className="btn-secundario px-3 py-1 text-xs">
          WhatsApp
        </a>
      )}
      <button
        disabled={pendente}
        onClick={() => iniciar(async () => void (await mudarTarefa(id, "concluida")))}
        className="btn bg-emerald-600 px-3 py-1 text-xs text-white hover:bg-emerald-700"
      >
        Concluir
      </button>
    </div>
  );
}
