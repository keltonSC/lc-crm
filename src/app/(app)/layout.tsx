import Link from "next/link";
import { Suspense } from "react";
import { usuarioAtual } from "@/lib/sessao";
import { PAPEL_NOME } from "@/lib/types";
import { iniciais } from "@/lib/format";
import { sair } from "@/app/login/actions";
import { NavLinks } from "@/components/nav-links";
import { BuscaGlobal } from "@/components/busca-global";
import { BotaoOnline } from "./botao-online";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const eu = await usuarioAtual();
  const itens = [
    { href: "/leads", nome: "Leads" },
    { href: "/tarefas", nome: "Agenda" },
    ...(eu.papel === "gestor"
      ? [
          { href: "/equipe", nome: "Equipe" },
          { href: "/distribuicao", nome: "Distribuição" },
        ]
      : []),
  ];

  return (
    <div className="min-h-dvh pb-16 md:pb-0">
      <header className="sticky top-0 z-30 border-b border-stone-200 bg-white/90 backdrop-blur">
        <div className="mx-auto flex h-14 max-w-7xl items-center gap-4 px-4">
          <Link href="/leads" className="flex shrink-0 items-center gap-2">
            <span className="grid size-8 place-items-center rounded-md bg-marca text-sm font-bold text-white">LC</span>
            <span className="hidden font-semibold sm:inline">CRM</span>
          </Link>
          <nav className="hidden md:block">
            <NavLinks itens={itens} variante="topo" />
          </nav>
          <div className="flex-1">
            <Suspense>
              <BuscaGlobal />
            </Suspense>
          </div>
          <details className="relative">
            <summary className="flex cursor-pointer list-none items-center gap-2 rounded-full p-1 hover:bg-stone-100">
              <span className="grid size-8 place-items-center rounded-full bg-stone-800 text-xs font-semibold text-white">
                {iniciais(eu.nome)}
              </span>
            </summary>
            <div className="cartao absolute right-0 mt-2 w-56 p-2 shadow-lg">
              <div className="px-2 py-1.5">
                <p className="truncate text-sm font-medium">{eu.nome}</p>
                <p className="text-xs text-stone-500">{PAPEL_NOME[eu.papel]}</p>
              </div>
              {eu.papel === "corretor" && <BotaoOnline inicial={eu.online} />}
              <form action={sair}>
                <button className="w-full rounded-md px-2 py-1.5 text-left text-sm hover:bg-stone-100">Sair</button>
              </form>
            </div>
          </details>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-6">{children}</main>

      {/* Navegação de baixo no celular */}
      <nav className="fixed inset-x-0 bottom-0 z-30 border-t border-stone-200 bg-white md:hidden">
        <NavLinks itens={[...itens, { href: "/leads/novo", nome: "+ Lead" }]} variante="baixo" />
      </nav>
    </div>
  );
}
