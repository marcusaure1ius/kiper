import SwiftUI

/// Review screen for detected recurring payments: create a subscription from a
/// candidate, attach its history to an existing one, or skip it.
struct StatementImportScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [StatementCandidate]
    @State private var attaching: StatementCandidate?

    init(candidates: [StatementCandidate]) {
        _candidates = State(initialValue: candidates)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(candidates) { candidate in
                        CandidateRow(candidate: candidate) {
                            withAnimation(.smooth) { store.createFromCandidate(candidate) }
                            candidates.removeAll { $0.id == candidate.id }
                        } onAttach: {
                            attaching = candidate
                        }
                    }
                    if candidates.isEmpty {
                        Label("Всё перенесено — кандидатов больше нет", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } footer: {
                    Text("Найдено по регулярности платежей: минимум три списания с похожими суммами и равными интервалами. Проверьте перед переносом.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Выписка из банка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
            .sheet(item: $attaching) { candidate in
                AttachSheet(candidate: candidate) {
                    candidates.removeAll { $0.id == candidate.id }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct CandidateRow: View {
    @Environment(AppStore.self) private var store
    let candidate: StatementCandidate
    let onCreate: () -> Void
    let onAttach: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(candidate.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Spacer()
                Text(Fmt.money(candidate.medianAmount, .rub))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Создать подписку", systemImage: "plus.circle.fill", action: onCreate)
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                Menu {
                    ForEach(store.notCancelled) { sub in
                        Button(sub.name) { onAttach() }
                    }
                } label: {
                    Label("Связать", systemImage: "link")
                }
                .disabled(store.notCancelled.isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let (period, customDays) = candidate.billingPeriod
        let every = period == .custom ? "каждые \(customDays ?? 14) дн." : period.label.lowercased()
        return "\(candidate.occurrences.count) \(Fmt.plural(candidate.occurrences.count, "списание", "списания", "списаний")) · \(every) · последний \(Fmt.day(candidate.lastDate))"
    }
}

/// Picks an existing subscription to attach the detected history to.
private struct AttachSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let candidate: StatementCandidate
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.notCancelled) { sub in
                        Button {
                            store.attachStatement(candidate, to: sub.id)
                            onDone()
                            dismiss()
                        } label: {
                            SubscriptionRow(subscription: sub, subtitle: sub.billingPeriod.label)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Списания из выписки станут оплаченной историей «\(candidate.name)».")
                }
            }
            .navigationTitle("Связать с подпиской")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
