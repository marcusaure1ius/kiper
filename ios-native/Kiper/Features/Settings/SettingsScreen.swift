import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @Environment(AppStore.self) private var store
    @AppStorage("themeMode") private var themeMode: ThemeMode = .system
    @AppStorage("backgroundStyle") private var backgroundStyle: BackgroundStyle = .lavender
    /// One file picker for both uses — SwiftUI ignores a second `.fileImporter` in the same view.
    /// The mode outlives the presentation flag: SwiftUI clears `isPresented`
    /// before calling the completion, so it can't be derived from it.
    @State private var showPicker = false
    @State private var pickerMode: PickerMode = .importFile
    private enum PickerMode { case importFile, backupFolder }
    @State private var pendingBackup: BackupFile?
    @State private var importError: String?
    @State private var editingCategory: Category?
    @State private var addingCategory = false
    @State private var deletingCategory: Category?
    @State private var confirmReset = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                if let error = store.loadError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("Сохранённые данные не прочитались. Восстановите их из резервной копии через «Импорт из файла» — новые изменения уже сохраняются.")
                    }
                }

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
                        if store.remindersBlocked {
                            Link(destination: URL(string: UIApplication.openNotificationSettingsURLString)!) {
                                Label("Уведомления запрещены — открыть настройки iOS", systemImage: "bell.slash.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } header: {
                    Text("Напоминания")
                } footer: {
                    Text("Уведомление приходит в это время — за столько дней до списания, сколько указано в подписке.")
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
                        LabeledContent("1 \(c.code)", value: Fmt.money(store.rateSnapshot.rate(c), .rub, decimals: 2))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Button {
                        Task { await store.refreshRates() }
                    } label: {
                        HStack {
                            Label("Обновить курсы", systemImage: "arrow.clockwise")
                            Spacer()
                            if store.isRefreshingRates { ProgressView() }
                        }
                    }
                    .disabled(store.isRefreshingRates)
                } header: {
                    Text("Курсы валют")
                } footer: {
                    Text(ratesFooter)
                }

                Section {
                    if store.autoBackup.isEnabled {
                        LabeledContent {
                            Text(store.autoBackup.folderName ?? "")
                        } label: {
                            Label("Автокопия", systemImage: "icloud.and.arrow.up")
                        }
                        if let error = store.autoBackup.lastError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                        }
                        Button("Сохранить копию сейчас", systemImage: "arrow.clockwise.icloud") {
                            if store.autoBackup.run(store.backup()) { store.show("Копия сохранена") }
                        }
                        Button("Сменить папку", systemImage: "folder") { pickerMode = .backupFolder; showPicker = true }
                        Button("Отключить автокопию", systemImage: "icloud.slash", role: .destructive) {
                            withAnimation { store.autoBackup.disable() }
                        }
                        .tint(.red)
                    } else {
                        Button("Включить автокопию в Файлы", systemImage: "icloud.and.arrow.up") { pickerMode = .backupFolder; showPicker = true }
                    }
                } header: {
                    Text("Резервная копия")
                } footer: {
                    Text(backupFooter)
                }

                Section {
                    ShareLink(
                        item: JSONExport(data: (try? BackupMapper.encode(store.backup())) ?? Data()),
                        preview: SharePreview("Резервная копия Кипера", image: Image(systemName: "doc.text"))
                    ) {
                        Label("Экспорт в JSON", systemImage: "square.and.arrow.up")
                    }
                    ShareLink(
                        item: CSVExport(text: CSVCodec.encode(store.subscriptions)),
                        preview: SharePreview("Подписки Кипера (CSV)", image: Image(systemName: "tablecells"))
                    ) {
                        Label("Экспорт в CSV", systemImage: "tablecells")
                    }
                    Button("Импорт из файла", systemImage: "square.and.arrow.down") { pickerMode = .importFile; showPicker = true }
                    Button("Удалить все данные", systemImage: "trash", role: .destructive) { confirmReset = true }
                        .tint(.red)
                } header: {
                    Text("Данные")
                } footer: {
                    Text("Формат совместим с Кипером для Android. JSON переносит подписки и категории, CSV — только подписки.")
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
            .alert("Удалить все данные?", isPresented: $confirmReset) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    withAnimation { store.resetAll() }
                    store.show("Данные удалены", symbol: "trash.circle.fill", tint: .red)
                }
            } message: {
                Text("Все подписки будут удалены, категории вернутся к стандартным. Сначала можно сделать «Экспорт в JSON».")
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: pickerMode == .backupFolder ? [.folder] : [.json, .commaSeparatedText, .plainText]
            ) { result in
                if pickerMode == .backupFolder { chooseBackupFolder(result) } else { handleImport(result) }
            }
            .confirmationDialog(
                "Импорт резервной копии",
                isPresented: Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } }),
                titleVisibility: .visible
            ) {
                if let file = pendingBackup {
                    Button("Добавить к текущим") { finishImport(file, mode: .merge) }
                    Button("Заменить все данные", role: .destructive) { finishImport(file, mode: .replace) }
                }
            } message: {
                if let file = pendingBackup {
                    Text("В файле \(file.subscriptions.count) \(Fmt.plural(file.subscriptions.count, "подписка", "подписки", "подписок")) и \(file.categories.count) \(Fmt.plural(file.categories.count, "категория", "категории", "категорий")). При добавлении совпадающие записи обновятся.")
                }
            }
            .alert("Не удалось импортировать", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK") {}
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var backupFooter: String {
        guard store.autoBackup.isEnabled else {
            return "Выберите папку в «Файлах», например iCloud Drive → Кипер. После каждого изменения туда сохранится «\(AutoBackup.latestName)» и копии за последние \(AutoBackup.keepDays) дней — их можно вернуть через «Импорт из файла»."
        }
        guard let last = store.autoBackup.lastBackup else { return "Копия ещё не сохранялась." }
        let when = Calendar.current.isDateInToday(last) ? "сегодня в \(last.formatted(date: .omitted, time: .shortened))" : Fmt.smartDate(last)
        return "Последняя копия: \(when). Сохраняется после каждого изменения."
    }

    private var ratesFooter: String {
        let s = store.rateSnapshot
        if s.isFallback { return "Резервные курсы: пока нет данных от ЦБ РФ." }
        let date = Fmt.smartDate(s.quoteDate ?? s.fetchedAt)
        return "Курс ЦБ РФ на \(date)" + (date.hasSuffix(".") ? "" : ".")
    }

    private func chooseBackupFolder(_ result: Result<URL, Error>) {
        do {
            try store.autoBackup.setFolder(result.get())
            if store.autoBackup.run(store.backup()) { store.show("Автокопия включена") }
        } catch {
            importError = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let text = String(decoding: data, as: UTF8.self)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
            if url.pathExtension.lowercased() == "csv" || !trimmed.hasPrefix("{") {
                let result = store.importCSV(text)
                guard result.subscriptions > 0 else { throw BackupError.unreadable }
                store.show("Импортировано: \(result.subscriptions) \(Fmt.plural(result.subscriptions, "подписка", "подписки", "подписок"))")
            } else {
                pendingBackup = try BackupMapper.decode(data)
            }
        } catch {
            importError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func finishImport(_ file: BackupFile, mode: AppStore.ImportMode) {
        let result = withAnimation { store.importBackup(file, mode: mode) }
        let skipped = result.skipped > 0 ? ", пропущено \(result.skipped)" : ""
        store.show("Импортировано: \(result.subscriptions) \(Fmt.plural(result.subscriptions, "подписка", "подписки", "подписок"))\(skipped)",
                   symbol: result.skipped > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                   tint: result.skipped > 0 ? .orange : .green)
        pendingBackup = nil
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
