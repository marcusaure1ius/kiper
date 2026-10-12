import Foundation

enum Fmt {
    private static let ru = Locale(identifier: "ru_RU")

    /// `1 234,56 $` / `1 234 ₽` — matches `format_utils.dart` (space thousands, comma decimals).
    static func money(_ amount: Double, _ currency: Currency, decimals: Int? = nil) -> String {
        let d = decimals ?? (amount.rounded() == amount ? 0 : 2)
        let number = amount.formatted(.number.locale(ru).precision(.fractionLength(d)))
        return "\(number) \(currency.symbol)"
    }

    static func rub(_ amount: Double) -> String { money(amount, .rub, decimals: 0) }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.locale(ru).day().month(.wide))
    }

    static func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(ru).day().month(.wide).year())
    }

    /// «12 ноября», or «12 ноября 2027 г.» when not the current year.
    static func smartDate(_ date: Date) -> String {
        Calendar.current.isDate(date, equalTo: .now, toGranularity: .year) ? day(date) : fullDate(date)
    }

    static func monthName(_ date: Date) -> String {
        standaloneMonth.string(from: date).capitalized(with: ru)
    }

    /// Nominative month name («Октябрь», not «октября»).
    private static let standaloneMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = ru
        f.dateFormat = "LLLL"
        return f
    }()

    /// «октябре» — for phrases like «оплачено в октябре».
    static func monthPrepositional(_ date: Date) -> String {
        let names = ["январе", "феврале", "марте", "апреле", "мае", "июне",
                     "июле", "августе", "сентябре", "октябре", "ноябре", "декабре"]
        return names[Calendar.current.component(.month, from: date) - 1]
    }

    static func monthShort(_ date: Date) -> String {
        date.formatted(.dateTime.locale(ru).month(.abbreviated))
    }

    /// Russian plural: plural(5, "списание", "списания", "списаний") → «списаний».
    static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let n10 = n % 10, n100 = n % 100
        if n10 == 1 && n100 != 11 { return one }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
        return many
    }

    /// «Сегодня», «Завтра», «Через 5 дн.», «3 дн. назад».
    static func relative(_ date: Date, now: Date = .now) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        return switch days {
        case 0: "Сегодня"
        case 1: "Завтра"
        case -1: "Вчера"
        case 2...: "Через \(days) дн."
        default: "\(-days) дн. назад"
        }
    }
}
