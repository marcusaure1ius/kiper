import AppIntents
import SwiftUI
import WidgetKit

// Both widgets read the tiny WidgetSnapshot the app writes into the shared
// App Group container; no data files are touched from the extension.

@main
struct KiperWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextChargeWidget()
        MonthWidget()
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Rebuilds at midnight and at the next charge date, so counters stay honest
/// without the app running.
struct SnapshotProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func snapshot(for configuration: ReloadIntent, in context: Context) async -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .sample)
    }

    func timeline(for configuration: ReloadIntent, in context: Context) async -> Timeline<SnapshotEntry> {
        let current = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .sample)
        let cal = Calendar.current
        var dates: [Date] = [cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: .now)!)]
        if let next = current.snapshot?.upcoming.first?.date, next > .now { dates.append(next) }
        return Timeline(entries: [current] + dates.map { SnapshotEntry(date: $0, snapshot: current.snapshot) }, policy: .atEnd)
    }
}

struct ReloadIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Обновить"
    static let description = IntentDescription("Показывает данные Кипера.")
}

// MARK: - Next charge widget

struct NextChargeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "NextCharge", intent: ReloadIntent.self, provider: SnapshotProvider(), content: { NextChargeView(entry: $0) })
            .configurationDisplayName("Ближайшее списание")
            .description("Следующая подписка, которая спишется.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextChargeView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: SnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = entry.snapshot?.upcoming.first {
                Text(next.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(when(next.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(money(next))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Image(systemName: "tray")
                    .font(.title)
                    .foregroundStyle(accent)
                Text("Списаний нет")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground()
    }

    private var accent: Color {
        Color(hex: scheme == .dark ? entry.snapshot?.accentHexDark ?? 0x8F84FF : entry.snapshot?.accentHexLight ?? 0x6A5CF1)
    }

    private func when(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: entry.date), to: Calendar.current.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "Сегодня"
        case 1: return "Завтра"
        default: return "Через \(days) дн."
        }
    }

    private func money(_ charge: WidgetSnapshot.Charge) -> String {
        let symbol = switch charge.currency { case "USD": "$"; case "EUR": "€"; default: "₽" }
        let number = Self.rubFormatter.string(from: NSNumber(value: charge.amount)) ?? "0"
        return number + " \(symbol)"
    }

    private static let rubFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()
}

// MARK: - Month widget

struct MonthWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Month", intent: ReloadIntent.self, provider: SnapshotProvider(), content: { MonthView(entry: $0) })
            .configurationDisplayName("Месяц")
            .description("Сумма подписок за месяц и прогресс бюджета.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MonthView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: SnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snap = entry.snapshot {
                Text(monthName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(rub(snap.monthlyTotalRub))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let budget = snap.budgetRub {
                    let committed = snap.paidRub + snap.remainingRub
                    ProgressView(value: min(committed / max(budget, 1), 1))
                        .tint(committed > budget ? .orange : accent)
                } else {
                    let fraction = snap.monthlyTotalRub > 0 ? snap.paidRub / max(snap.paidRub + snap.remainingRub, 1) : 0
                    ProgressView(value: fraction)
                        .tint(accent)
                }
                Text("Оплачено \(rub(snap.paidRub)) · осталось \(rub(snap.remainingRub))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("Данные появятся после запуска Кипера")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground()
    }

    private var accent: Color {
        Color(hex: scheme == .dark ? entry.snapshot?.accentHexDark ?? 0x8F84FF : entry.snapshot?.accentHexLight ?? 0x6A5CF1)
    }

    private var monthName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL"
        return f.string(from: entry.date).capitalized
    }

    private func rub(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: value)) ?? "0") + " ₽"
    }
}

// MARK: - Shared bits

private extension Color {
    /// Mirror of the app's helper (KiperShared must stay dependency-free).
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private extension View {
    /// iOS 17+: content margins are opt-out; keep the snapshot's own padding.
    func widgetBackground() -> some View {
        containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

extension WidgetSnapshot {
    /// Placeholder for the widget gallery (the extension can't seed real data).
    static let sample = WidgetSnapshot(
        upcoming: [WidgetSnapshot.Charge(name: "Netflix", domain: "netflix.com", date: .now.addingTimeInterval(86_400), amount: 19.99, currency: "USD")],
        monthlyTotalRub: 24_393,
        paidRub: 2_338,
        remainingRub: 22_055,
        budgetRub: 25_000,
        accentHexLight: 0x6A5CF1,
        accentHexDark: 0x8F84FF,
        generatedAt: .now
    )
}
