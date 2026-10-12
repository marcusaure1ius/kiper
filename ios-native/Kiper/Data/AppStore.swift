import SwiftUI

/// App state: subscriptions, categories, rates and settings. Persists to a local
/// JSON file (same format as backups), keeps reminders in sync and refreshes
/// CBR rates. Calculations mirror `home_providers.dart` / `analytics_provider.dart`.
@MainActor
@Observable
final class AppStore {
    private(set) var subscriptions: [Subscription] = []
    private(set) var categories: [Category] = []
    private(set) var rateSnapshot: RateSnapshot
    private(set) var isRefreshingRates = false
    /// Set when the stored file could not be read; shown once in Settings.
    private(set) var loadError: String?

    var remindersEnabled: Bool {
        didSet {
            defaults.set(remindersEnabled, forKey: Keys.remindersEnabled)
            if remindersEnabled && !oldValue { Task { await enableReminders() } } else { scheduleReminders() }
        }
    }
    var reminderTime: Date {
        didSet {
            let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            defaults.set(c.hour ?? 10, forKey: Keys.reminderHour)
            defaults.set(c.minute ?? 0, forKey: Keys.reminderMinute)
            scheduleReminders()
        }
    }
    /// Notifications denied in system Settings while reminders are on.
    private(set) var remindersBlocked = false

    /// Transient confirmation shown at the top of the app.
    var toast: Toast?

    private let persistence: Persistence?
    private let defaults: UserDefaults
    private let remindersEnabledInSystem: Bool

    private enum Keys {
        static let remindersEnabled = "reminders.enabled"
        static let reminderHour = "reminders.hour"
        static let reminderMinute = "reminders.minute"
    }

    /// - Parameters:
    ///   - persistence: `nil` keeps everything in memory (previews, tests).
    ///   - seedDemoData: fill test subscriptions on first launch (DEBUG builds, like Android).
    init(persistence: Persistence? = .live, defaults: UserDefaults = .standard, seedDemoData: Bool = AppStore.isDebug, systemReminders: Bool = true) {
        self.persistence = persistence
        self.defaults = defaults
        self.remindersEnabledInSystem = systemReminders
        rateSnapshot = persistence == nil ? .fallback : ExchangeRates.cached(defaults: defaults)
        remindersEnabled = defaults.object(forKey: Keys.remindersEnabled) as? Bool ?? true
        reminderTime = Calendar.current.date(from: DateComponents(
            hour: defaults.object(forKey: Keys.reminderHour) as? Int ?? 10,
            minute: defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0
        ))!

        do {
            if let file = try persistence?.load() {
                categories = file.categories.map(BackupMapper.category)
                subscriptions = file.subscriptions.compactMap(BackupMapper.subscription)
            } else {
                // First launch: seed categories (always) and demo subscriptions (debug only).
                categories = SeedData.categories
                subscriptions = seedDemoData ? SeedData.subscriptions() : []
                save()
            }
        } catch {
            // Never overwrite a file we failed to read; start empty in memory.
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            categories = SeedData.categories
        }
        advanceBillingDates()
    }

    static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    func show(_ text: String, symbol: String = "checkmark.circle.fill", tint: Color = .green) {
        withAnimation(.bouncy) { toast = Toast(text: text, symbol: symbol, tint: tint) }
    }

    // MARK: - Lookup

    func category(for id: String?) -> Category? {
        categories.first { $0.id == id }
    }

    func subscription(id: String) -> Subscription? {
        subscriptions.first { $0.id == id }
    }

    var rates: [Currency: Double] {
        Dictionary(uniqueKeysWithValues: Currency.allCases.map { ($0, rateSnapshot.rate($0)) })
    }

    func toRub(_ amount: Double, _ currency: Currency) -> Double {
        amount * rateSnapshot.rate(currency)
    }

    var active: [Subscription] { subscriptions.filter { $0.status == .active } }
    var notCancelled: [Subscription] { subscriptions.filter { $0.status != .cancelled } }

    // MARK: - Mutations

    func upsert(_ sub: Subscription) {
        if let i = subscriptions.firstIndex(where: { $0.id == sub.id }) {
            subscriptions[i] = sub
        } else {
            subscriptions.append(sub)
        }
        advanceBillingDates()
        didChange()
    }

    func togglePause(_ id: String) {
        guard let i = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[i].status = subscriptions[i].status == .paused ? .active : .paused
        advanceBillingDates()
        didChange()
    }

    /// Soft delete, same as Android: row stays for analytics.
    func cancel(_ id: String) {
        guard let i = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[i].status = .cancelled
        didChange()
    }

    func upsertCategory(_ cat: Category) {
        if let i = categories.firstIndex(where: { $0.id == cat.id }) {
            categories[i] = cat
        } else {
            categories.append(cat)
        }
        didChange()
    }

    /// Same rule as Android: detach subscriptions first, then drop the category.
    func deleteCategory(_ id: String) {
        for i in subscriptions.indices where subscriptions[i].categoryId == id {
            subscriptions[i].categoryId = nil
        }
        categories.removeAll { $0.id == id }
        didChange()
    }

