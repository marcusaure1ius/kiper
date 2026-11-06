import LocalAuthentication
import SwiftUI

/// Pure lock state machine (unit-tested): the lock screen covers the app while
/// the feature is on and this session hasn't been authorized yet. Going to the
/// background re-arms it. Turning the toggle on mid-session keeps the current
/// (already authenticated) session open — like system Notes.
struct LockPolicy: Equatable {
    private(set) var isEnabled: Bool
    private(set) var isUnlocked: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
        // A fresh process starts locked when the feature is on.
        self.isUnlocked = !isEnabled
    }

    var isLocked: Bool { isEnabled && !isUnlocked }

    mutating func unlock() { isUnlocked = true }

    /// Enabling never locks the person out of the screen they're on.
    mutating func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { isUnlocked = true }
    }

    mutating func scenePhaseChanged(_ phase: ScenePhase) {
        if phase == .background { isUnlocked = false }
        if phase == .active && !isEnabled { isUnlocked = true }
    }
}

/// App-level gate: Face ID (or the device passcode) before showing any data.
@MainActor
@Observable
final class AppLock {
    private static let key = "appLock.enabled"
    private(set) var policy: LockPolicy
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        // `-KiperNoLock` (DEBUG launch argument): bypass for UI tests and screenshots.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-KiperNoLock") {
            self.defaults = defaults
            policy = LockPolicy(isEnabled: false)
            return
        }
        #endif
        self.defaults = defaults
        policy = LockPolicy(isEnabled: defaults.bool(forKey: Self.key))
    }

    var isLocked: Bool { policy.isLocked }
    var isEnabled: Bool { policy.isEnabled }

    func setEnabled(_ enabled: Bool) {
        policy.setEnabled(enabled)
        defaults.set(enabled, forKey: Self.key)
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        policy.scenePhaseChanged(phase)
    }

    /// Runs the system authentication prompt. Devices without any passcode
    /// can't be gated — the lock silently opens (there is nothing to authenticate with).
    func unlock() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            policy.unlock()
            return true
        }
        let granted = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Разблокировать Кипер")) ?? false
        if granted { policy.unlock() }
        return granted
    }
}

/// Full-screen cover shown while locked.
struct LockView: View {
    @Environment(AppLock.self) private var lock
    @Environment(\.appAccent) private var accent
    @State private var failed = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(accent)
                .symbolEffect(.pulse, isActive: lock.isLocked)
            Text("Кипер заблокирован")
                .font(.title3.bold())
            Text(failed ? "Не получилось — попробуйте ещё раз" : "Подтвердите вход, чтобы увидеть данные")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Разблокировать", systemImage: "faceid") {
                Task { failed = !(await lock.unlock()) }
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 6)
            Spacer()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AmbientBackground() }
        .transition(.opacity)
        .task {
            // Auto-attempt on appear, like banking apps.
            failed = !(await lock.unlock())
        }
    }
}
