import Charts
import SwiftUI

enum ChartPeriod: String, CaseIterable {
    case month = "Месяц"
    case week = "Неделя"

    var unit: Calendar.Component { self == .month ? .month : .weekOfYear }

    var calendar: Calendar {
        guard self == .week else { return .current }
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    func interval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: unit, for: date)!
    }
}

struct AnalyticsScreen: View {
    @State private var period: ChartPeriod = .month
    @State private var selection = ChartPeriod.month.interval(containing: .now)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SpendingChartCard(period: $period, selection: $selection)
                    CategoryRingsCard(period: period, interval: selection)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background { AmbientBackground() }
            .navigationTitle("Аналитика")
            .withRoutes()
        }
    }
}

/// Bar chart of spending; tapping a bar selects that month/week for the category card below.
private struct SpendingChartCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.appAccent) private var accent
    @Binding var period: ChartPeriod
    @Binding var selection: DateInterval

    var body: some View {
        let data = period == .month ? store.monthlyTotals() : store.weeklyTotals()
        let selected = data.first { $0.start == selection.start }

        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(period == .month ? "Расходы по месяцам" : "Расходы по неделям")
                    .font(.headline)
                if let selected {
                    Text(Fmt.rub(selected.amount))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(caption(selected))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)

            Chart(data) { item in
                BarMark(
                    x: .value("Период", item.start, unit: period.unit),
                    y: .value("Сумма", item.amount)
                )
                .clipShape(.rect(cornerRadius: 6))
                .foregroundStyle(
                    item.start == selection.start
                        ? AnyShapeStyle(accent.gradient)
                        : AnyShapeStyle(accent.opacity(item.isForecast ? 0.22 : 0.5))
                )
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(.rect)
                        .gesture(SpatialTapGesture().onEnded { tap in
                            guard let plot = proxy.plotFrame,
                                  let date: Date = proxy.value(atX: tap.location.x - geo[plot].origin.x)
                            else { return }
                            select(period.interval(containing: date), in: data)
                        })
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel { if let v = value.as(Double.self) { Text("\(Int(v / 1000))к") } }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: period.unit, count: period == .month ? 1 : 2)) { value in
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(period == .month ? Fmt.monthShort(d) : d.formatted(.dateTime.day().month(.defaultDigits)))
                        }
                    }
                }
            }
            .frame(height: 220)
            .sensoryFeedback(.selection, trigger: selection)

            Picker("Период", selection: $period) {
                ForEach(ChartPeriod.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .padding(.top, 14)
            .onChange(of: period) { _, new in
                withAnimation(.smooth) { selection = new.interval(containing: .now) }
            }
        }
    }

    private func select(_ interval: DateInterval, in data: [PeriodTotal]) {
        guard data.contains(where: { $0.start == interval.start }) else { return }
        withAnimation(.smooth) { selection = interval }
    }

    private func caption(_ point: PeriodTotal) -> String {
        let label = period == .month ? Fmt.monthName(point.start) : "Неделя с \(Fmt.day(point.start))"
        if period.interval(containing: .now).start == point.start { return "\(label) · сейчас" }
        return point.isForecast ? "\(label) · прогноз" : label
    }
}

/// Categories for the selected period. Current period: share already paid.
/// Any other period: each category's share of that period's spending.
private struct CategoryRingsCard: View {
    @Environment(AppStore.self) private var store
    let period: ChartPeriod
    let interval: DateInterval

    var body: some View {
        let rows = store.categoryShares(in: interval)
        let total = rows.reduce(0) { $0 + $1.total }
        let isCurrent = interval.contains(.now)

        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("По категориям").font(.headline)
                Spacer()
                Text(subtitle(isCurrent: isCurrent))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .padding(.bottom, 4)

            if rows.isEmpty {
                Text("Списаний нет")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            ForEach(rows) { row in
                let color = row.category?.color ?? .gray
                let fraction = isCurrent ? row.paid / max(row.total, 1) : row.total / max(total, 1)
                HStack(spacing: 12) {
                    Ring(progress: fraction, color: color, lineWidth: 5)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.category?.name ?? "Без категории").font(.body.weight(.medium))
                        Text(isCurrent ? "\(Fmt.rub(row.paid)) из \(Fmt.rub(row.total))" : Fmt.rub(row.total))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(color)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.vertical, 8)
                if row.id != rows.last?.id { Divider().padding(.leading, 40) }
            }
        }
        .animation(.smooth, value: interval)
    }

    private func subtitle(isCurrent: Bool) -> String {
        let name = period == .month ? "в \(Fmt.monthPrepositional(interval.start))" : "за неделю с \(Fmt.day(interval.start))"
        if isCurrent { return period == .month ? "оплачено \(name)" : "оплачено за эту неделю" }
        return interval.start > .now ? "прогноз \(name)" : "доля трат \(name)"
    }
}

private struct Ring: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}
