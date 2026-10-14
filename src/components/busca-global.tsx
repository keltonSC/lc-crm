"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef } from "react";

/** Busca por nome, e-mail ou telefone. "/" foca o campo de qualquer tela. */
export function BuscaGlobal() {
  const router = useRouter();
  const params = useSearchParams();
  const ref = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const atalho = (e: KeyboardEvent) => {
      const alvo = e.target as HTMLElement;
      if (e.key === "/" && !["INPUT", "TEXTAREA", "SELECT"].includes(alvo.tagName)) {
        e.preventDefault();
        ref.current?.focus();
      }
    };
    window.addEventListener("keydown", atalho);
    return () => window.removeEventListener("keydown", atalho);
  }, []);

  return (
    <form
      role="search"
      onSubmit={(e) => {
        e.preventDefault();
        const q = ref.current?.value.trim() ?? "";
        router.push(q ? `/leads?q=${encodeURIComponent(q)}` : "/leads");
      }}
      className="mx-auto max-w-md"
    >
      <input
        ref={ref}
        key={params.get("q") ?? ""}
        defaultValue={params.get("q") ?? ""}
        placeholder="Buscar lead por nome, e-mail ou telefone   /"
        className="campo bg-stone-50"
        aria-label="Buscar leads"
      />
    </form>
  );
}
