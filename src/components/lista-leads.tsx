import Link from "next/link";
import type { LeadView } from "@/lib/types";
import { relativo, telefone } from "@/lib/format";

export function Etapa({ nome, cor }: { nome: string; cor: string }) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-stone-100 px-2 py-0.5 text-xs font-medium whitespace-nowrap">
      <span className="size-2 rounded-full" style={{ background: cor }} />
      {nome}
    </span>
  );
}

export function ListaLeads({ leads }: { leads: LeadView[] }) {
  return (
    <>
      {/* Celular: cartões */}
      <ul className="space-y-2 md:hidden">
        {leads.map((l) => (
          <li key={l.id}>
            <Link href={`/leads/${l.id}`} className="cartao block p-3">
              <div className="flex items-center gap-2">
                <p className="flex-1 truncate font-medium">{l.nome}</p>
                <Etapa nome={l.situacao_nome} cor={l.situacao_cor} />
              </div>
              <p className="mt-1 text-sm text-stone-500">{telefone(l.telefone)}</p>
              <p className="mt-1 text-xs text-stone-500">
                {l.corretor_nome ?? "Sem corretor"} · {relativo(l.data_ultima_interacao ?? l.created_at)}
              </p>
            </Link>
          </li>
        ))}
      </ul>

      {/* Desktop: tabela */}
      <div className="cartao hidden overflow-x-auto md:block">
        <table className="w-full text-sm">
          <thead className="border-b border-stone-200 text-left text-xs text-stone-500">
            <tr>
              <th className="px-4 py-2.5 font-medium">Lead</th>
              <th className="px-4 py-2.5 font-medium">Etapa</th>
              <th className="px-4 py-2.5 font-medium">Interesse</th>
              <th className="px-4 py-2.5 font-medium">Origem</th>
              <th className="px-4 py-2.5 font-medium">Equipe / corretor</th>
              <th className="px-4 py-2.5 font-medium">Último contato</th>
              <th className="px-4 py-2.5 font-medium">Entrada</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-stone-100">
            {leads.map((l) => (
              <tr key={l.id} className="hover:bg-stone-50">
                <td className="px-4 py-2.5">
                  <Link href={`/leads/${l.id}`} className="font-medium hover:text-marca">
                    {l.nome}
                  </Link>
                  <p className="text-xs text-stone-500">{telefone(l.telefone)}</p>
                </td>
                <td className="px-4 py-2.5">
                  <Etapa nome={l.situacao_nome} cor={l.situacao_cor} />
                  {l.sla_estourado && <span className="ml-1 text-xs text-red-600">atrasado</span>}
                </td>
                <td className="max-w-48 truncate px-4 py-2.5 text-stone-600">{l.empreendimentos ?? "—"}</td>
                <td className="px-4 py-2.5 text-stone-600">
                  {l.origem_nome}
                  {l.total_conversoes > 1 && <span className="ml-1 text-xs text-marca">×{l.total_conversoes}</span>}
                </td>
                <td className="px-4 py-2.5 text-stone-600">
                  {l.equipe_nome ?? "—"}
                  <p className="text-xs">{l.corretor_nome ?? "Sem corretor"}</p>
                </td>
                <td className="px-4 py-2.5 text-stone-600">{relativo(l.data_ultima_interacao)}</td>
                <td className="px-4 py-2.5 text-stone-600">{relativo(l.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
