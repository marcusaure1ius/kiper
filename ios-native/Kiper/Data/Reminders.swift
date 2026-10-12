import Foundation
import UserNotifications

/// Local reminders before charges (mirrors `_scheduleNotification` in the Android app).
/// One pending request per subscription; the whole set is rebuilt on every change.
enum Reminders {
    static let prefix = "sub-"
    static let subscriptionIdKey = "subscriptionId"
    /// iOS keeps at most 64 pending local notifications per app.
    static let limit = 60

    struct Plan: Equatable {
        let id: String
        let subscriptionId: String
        let fireDate: Date
        let title: String
        let body: String
    }

    /// Pure planning step (unit-tested): which reminder fires when.
    static func plan(
        subscriptions: [Subscription],
        hour: Int, minute: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Plan] {
        var plans: [Plan] = []
        for sub in subscriptions where sub.status == .active && sub.reminderDaysBefore > 0 {
            // First charge whose reminder is still in the future.
            var charge = sub.nextBillingDate
            for _ in 0..<3 {
                if let fire = fireDate(for: charge, daysBefore: sub.reminderDaysBefore, hour: hour, minute: minute, calendar: calendar), fire > now {
                    plans.append(Plan(
                        id: prefix + sub.id,
                        subscriptionId: sub.id,
                        fireDate: fire,
                        title: "Напоминание о подписке",
                        body: body(for: sub, daysBefore: sub.reminderDaysBefore)
                    ))
                    break
                }
                charge = sub.billingPeriod.next(after: charge, customDays: sub.customPeriodDays)
            }
        }
        return Array(plans.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }

    static func fireDate(for charge: Date, daysBefore: Int, hour: Int, minute: Int, calendar: Calendar = .current) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: charge)) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    static func body(for sub: Subscription, daysBefore: Int) -> String {
        let when = switch daysBefore {
        case 1: "завтра"
        default: "через \(daysBefore) \(Fmt.plural(daysBefore, "день", "дня", "дней"))"
        }
        return "\(sub.name) — списание \(when), \(Fmt.money(sub.amount, sub.currency))"
    }

    // MARK: - System

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Replaces all Kiper reminders with `plans` (empty = just clear).
    static func apply(_ plans: [Plan]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })

        let calendar = Calendar.current
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.threadIdentifier = "reminders"
            content.userInfo = [subscriptionIdKey: plan.subscriptionId]
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
        }
    }
}
