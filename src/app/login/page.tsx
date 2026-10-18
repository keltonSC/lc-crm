import { FormLogin } from "./form";

const ERROS: Record<string, string> = {
  inativo: "Seu acesso ainda não foi liberado. Peça um convite à gestão da LC.",
  google: "Não foi possível entrar com o Google.",
  link: "O link expirou ou já foi usado. Peça um novo.",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; erro?: string; primeiro?: string; email?: string }>;
}) {
  const { next, erro, primeiro, email } = await searchParams;
  const google = process.env.NEXT_PUBLIC_LOGIN_GOOGLE === "on";

  return (
    <main className="grid min-h-dvh lg:grid-cols-[1fr_1.1fr]">
      {/* Painel lateral: espaço para recados internos (lançamento, meta do mês) */}
      <aside className="relative hidden flex-col justify-between overflow-hidden bg-tinta p-12 text-white lg:flex">
        <div className="flex items-center gap-3">
          <div className="grid size-10 place-items-center rounded-lg bg-marca text-lg font-bold">LC</div>
          <span className="text-sm tracking-wide text-stone-300">Luciano Cavalcante Imóveis</span>
        </div>
        <div className="max-w-md">
          <p className="text-4xl font-semibold leading-tight">
            Cada lead respondido rápido é uma visita a mais na agenda.
          </p>
          <p className="mt-4 text-stone-400">Seus leads, tarefas e visitas num só lugar.</p>
        </div>
        <div className="pointer-events-none absolute -right-24 -bottom-24 size-96 rounded-full bg-marca/20 blur-3xl" />
        <p className="text-xs text-stone-500">LC CRM</p>
      </aside>

      <section className="flex items-center justify-center px-4 py-12">
        <div className="w-full max-w-sm">
          <div className="mb-8 flex items-center gap-3 lg:hidden">
            <div className="grid size-10 place-items-center rounded-lg bg-marca text-lg font-bold text-white">LC</div>
            <span className="text-sm text-stone-600">LC Imóveis</span>
          </div>
          <h1 className="text-2xl font-semibold">Acesse sua conta</h1>
          <p className="mt-1 text-sm text-stone-500">Use seu e-mail cadastrado. Seu perfil abre automaticamente.</p>
          {erro && ERROS[erro] && (
            <p className="mt-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{ERROS[erro]}</p>
          )}
          <FormLogin next={next ?? "/"} google={google} primeiro={primeiro === "1"} emailInicial={email ?? ""} />
        </div>
      </section>
    </main>
  );
}
