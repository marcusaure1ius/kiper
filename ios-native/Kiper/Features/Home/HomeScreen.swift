import SwiftUI

struct HomeScreen: View {
    @Environment(AppStore.self) private var store
    @State private var showForm = false
    @State private var showPayments = false
    @Environment(AppRouter.self) private var router
    @Namespace private var glass

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.homePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MonthSummaryCard()

                    // Two glass buttons that blend into each other inside one container.
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                router.homePath.append(.list)
                            } label: {
                                Label("Подписки", systemImage: "list.bullet")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                            .glassEffectID("list", in: glass)

                            Button {
                                showForm = true
                            } label: {
                                Label("Добавить", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .glassEffectID("add", in: glass)
                        }
                        .controlSize(.large)
                        .font(.body.weight(.semibold))
                    }

                    upcoming
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background { AmbientBackground() }
            .navigationTitle("Кипер")
            .withRoutes()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Все платежи", systemImage: "calendar") { showPayments = true }
                }
            }
            .sheet(isPresented: $showForm) { AddSubscriptionFlow() }
            .sheet(isPresented: $showPayments) { PaymentsSheet() }
        }
    }

    private var upcoming: some View {
        Card {
            HStack {
                Text("Ближайшие списания")
                    .font(.headline)
                Spacer()
                Button("Все") { showPayments = true }
                    .font(.subheadline.weight(.medium))
            }
            .padding(.bottom, 8)

            let events = Array(store.futurePayments(days: 30).prefix(6))
            if events.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: store.active.isEmpty ? "tray" : "checkmark.seal")
                        .font(.system(size: 34))
                        .foregroundStyle(.tint)
                        .symbolEffect(.bounce, value: store.active.count)
                    Text(store.active.isEmpty ? "Пока нет подписок" : "В ближайший месяц списаний нет")
                        .font(.subheadline.weight(.semibold))
                    if store.active.isEmpty {
                        Text("Добавьте первую — Кипер напомнит о списании заранее.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Добавить подписку", systemImage: "plus") { showForm = true }
                            .buttonStyle(.glassProminent)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            ForEach(events) { event in
                NavigationLink(value: Route.detail(event.subscription.id)) {
                    SubscriptionRow(subscription: event.subscription, subtitle: "\(Fmt.relative(event.date)) · \(Fmt.day(event.date))")
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .scrollReveal()
                if event.id != events.last?.id {
                    Divider().padding(.leading, 58)
                }
            }
        }
    }
}

/// Glass summary for the current month — the hero element of the home screen.
private struct MonthSummaryCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.appAccent) private var accent

    var body: some View {
        let progress = store.monthProgress()
        let total = progress.paid + progress.remaining
        let fraction = total > 0 ? progress.paid / total : 0

        VStack(alignment: .leading, spacing: 14) {
            Text(Fmt.monthName(.now))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            CountUpRub(value: store.monthlyTotalRub)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()

            ProgressView(value: fraction)
                .scaleEffect(y: 1.6)

            HStack {
                stat("Оплачено", progress.paid, systemImage: "checkmark.circle.fill")
                Spacer()
                stat("Осталось", progress.remaining, systemImage: "clock.fill")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(accent.opacity(0.12)).interactive(), in: .rect(cornerRadius: 32, style: .continuous))
        .modifier(HolographicSheen(cornerRadius: 32))
        .padding(.top, 8)
        .animation(.smooth, value: store.monthlyTotalRub)
    }

    private func stat(_ title: String, _ value: Double, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(Fmt.rub(value)).font(.subheadline.weight(.semibold)).monospacedDigit()
            }
        } icon: {
            Image(systemName: systemImage).foregroundStyle(.tint)
        }
    }
}
