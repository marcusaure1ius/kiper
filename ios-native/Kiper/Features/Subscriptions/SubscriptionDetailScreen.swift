import SwiftUI

struct SubscriptionDetailScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let subscriptionId: String
    @State private var editing = false
    @State private var confirmCancel = false

    var body: some View {
        if let sub = store.subscription(id: subscriptionId) {
            content(sub)
        } else {
            ContentUnavailableView("Подписка не найдена", systemImage: "questionmark.circle")
        }
    }

    private func content(_ sub: Subscription) -> some View {
        let category = store.category(for: sub.categoryId)
        return List {
            Section {
                VStack(spacing: 12) {
                    SubscriptionLogo(subscription: sub, category: category, size: 84)
                    Text(sub.name).font(.title2.bold())
                    AmountLabel(amount: sub.amount, currency: sub.currency, alignment: .center)
                        .font(.title3)
                    if let category {
                        CategoryTag(category: category)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            Section {
                row("Период", sub.billingPeriod == .custom ? "Каждые \(sub.customPeriodDays ?? 30) дн." : sub.billingPeriod.label)
                row("Следующее списание", "\(Fmt.fullDate(sub.nextBillingDate)) · \(Fmt.relative(sub.nextBillingDate).lowercased())")
                row("Дата начала", Fmt.fullDate(sub.startDate))
                row("Статус", sub.status.label)
                row("Напоминание", sub.reminderDaysBefore == 0 ? "Выключено" : "За \(sub.reminderDaysBefore) дн.")
                row("В месяц", Fmt.rub(store.toRub(sub.amount, sub.currency) * sub.billingPeriod.monthlyEquivalent))
            }

            if let note = sub.note, !note.isEmpty {
                Section("Заметка") { Text(note) }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AmbientBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Изменить") { editing = true }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Ещё", systemImage: "ellipsis") {
                    Button(sub.status == .paused ? "Возобновить" : "Приостановить",
                           systemImage: sub.status == .paused ? "play.fill" : "pause.fill") {
                        withAnimation { store.togglePause(sub.id) }
                        store.show(sub.status == .paused ? "Подписка возобновлена" : "Подписка на паузе",
                                   symbol: sub.status == .paused ? "play.circle.fill" : "pause.circle.fill",
                                   tint: sub.status == .paused ? .green : .orange)
                    }
                    Button("Отменить подписку", systemImage: "xmark.circle", role: .destructive) {
                        confirmCancel = true
                    }
                }
            }
        }
        .sheet(isPresented: $editing) { SubscriptionFormScreen(editing: sub) }
        .confirmationDialog("Отменить «\(sub.name)»?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Отменить подписку", role: .destructive) {
                store.cancel(sub.id)
                store.show("Подписка отменена", symbol: "xmark.circle.fill", tint: .red)
                dismiss()
            }
        } message: {
            Text("Подписка останется в аналитике, но исчезнет из списка.")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }
}

/// Flat tinted tag (system-style): icon and text in the category colour, no glass, no shadow.
private struct CategoryTag: View {
    let category: Category
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: category.symbol)
                .font(.caption.weight(.semibold))
            Text(category.name)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(category.color.mix(with: scheme == .dark ? .white : .black, by: 0.15))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(category.color.opacity(scheme == .dark ? 0.24 : 0.14), in: .capsule)
    }
}
