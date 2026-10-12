import Foundation
import Testing
@testable import Kiper

@MainActor
struct RouterTests {
    /// What a reminder tap does (AppDelegate → router), from any tab and depth.
    @Test func reminderTapOpensSubscriptionOnHome() {
        let router = AppRouter()
        router.tab = .settings
        router.homePath = [.list, .detail("other")]
        router.openSubscription("test-1")
        #expect(router.tab == .home)
        #expect(router.homePath == [.detail("test-1")])
    }

    @Test func reminderCarriesSubscriptionId() {
        let sub = makeSub(id: "abc", next: day(2026, 12, 1), start: day(2026, 1, 1))
        let plan = Reminders.plan(subscriptions: [sub], hour: 10, minute: 0, now: day(2026, 10, 1)).first
        #expect(plan?.subscriptionId == "abc")
        #expect(Reminders.subscriptionIdKey == "subscriptionId")
    }
}
