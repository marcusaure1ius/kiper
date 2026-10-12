import SwiftUI

/// Prefill for a new subscription: a catalog entry, or just a typed name.
struct FormPreset: Hashable {
    var entry: CatalogEntry?
    var name: String?
}

/// Editing an existing subscription: the form in its own sheet with Cancel.
struct SubscriptionFormScreen: View {
    @Environment(\.dismiss) private var dismiss
    let editing: Subscription

    var body: some View {
        NavigationStack {
            SubscriptionForm(editing: editing, showsCancel: true) { dismiss() }
        }
    }
}

/// Form body without its own NavigationStack, so it can be pushed inside the add flow.
struct SubscriptionForm: View {
    @Environment(AppStore.self) private var store

    private let existing: Subscription?
    private let showsCancel: Bool
    private let onDone: () -> Void
    @State private var draft: Subscription
    @State private var amountText: String
    @FocusState private var focus: Field?
    @State private var openDate: DateField?

    private enum Field { case name, amount }
    private enum DateField { case start, next }

    init(editing: Subscription? = nil, preset: FormPreset? = nil, showsCancel: Bool = false, onDone: @escaping () -> Void) {
        existing = editing
        self.showsCancel = showsCancel
        self.onDone = onDone
        var d = editing ?? Subscription(
            id: UUID().uuidString, name: "", amount: 0, currency: .rub, billingPeriod: .monthly,
            nextBillingDate: Calendar.current.date(byAdding: .month, value: 1, to: .now)!, startDate: .now
        )
        if let e = preset?.entry {
            d.name = e.name
            d.currency = e.currency
            d.billingPeriod = e.period
            d.categoryId = e.categoryId
            d.domain = e.domain
        }
        if let name = preset?.name { d.name = name }
        _draft = State(initialValue: d)
        _amountText = State(initialValue: d.amount == 0 ? "" : String(d.amount))
    }

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && (amount ?? 0) > 0
    }

    var body: some View {
        Form {
            Section {
                TextField("Название", text: $draft.name)
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .amount }
                HStack {
                    TextField("Сумма", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focus, equals: .amount)
                    Picker("Валюта", selection: $draft.currency) {
                        ForEach(Currency.allCases) { Text("\($0.symbol) \($0.code)").tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                if let amount, draft.currency != .rub {
                    LabeledContent("В рублях", value: "≈ \(Fmt.rub(store.toRub(amount, draft.currency)))")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Период", selection: $draft.billingPeriod) {
                    ForEach(BillingPeriod.allCases) { Text($0.label).tag($0) }
                }
                if draft.billingPeriod == .custom {
                    Stepper("Каждые \(draft.customPeriodDays ?? 30) дн.",
                            value: Binding(get: { draft.customPeriodDays ?? 30 }, set: { draft.customPeriodDays = $0 }),
                            in: 1...365)
                }
                Picker("Категория", selection: $draft.categoryId) {
                    Text("Без категории").tag(String?.none)
                    ForEach(store.categories) { cat in
                        Label(cat.name, systemImage: cat.symbol).tag(Optional(cat.id))
                    }
                }
            }

            Section {
                DateRow(title: "Дата начала", date: $draft.startDate, isOpen: openBinding(.start))
                DateRow(title: "Следующее списание", date: $draft.nextBillingDate, isOpen: openBinding(.next))
                Picker("Напоминание", selection: $draft.reminderDaysBefore) {
                    Text("Выключено").tag(0)
                    Text("За 1 день").tag(1)
                    Text("За 3 дня").tag(3)
                    Text("За 7 дней").tag(7)
                }
            }

            Section("Заметка") {
                TextField("Необязательно", text: Binding(get: { draft.note ?? "" }, set: { draft.note = $0 }), axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .navigationTitle(existing == nil ? "Новая подписка" : "Редактирование")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { onDone() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    draft.amount = amount ?? 0
                    withAnimation { store.upsert(draft) }
                    store.show(existing == nil ? "Подписка добавлена" : "Изменения сохранены")
                    onDone()
                }
                .disabled(!isValid)
            }
        }
        .task {
            // A category from the catalog may have been deleted by the user.
            if let id = draft.categoryId, store.category(for: id) == nil { draft.categoryId = nil }
            guard existing == nil else { return }
            // Wait for the push animation, then put the cursor where typing starts.
            try? await Task.sleep(for: .milliseconds(450))
            focus = draft.name.isEmpty ? .name : .amount
        }
    }

    /// Only one inline calendar open at a time, like event editing in Calendar.
    private func openBinding(_ field: DateField) -> Binding<Bool> {
        Binding(
            get: { openDate == field },
            set: { isOpen in withAnimation(.snappy) { openDate = isOpen ? field : nil } }
        )
    }
}

/// Calendar-app style date row: consistent full date, tap to expand an inline calendar.
private struct DateRow: View {
    @Environment(\.appAccent) private var accent
    let title: String
    @Binding var date: Date
    @Binding var isOpen: Bool

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            LabeledContent(title) {
                Text(Fmt.smartDate(date))
                    .foregroundStyle(isOpen ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
                    .contentTransition(.numericText())
            }
        }
        .tint(.primary)

        if isOpen {
            DatePicker(title, selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
        }
    }
}
