import SwiftUI

/// Service favicon with a category-coloured SF Symbol fallback.
struct SubscriptionLogo: View {
    let subscription: Subscription
    var category: Category?
    var size: CGFloat = 44

    var body: some View {
        let tint = category?.color ?? .gray
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(tint.gradient.opacity(0.18))
            if let url = subscription.logoURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(size * 0.18)
                    } else {
                        fallback(tint)
                    }
                }
            } else {
                fallback(tint)
            }
        }
        .frame(width: size, height: size)
    }

    private func fallback(_ tint: Color) -> some View {
        Image(systemName: category?.symbol ?? "creditcard.fill")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
    }
}

/// Original amount + RUB equivalent (CLAUDE.md: always show both).
struct AmountLabel: View {
    @Environment(MockStore.self) private var store
    let amount: Double
    let currency: Currency
    var alignment: HorizontalAlignment = .trailing

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(Fmt.money(amount, currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
            if currency != .rub {
                Text("≈ \(Fmt.rub(store.toRub(amount, currency)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

/// A row used in payment lists and the subscriptions list.
struct SubscriptionRow: View {
    @Environment(MockStore.self) private var store
    let subscription: Subscription
    var subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            SubscriptionLogo(subscription: subscription, category: store.category(for: subscription.categoryId))
            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            AmountLabel(amount: subscription.amount, currency: subscription.currency)
        }
        .contentShape(.rect)
    }
}

/// Rounded content card. Content stays on a solid-ish surface; glass is reserved for controls.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: 26, style: .continuous))
    }
}
