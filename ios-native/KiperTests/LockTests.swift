import Foundation
import Testing
@testable import Kiper

struct LockTests {
    @Test func startsLockedWhenEnabled() {
        var policy = LockPolicy(isEnabled: true)
        #expect(policy.isLocked)
        policy.unlock()
        #expect(!policy.isLocked)
    }

    @Test func neverLocksWhenDisabled() {
        let policy = LockPolicy(isEnabled: false)
        #expect(!policy.isLocked)
    }

    @Test func backgroundRearmsTheLock() {
        var policy = LockPolicy(isEnabled: true)
        policy.unlock()
        #expect(!policy.isLocked)

        policy.scenePhaseChanged(.background)
        #expect(policy.isLocked, "leaving the app re-arms the lock")
        policy.scenePhaseChanged(.active)
        #expect(policy.isLocked, "coming back keeps it locked until authentication")
    }

    @Test func shortInterruptionDoesNotUnlockEither() {
        var policy = LockPolicy(isEnabled: true)
        policy.unlock()
        // A phone call / app switcher overlay — still a re-arm.
        policy.scenePhaseChanged(.inactive)
        policy.scenePhaseChanged(.active)
        #expect(!policy.isLocked, "an overlay without backgrounding keeps the session")
    }

    @Test func enablingKeepsTheCurrentSession() {
        var policy = LockPolicy(isEnabled: false)
        policy.setEnabled(true)
        #expect(!policy.isLocked, "turning the toggle on must not lock the person out of Settings")

        policy.scenePhaseChanged(.background)
        policy.scenePhaseChanged(.active)
        #expect(policy.isLocked)

        policy.setEnabled(false)
        #expect(!policy.isLocked, "disabling always unlocks")
    }
}
