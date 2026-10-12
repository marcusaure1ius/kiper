import SwiftUI

struct SubscriptionsListScreen: View {
    @Environment(AppStore.self) private var store
    @State private var filter: String? = nil
    @State private var search = ""
    @State private var showAdd = false

    private var items: [Subscription] {
        store.subscriptions
            .filter { $0.status != .cancelled }
            .filter { filter == nil || $0.categoryId == filter }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { ($0.status == .active ? 0 : 1, $0.nextBillingDate) < ($1.status == .active ? 0 : 1, $1.nextBillingDate) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                TotalHeader(items: items)
                ForEach(items) { sub in
                    NavigationLink(value: Route.detail(sub.id)) {
                        SubscriptionRow(subscription: sub, subtitle: subtitle(for: sub))
                            .padding(14)
                            .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
                            .opacity(sub.status == .paused ? 0.55 : 1)
                    }
                    .buttonStyle(.plain)
                    .scrollReveal()
                }
                if items.isEmpty {
                    if !search.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else if filter != nil {
                        ContentUnavailableView("В этой категории пусто", systemImage: "tray",
                                               description: Text("Выберите другую категорию или добавьте подписку."))
                    } else {
                        ContentUnavailableView {
                            Label("Пока нет подписок", systemImage: "tray")
                        } description: {
                            Text("Добавьте первую — Кипер напомнит о списании заранее.")
                        } actions: {
                            Button("Добавить подписку", systemImage: "plus") { showAdd = true }
                                .buttonStyle(.glassProminent)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .animation(.smooth, value: filter)
        }
        .background { AmbientBackground() }
        .safeAreaBar(edge: .top, spacing: 0) {
            CategoryFilterBar(selection: $filter)
        }
        .navigationTitle("Подписки")
        .searchable(text: $search, prompt: "Поиск")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Добавить", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) { AddSubscriptionFlow() }
    }

    private func subtitle(for sub: Subscription) -> String {
        if sub.status == .paused { return "Приостановлена" }
        return "\(sub.billingPeriod.label) · \(Fmt.day(sub.nextBillingDate))"
    }
}

private struct TotalHeader: View {
    @Environment(AppStore.self) private var store
    let items: [Subscription]

    var body: some View {
        let active = items.filter { $0.status == .active }
        let monthly = active.reduce(0) { $0 + store.toRub($1.amount, $1.currency) * $1.billingPeriod.monthlyEquivalent }
        HStack(alignment: .firstTextBaseline) {
            Text("\(active.count) активных")
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Fmt.rub(monthly)) / мес")
                .font(.headline)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }
}

private struct CategoryFilterBar: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: String?

    var body: some View {
        GlassChips(
            items: [.init(id: nil, title: "Все", symbol: "tray.full.fill")]
                + store.categories.map { .init(id: $0.id, title: $0.name, symbol: $0.symbol, color: $0.color) },
            selection: $selection
        )
    }
}
