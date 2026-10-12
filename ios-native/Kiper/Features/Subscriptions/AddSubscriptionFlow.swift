import SwiftUI

/// The single "add subscription" flow, used by every "+" in the app.
/// Search-first catalog (like adding a medication in Health); picking a service
/// or "own subscription" pushes the form inside the same sheet.
struct AddSubscriptionFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var path: [FormPreset] = []
    @State private var search = ""

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    private var matches: [CatalogEntry] {
        query.isEmpty ? CatalogEntry.all : CatalogEntry.all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: FormPreset(name: query.isEmpty ? nil : query)) {
                        Label {
                            Text(query.isEmpty ? "Своя подписка" : "Создать «\(query)»")
                        } icon: {
                            Image(systemName: query.isEmpty ? "square.and.pencil" : "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                } footer: {
                    if query.isEmpty {
                        Text("Или выберите сервис — название, валюта и период подставятся сами.")
                    }
                }

                ForEach(CatalogEntry.groups, id: \.id) { group in
                    let items = matches.filter { $0.categoryId == group.id }
                    if !items.isEmpty {
                        Section(group.name) {
                            ForEach(items) { entry in
                                NavigationLink(value: FormPreset(entry: entry)) {
                                    HStack(spacing: 12) {
                                        SubscriptionLogo(subscription: entry.asSubscription, category: store.category(for: entry.categoryId), size: 36)
                                        Text(entry.name)
                                        Spacer()
                                        Text(entry.currency.symbol).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Новая подписка")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Название сервиса")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .navigationDestination(for: FormPreset.self) { preset in
                SubscriptionForm(preset: preset) { dismiss() }
            }
        }
    }
}
