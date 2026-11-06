import SwiftUI

/// Past / upcoming payments for ±90 days. Sheets get Liquid Glass automatically on iOS 26.
/// History rows come from recorded payments (real amounts); upcoming ones from the schedule.
struct PaymentsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .future

    enum Mode: String, CaseIterable {
        case past = "История"
        case future = "Предстоящие"
    }

    var body: some View {
        NavigationStack {
            let events = mode == .future ? store.futurePayments() : store.pastPayments()
            let grouped = Dictionary(grouping: events) { Calendar.current.dateInterval(of: .month, for: $0.date)!.start }
            let months = grouped.keys.sorted(by: mode == .future ? (<) : (>))

            List {
                ForEach(months, id: \.self) { month in
                    let items = grouped[month]!
                    Section {
                        ForEach(items) { event in
                            if mode == .future {
                                SubscriptionRow(subscription: event.subscription, subtitle: Fmt.day(event.date))
                            } else {
                                HistoryRow(event: event)
                            }
                        }
                    } header: {
                        HStack {
                            Text(Fmt.monthName(month))
                            Spacer()
                            Text(Fmt.rub(monthTotal(items)))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Платежи")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaBar(edge: .top) {
                Picker("Период", selection: $mode.animation(.smooth)) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    /// Recorded amounts where they exist; skipped charges don't count.
    private func monthTotal(_ items: [PaymentEvent]) -> Double {
        items.reduce(0) { sum, event in
            guard event.record?.kind != .skip else { return sum }
            return sum + (event.record?.amountRub ?? store.toRub(event.subscription.amount, event.subscription.currency))
        }
    }
}

/// A past charge: the amount that actually left the account (from the record),
/// with «Оплачено / Пропустить / Удалить» swipe actions.
private struct HistoryRow: View {
    @Environment(AppStore.self) private var store
    let event: PaymentEvent

    private var skipped: Bool { event.record?.kind == .skip }

    var body: some View {
        HStack(spacing: 14) {
            SubscriptionLogo(subscription: event.subscription, category: store.category(for: event.subscription.categoryId))
            VStack(alignment: .leading, spacing: 3) {
                Text(event.subscription.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(skipped ? "Пропущено" : Fmt.day(event.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            AmountLabel(amount: event.record?.amount ?? event.subscription.amount,
                        currency: event.record?.currency ?? event.subscription.currency)
        }
        .contentShape(.rect)
        .opacity(skipped ? 0.55 : 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: !skipped) {
            if let record = event.record {
                Button("Удалить", role: .destructive) {
                    store.deletePayment(record.id)
                }
            }
            if !skipped {
                Button("Пропустить") {
                    store.skip(event.subscription, on: event.date)
                }
                .tint(.orange)
            }
            if skipped || event.record == nil {
                Button("Оплачено") {
                    store.markPaid(event.subscription, on: event.date)
                }
                .tint(.green)
            }
        }
    }
}
