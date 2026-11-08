import SwiftUI

/// App state: subscriptions, categories, rates and settings. Persists to a local
/// JSON file (same format as backups), keeps reminders in sync and refreshes
/// CBR rates. Calculations mirror `home_providers.dart` / `analytics_provider.dart`.
@MainActor
@Observable
final class AppStore {
    private(set) var subscriptions: [Subscription] = []
    private(set) var categories: [Category] = []
    private(set) var payments: [PaymentRecord] = []
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
    /// Monthly spending cap for all subscriptions (RUB). Lives in the backup file's
    /// `settings` so it travels with exports; the home card turns orange past it.
    var monthlyBudgetRub: Double? {
        didSet { save() }
    }
    /// Notifications denied in system Settings while reminders are on.
    private(set) var remindersBlocked = false

    /// Copies of the data into a user-picked Files folder (e.g. iCloud Drive).
    let autoBackup: AutoBackup

    /// CloudKit sync engine, attached by the app entry point (`nil` in tests/previews).
    var cloudEngine: CloudSyncEngine?

    /// Transient confirmation shown at the top of the app.
    var toast: Toast?

    private let persistence: Persistence?
    private let defaults: UserDefaults
    private let remindersEnabledInSystem: Bool

    private enum Keys {
        static let remindersEnabled = "reminders.enabled"
        static let reminderHour = "reminders.hour"
        static let reminderMinute = "reminders.minute"
        /// Key inside `BackupFile.settings`.
        static let backupBudget = "budgetRub"
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
                payments = (file.payments ?? []).compactMap(BackupMapper.payment)
                monthlyBudgetRub = Double(file.settings[Keys.backupBudget] ?? "")
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
        backfillPaymentsIfNeeded()
        advanceBillingDates()
    }

    /// One-time migration when payment history arrives with an existing data set:
    /// infer records for every past charge so analytics are complete from day one.
    private func backfillPaymentsIfNeeded(now: Date = .now) {
        guard payments.isEmpty else { return }
        let today = Calendar.current.startOfDay(for: now)
        for sub in chargeable {
            for date in billingDates(of: sub, from: sub.startDate, to: today, now: now) {
                payments.append(PaymentRecord(subscriptionId: sub.id, date: date, amount: sub.amount,
                                              currency: sub.currency, amountRub: toRub(sub.amount, sub.currency)))
            }
        }
        if !payments.isEmpty { save() }
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
    /// Trials don't generate charge history yet, so analytics skips them
    /// (they still show their scheduled first charge on the Home screen).
    var chargeable: [Subscription] { subscriptions.filter { $0.status != .cancelled && $0.status != .trial } }

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
        guard let i = subscriptions.firstIndex(where: { $0.id == id }),
              subscriptions[i].status == .active || subscriptions[i].status == .paused else { return }
        subscriptions[i].status = subscriptions[i].status == .paused ? .active : .paused
        advanceBillingDates()
        didChange()
    }

    /// Finishes the trial early or on time (Detail → «Завершить триал»):
    /// the subscription becomes active and paid history starts at its first charge.
    func endTrial(_ id: String) {
        guard let i = subscriptions.firstIndex(where: { $0.id == id }), subscriptions[i].status == .trial else { return }
        subscriptions[i].status = .active
        subscriptions[i].trialEndDate = nil
        subscriptions[i].startDate = subscriptions[i].nextBillingDate
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
        cloudEngine?.recordTombstone(categoryId: id)
        didChange()
    }

    // MARK: - Payments

    /// Marks a charge as paid (or corrects an existing record) with today's price.
    func markPaid(_ sub: Subscription, on date: Date) {
        recordPayment(for: sub, on: date, kind: .charge, source: .manual)
        didChange()
    }

    /// Marks a charge as skipped — it stays in history but stops counting anywhere.
    func skip(_ sub: Subscription, on date: Date) {
        recordPayment(for: sub, on: date, kind: .skip, source: .manual)
        didChange()
    }

    func deletePayment(_ id: String) {
        payments.removeAll { $0.id == id }
        didChange()
    }

