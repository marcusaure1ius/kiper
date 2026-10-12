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
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore()
    @AppStorage("themeMode") private var themeMode: ThemeMode = .system
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modifier(PaletteAccent())
                .environment(store)
                .environment(appDelegate.router)
                .task {
                    // Ask once on first launch (reminders default to on, like Android).
                    if store.remindersEnabled { await store.enableReminders() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.refreshOnForeground() } }
                }
                .preferredColorScheme(themeMode.colorScheme)
                .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }
}
