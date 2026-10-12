import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Авто"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@main
struct KiperApp: App {
    @State private var store = MockStore()
    @AppStorage("themeMode") private var themeMode: ThemeMode = .system

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modifier(PaletteAccent())
                .environment(store)
                .preferredColorScheme(themeMode.colorScheme)
                .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }
}
