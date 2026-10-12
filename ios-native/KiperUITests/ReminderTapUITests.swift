import XCTest

/// End-to-end: a real local reminder is delivered, the user taps the banner in
/// SpringBoard, and the app opens that subscription's detail screen.
final class ReminderTapUITests: XCTestCase {
    @MainActor
    func testTappingReminderOpensSubscription() throws {
        let app = XCUIApplication()
        // DEBUG flag: schedules a real reminder for the first active subscription ~8 s after launch.
        app.launchArguments = ["-KiperTestReminder"]
        app.launch()

        // Allow notifications if the system asks (fresh simulator).
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Разрешить", "Allow"] {
            let allow = springboard.buttons[title]
            if allow.waitForExistence(timeout: 2) { allow.tap(); break }
        }

        // Start on another tab so the jump is visible, then leave the app.
        app.tabBars.buttons["Настройки"].firstMatch.tap()
        XCUIDevice.shared.press(.home)

        // Banner text: "<name> — списание …".
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'списание' OR identifier == 'NotificationShortLookView'")).firstMatch
        if !banner.waitForExistence(timeout: 30) {
            print("SPRINGBOARD TREE:\n\(springboard.debugDescription)")
        }
        XCTAssertTrue(banner.exists, "reminder banner was not delivered")
        banner.tap()

        // Detail screen of the subscription (rows unique to it).
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.staticTexts["Следующее списание"].waitForExistence(timeout: 10), "app did not open the subscription")
        XCTAssertTrue(app.staticTexts["Дата начала"].exists)
    }
}
