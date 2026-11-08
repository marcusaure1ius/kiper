// Server-side proxy for the CBR daily rates XML (cbr.ru sends no CORS headers,
// the iOS app fetches it natively). Cached 6 h, like ExchangeRates.maxAge.
// Fallback USD 90 / EUR 98 lives on the client.

const CBR_URL = "https://www.cbr.ru/scripts/XML_daily.asp";
/// Mirror with JSON output; reachable from non-RU datacenters where cbr.ru
/// sometimes is not (Vercel functions run abroad).
const CBR_MIRROR_URL = "https://www.cbr-xml-daily.ru/daily_json.js";

export const revalidate = 21600;

interface Valute {
  charCode: string;
  value: string;
  nominal: string;
}

function parseValutes(xml: string): Valute[] {
  const result: Valute[] = [];
  const re = /<Valute[^>]*>([\s\S]*?)<\/Valute>/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(xml))) {
    const block = m[1];
    const tag = (name: string) => block.match(new RegExp(`<${name}>([^<]*)</${name}>`))?.[1];
    if (tag("CharCode") && tag("Value")) {
      result.push({
        charCode: tag("CharCode")!,
        // CBR uses a comma decimal separator: "91,2345".
        value: tag("Value")!.replace(",", "."),
        nominal: tag("Nominal") ?? "1",
      });
    }
  }
  return result;
}

function round4(n: number): number {
  return Math.round(n * 10000) / 10000;
}

async function fromCBRXml(): Promise<{ usd: number; eur: number }> {
  const res = await fetch(CBR_URL, {
    next: { revalidate },
    headers: { "User-Agent": "Kiper/1.0 (web)" },
  });
  if (!res.ok) throw new Error(`CBR ${res.status}`);
  // The feed is windows-1251; the runtime decodes what it can, digits survive.
  const xml = new TextDecoder("utf-8", { fatal: false }).decode(await res.arrayBuffer());
  const valutes = parseValutes(xml);
  const rate = (code: string): number => {
    const v = valutes.find((x) => x.charCode === code);
    if (!v) throw new Error(`no ${code}`);
    return round4(Number(v.value) / (Number(v.nominal) || 1));
  };
  return { usd: rate("USD"), eur: rate("EUR") };
}

interface MirrorJson {
  Valute: Record<string, { Value: number; Nominal?: number }>;
}

async function fromMirror(): Promise<{ usd: number; eur: number }> {
  const res = await fetch(CBR_MIRROR_URL, { next: { revalidate } });
  if (!res.ok) throw new Error(`mirror ${res.status}`);
  const data = (await res.json()) as MirrorJson;
  const rate = (code: string): number => {
    const v = data.Valute?.[code];
    if (!v?.Value) throw new Error(`no ${code}`);
    return round4(v.Value / (v.Nominal || 1));
  };
  return { usd: rate("USD"), eur: rate("EUR") };
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