    private func recordPayment(for sub: Subscription, on date: Date, kind: PaymentRecord.Kind, source: PaymentRecord.Source) {
        // A manual edit wins over anything; an auto record never overwrites one.
        let record = PaymentRecord(subscriptionId: sub.id, date: date, amount: sub.amount,
                                   currency: sub.currency, amountRub: toRub(sub.amount, sub.currency),
                                   kind: kind, source: source)
        if let i = payments.firstIndex(where: { $0.id == record.id }) {
            if source == .manual || payments[i].source == .auto { payments[i] = record }
        } else {
            payments.append(record)
        }
    }

    /// RUB a charge actually cost, from the record; nil when it wasn't recorded yet.
    private func recordedRub(for sub: Subscription, on date: Date) -> Double? {
        let id = PaymentRecord.makeId(subscriptionId: sub.id, date: date)
        guard let r = payments.first(where: { $0.id == id }) else { return nil }
        return r.kind == .skip ? 0 : r.amountRub
    }

    /// The last charge that actually happened, if any (recorded amounts only).
    func lastCharge(for sub: Subscription) -> PaymentRecord? {
        payments
            .filter { $0.subscriptionId == sub.id && $0.kind == .charge }
            .max { $0.date < $1.date }
    }

    // MARK: - Statement import

    /// Creates a subscription from a bank-statement detection and backfills its
    /// history with the occurrences already paid (source: .bank).
    @discardableResult
    func createFromCandidate(_ candidate: StatementCandidate, now: Date = .now) -> Subscription {
        let (period, customDays) = candidate.billingPeriod
        var sub = Subscription(
            id: UUID().uuidString, name: candidate.name,
            amount: candidate.medianAmount, currency: .rub,
            billingPeriod: period, customPeriodDays: customDays,
            nextBillingDate: candidate.nextCharge(now: now),
            startDate: candidate.occurrences.first!.date
        )
        sub.createdAt = now
        recordStatementHistory(candidate, for: sub, now: now)
        upsert(sub)
        show("Подписка «\(sub.name)» создана из выписки")
        return sub
    }

    /// Links detected occurrences to an existing subscription as paid history.
    func attachStatement(_ candidate: StatementCandidate, to id: String, now: Date = .now) {
        guard var sub = subscription(id: id) else { return }
        recordStatementHistory(candidate, for: sub, now: now)
        // A bank statement knows charges more recent than our own grid.
        if candidate.lastDate > sub.nextBillingDate {
            sub.nextBillingDate = candidate.nextCharge(now: now)
            upsert(sub)
        }
        didChange()
        show("История «\(sub.name)» пополнена из выписки")
    }

    private func recordStatementHistory(_ candidate: StatementCandidate, for sub: Subscription, now: Date) {
        let today = Calendar.current.startOfDay(for: now)
        for occurrence in candidate.occurrences where Calendar.current.startOfDay(for: occurrence.date) <= today {
            let record = PaymentRecord(
                subscriptionId: sub.id, date: occurrence.date,
                amount: occurrence.amount, currency: .rub,
                amountRub: occurrence.amount, kind: .charge, source: .bank
            )
            if let i = payments.firstIndex(where: { $0.id == record.id }) {
                // A manual edit wins over the bank too (same rule as recordPayment / Android).
                if payments[i].source == .auto { payments[i] = record }
            } else {
                payments.append(record)
            }
        }
    }

