"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

type Item = { href: string; nome: string };

export function NavLinks({ itens, variante }: { itens: Item[]; variante: "topo" | "baixo" }) {
  const atual = usePathname();
  const ativo = (href: string) =>
    href === "/leads" ? atual === "/leads" || /^\/leads\/\d/.test(atual) : atual.startsWith(href);

  if (variante === "baixo") {
    return (
      <ul className="grid" style={{ gridTemplateColumns: `repeat(${itens.length}, 1fr)` }}>
        {itens.map((i) => (
          <li key={i.href}>
            <Link
              href={i.href}
              className={`block py-3 text-center text-sm ${ativo(i.href) ? "font-semibold text-marca" : "text-stone-600"}`}
            >
              {i.nome}
            </Link>
          </li>
        ))}
      </ul>
    );
  }
  return (
    <ul className="flex gap-1">
      {itens.map((i) => (
        <li key={i.href}>
          <Link
            href={i.href}
            className={`rounded-md px-3 py-1.5 text-sm ${
              ativo(i.href) ? "bg-marca-clara font-medium text-marca-escura" : "text-stone-600 hover:bg-stone-100"
            }`}
          >
            {i.nome}
          </Link>
        </li>
      ))}
    </ul>
  );
}
