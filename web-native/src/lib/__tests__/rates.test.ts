import { describe, expect, it } from "vitest";
import { parseValutes, round4, usdEurFromMirror, usdEurFromValutes } from "@/lib/rates";

const FEED = `<?xml version="1.0" encoding="windows-1251"?>
<ValCurs Date="08.11.2026" name="Foreign Currency Market">
<Valute ID="R01235"><NumCode>840</NumCode><CharCode>USD</CharCode><Nominal>1</Nominal><Name>Доллар США</Name><Value>81,7186</Value></Valute>
<Valute ID="R01239"><NumCode>978</NumCode><CharCode>EUR</CharCode><Nominal>1</Nominal><Name>Евро</Name><Value>94,8810</Value></Valute>
<Valute ID="R01350"><NumCode>398</NumCode><CharCode>KZT</CharCode><Nominal>100</Nominal><Name>Тенге</Name><Value>17,1172</Value></Valute>
<Valute ID="R01700"><NumCode>949</NumCode><CharCode>TRY</CharCode><Nominal>10</Nominal><Name>Турецкая лира</Name><Value>2,40105</Value></Valute>
</ValCurs>`;

describe("parseValutes", () => {
  it("reads comma decimals and defaults the nominal to 1", () => {
    const v = parseValutes(FEED);
    expect(v).toHaveLength(4);
    const usd = v.find((x) => x.charCode === "USD")!;
    expect(usd.value).toBe("81.7186");
    expect(usd.nominal).toBe("1");
  });

  it("keeps the raw nominal string when present", () => {
    const kzt = parseValutes(FEED).find((x) => x.charCode === "KZT")!;
    expect(kzt.nominal).toBe("100");
  });

  it("skips blocks without a value", () => {
    const v = parseValutes('<Valute><CharCode>USD</CharCode></Valute><Valute><CharCode>EUR</CharCode><Value>1,0</Value></Valute>');
    expect(v).toHaveLength(1);
    expect(v[0].charCode).toBe("EUR");
  });

  it("returns nothing for junk input", () => {
    expect(parseValutes("<html>service unavailable</html>")).toEqual([]);
  });
});

describe("usdEurFromValutes", () => {
  it("divides by the nominal like the native parsers (v / n)", () => {
    // Synthetic: a USD row quoted per 2 units must halve, mirroring Nominal-aware CBR rows.
    const rates = usdEurFromValutes([
      { charCode: "USD", value: "163.4372", nominal: "2" },
      { charCode: "EUR", value: "9488.10", nominal: "100" },
    ]);
    expect(rates).toEqual({ usd: 81.7186, eur: 94.881 });
  });

  it("rounds to 4 decimals", () => {
    expect(round4(81.71865 * 1000)).toBe(81718.65);
    const rates = usdEurFromValutes([
      { charCode: "USD", value: "81.71864999", nominal: "1" },
      { charCode: "EUR", value: "94.88105", nominal: "1" },
    ]);
    expect(rates.usd).toBe(81.7186);
    expect(rates.eur).toBe(94.8811);
  });

  it("throws when a requested currency is missing", () => {
    expect(() => usdEurFromValutes([{ charCode: "EUR", value: "94.0", nominal: "1" }])).toThrow("no USD");
  });
});

describe("usdEurFromMirror", () => {
  it("maps the mirror JSON with nominals", () => {
    const rates = usdEurFromMirror({
      Valute: {
        USD: { Value: 163.4372, Nominal: 2 },
        EUR: { Value: 94.881 },
      },
    });
    expect(rates).toEqual({ usd: 81.7186, eur: 94.881 });
  });

  it("throws on a zero value or missing currency", () => {
    expect(() => usdEurFromMirror({ Valute: { USD: { Value: 0 }, EUR: { Value: 1 } } })).toThrow("no USD");
    expect(() => usdEurFromMirror({ Valute: {} })).toThrow("no USD");
  });
});
