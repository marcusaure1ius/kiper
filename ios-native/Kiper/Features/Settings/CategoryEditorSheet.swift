import SwiftUI

/// Create / edit a category: name, colour, SF Symbol, with a live glass preview.
struct CategoryEditorSheet: View {
    @Environment(MockStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: Category?
    @State private var draft: Category
    @State private var confirmDelete = false

    static let palette: [UInt32] = [
        0x7C4DFF, 0x5856D6, 0x2196F3, 0x00B8D4, 0x00C853, 0x8BC34A,
        0xFFC107, 0xFF9800, 0xFF6B35, 0xE50914, 0xFF2D78, 0x9E9E9E,
    ]

    static let symbols = [
        "play.tv.fill", "music.note", "sparkles", "brain.head.profile", "antenna.radiowaves.left.and.right", "wifi",
        "gamecontroller.fill", "film.fill", "book.fill", "newspaper.fill", "cloud.fill", "lock.shield.fill",
        "cart.fill", "bag.fill", "fork.knife", "cup.and.saucer.fill", "car.fill", "tram.fill",
        "figure.run", "heart.fill", "graduationcap.fill", "briefcase.fill", "house.fill", "pawprint.fill",
        "creditcard.fill", "gift.fill", "paintbrush.fill", "camera.fill", "airplane", "square.grid.2x2.fill",
    ]

    init(editing: Category? = nil) {
        existing = editing
        _draft = State(initialValue: editing ?? Category(
            id: "cat-\(UUID().uuidString.prefix(8).lowercased())",
            name: "",
            color: Color(hex: Self.palette[0]),
            symbol: Self.symbols[0]
        ))
    }

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section("Название") {
                    TextField("Например, Обучение", text: $draft.name)
                }

                Section("Цвет") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(Self.palette, id: \.self) { hex in
                            let color = Color(hex: hex)
                            let selected = draft.color == color
                            Button { withAnimation(.snappy) { draft.color = color } } label: {
                                Circle()
                                    .fill(color.gradient)
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(.background, lineWidth: selected ? 3 : 0).padding(3))
                                    .overlay(Circle().stroke(color, lineWidth: selected ? 2 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Цвет")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Иконка") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Self.symbols, id: \.self) { symbol in
                            let selected = draft.symbol == symbol
                            Button { withAnimation(.snappy) { draft.symbol = symbol } } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                                    .foregroundStyle(selected ? .white : draft.color)
                                    .background(selected ? AnyShapeStyle(draft.color.gradient) : AnyShapeStyle(draft.color.opacity(0.12)),
                                                in: .rect(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                if existing != nil {
                    Section {
                        Button("Удалить категорию", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(existing == nil ? "Новая категория" : "Категория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        draft.name = trimmedName
                        withAnimation { store.upsertCategory(draft) }
                        store.show(existing == nil ? "Категория добавлена" : "Категория сохранена")
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog("Удалить «\(draft.name)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить категорию", role: .destructive) {
                    if let id = existing?.id { withAnimation { store.deleteCategory(id) } }
                    dismiss()
                }
            } message: {
                Text("Подписки этой категории останутся без категории.")
            }
        }
    }

    /// Glass chip exactly as it appears in the subscriptions filter.
    private var preview: some View {
        VStack(spacing: 14) {
            Image(systemName: draft.symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(draft.color.gradient, in: .rect(cornerRadius: 22, style: .continuous))
                .contentTransition(.symbolEffect(.replace))
            Label(trimmedName.isEmpty ? "Категория" : trimmedName, systemImage: draft.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassEffect(.regular.tint(draft.color), in: .capsule)
        }
        .padding(.vertical, 8)
    }
}