    /// Moves past `nextBillingDate`s of active subscriptions forward (Android: `advanceBillingDates`).
    /// Trials whose end has passed become active here. Returns true if anything changed.
    @discardableResult
    func advanceBillingDates(now: Date = .now) -> Bool {
        let today = Calendar.current.startOfDay(for: now)
        var changed = false
        // A trial that ended while we were away becomes active. Paid history starts
        // at the first charge (the old nextBillingDate), so the trial days never
        // produce phantom charges in analytics.
        for i in subscriptions.indices where subscriptions[i].status == .trial {
            guard let end = subscriptions[i].trialEndDate, Calendar.current.startOfDay(for: end) < today else { continue }
            subscriptions[i].status = .active
            subscriptions[i].trialEndDate = nil
            subscriptions[i].startDate = subscriptions[i].nextBillingDate
            changed = true
        }
        for i in subscriptions.indices where subscriptions[i].status == .active {
            guard Calendar.current.startOfDay(for: subscriptions[i].nextBillingDate) < today else { continue }
            // Charges that slipped by while the app wasn't looking are recorded now,
            // with the amounts as they were on the grid (not today's edited price).
            for date in billingDates(of: subscriptions[i], from: subscriptions[i].nextBillingDate, to: today, now: now) {
                recordPayment(for: subscriptions[i], on: date, kind: .charge, source: .auto)
            }
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
        cloudEngine?.schedulePush(self)
    }

    private func save() {
        WidgetSnapshot.store(widgetSnapshot())
        guard let persistence else { return }
        do {
            try persistence.save(backup())
        } catch {
            show("Не удалось сохранить данные", symbol: "exclamationmark.triangle.fill", tint: .orange)
        }
    }

    /// What the home-screen widgets show. Written into the App Group container
    /// on every save; safe no-op when the container is unavailable (tests).
    func widgetSnapshot(now: Date = .now) -> WidgetSnapshot {
        let style = defaults.string(forKey: "backgroundStyle").flatMap(BackgroundStyle.init) ?? .lavender
        let upcoming = futurePayments(days: 45, now: now).prefix(3).map { event in
            WidgetSnapshot.Charge(
                name: event.subscription.name,
                domain: event.subscription.domain,
                date: event.date,
                amount: event.subscription.amount,
                currency: event.subscription.currency.rawValue
            )
        }
        let progress = monthProgress(now: now)
        return WidgetSnapshot(
            upcoming: Array(upcoming),
            monthlyTotalRub: monthlyTotalRub,
            paidRub: progress.paid,
            remainingRub: progress.remaining,
            budgetRub: monthlyBudgetRub,
            accentHexLight: style.accentHex(dark: false),
            accentHexDark: style.accentHex(dark: true),
            generatedAt: now
        )
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
        var file = BackupMapper.file(subscriptions: subscriptions, categories: categories, payments: payments, now: now)
        file.subscriptions += unparsed
        if let monthlyBudgetRub { file.settings[Keys.backupBudget] = String(monthlyBudgetRub) }
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
        let pays = (file.payments ?? []).compactMap(BackupMapper.payment)
        switch mode {
        case .replace:
            categories = cats
            subscriptions = subs
            payments = pays
            unparsed = []
        case .merge:
            for c in cats {
                if let i = categories.firstIndex(where: { $0.id == c.id }) { categories[i] = c } else { categories.append(c) }
            }
            for s in subs {
                if let i = subscriptions.firstIndex(where: { $0.id == s.id }) { subscriptions[i] = s } else { subscriptions.append(s) }
            }
            for p in pays {
                if let i = payments.firstIndex(where: { $0.id == p.id }) { payments[i] = p } else { payments.append(p) }
            }
        }
        // Drop dangling category links (a category may be missing from the file).
        let known = Set(categories.map(\.id))
        for i in subscriptions.indices where subscriptions[i].categoryId.map({ !known.contains($0) }) ?? false {
            subscriptions[i].categoryId = nil
        }
        if mode == .replace { loadError = nil }
        if let raw = file.settings[Keys.backupBudget] { monthlyBudgetRub = Double(raw) }
        advanceBillingDates()
        didChange()
        return ImportResult(subscriptions: subs.count, categories: cats.count, skipped: file.subscriptions.count - subs.count)
    }

    /// Wipes subscriptions and restores the default categories (Settings → «Удалить все данные»).
    func resetAll() {
        subscriptions = []
        categories = SeedData.categories
        payments = []
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

    // MARK: - Cloud merge (called by CloudSyncEngine's pull; no side effects)

    func upsertSilently(_ sub: Subscription) {
        if let i = subscriptions.firstIndex(where: { $0.id == sub.id }) {
            subscriptions[i] = sub
        } else {
            subscriptions.append(sub)
        }
    }

    func upsertCategorySilently(_ cat: Category) {
        if let i = categories.firstIndex(where: { $0.id == cat.id }) {
            categories[i] = cat
        } else {
            categories.append(cat)
        }
    }

    func upsertPaymentSilently(_ record: PaymentRecord) {
        if let i = payments.firstIndex(where: { $0.id == record.id }) {
            payments[i] = record
        } else {
            payments.append(record)
        }
    }

    /// One save + reminder pass after a cloud pull merged silently.
    func finishCloudMerge() {
        advanceBillingDates()
        didChange()
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
            for date in billingDates(of: sub, from: month.start, to: month.end, now: now) {
                let rub = recordedRub(for: sub, on: date) ?? toRub(sub.amount, sub.currency)
                if date < today { paid += rub } else { remaining += rub }
            }
        }
        // A trial's first charge is already scheduled — count it as remaining
        // (from today, so trial days never leak in as paid history).
        for sub in subscriptions where sub.status == .trial {
            for _ in billingDates(of: sub, from: today, to: month.end, now: now) {
                remaining += toRub(sub.amount, sub.currency)
            }
        }
        return (paid, remaining)
    }

    /// Past charges: recorded payments first (real amounts, survives cancellation),
    /// then schedule inference for anything older than recording itself.
    func pastPayments(days: Int = 90, now: Date = .now) -> [PaymentEvent] {
        let today = Calendar.current.startOfDay(for: now)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: today)!
        var events: [PaymentEvent] = []
        var covered = Set<String>()
        for r in payments where r.kind == .charge && r.date >= start && r.date < today {
            guard let sub = subscription(id: r.subscriptionId) else { continue }
            events.append(PaymentEvent(subscription: sub, date: r.date, record: r))
            covered.insert(r.id)
        }
        events += active.flatMap { sub in
            billingDates(of: sub, from: start, to: today, now: now)
                .filter { !covered.contains(PaymentRecord.makeId(subscriptionId: sub.id, date: $0)) }
                .map { PaymentEvent(subscription: sub, date: $0) }
        }
        return events.sorted { $0.date > $1.date }
    }

