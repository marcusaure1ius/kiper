import { describe, expect, it } from "vitest";
import { fullDate, money, monthName, plural, relative, rub, smartDate } from "@/lib/format";

describe("Fmt.money", () => {
  it("formats rubles with space thousands, comma decimals", () => {
    expect(money(1234.56, "RUB")).toContain("1");
    expect(money(1234.56, "RUB")).toContain("234");
    expect(money(1234.56, "RUB").endsWith("₽")).toBe(true);
    expect(money(1234.56, "RUB")).toContain(",");
  });

  it("omits decimals for whole amounts", () => {
    expect(money(890, "RUB")).not.toContain(",");
    expect(money(20, "USD").endsWith("$")).toBe(true);
  });

  it("rub() forces 0 decimals", () => {
    expect(rub(1234.56)).not.toContain(",");
    expect(rub(1234.56).endsWith("₽")).toBe(true);
  });
});

describe("Fmt.dates", () => {
  it("fullDate matches iOS «8 ноября 2026 г.» style", () => {
    expect(fullDate(new Date(2026, 10, 8))).toBe("8 ноября 2026 г.");
  });

  it("smartDate hides the current year", () => {
    const now = new Date(2026, 10, 8);
    expect(smartDate(new Date(2026, 10, 13), now)).toBe("13 ноября");
    expect(smartDate(new Date(2027, 0, 5), now)).toBe("5 января 2027 г.");
  });

  it("monthName is nominative capitalized", () => {
    expect(monthName(new Date(2026, 10, 1))).toBe("Ноябрь");
    expect(monthName(new Date(2026, 2, 1))).toBe("Март");
  });
});

describe("Fmt.plural", () => {
  it("russian plural forms", () => {
    const f = (n: number) => plural(n, "списание", "списания", "списаний");
    expect(f(1)).toBe("списание");
    expect(f(2)).toBe("списания");
    expect(f(5)).toBe("списаний");
    expect(f(11)).toBe("списаний");
    expect(f(21)).toBe("списание");
    expect(f(22)).toBe("списания");
  });
});

describe("Fmt.relative", () => {
  it("today/tomorrow/days-ahead/days-ago", () => {
    const now = new Date(2026, 10, 8);
    expect(relative(new Date(2026, 10, 8), now)).toBe("Сегодня");
    expect(relative(new Date(2026, 10, 9), now)).toBe("Завтра");
    expect(relative(new Date(2026, 10, 7), now)).toBe("Вчера");
    expect(relative(new Date(2026, 10, 13), now)).toBe("Через 5 дн.");
    expect(relative(new Date(2026, 10, 3), now)).toBe("5 дн. назад");
  });
});
