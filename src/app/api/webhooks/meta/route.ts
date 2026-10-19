import { NextResponse, type NextRequest } from "next/server";
import { processarEntrada } from "@/lib/entrada";
import { createServiceClient } from "@/lib/supabase/server";
import { assinaturaMetaValida, eventosLeadgen, leadDaMeta } from "@/lib/meta";

export const dynamic = "force-dynamic";

const GRAPH = "https://graph.facebook.com/v21.0";

/** Verificação do webhook (assinatura da inscrição no app da Meta). */
export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams;
  const esperado = process.env.META_VERIFY_TOKEN;
  if (esperado && q.get("hub.mode") === "subscribe" && q.get("hub.verify_token") === esperado) {
    return new NextResponse(q.get("hub.challenge") ?? "", { status: 200 });
  }
  return new NextResponse("Proibido", { status: 403 });
}

/**
 * Meta Lead Ads: o webhook traz só o leadgen_id; os dados do lead vêm da Graph API.
 * Responde 200 mesmo se um lead falhar (o erro fica em entradas_leads) para a Meta não reenviar em loop;
 * o identificador_meta garante que um reenvio não duplica.
 */
export async function POST(req: NextRequest) {
  const segredo = process.env.META_APP_SECRET;
  const tokenPagina = process.env.META_PAGE_TOKEN;
  const corpo = await req.text();
  if (!segredo || !tokenPagina || !assinaturaMetaValida(corpo, req.headers.get("x-hub-signature-256"), segredo)) {
    return NextResponse.json({ erro: "Assinatura inválida" }, { status: 401 });
  }

  let json: unknown;
  try {
    json = JSON.parse(corpo);
  } catch {
    return NextResponse.json({ erro: "JSON inválido" }, { status: 400 });
  }

  for (const ev of eventosLeadgen(json)) {
    try {
      const campos = "field_data,form_id,ad_name,campaign_name,platform,is_organic";
      const res = await fetch(`${GRAPH}/${encodeURIComponent(ev.leadgen_id)}?fields=${campos}&access_token=${encodeURIComponent(tokenPagina)}`, {
        cache: "no-store",
      });
      if (!res.ok) throw new Error(`Graph API ${res.status}: ${(await res.text()).slice(0, 300)}`);
      const graph = await res.json();
      await processarEntrada("meta", { evento: ev, lead: graph }, leadDaMeta(graph));
    } catch (e) {
      // Sem os dados do lead não há o que registrar; guarda o evento com o erro para reprocessar.
      await registrarFalha(ev, e);
    }
  }
  return NextResponse.json({ ok: true });
}

async function registrarFalha(ev: unknown, e: unknown) {
  await createServiceClient()
    .from("entradas_leads")
    .insert({ fonte: "meta", payload: { evento: ev }, status: "erro", erro: e instanceof Error ? e.message : String(e), processado_em: new Date().toISOString() });
}