    /// Moves past `nextBillingDate`s of active subscriptions forward (Android: `advanceBillingDates`).
    /// Returns true if anything changed.
    @discardableResult
    func advanceBillingDates(now: Date = .now) -> Bool {
        let today = Calendar.current.startOfDay(for: now)
        var changed = false
        for i in subscriptions.indices where subscriptions[i].status == .active {
            var next = subscriptions[i].nextBillingDate
            var guardSteps = 0
            while Calendar.current.startOfDay(for: next) < today && guardSteps < 5000 {
                next = subscriptions[i].billingPeriod.next(after: next, customDays: subscriptions[i].customPeriodDays)
                guardSteps += 1
            }
            if next != subscriptions[i].nextBillingDate {
                subscriptions[i].nextBillingDate = next
                changed = true
            }
        }
        if changed { save() }
        return changed
    }

    /// Called when the app becomes active: roll dates, refresh stale rates, resync reminders.
    func refreshOnForeground() async {
        if advanceBillingDates() { scheduleReminders() }
        if Date.now.timeIntervalSince(rateSnapshot.fetchedAt) > ExchangeRates.maxAge {
            await refreshRates(silent: true)
        }
    }

    private func didChange() {
        save()
        scheduleReminders()
    }

    private func save() {
        guard let persistence, loadError == nil else { return }
        do {
            try persistence.save(backup())
        } catch {
            show("Не удалось сохранить данные", symbol: "exclamationmark.triangle.fill", tint: .orange)
        }
    }

    // MARK: - Rates

    func refreshRates(silent: Bool = false) async {
        guard !isRefreshingRates, persistence != nil else { return }
        isRefreshingRates = true
        defer { isRefreshingRates = false }
        do {
            let snapshot = try await ExchangeRates.fetch()
            rateSnapshot = snapshot
            ExchangeRates.store(snapshot, defaults: defaults)
            if !silent { show("Курсы обновлены") }
        } catch {
            if !silent { show("Нет связи с ЦБ — используются сохранённые курсы", symbol: "wifi.exclamationmark", tint: .orange) }
        }
    }

    // MARK: - Reminders

    private var reminderTask: Task<Void, Never>?

    func scheduleReminders() {
        guard remindersEnabledInSystem else { return }
        let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let plans = remindersEnabled
            ? Reminders.plan(subscriptions: subscriptions, hour: c.hour ?? 10, minute: c.minute ?? 0)
            : []
        reminderTask?.cancel()
        reminderTask = Task {
            guard !Task.isCancelled else { return }
            if remindersEnabled {
                remindersBlocked = await Reminders.authorizationStatus() == .denied
            }
            await Reminders.apply(plans)
        }
    }

    /// Asks for permission (first time) and schedules everything.
    func enableReminders() async {
        guard remindersEnabledInSystem else { return }
        let granted = await Reminders.requestAuthorization()
        remindersBlocked = !granted
        scheduleReminders()
    }

    // MARK: - Backup

    func backup(now: Date = .now) -> BackupFile {
        BackupMapper.file(subscriptions: subscriptions, categories: categories, now: now)
    }

    enum ImportMode { case replace, merge }

    struct ImportResult: Equatable {
        var subscriptions: Int
        var categories: Int
    }

    /// Imports a JSON backup (Android or iOS). `replace` wipes current data first;
    /// `merge` upserts by id, like the Android app.
    @discardableResult
    func importBackup(_ file: BackupFile, mode: ImportMode) -> ImportResult {
        let cats = file.categories.map(BackupMapper.category)
        let subs = file.subscriptions.compactMap(BackupMapper.subscription)
        switch mode {
        case .replace:
            categories = cats
            subscriptions = subs
        case .merge:
            for c in cats {
                if let i = categories.firstIndex(where: { $0.id == c.id }) { categories[i] = c } else { categories.append(c) }
            }
            for s in subs {
                if let i = subscriptions.firstIndex(where: { $0.id == s.id }) { subscriptions[i] = s } else { subscriptions.append(s) }
            }
        }
        // Drop dangling category links (a category may be missing from the file).
        let known = Set(categories.map(\.id))
        for i in subscriptions.indices where subscriptions[i].categoryId.map({ !known.contains($0) }) ?? false {
            subscriptions[i].categoryId = nil
        }
        loadError = nil
        advanceBillingDates()
        didChange()
        return ImportResult(subscriptions: subs.count, categories: cats.count)
    }

    /// CSV carries subscriptions only; rows are upserted by id (Android behaviour).
    @discardableResult
    func importCSV(_ text: String) -> ImportResult {
        let subs = CSVCodec.decode(text)
        let file = BackupFile(exportedAt: "", subscriptions: subs.map(BackupMapper.dto), categories: [])
        return importBackup(file, mode: .merge)
    }

    // MARK: - Home

    var monthlyTotalRub: Double {
        active.reduce(0) { $0 + toRub($1.amount, $1.currency) * $1.billingPeriod.monthlyEquivalent }
    }

