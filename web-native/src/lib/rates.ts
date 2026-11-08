// Pure CBR-feed parsing, extracted from app/api/rates/route.ts so it can be
// unit-tested (the route itself only adds fetch + mirror-fallback plumbing).
// Mirrors ExchangeRates.swift / ExchangeRates.kt: decimal comma, Nominal divisor.

export interface Valute {
  charCode: string;
  value: string;
  nominal: string;
}

export function parseValutes(xml: string): Valute[] {
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

export function round4(n: number): number {
  return Math.round(n * 10000) / 10000;
}

export function usdEurFromValutes(valutes: Valute[]): { usd: number; eur: number } {
  const rate = (code: string): number => {
    const v = valutes.find((x) => x.charCode === code);
    if (!v) throw new Error(`no ${code}`);
    return round4(Number(v.value) / (Number(v.nominal) || 1));
  };
  return { usd: rate("USD"), eur: rate("EUR") };
}

export interface MirrorJson {
  Valute: Record<string, { Value: number; Nominal?: number }>;
}

export function usdEurFromMirror(data: MirrorJson): { usd: number; eur: number } {
  const rate = (code: string): number => {
    const v = data.Valute?.[code];
    if (!v?.Value) throw new Error(`no ${code}`);
    return round4(v.Value / (v.Nominal || 1));
  };
  return { usd: rate("USD"), eur: rate("EUR") };
}
