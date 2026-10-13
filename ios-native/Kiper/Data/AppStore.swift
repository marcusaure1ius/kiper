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
    /// Stored rows that couldn't be parsed (bad dates etc.). Written back untouched,
    /// so saving never deletes data we failed to understand.
    private var unparsed: [SubscriptionDTO] = []

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

    /// Copies of the data into a user-picked Files folder (e.g. iCloud Drive).
    let autoBackup: AutoBackup

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
        self.autoBackup = AutoBackup(defaults: defaults)
        rateSnapshot = persistence == nil ? .fallback : ExchangeRates.cached(defaults: defaults)
        remindersEnabled = defaults.object(forKey: Keys.remindersEnabled) as? Bool ?? true
        reminderTime = Calendar.current.date(from: DateComponents(
            hour: defaults.object(forKey: Keys.reminderHour) as? Int ?? 10,
            minute: defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0
        ))!

        do {
            if let file = try persistence?.load() {
                categories = file.categories.map(BackupMapper.category)
                for dto in file.subscriptions {
                    if let sub = BackupMapper.subscription(dto) { subscriptions.append(sub) } else { unparsed.append(dto) }
                }
            } else {
                // First launch: seed categories (always) and demo subscriptions (debug only).
                categories = SeedData.categories
                subscriptions = seedDemoData ? SeedData.subscriptions() : []
                save()
            }
        } catch {
            // Keep the unreadable file as a side copy, then work normally (so edits
            // made from now on are saved, and nothing old is lost).
            let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let copy = persistence.flatMap { try? $0.quarantine() }
            loadError = copy.map { "\(reason) Исходный файл сохранён как «\($0.lastPathComponent)»." } ?? reason
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
            guard Calendar.current.startOfDay(for: subscriptions[i].nextBillingDate) < today else { continue }
            let next = Schedule.firstCharge(of: subscriptions[i], onOrAfter: today)
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
        // At least one copy a day even without edits (keeps the dated history going).
        if autoBackup.isEnabled, !(autoBackup.lastBackup.map { Calendar.current.isDateInToday($0) } ?? false) {
            autoBackup.run(backup())
        }
        if Date.now.timeIntervalSince(rateSnapshot.fetchedAt) > ExchangeRates.maxAge {
            await refreshRates(silent: true)
        }
    }

    private func didChange() {
        save()
        scheduleReminders()
        autoBackup.schedule { [unowned self] in self.backup() }
    }

    private func save() {
        guard let persistence else { return }
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
        // Chain runs so two rebuilds never interleave (remove/add of an older plan
        // landing after a newer one); a superseded run stops at its next check.
        let previous = reminderTask
        previous?.cancel()
        reminderTask = Task {
            await previous?.value
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
        var file = BackupMapper.file(subscriptions: subscriptions, categories: categories, now: now)
        file.subscriptions += unparsed
        return file
    }

    enum ImportMode { case replace, merge }

    struct ImportResult: Equatable {
        var subscriptions: Int
        var categories: Int
        /// Rows skipped because they couldn't be read (bad dates).
        var skipped: Int = 0
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
            unparsed = []
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
        if mode == .replace { loadError = nil }
        advanceBillingDates()
        didChange()
        return ImportResult(subscriptions: subs.count, categories: cats.count, skipped: file.subscriptions.count - subs.count)
    }

    /// Wipes subscriptions and restores the default categories (Settings → «Удалить все данные»).
    func resetAll() {
        subscriptions = []
        categories = SeedData.categories
        unparsed = []
        loadError = nil
        didChange()
    }

    /// CSV carries subscriptions only; rows are upserted by id (Android behaviour).
    @discardableResult
    func importCSV(_ text: String) -> ImportResult {
        // CSV has no icon/domain/createdAt — keep them from rows we already have.
        let subs = CSVCodec.decode(text).map { row -> Subscription in
            guard let old = subscription(id: row.id) else { return row }
            var merged = row
            merged.icon = old.icon
            merged.domain = old.domain ?? row.domain
            merged.createdAt = old.createdAt
            return merged
        }
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

    func billingDates(of sub: Subscription, from: Date, to: Date) -> [Date] {
        Schedule.dates(of: sub, from: from, to: to)
    }
}
