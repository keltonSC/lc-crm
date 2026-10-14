"use client";

import { useActionState, useState } from "react";
import { entrar, entrarComGoogle, esqueciSenha, type EstadoLogin } from "./actions";

export function FormLogin({ next, google }: { next: string; google: boolean }) {
  const [estado, acao, enviando] = useActionState<EstadoLogin, FormData>(entrar, {});
  const [estadoReset, acaoReset, enviandoReset] = useActionState<EstadoLogin, FormData>(esqueciSenha, {});
  const [ver, setVer] = useState(false);

  const msg = estado.erro ?? estadoReset.erro;

  return (
    <div className="mt-6 space-y-4">
      <form action={acao} className="space-y-4">
        <input type="hidden" name="next" value={next} />
        <div>
          <label className="rotulo" htmlFor="email">E-mail</label>
          <input id="email" name="email" type="email" autoComplete="email" required className="campo" />
        </div>
        <div>
          <label className="rotulo" htmlFor="senha">Senha</label>
          <div className="relative">
            <input
              id="senha"
              name="senha"
              type={ver ? "text" : "password"}
              autoComplete="current-password"
              className="campo pr-16"
            />
            <button
              type="button"
              onClick={() => setVer((v) => !v)}
              className="absolute inset-y-0 right-2 my-auto h-7 rounded px-2 text-xs text-stone-500 hover:bg-stone-100"
            >
              {ver ? "Ocultar" : "Mostrar"}
            </button>
          </div>
        </div>
        {msg && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{msg}</p>}
        {estadoReset.aviso && (
          <p className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-800">{estadoReset.aviso}</p>
        )}
        <button className="btn-primario w-full py-2.5" disabled={enviando}>
          {enviando ? "Entrando…" : "Entrar"}
        </button>
        <button
          formAction={acaoReset}
          formNoValidate
          className="block text-sm text-marca hover:underline disabled:opacity-50"
          disabled={enviandoReset}
        >
          Esqueci minha senha
        </button>
      </form>

      {google && (
        <>
          <div className="flex items-center gap-3 text-xs text-stone-400">
            <span className="h-px flex-1 bg-stone-200" />
            ou
            <span className="h-px flex-1 bg-stone-200" />
          </div>
          <form action={entrarComGoogle}>
            <button className="btn-secundario w-full py-2.5">Entrar com Google</button>
          </form>
        </>
      )}
    </div>
  );
}
