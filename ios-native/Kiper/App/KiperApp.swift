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
    @State private var store = KiperApp.makeStore()
    @AppStorage("themeMode") private var themeMode: ThemeMode = .system
    @Environment(\.scenePhase) private var scenePhase

    /// `-KiperEmptyState` (DEBUG launch argument): fresh in-memory store, for checking empty screens.
    private static func makeStore() -> AppStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-KiperEmptyState") {
            return AppStore(persistence: nil, seedDemoData: false)
        }
        #endif
        return AppStore()
    }

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
