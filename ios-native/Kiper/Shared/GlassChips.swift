import SwiftUI

/// Horizontal row of Liquid Glass chips. All chips share one GlassEffectContainer,
/// so the tinted selection blends between neighbours as it changes.
struct GlassChips<ID: Hashable & Sendable>: View {
    struct Item: Identifiable {
        let id: ID
        let title: String
        let symbol: String
        var color: Color? = nil
    }

    let items: [Item]
    @Binding var selection: ID
    @Namespace private var ns
    @Environment(\.appAccent) private var accent

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(items) { chip($0).id(item: $0.id) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .scrollClipDisabled()
            .onAppear { proxy.scrollTo(ChipAnchor(selection), anchor: .center) }
            .onChange(of: selection) { _, new in
                withAnimation(.smooth) { proxy.scrollTo(ChipAnchor(new), anchor: .center) }
            }
        }
    }

    private func chip(_ item: Item) -> some View {
        let selected = selection == item.id
        return Button {
            withAnimation(.bouncy) { selection = item.id }
        } label: {
            Label(item.title, systemImage: item.symbol)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .glassEffect(selected ? .regular.tint(item.color ?? accent).interactive() : .regular.interactive(), in: .capsule)
        .glassEffectID(item.id, in: ns)
    }
}

/// Wraps a chip id so it can be used as a ScrollViewReader anchor even when the id is Optional.
private struct ChipAnchor<ID: Hashable>: Hashable {
    let value: ID
    init(_ value: ID) { self.value = value }
}

private extension View {
    func id<ID: Hashable>(item: ID) -> some View { id(ChipAnchor(item)) }
}