    func monthProgress(now: Date = .now) -> (paid: Double, remaining: Double) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let month = cal.dateInterval(of: .month, for: now)!
        var paid = 0.0, remaining = 0.0
        for sub in active {
            for date in billingDates(of: sub, from: month.start, to: month.end) {
                let rub = toRub(sub.amount, sub.currency)
                if date < today { paid += rub } else { remaining += rub }
            }
        }
        return (paid, remaining)
    }

    func pastPayments(days: Int = 90, now: Date = .now) -> [PaymentEvent] {
        let today = Calendar.current.startOfDay(for: now)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: today)!
        return active
            .flatMap { sub in billingDates(of: sub, from: start, to: today).map { PaymentEvent(subscription: sub, date: $0) } }
            .sorted { $0.date > $1.date }
    }

    func futurePayments(days: Int = 90, now: Date = .now) -> [PaymentEvent] {
        let today = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: days, to: today)!
        return active
            .flatMap { sub in billingDates(of: sub, from: today, to: end).map { PaymentEvent(subscription: sub, date: $0) } }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Analytics

    func monthlyTotals(past: Int = 6, future: Int = 3, now: Date = .now) -> [PeriodTotal] {
        let cal = Calendar.current
        let current = cal.dateInterval(of: .month, for: now)!.start
        let starts = (-past...future).map { cal.date(byAdding: .month, value: $0, to: current)! }
        return totals(buckets: starts, end: cal.date(byAdding: .month, value: 1, to: starts.last!)!, current: current) {
            cal.dateInterval(of: .month, for: $0)!.start
        }
    }

    func weeklyTotals(past: Int = 6, future: Int = 4, now: Date = .now) -> [PeriodTotal] {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let current = cal.dateInterval(of: .weekOfYear, for: now)!.start
        let starts = (-past...future).map { cal.date(byAdding: .weekOfYear, value: $0, to: current)! }
        return totals(buckets: starts, end: cal.date(byAdding: .weekOfYear, value: 1, to: starts.last!)!, current: current) {
            cal.dateInterval(of: .weekOfYear, for: $0)!.start
        }
    }

    /// Per-category charges inside `interval` (RUB), split into already paid (before today)
    /// and total. Uses the same subscriptions as the bar chart, so totals add up to the bar.
    func categoryShares(in interval: DateInterval, now: Date = .now) -> [CategoryShare] {
        let today = Calendar.current.startOfDay(for: now)
        var paid: [String?: Double] = [:], total: [String?: Double] = [:]
        for sub in notCancelled {
            for date in billingDates(of: sub, from: interval.start, to: interval.end) {
                let rub = toRub(sub.amount, sub.currency)
                total[sub.categoryId, default: 0] += rub
                if date < today { paid[sub.categoryId, default: 0] += rub }
            }
        }
        return total
            .map { CategoryShare(category: category(for: $0.key), paid: paid[$0.key] ?? 0, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Helpers

    private func totals(buckets: [Date], end: Date, current: Date, bucketOf: (Date) -> Date) -> [PeriodTotal] {
        var sums = Dictionary(uniqueKeysWithValues: buckets.map { ($0, 0.0) })
        for sub in notCancelled {
            for date in billingDates(of: sub, from: buckets.first!, to: end) {
                sums[bucketOf(date), default: 0] += toRub(sub.amount, sub.currency)
            }
        }
        return buckets.map { PeriodTotal(start: $0, amount: sums[$0] ?? 0, isForecast: $0 >= current) }
    }

    /// Billing dates in `[from, to)`, anchored on `nextBillingDate` and stepping by multiples
    /// of the period in both directions (never before `startDate`). Multiples avoid
    /// day-of-month drift such as Jan 31 → Feb 28 → Mar 28.
    func billingDates(of sub: Subscription, from: Date, to: Date) -> [Date] {
        let cal = Calendar.current
        let lower = max(from, cal.startOfDay(for: sub.startDate))
        // Nothing is charged between today and the next billing date: past occurrences
        // are history (before today), future ones start exactly at nextBillingDate.
        let today = cal.startOfDay(for: .now)
        let next = cal.startOfDay(for: sub.nextBillingDate)
        var n = 0
        while n > -10_000, step(sub, n - 1, cal) >= lower { n -= 1 }
        var result: [Date] = []
        while n < 10_000 {
            let date = step(sub, n, cal)
            if date >= to { break }
            if date >= lower && !(date >= today && date < next) { result.append(date) }
            n += 1
        }
        return result
    }

    private func step(_ sub: Subscription, _ n: Int, _ cal: Calendar) -> Date {
        let s = sub.nextBillingDate
        return switch sub.billingPeriod {
        case .weekly: cal.date(byAdding: .day, value: 7 * n, to: s)!
        case .monthly: cal.date(byAdding: .month, value: n, to: s)!
        case .quarterly: cal.date(byAdding: .month, value: 3 * n, to: s)!
        case .semiannual: cal.date(byAdding: .month, value: 6 * n, to: s)!
        case .annual: cal.date(byAdding: .year, value: n, to: s)!
        case .custom: cal.date(byAdding: .day, value: max(sub.customPeriodDays ?? 30, 1) * n, to: s)!
        }
    }
}
