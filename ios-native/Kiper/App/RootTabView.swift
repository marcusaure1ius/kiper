import SwiftUI

enum AppTab: Hashable {
    case home, analytics, settings
}

struct RootTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showPayments = false

    var body: some View {
        @Bindable var router = router
        // System tab bar = Liquid Glass out of the box on iOS 26.
        TabView(selection: $router.tab) {
            Tab("Главная", systemImage: "house.fill", value: .home) {
                HomeScreen()
            }
            Tab("Аналитика", systemImage: "chart.pie.fill", value: .analytics) {
                AnalyticsScreen()
            }
            Tab("Настройки", systemImage: "gearshape.fill", value: .settings) {
                SettingsScreen()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            NextPaymentAccessory { showPayments = true }
        }
        .sheet(isPresented: $showPayments) {
            PaymentsSheet()
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                ToastView(toast: toast)
                    .id(toast.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2.2))
                        withAnimation(.smooth) { if store.toast?.id == toast.id { store.toast = nil } }
                    }
            }
        }
    }
}

/// Glass accessory above the tab bar with the nearest charge day.
/// Several charges on that day collapse into stacked logos + a RUB total.
private struct NextPaymentAccessory: View {
    @Environment(AppStore.self) private var store
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            let upcoming = store.futurePayments(days: 60)
            if let first = upcoming.first {
                let day = upcoming.filter { Calendar.current.isDate($0.date, inSameDayAs: first.date) }
                HStack(spacing: 10) {
                    LogoStack(events: day)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title(day))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if placement != .inline {
                            Text(subtitle(day, date: first.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    Text(amount(day))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
            } else {
                Text("Нет ближайших списаний")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    /// «МТС» / «МТС и Claude Pro» / «МТС, Claude Pro и ещё 1».
    private func title(_ day: [PaymentEvent]) -> String {
        let names = day.map(\.subscription.name)
        switch names.count {
        case 1: return names[0]
        case 2: return "\(names[0]) и \(names[1])"
        default:
            if placement == .inline { return "\(names.count) \(Fmt.plural(names.count, "списание", "списания", "списаний"))" }
            return "\(names[0]), \(names[1]) и ещё \(names.count - 2)"
        }
    }

    private func subtitle(_ day: [PaymentEvent], date: Date) -> String {
        let when = Fmt.relative(date).lowercased()
        return day.count == 1
            ? "Следующее списание · \(when)"
            : "\(day.count) \(Fmt.plural(day.count, "списание", "списания", "списаний")) · \(when)"
    }

    /// One charge: original currency. Several: total in roubles.
    private func amount(_ day: [PaymentEvent]) -> String {
        if day.count == 1, let s = day.first?.subscription { return Fmt.money(s.amount, s.currency) }
        return Fmt.rub(day.reduce(0) { $0 + store.toRub($1.subscription.amount, $1.subscription.currency) })
    }
}

/// Up to three overlapping logos, like stacked avatars.
private struct LogoStack: View {
    @Environment(AppStore.self) private var store
    let events: [PaymentEvent]

    var body: some View {
        HStack(spacing: -12) {
            ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { index, event in
                SubscriptionLogo(subscription: event.subscription, category: store.category(for: event.subscription.categoryId), size: 28)
                    .background(.background, in: .rect(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.background, lineWidth: 1.5))
                    .zIndex(Double(3 - index))
            }
        }
    }
}
