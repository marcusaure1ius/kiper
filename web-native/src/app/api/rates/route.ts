// Server-side proxy for the CBR daily rates XML (cbr.ru sends no CORS headers,
// the iOS app fetches it natively). Cached 6 h, like ExchangeRates.maxAge.
// Fallback USD 90 / EUR 98 lives on the client.

import { parseValutes, usdEurFromMirror, usdEurFromValutes, type MirrorJson } from "@/lib/rates";

const CBR_URL = "https://www.cbr.ru/scripts/XML_daily.asp";
/// Mirror with JSON output; reachable from non-RU datacenters where cbr.ru
/// sometimes is not (Vercel functions run abroad).
const CBR_MIRROR_URL = "https://www.cbr-xml-daily.ru/daily_json.js";

export const revalidate = 21600;

async function fromCBRXml(): Promise<{ usd: number; eur: number }> {
  const res = await fetch(CBR_URL, {
    next: { revalidate },
    headers: { "User-Agent": "Kiper/1.0 (web)" },
  });
  if (!res.ok) throw new Error(`CBR ${res.status}`);
  // The feed is windows-1251; the runtime decodes what it can, digits survive.
  const xml = new TextDecoder("utf-8", { fatal: false }).decode(await res.arrayBuffer());
  return usdEurFromValutes(parseValutes(xml));
}

async function fromMirror(): Promise<{ usd: number; eur: number }> {
  const res = await fetch(CBR_MIRROR_URL, { next: { revalidate } });
  if (!res.ok) throw new Error(`mirror ${res.status}`);
  return usdEurFromMirror((await res.json()) as MirrorJson);
}

export async function GET(): Promise<Response> {
  try {
    return Response.json(await fromCBRXml());
  } catch {
    try {
      return Response.json(await fromMirror());
    } catch {
      return Response.json({ error: "cbr-unavailable" }, { status: 502 });
    }
  }
}