    func futurePayments(days: Int = 90, now: Date = .now) -> [PaymentEvent] {
        let today = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: days, to: today)!
        return (active + subscriptions.filter { $0.status == .trial })
            .flatMap { sub in billingDates(of: sub, from: today, to: end, now: now).map { PaymentEvent(subscription: sub, date: $0) } }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Analytics

    func monthlyTotals(past: Int = 6, future: Int = 3, now: Date = .now) -> [PeriodTotal] {
        let cal = Calendar.current
        let current = cal.dateInterval(of: .month, for: now)!.start
        let starts = (-past...future).map { cal.date(byAdding: .month, value: $0, to: current)! }
        return totals(buckets: starts, end: cal.date(byAdding: .month, value: 1, to: starts.last!)!, current: current, now: now) {
            cal.dateInterval(of: .month, for: $0)!.start
        }
    }

    func weeklyTotals(past: Int = 6, future: Int = 4, now: Date = .now) -> [PeriodTotal] {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let current = cal.dateInterval(of: .weekOfYear, for: now)!.start
        let starts = (-past...future).map { cal.date(byAdding: .weekOfYear, value: $0, to: current)! }
        return totals(buckets: starts, end: cal.date(byAdding: .weekOfYear, value: 1, to: starts.last!)!, current: current, now: now) {
            cal.dateInterval(of: .weekOfYear, for: $0)!.start
        }
    }

