import SwiftUI

/// Soft colourful backdrop so Liquid Glass has something to refract.
/// Palette is picked in Settings; the mesh slowly flows like Apple Music.
struct AmbientBackground: View {
    @AppStorage("backgroundStyle") private var style: BackgroundStyle = .lavender

    var body: some View {
        FlowingBackdrop(style: style)
            .ignoresSafeArea()
    }
}

/// Renders a palette; also used for the small previews in Settings.
struct MeshBackdrop: View {
    let style: BackgroundStyle
    @Environment(\.colorScheme) private var scheme

    static let points: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.45], [0.6, 0.4], [1, 0.5],
        [0, 1], [0.5, 1], [1, 1],
    ]

    var body: some View {
        MeshGradient(width: 3, height: 3, points: Self.points, colors: style.colors(dark: scheme == .dark).map { Color(hex: $0) })
    }
}

/// Apple Music–style: the palette warps noticeably and is heavily blurred.
struct FlowingBackdrop: View {
    let style: BackgroundStyle
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = style.colors(dark: scheme == .dark).map { Color(hex: $0) }
        TimelineView(.animation(paused: reduceMotion)) { context in
            MeshGradient(width: 3, height: 3, points: Self.points(t: context.date.timeIntervalSinceReferenceDate), colors: colors)
        }
        .saturation(1.25)
        .scaleEffect(1.35)
        .blur(radius: 36)
    }

    private static func points(t: Double) -> [SIMD2<Float>] {
        func w(_ speed: Double, _ phase: Double, _ amp: Float) -> Float { Float(sin(t * speed + phase)) * amp }
        return [
            [0, 0], [0.5 + w(0.55, 0, 0.3), 0], [1, 0],
            [0, 0.5 + w(0.45, 1.3, 0.3)], [0.5 + w(0.6, 2.1, 0.32), 0.5 + w(0.5, 0.4, 0.32)], [1, 0.5 + w(0.4, 3.7, 0.3)],
            [0, 1], [0.5 + w(0.5, 5.2, 0.3), 1], [1, 1],
        ]
    }
}

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case lavender, aurora, sunset, ocean, graphite, iris

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lavender: "Лаванда"
        case .aurora: "Аврора"
        case .sunset: "Закат"
        case .ocean: "Океан"
        case .graphite: "Графит"
        case .iris: "Ирис"
        }
    }

    /// Accent for controls, selections and charts — tuned per palette and theme.
    func accent(dark: Bool) -> Color {
        let hex: UInt32 = switch (self, dark) {
        case (.lavender, false): 0x6A5CF1
        case (.lavender, true):  0x8F84FF
        case (.aurora, false):   0x0E9F7E
        case (.aurora, true):    0x3DD9A8
        case (.sunset, false):   0xE8553A
        case (.sunset, true):    0xFF8A65
        case (.ocean, false):    0x1E7FD9
        case (.ocean, true):     0x4FB0FF
        case (.graphite, false): 0x4A505C
        case (.graphite, true):  0xC7CBD3
        case (.iris, false):     0xD13F8A
        case (.iris, true):      0xFF6FB5
        }
        return Color(hex: hex)
    }

    /// 3×3 mesh colours, row by row.
    func colors(dark: Bool) -> [UInt32] {
        switch (self, dark) {
        case (.lavender, false): [0xDCD6FF, 0xF3E8FF, 0xD3ECFF, 0xF7F5FF, 0xE6DCFF, 0xFFE9DD, 0xFBF9F6, 0xF6F4FA, 0xFBF9F6]
        case (.lavender, true):  [0x2A1B5E, 0x1E1648, 0x14204A, 0x170F33, 0x4A2B9A, 0x16224F, 0x0B0818, 0x120C26, 0x0A0D1C]
        case (.aurora, false):   [0xCFF5E7, 0xD8E9FF, 0xE9DDFF, 0xE6FFF5, 0xB8F0DC, 0xDCD3FF, 0xF7FBFA, 0xEAF7F3, 0xF6F4FF]
        case (.aurora, true):    [0x06302F, 0x0A2238, 0x1A1446, 0x05221F, 0x12805F, 0x2A1C66, 0x030B0C, 0x061A18, 0x0A0820]
        case (.sunset, false):   [0xFFD9C7, 0xFFE3D3, 0xFFD0E0, 0xFFF0E5, 0xFFC9B0, 0xFFDCEA, 0xFFF8F2, 0xFFEFE6, 0xFDF3F7]
        case (.sunset, true):    [0x3B1030, 0x4A1A2A, 0x2A1240, 0x240A1C, 0x8A3048, 0x3A1650, 0x0E050C, 0x1C0812, 0x100616]
        case (.ocean, false):    [0xCDE8FF, 0xD5F3FF, 0xCFF7EE, 0xEAF6FF, 0xB9E2FF, 0xD7FBF2, 0xF6FAFD, 0xEDF7FB, 0xF4FBF9]
        case (.ocean, true):     [0x0A2350, 0x0C3566, 0x07384A, 0x061633, 0x1460A8, 0x087060, 0x020A18, 0x04142A, 0x021614]
        case (.graphite, false): [0xEDEDF0, 0xF4F4F6, 0xE8EAEE, 0xF7F7F8, 0xE4E4E8, 0xEFEFF2, 0xFAFAFA, 0xF3F3F5, 0xF8F8F9]
        case (.graphite, true):  [0x26262B, 0x2C2C31, 0x222328, 0x18181B, 0x34343A, 0x1D1E22, 0x0A0A0B, 0x111113, 0x0C0C0D]
        case (.iris, false):     [0xE3D6FF, 0xFFE0D1, 0xD2E9FF, 0xFFD6DE, 0xF5F0FF, 0xD9F7E3, 0xFFF1C9, 0xE0DBFF, 0xFFDDEB]
        case (.iris, true):      [0x3B1F86, 0x7A2450, 0x10407A, 0x6A1838, 0x161226, 0x0D5240, 0x0E4B5A, 0x231A5E, 0x5A1640]
        }
    }
}


extension EnvironmentValues {
    /// App accent derived from the chosen palette (use where a concrete Color is needed).
    @Entry var appAccent: Color = .accentColor
}

/// Applies the palette accent as the app-wide tint and as `appAccent`.
struct PaletteAccent: ViewModifier {
    @AppStorage("backgroundStyle") private var style: BackgroundStyle = .lavender
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let accent = style.accent(dark: scheme == .dark)
        content
            .tint(accent)
            .environment(\.appAccent, accent)
            .animation(.smooth, value: style)
    }
}
