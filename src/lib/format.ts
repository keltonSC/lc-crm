const tz = "America/Fortaleza";

export function dataHora(iso: string | null | undefined) {
  if (!iso) return "—";
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: tz,
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(iso));
}

export function data(iso: string | null | undefined) {
  if (!iso) return "—";
  return new Intl.DateTimeFormat("pt-BR", { timeZone: tz, day: "2-digit", month: "2-digit", year: "numeric" }).format(
    new Date(iso),
  );
}

/** "há 3 h", "há 2 d" */
export function relativo(iso: string | null | undefined) {
  if (!iso) return "—";
  const min = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
  if (min < 1) return "agora";
  if (min < 60) return `há ${min} min`;
  const h = Math.round(min / 60);
  if (h < 48) return `há ${h} h`;
  return `há ${Math.round(h / 24)} d`;
}

export function duracao(de: string | null, ate: string | null) {
  if (!de || !ate) return "—";
  const min = Math.round((new Date(ate).getTime() - new Date(de).getTime()) / 60000);
  if (min < 60) return `${min} min`;
  const h = min / 60;
  if (h < 48) return `${h.toFixed(1).replace(".", ",")} h`;
  return `${Math.round(h / 24)} d`;
}

/** 5585999990001 → (85) 99999-0001 */
export function telefone(t: string | null) {
  if (!t) return "—";
  const d = t.startsWith("55") && t.length >= 12 ? t.slice(2) : t;
  if (d.length === 11) return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`;
  if (d.length === 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`;
  return `+${t}`;
}

export function whatsappLink(t: string | null) {
  return t ? `https://wa.me/${t}` : null;
}

export function iniciais(nome: string | null | undefined) {
  if (!nome) return "?";
  const p = nome.trim().split(/\s+/);
  return ((p[0]?.[0] ?? "") + (p.length > 1 ? p[p.length - 1][0] : "")).toUpperCase();
}
