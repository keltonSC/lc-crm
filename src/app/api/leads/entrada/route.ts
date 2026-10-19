import { createHash, timingSafeEqual } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";
import { processarEntrada, type LeadEntrada } from "@/lib/entrada";

export const dynamic = "force-dynamic";

const hash = (s: string) => createHash("sha256").update(s).digest();

/**
 * Entrada genérica de leads (site, portais via automação, Make/Zapier…).
 * Autenticação: header "Authorization: Bearer <LEADS_API_TOKEN>".
 * A "fonte" opcional (?fonte=olx) só identifica o log; a origem do lead vem do corpo.
 */
export async function POST(req: NextRequest) {
  const token = process.env.LEADS_API_TOKEN;
  const enviado = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!token || !timingSafeEqual(hash(enviado), hash(token))) {
    return NextResponse.json({ erro: "Não autorizado" }, { status: 401 });
  }

  let corpo: unknown;
  try {
    corpo = await req.json();
  } catch {
    return NextResponse.json({ erro: "JSON inválido" }, { status: 400 });
  }
  if (!corpo || typeof corpo !== "object" || Array.isArray(corpo)) {
    return NextResponse.json({ erro: "Envie um objeto JSON" }, { status: 400 });
  }
  const lead = corpo as LeadEntrada;
  if (!lead.email && !lead.telefone && !lead.identificador_meta) {
    return NextResponse.json({ erro: "Informe e-mail, telefone ou identificador_meta" }, { status: 422 });
  }

  const fonte = (req.nextUrl.searchParams.get("fonte") ?? "api").slice(0, 40);
  const r = await processarEntrada(fonte, corpo, lead);
  if (!r.ok) return NextResponse.json({ erro: r.erro }, { status: 500 });
  return NextResponse.json({ id: r.leadId, novo: r.novo, reativado: r.reativado }, { status: r.novo ? 201 : 200 });
}
