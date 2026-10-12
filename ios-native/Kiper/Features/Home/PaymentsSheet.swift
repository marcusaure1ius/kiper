import SwiftUI

/// Past / upcoming payments for ±90 days. Sheets get Liquid Glass automatically on iOS 26.
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
                            SubscriptionRow(subscription: event.subscription, subtitle: Fmt.day(event.date))
                        }
                    } header: {
                        HStack {
                            Text(Fmt.monthName(month))
                            Spacer()
                            Text(Fmt.rub(items.reduce(0) { $0 + store.toRub($1.subscription.amount, $1.subscription.currency) }))
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
}