    /// Per-category charges inside `interval` (RUB), split into already paid (before today)
    /// and total. Uses the same subscriptions as the bar chart, so totals add up to the bar.
    func categoryShares(in interval: DateInterval, now: Date = .now) -> [CategoryShare] {
        let today = Calendar.current.startOfDay(for: now)
        var paid: [String?: Double] = [:], total: [String?: Double] = [:]
        for sub in chargeable {
            for date in billingDates(of: sub, from: interval.start, to: interval.end, now: now) {
                let rub = recordedRub(for: sub, on: date) ?? toRub(sub.amount, sub.currency)
                total[sub.categoryId, default: 0] += rub
                if date < today { paid[sub.categoryId, default: 0] += rub }
            }
        }
        return total
            .map { CategoryShare(category: category(for: $0.key), paid: paid[$0.key] ?? 0, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Insights

    /// Same-span comparison: charges since this month's start vs the same span
    /// of the previous month (fair while the month is still running).
    func monthOverMonth(now: Date = .now) -> MonthDelta? {
        let cal = Calendar.current
        let month = cal.dateInterval(of: .month, for: now)!
        let prevMonth = cal.dateInterval(of: .month, for: cal.date(byAdding: .day, value: -1, to: month.start)!)!
        let today = cal.startOfDay(for: now)
        let span = today.timeIntervalSince(month.start)
        let current = chargesTotal(from: month.start, to: today, now: now)
        let previous = chargesTotal(from: prevMonth.start, to: prevMonth.start.addingTimeInterval(span), now: now)
        // Nothing charged in either span — nothing to compare yet.
        guard current > 0 || previous > 0 else { return nil }
        return MonthDelta(current: current, previous: previous)
    }

    private func chargesTotal(from: Date, to: Date, now: Date) -> Double {
        chargeable.reduce(0) { sum, sub in
            sum + billingDates(of: sub, from: from, to: to, now: now)
                .reduce(0) { $0 + (recordedRub(for: sub, on: $1) ?? toRub(sub.amount, sub.currency)) }
        }
    }

    /// Steady-state year cost: active spending projected over 12 months.
    func annualForecast() -> (totalRub: Double, top: [AnnualCost]) {
        let items = active
            .map { AnnualCost(subscription: $0, perYearRub: toRub($0.amount, $0.currency) * $0.billingPeriod.monthlyEquivalent * 12) }
            .sorted { $0.perYearRub > $1.perYearRub }
        return (items.reduce(0) { $0 + $1.perYearRub }, Array(items.prefix(3)))
    }

    /// Likely duplicates: same service domain, or same category with one name
    /// containing the other ("Netflix" vs "Netflix Premium"). A hint, not a verdict.
    func duplicateGroups() -> [[Subscription]] {
        let pool = notCancelled
        var groups: [[Subscription]] = []
        var byDomain: [String: [Subscription]] = [:]
        for sub in pool {
            if let domain = sub.domain?.lowercased(), !domain.isEmpty { byDomain[domain, default: []].append(sub) }
        }
        groups += byDomain.values.filter { $0.count > 1 }
        var used = Set(groups.flatMap { $0.map(\.id) })

        for peers in Dictionary(grouping: pool, by: \.categoryId).values {
            for seed in peers {
                guard !used.contains(seed.id) else { continue }
                let matches = peers.filter { other in
                    guard other.id != seed.id, !used.contains(other.id) else { return false }
                    let a = Self.normalized(seed.name), b = Self.normalized(other.name)
                    guard min(a.count, b.count) >= 3 else { return false }
                    return a.contains(b) || b.contains(a)
                }
                guard !matches.isEmpty else { continue }
                let group = [seed] + matches
                groups.append(group)
                used.formUnion(group.map(\.id))
            }
        }
        return groups
    }

    private static func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func totals(buckets: [Date], end: Date, current: Date, now: Date, bucketOf: (Date) -> Date) -> [PeriodTotal] {
        var sums = Dictionary(uniqueKeysWithValues: buckets.map { ($0, 0.0) })
        for sub in chargeable {
            for date in billingDates(of: sub, from: buckets.first!, to: end, now: now) {
                sums[bucketOf(date), default: 0] += recordedRub(for: sub, on: date) ?? toRub(sub.amount, sub.currency)
            }
        }
        return buckets.map { PeriodTotal(start: $0, amount: sums[$0] ?? 0, isForecast: $0 >= current) }
    }

    func billingDates(of sub: Subscription, from: Date, to: Date, now: Date = .now) -> [Date] {
        Schedule.dates(of: sub, from: from, to: to, now: now)
    }
}
