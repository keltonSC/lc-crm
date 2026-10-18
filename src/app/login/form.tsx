"use client";

import { useActionState, useState } from "react";
import { entrar, entrarComGoogle, esqueciSenha, primeiroAcesso, type EstadoLogin } from "./actions";

export function FormLogin({
  next,
  google,
  primeiro,
  emailInicial,
}: {
  next: string;
  google: boolean;
  primeiro: boolean;
  emailInicial: string;
}) {
  const [modo, setModo] = useState<"entrar" | "primeiro">(primeiro ? "primeiro" : "entrar");
  const [estado, acao, enviando] = useActionState<EstadoLogin, FormData>(entrar, {});
  const [estadoNovo, acaoNovo, criando] = useActionState<EstadoLogin, FormData>(primeiroAcesso, {});
  const [estadoReset, acaoReset, enviandoReset] = useActionState<EstadoLogin, FormData>(esqueciSenha, {});
  const [ver, setVer] = useState(false);

  const novo = modo === "primeiro";
  const erro = novo ? estadoNovo.erro : (estado.erro ?? estadoReset.erro);
  const aviso = novo ? estadoNovo.aviso : estadoReset.aviso;

  return (
    <div className="mt-6 space-y-4">
      <div className="grid grid-cols-2 rounded-lg bg-stone-100 p-1 text-sm">
        {(["entrar", "primeiro"] as const).map((m) => (
          <button
            key={m}
            type="button"
            onClick={() => setModo(m)}
            className={`rounded-md py-2 font-medium ${modo === m ? "bg-white shadow-sm" : "text-stone-500"}`}
          >
            {m === "entrar" ? "Entrar" : "Primeiro acesso"}
          </button>
        ))}
      </div>

      {novo && (
        <p className="text-sm text-stone-600">
          Recebeu um convite? Use o mesmo e-mail do convite e crie sua senha.
        </p>
      )}

      <form action={novo ? acaoNovo : acao} className="space-y-4">
        <input type="hidden" name="next" value={next} />
        <div>
          <label className="rotulo" htmlFor="email">E-mail</label>
          <input
            id="email"
            name="email"
            type="email"
            autoComplete="email"
            inputMode="email"
            defaultValue={emailInicial}
            required
            className="campo py-2.5 text-base sm:text-sm"
          />
        </div>
        <div>
          <label className="rotulo" htmlFor="senha">{novo ? "Crie uma senha (mín. 8 caracteres)" : "Senha"}</label>
          <div className="relative">
            <input
              id="senha"
              name="senha"
              type={ver ? "text" : "password"}
              autoComplete={novo ? "new-password" : "current-password"}
              minLength={novo ? 8 : undefined}
              className="campo py-2.5 pr-16 text-base sm:text-sm"
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
        {erro && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erro}</p>}
        {aviso && <p className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-800">{aviso}</p>}
        <button className="btn-primario w-full py-3" disabled={enviando || criando}>
          {novo ? (criando ? "Criando acesso…" : "Criar meu acesso") : enviando ? "Entrando…" : "Entrar"}
        </button>
        {!novo && (
          <button
            formAction={acaoReset}
            formNoValidate
            className="block text-sm text-marca hover:underline disabled:opacity-50"
            disabled={enviandoReset}
          >
            Esqueci minha senha
          </button>
        )}
      </form>

      {google && !novo && (
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
