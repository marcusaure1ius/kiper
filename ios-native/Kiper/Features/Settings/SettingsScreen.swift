import SwiftUI

struct SettingsScreen: View {
    @Environment(MockStore.self) private var store
    @AppStorage("themeMode") private var themeMode: ThemeMode = .system
    @AppStorage("backgroundStyle") private var backgroundStyle: BackgroundStyle = .lavender
    @State private var stubAlert: String?
    @State private var editingCategory: Category?
    @State private var addingCategory = false
    @State private var deletingCategory: Category?

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Внешний вид") {
                    Picker("Тема", selection: $themeMode) {
                        ForEach(ThemeMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
                    .listRowSeparator(.hidden)

                    TilePicker(title: "Цвета", items: BackgroundStyle.allCases, selection: $backgroundStyle) { style in
                        MeshBackdrop(style: style)
                    } label: { $0.title }
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 12, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                Section {
                    Toggle("Включить напоминания", isOn: $store.remindersEnabled)
                    if store.remindersEnabled {
                        DatePicker("Время напоминания", selection: $store.reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Напоминания")
                } footer: {
                    Text("Уведомления о предстоящих списаниях")
                }

                Section("Категории") {
                    ForEach(store.categories) { cat in
                        let count = store.active.filter { $0.categoryId == cat.id }.count
                        Button { editingCategory = cat } label: {
                            Label {
                                LabeledContent(cat.name, value: "\(count)")
                            } icon: {
                                Image(systemName: cat.symbol).foregroundStyle(cat.color)
                            }
                        }
                        .tint(.primary)
                        .swipeActions {
                            Button("Удалить", systemImage: "trash", role: .destructive) { deletingCategory = cat }
                        }
                    }
                    Button("Добавить категорию", systemImage: "plus") { addingCategory = true }
                }

                Section {
                    ForEach([Currency.usd, .eur]) { c in
                        LabeledContent("1 \(c.code)", value: Fmt.rub(store.rates[c] ?? 0))
                            .monospacedDigit()
                    }
                } header: {
                    Text("Курсы валют")
                } footer: {
                    Text("Прототип: резервные курсы. В рабочей версии — ЦБ РФ.")
                }

                Section("Данные") {
                    Button("Экспорт в JSON", systemImage: "square.and.arrow.up") { stubAlert = "Экспорт в JSON" }
                    Button("Экспорт в CSV", systemImage: "tablecells") { stubAlert = "Экспорт в CSV" }
                    Button("Импорт", systemImage: "square.and.arrow.down") { stubAlert = "Импорт" }
                }

                Section {
                    LabeledContent("Версия", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                }
            }
            .scrollContentBackground(.hidden)
            .background { AmbientBackground() }
            .navigationTitle("Настройки")
            .sheet(item: $editingCategory) { CategoryEditorSheet(editing: $0) }
            .sheet(isPresented: $addingCategory) { CategoryEditorSheet() }
            .alert(
                "Удалить «\(deletingCategory?.name ?? "")»?",
                isPresented: Binding(get: { deletingCategory != nil }, set: { if !$0 { deletingCategory = nil } })
            ) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    if let id = deletingCategory?.id { withAnimation { store.deleteCategory(id) } }
                }
            } message: {
                Text("Подписки этой категории останутся без категории.")
            }
            .alert(stubAlert ?? "", isPresented: Binding(get: { stubAlert != nil }, set: { if !$0 { stubAlert = nil } })) {
                Button("OK") {}
            } message: {
                Text("Будет в следующей версии — сейчас прототип на моковых данных.")
            }
        }
    }
}

/// Wallpaper-style row of mini previews with a caption.
private struct TilePicker<Item: Hashable & Identifiable, Preview: View>: View {
    @Environment(\.appAccent) private var accent
    let title: String
    let items: [Item]
    @Binding var selection: Item
    @ViewBuilder var preview: (Item) -> Preview
    var label: (Item) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        let selected = item == selection
                        Button {
                            withAnimation(.smooth(duration: 0.6)) { selection = item }
                        } label: {
                            VStack(spacing: 6) {
                                preview(item)
                                    .frame(width: 72, height: 112)
                                    .clipShape(.rect(cornerRadius: 16, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(selected ? accent : Color.primary.opacity(0.1), lineWidth: selected ? 3 : 1)
                                    }
                                Text(label(item))
                                    .font(.caption.weight(selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }
}
