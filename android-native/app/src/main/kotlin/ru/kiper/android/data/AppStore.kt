package ru.kiper.android.data

import android.content.Context
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth

/**
 * App state: subscriptions, categories, rates and settings. Persists to a local
 * JSON file (same format as backups), keeps reminders in sync and refreshes
 * CBR rates. Mirrors `AppStore.swift`; calculations match
 * `home_providers.dart` / `analytics_provider.dart`.
 *
 * Uses Compose snapshot state so Compose screens recompose on every change.
 */
class AppStore(
    private val persistence: Persistence?,
    private val prefs: android.content.SharedPreferences?,
    val filesDir: java.io.File? = null,
    seedDemoData: Boolean = true,
    private val remindersEnabledInSystem: Boolean = true,
) {
    constructor(context: Context, seedDemoData: Boolean = true) : this(
        persistence = Persistence.live(context.filesDir),
        prefs = context.getSharedPreferences("kiper", Context.MODE_PRIVATE),
        filesDir = context.filesDir,
        seedDemoData = seedDemoData,
    )

    val subscriptions = mutableStateListOf<Subscription>()
    val categories = mutableStateListOf<Category>()
    val payments = mutableStateListOf<PaymentRecord>()
    val rateSnapshot = mutableStateOf(RateSnapshot.fallback)
    val isRefreshingRates = mutableStateOf(false)
    /** Set when the stored file could not be read; shown once in Settings. */
    val loadError = mutableStateOf<String?>(null)
    /** Stored rows that couldn't be parsed (bad dates etc.). Written back untouched. */
    private val unparsed = mutableListOf<SubscriptionDTO>()

    /** Reminders scheduling delegate (AlarmManager on device, no-op in tests). */
    var reminderScheduler: ReminderScheduler = object : ReminderScheduler {}

    var autoBackup: AutoBackup = AutoBackup.NONE

    /** Transient confirmation shown at the top of the app. */
    val toast = mutableStateOf<Toast?>(null)

    /** Fired after every save so the app can redraw the home-screen widgets. */
    var onWidgetsChanged: (() -> Unit)? = null

    data class Toast(val text: String, val isError: Boolean = false)

    private object Keys {
        const val REMINDERS_ENABLED = "reminders.enabled"
        const val REMINDER_HOUR = "reminders.hour"
        const val REMINDER_MINUTE = "reminders.minute"
        const val BUDGET_RUB = "budgetRub"
        const val RATES_SNAPSHOT = "rates.snapshot"
        const val THEME_MODE = "themeMode"
        const val BACKGROUND_STYLE = "backgroundStyle"
    }

    var remindersEnabled: Boolean = true
        set(value) {
            val was = field
            field = value
            prefs?.edit()?.putBoolean(Keys.REMINDERS_ENABLED, value)?.apply()
            if (value && !was) enableReminders() else scheduleReminders()
        }

    var reminderHour: Int = 10
        set(value) {
            field = value
            prefs?.edit()?.putInt(Keys.REMINDER_HOUR, value)?.apply()
            scheduleReminders()
        }

    var reminderMinute: Int = 0
        set(value) {
            field = value
            prefs?.edit()?.putInt(Keys.REMINDER_MINUTE, value)?.apply()
            scheduleReminders()
        }

    /** Monthly spending cap for all subscriptions (RUB). Lives in the backup file's
     * `settings` so it travels with exports; the home card turns orange past it. */
    var monthlyBudgetRub: Double? = null
        set(value) {
            field = value
            save()
        }

    /** Notifications denied in system Settings while reminders are on. */
    val remindersBlocked = mutableStateOf(false)

    /** Reactive theme/palette state — changing these recomposes the UI instantly. */
    val themeMode = mutableStateOf("system")
    val backgroundStyle = mutableStateOf("lavender")

    fun setThemeMode(mode: String) {
        themeMode.value = mode
        prefs?.edit()?.putString(Keys.THEME_MODE, mode)?.apply()
    }

    fun setBackgroundStyle(style: String) {
        backgroundStyle.value = style
        prefs?.edit()?.putString(Keys.BACKGROUND_STYLE, style)?.apply()
        updateWidgetSnapshot()
    }

    init {
        if (prefs != null) {
            remindersEnabled = prefs.getBoolean(Keys.REMINDERS_ENABLED, true)
            reminderHour = prefs.getInt(Keys.REMINDER_HOUR, 10)
            reminderMinute = prefs.getInt(Keys.REMINDER_MINUTE, 0)
            themeMode.value = prefs.getString(Keys.THEME_MODE, "system") ?: "system"
            backgroundStyle.value = prefs.getString(Keys.BACKGROUND_STYLE, "lavender") ?: "lavender"
            rateSnapshot.value = ExchangeRates.cached(prefs.getString(Keys.RATES_SNAPSHOT, null))
        }
        try {
            val file = persistence?.load()
            if (file != null) {
                file.categories.map(BackupMapper::category).forEach { categories.add(it) }
                for (dto in file.subscriptions) {
                    val sub = BackupMapper.subscription(dto)
                    if (sub != null) subscriptions.add(sub) else unparsed.add(dto)
                }
                (file.payments ?: emptyList()).mapNotNull(BackupMapper::payment).forEach { payments.add(it) }
                monthlyBudgetRub = file.settings[Keys.BUDGET_RUB]?.toDoubleOrNull()
            } else {
                // First launch: seed categories (always) and demo subscriptions.
                SeedData.categories.forEach { categories.add(it) }
                if (seedDemoData) SeedData.subscriptions().forEach { subscriptions.add(it) }
                save()
            }
        } catch (e: Exception) {
            // Keep the unreadable file as a side copy, then work normally (so edits
            // made from now on are saved, and nothing old is lost).
            val reason = e.message ?: e.toString()
            val copy = try {
                persistence?.quarantine()
            } catch (_: Exception) {
                null
            }
            loadError.value = copy?.let { "$reason Исходный файл сохранён как «${it.name}»." } ?: reason
            SeedData.categories.forEach { categories.add(it) }
        }
        backfillPaymentsIfNeeded()
        advanceBillingDates()
    }

    /** One-time migration when payment history arrives with an existing data set:
     * infer records for every past charge so analytics are complete from day one. */
    private fun backfillPaymentsIfNeeded(now: LocalDate = LocalDate.now()) {
        if (payments.isNotEmpty()) return
        val today = now
        for (sub in chargeable) {
            for (date in billingDates(sub, sub.startDate, today, now)) {
                payments.add(
                    PaymentRecord(
                        subscriptionId = sub.id, date = date, amount = sub.amount,
                        currency = sub.currency, amountRub = toRub(sub.amount, sub.currency),
                    )
                )
            }
        }
        if (payments.isNotEmpty()) save()
    }

    fun show(text: String, isError: Boolean = false) {
        toast.value = AppStore.Toast(text, isError)
    }

    // MARK: - Lookup

    fun category(id: String?): Category? = categories.firstOrNull { it.id == id }

    fun subscription(id: String): Subscription? = subscriptions.firstOrNull { it.id == id }

    fun toRub(amount: Double, currency: Currency): Double = amount * rateSnapshot.value.rate(currency)

    val active: List<Subscription> get() = subscriptions.filter { it.status == SubscriptionStatus.ACTIVE }
    val notCancelled: List<Subscription> get() = subscriptions.filter { it.status != SubscriptionStatus.CANCELLED }
    /** Trials don't generate charge history yet, so analytics skips them. */
    val chargeable: List<Subscription>
        get() = subscriptions.filter { it.status != SubscriptionStatus.CANCELLED && it.status != SubscriptionStatus.TRIAL }

    // MARK: - Mutations

    fun upsert(sub: Subscription) {
        val i = subscriptions.indexOfFirst { it.id == sub.id }
        if (i >= 0) subscriptions[i] = sub else subscriptions.add(sub)
        advanceBillingDates()
        didChange()
    }

    fun togglePause(id: String) {
        val i = subscriptions.indexOfFirst { it.id == id }
        if (i < 0) return
        val status = subscriptions[i].status
        if (status != SubscriptionStatus.ACTIVE && status != SubscriptionStatus.PAUSED) return
        subscriptions[i].status = if (status == SubscriptionStatus.PAUSED) SubscriptionStatus.ACTIVE else SubscriptionStatus.PAUSED
        advanceBillingDates()
        didChange()
    }

    /** Finishes the trial early or on time (Detail → «Завершить триал»). */
    fun endTrial(id: String) {
        val i = subscriptions.indexOfFirst { it.id == id }
        if (i < 0 || subscriptions[i].status != SubscriptionStatus.TRIAL) return
        subscriptions[i].status = SubscriptionStatus.ACTIVE
        subscriptions[i].trialEndDate = null
        subscriptions[i].startDate = subscriptions[i].nextBillingDate
        advanceBillingDates()
        didChange()
    }

    /** Soft delete: row stays for analytics. */
    fun cancel(id: String) {
        val i = subscriptions.indexOfFirst { it.id == id }
        if (i < 0) return
        subscriptions[i].status = SubscriptionStatus.CANCELLED
        didChange()
    }

    fun upsertCategory(cat: Category) {
        val i = categories.indexOfFirst { it.id == cat.id }
        if (i >= 0) categories[i] = cat else categories.add(cat)
        didChange()
    }

    /** Same rule as iOS: detach subscriptions first, then drop the category. */
    fun deleteCategory(id: String) {
        for (i in subscriptions.indices) {
            if (subscriptions[i].categoryId == id) subscriptions[i].categoryId = null
        }
        categories.removeAll { it.id == id }
        didChange()
    }

    // MARK: - Payments

    /** Marks a charge as paid (or corrects an existing record) with today's price. */
    fun markPaid(sub: Subscription, on: LocalDate) {
        recordPayment(sub, on, PaymentRecord.Kind.CHARGE, PaymentRecord.Source.MANUAL)
        didChange()
    }

    /** Marks a charge as skipped — it stays in history but stops counting anywhere. */
    fun skip(sub: Subscription, on: LocalDate) {
        recordPayment(sub, on, PaymentRecord.Kind.SKIP, PaymentRecord.Source.MANUAL)
        didChange()
    }

    fun deletePayment(id: String) {
        payments.removeAll { it.id == id }
        didChange()
    }

    private fun recordPayment(sub: Subscription, date: LocalDate, kind: PaymentRecord.Kind, source: PaymentRecord.Source) {
        // A manual edit wins over anything; an auto record never overwrites one.
        val record = PaymentRecord(
            subscriptionId = sub.id, date = date, amount = sub.amount,
            currency = sub.currency, amountRub = toRub(sub.amount, sub.currency),
            kind = kind, source = source,
        )
        val i = payments.indexOfFirst { it.id == record.id }
        if (i >= 0) {
            if (source == PaymentRecord.Source.MANUAL || payments[i].source == PaymentRecord.Source.AUTO) payments[i] = record
        } else {
            payments.add(record)
        }
    }

    /** RUB a charge actually cost, from the record; null when it wasn't recorded yet. */
    private fun recordedRub(sub: Subscription, date: LocalDate): Double? {
        val id = PaymentRecord.makeId(sub.id, date)
        val r = payments.firstOrNull { it.id == id } ?: return null
        return if (r.kind == PaymentRecord.Kind.SKIP) 0.0 else r.amountRub
    }

    /** The last charge that actually happened, if any (recorded amounts only). */
    fun lastCharge(sub: Subscription): PaymentRecord? =
        payments.filter { it.subscriptionId == sub.id && it.kind == PaymentRecord.Kind.CHARGE }
            .maxByOrNull { it.date }

    // MARK: - Statement import

    /** Creates a subscription from a bank-statement detection and backfills its
     * history with the occurrences already paid (source: .bank). */
    fun createFromCandidate(candidate: StatementCandidate, now: LocalDate = LocalDate.now()): Subscription {
        val (period, customDays) = candidate.billingPeriod
        val sub = Subscription(
            id = newId(),
            name = candidate.name,
            amount = candidate.medianAmount,
            currency = Currency.RUB,
            billingPeriod = period,
            customPeriodDays = customDays,
            nextBillingDate = candidate.nextCharge(now),
            startDate = candidate.occurrences.first().date,
        )
        sub.createdAt = now
        recordStatementHistory(candidate, sub, now)
        upsert(sub)
        show("Подписка «${sub.name}» создана из выписки")
        return sub
    }

    /** Links detected occurrences to an existing subscription as paid history. */
    fun attachStatement(candidate: StatementCandidate, id: String, now: LocalDate = LocalDate.now()) {
        val sub = subscription(id) ?: return
        recordStatementHistory(candidate, sub, now)
        // A bank statement knows charges more recent than our own grid.
        if (candidate.lastDate > sub.nextBillingDate) {
            sub.nextBillingDate = candidate.nextCharge(now)
            upsert(sub)
        }
        didChange()
        show("История «${sub.name}» пополнена из выписки")
    }

    private fun recordStatementHistory(candidate: StatementCandidate, sub: Subscription, now: LocalDate) {
        val today = now
        for (occurrence in candidate.occurrences) {
            if (occurrence.date > today) continue
            val record = PaymentRecord(
                subscriptionId = sub.id, date = occurrence.date,
                amount = occurrence.amount, currency = Currency.RUB,
                amountRub = occurrence.amount, kind = PaymentRecord.Kind.CHARGE,
                source = PaymentRecord.Source.BANK,
            )
            val i = payments.indexOfFirst { it.id == record.id }
            // A manual edit wins over the bank too (same rule as recordPayment / iOS).
            if (i >= 0) {
                if (payments[i].source == PaymentRecord.Source.AUTO) payments[i] = record
            } else {
                payments.add(record)
            }
        }
    }

    /** Moves past `nextBillingDate`s of active subscriptions forward. Trials whose
     * end has passed become active here. Returns true if anything changed. */
    fun advanceBillingDates(now: LocalDate = LocalDate.now()): Boolean {
        val today = now
        var changed = false
        // A trial that ended while we were away becomes active. Paid history starts
        // at the first charge (the old nextBillingDate).
        for (i in subscriptions.indices) {
            if (subscriptions[i].status != SubscriptionStatus.TRIAL) continue
            val end = subscriptions[i].trialEndDate ?: continue
            if (end >= today) continue
            subscriptions[i].status = SubscriptionStatus.ACTIVE
            subscriptions[i].trialEndDate = null
            subscriptions[i].startDate = subscriptions[i].nextBillingDate
            changed = true
        }
        for (i in subscriptions.indices) {
            if (subscriptions[i].status != SubscriptionStatus.ACTIVE) continue
            if (subscriptions[i].nextBillingDate >= today) continue
            // Charges that slipped by while the app wasn't looking are recorded now,
            // with the amounts as they were on the grid (not today's edited price).
            val sub = subscriptions[i]
            for (date in billingDates(sub, sub.nextBillingDate, today, now)) {
                recordPayment(sub, date, PaymentRecord.Kind.CHARGE, PaymentRecord.Source.AUTO)
            }
            val next = Schedule.firstCharge(subscriptions[i], today)
            if (next != subscriptions[i].nextBillingDate) {
                subscriptions[i].nextBillingDate = next
                changed = true
            }
        }
        if (changed) save()
        return changed
    }

    /** Called when the app becomes active: roll dates, refresh stale rates, resync reminders. */
    suspend fun refreshOnForeground() {
        if (advanceBillingDates()) scheduleReminders()
        // At least one copy a day even without edits (keeps the dated history going).
        val last = autoBackup.lastBackup
        val today = LocalDate.now()
        if (autoBackup.isEnabled && (last == null || last != today)) {
            autoBackup.run(backup())
        }
        if (java.time.Duration.between(rateSnapshot.value.fetchedAtTime, java.time.Instant.now()).toMillis() > ExchangeRates.MAX_AGE_MS) {
            refreshRates(silent = true)
        }
    }

    private fun didChange() {
        save()
        scheduleReminders()
        autoBackup.schedule { backup() }
    }

    private fun save() {
        updateWidgetSnapshot()
        persistence ?: return
        try {
            persistence.save(backup())
        } catch (e: Exception) {
            show("Не удалось сохранить данные", isError = true)
        }
    }

    private fun updateWidgetSnapshot() {
        WidgetSnapshot.store(filesDir, widgetSnapshot())
        onWidgetsChanged?.invoke()
    }

    /** What the home-screen widgets show. */
    fun widgetSnapshot(now: LocalDate = LocalDate.now()): WidgetSnapshot {
        val style = try {
            ru.kiper.android.ui.theme.BackgroundStyle.of(backgroundStyle.value)
        } catch (_: Exception) {
            ru.kiper.android.ui.theme.BackgroundStyle.LAVENDER
        }
        val upcoming = futurePayments(days = 45, now = now).take(3).map { event ->
            WidgetSnapshot.Charge(
                name = event.subscription.name,
                domain = event.subscription.domain,
                date = WidgetSnapshot.isoOf(event.date),
                amount = event.subscription.amount,
                currency = event.subscription.currency.code,
            )
        }
        val progress = monthProgress(now)
        return WidgetSnapshot(
            upcoming = upcoming,
            monthlyTotalRub = monthlyTotalRub,
            paidRub = progress.first,
            remainingRub = progress.second,
            budgetRub = monthlyBudgetRub,
            accentHexLight = style.accentHex(dark = false),
            accentHexDark = style.accentHex(dark = true),
            generatedAt = WidgetSnapshot.nowIso(),
        )
    }

    // MARK: - Rates

    fun refreshRates(silent: Boolean = false) {
        if (isRefreshingRates.value || persistence == null) return
        isRefreshingRates.value = true
        try {
            val snapshot = ExchangeRates.fetch()
            rateSnapshot.value = snapshot
            prefs?.edit()?.putString(Keys.RATES_SNAPSHOT, ExchangeRates.store(snapshot))?.apply()
            if (!silent) show("Курсы обновлены")
        } catch (e: Exception) {
            if (!silent) show("Нет связи с ЦБ — используются сохранённые курсы", isError = true)
        } finally {
            isRefreshingRates.value = false
        }
    }

    // MARK: - Reminders

    fun scheduleReminders() {
        if (!remindersEnabledInSystem) return
        val plans = if (remindersEnabled) {
            Reminders.plan(subscriptions = subscriptions.toList(), hour = reminderHour, minute = reminderMinute)
        } else emptyList()
        remindersBlocked.value = remindersEnabled && !reminderScheduler.notificationsAllowed()
        reminderScheduler.apply(plans)
    }

    /** Asks for permission (first time) and schedules everything. */
    fun enableReminders() {
        reminderScheduler.requestPermission { granted ->
            remindersBlocked.value = !granted
            scheduleReminders()
        }
    }

    // MARK: - Backup

    fun backup(now: LocalDate = LocalDate.now()): BackupFile {
        val file = BackupMapper.file(
            subscriptions = subscriptions.toList(),
            categories = categories.toList(),
            payments = payments.toList(),
            now = now,
        )
        val withUnparsed = file.copy(subscriptions = file.subscriptions + unparsed)
        return if (monthlyBudgetRub != null) {
            withUnparsed.copy(settings = withUnparsed.settings + (Keys.BUDGET_RUB to monthlyBudgetRub.toString()))
        } else withUnparsed
    }

    enum class ImportMode { REPLACE, MERGE }

    data class ImportResult(val subscriptions: Int, val categories: Int, val skipped: Int = 0)

    /** Imports a JSON backup (Android or iOS). REPLACE wipes current data first;
     * MERGE upserts by id, like on iOS. */
    fun importBackup(file: BackupFile, mode: ImportMode): ImportResult {
        val cats = file.categories.map(BackupMapper::category)
        val subs = file.subscriptions.mapNotNull(BackupMapper::subscription)
        val pays = (file.payments ?: emptyList()).mapNotNull(BackupMapper::payment)
        when (mode) {
            ImportMode.REPLACE -> {
                categories.clear(); categories.addAll(cats)
                subscriptions.clear(); subscriptions.addAll(subs)
                payments.clear(); payments.addAll(pays)
                unparsed.clear()
            }
            ImportMode.MERGE -> {
                for (c in cats) upsertIn(categories, c) { it.id == c.id }
                for (s in subs) upsertIn(subscriptions, s) { it.id == s.id }
                for (p in pays) upsertIn(payments, p) { it.id == p.id }
            }
        }
        // Drop dangling category links (a category may be missing from the file).
        val known = categories.map { it.id }.toSet()
        for (i in subscriptions.indices) {
            val catId = subscriptions[i].categoryId
            if (catId != null && catId !in known) subscriptions[i].categoryId = null
        }
        if (mode == ImportMode.REPLACE) loadError.value = null
        file.settings[Keys.BUDGET_RUB]?.toDoubleOrNull()?.let { monthlyBudgetRub = it }
        advanceBillingDates()
        didChange()
        return ImportResult(
            subscriptions = subs.size,
            categories = cats.size,
            skipped = file.subscriptions.size - subs.size,
        )
    }

    private fun <T> upsertIn(list: MutableList<T>, item: T, sameId: (T) -> Boolean) {
        val i = list.indexOfFirst(sameId)
        if (i >= 0) list[i] = item else list.add(item)
    }

    /** Wipes subscriptions and restores the default categories (Settings → «Удалить все данные»). */
    fun resetAll() {
        subscriptions.clear()
        categories.clear()
        categories.addAll(SeedData.categories)
        payments.clear()
        unparsed.clear()
        loadError.value = null
        didChange()
    }

    /** CSV carries subscriptions only; rows are upserted by id (same as iOS). */
    fun importCsv(text: String): ImportResult {
        // CSV has no icon/domain/createdAt — keep them from rows we already have.
        val subs = CsvCodec.decode(text).map { row ->
            val old = subscription(row.id) ?: return@map row
            row.icon = old.icon
            row.domain = row.domain ?: old.domain
            row.createdAt = old.createdAt
            row
        }
        val file = BackupFile(exportedAt = "", subscriptions = subs.map(BackupMapper::dto))
        return importBackup(file, ImportMode.MERGE)
    }

    // MARK: - Home

    val monthlyTotalRub: Double
        get() = active.sumOf { toRub(it.amount, it.currency) * it.billingPeriod.monthlyEquivalent }

    fun monthProgress(now: LocalDate = LocalDate.now()): Pair<Double, Double> {
        val today = now
        val month = YearMonth.from(now)
        val monthStart = month.atDay(1)
        val monthEnd = month.atEndOfMonth().plusDays(1)
        var paid = 0.0
        var remaining = 0.0
        for (sub in active) {
            for (date in billingDates(sub, monthStart, monthEnd, now)) {
                val rub = recordedRub(sub, date) ?: toRub(sub.amount, sub.currency)
                if (date < today) paid += rub else remaining += rub
            }
        }
        // A trial's first charge is already scheduled — count it as remaining.
        for (sub in subscriptions) {
            if (sub.status != SubscriptionStatus.TRIAL) continue
            remaining += billingDates(sub, today, monthEnd, now).size * toRub(sub.amount, sub.currency)
        }
        return paid to remaining
    }

    /** Past charges: recorded payments first (real amounts, survives cancellation),
     * then schedule inference for anything older than recording itself. */
    fun pastPayments(days: Int = 90, now: LocalDate = LocalDate.now()): List<PaymentEvent> {
        val today = now
        val start = today.minusDays(days.toLong())
        val events = mutableListOf<PaymentEvent>()
        val covered = HashSet<String>()
        for (r in payments) {
            if (r.kind != PaymentRecord.Kind.CHARGE || r.date < start || r.date >= today) continue
            val sub = subscription(r.subscriptionId) ?: continue
            events.add(PaymentEvent(sub, r.date, r))
            covered.add(r.id)
        }
        for (sub in active) {
            for (date in billingDates(sub, start, today, now)) {
                val id = PaymentRecord.makeId(sub.id, date)
                if (!covered.contains(id)) events.add(PaymentEvent(sub, date))
            }
        }
        return events.sortedByDescending { it.date }
    }

    fun futurePayments(days: Int = 90, now: LocalDate = LocalDate.now()): List<PaymentEvent> {
        val today = now
        val end = today.plusDays(days.toLong())
        return (active + subscriptions.filter { it.status == SubscriptionStatus.TRIAL })
            .flatMap { sub -> billingDates(sub, today, end, now).map { PaymentEvent(sub, it) } }
            .sortedBy { it.date }
    }

    // MARK: - Analytics

    fun monthlyTotals(past: Int = 6, future: Int = 3, now: LocalDate = LocalDate.now()): List<PeriodTotal> {
        val current = YearMonth.from(now).atDay(1)
        val starts = (-past..future).map { YearMonth.from(current).plusMonths(it.toLong()).atDay(1) }
        val end = YearMonth.from(starts.last()).atEndOfMonth().plusDays(1)
        return totals(starts, end, current, now) { YearMonth.from(it).atDay(1) }
    }

    fun weeklyTotals(past: Int = 6, future: Int = 4, now: LocalDate = LocalDate.now()): List<PeriodTotal> {
        // ISO weeks (Monday first), like the iOS app's `.iso8601` calendar.
        val current = now.with(java.time.temporal.TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY))
        val starts = (-past..future).map { current.plusWeeks(it.toLong()) }
        val end = starts.last().plusWeeks(1)
        return totals(starts, end, current, now) { it.with(java.time.temporal.TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY)) }
    }

    /** Per-category charges inside `[start, end)` (RUB), split into already paid
     * (before today) and total. */
    fun categoryShares(start: LocalDate, end: LocalDate, now: LocalDate = LocalDate.now()): List<CategoryShare> {
        val today = now
        val paid = HashMap<String?, Double>()
        val total = HashMap<String?, Double>()
        for (sub in chargeable) {
            for (date in billingDates(sub, start, end, now)) {
                val rub = recordedRub(sub, date) ?: toRub(sub.amount, sub.currency)
                total[sub.categoryId] = (total[sub.categoryId] ?: 0.0) + rub
                if (date < today) paid[sub.categoryId] = (paid[sub.categoryId] ?: 0.0) + rub
            }
        }
        return total.entries
            .map { CategoryShare(category(it.key), paid[it.key] ?: 0.0, it.value) }
            .sortedByDescending { it.total }
    }

    // MARK: - Insights

    /** Same-span comparison: charges since this month's start vs the same span
     * of the previous month (fair while the month is still running). */
    fun monthOverMonth(now: LocalDate = LocalDate.now()): MonthDelta? {
        val monthStart = YearMonth.from(now).atDay(1)
        val prevMonthStart = YearMonth.from(monthStart.minusDays(1)).atDay(1)
        val today = now
        val spanDays = java.time.temporal.ChronoUnit.DAYS.between(monthStart, today)
        val current = chargesTotal(monthStart, today, now)
        val previous = chargesTotal(prevMonthStart, prevMonthStart.plusDays(spanDays), now)
        // Nothing charged in either span — nothing to compare yet.
        if (current <= 0 && previous <= 0) return null
        return MonthDelta(current, previous)
    }

    private fun chargesTotal(from: LocalDate, to: LocalDate, now: LocalDate): Double =
        chargeable.sumOf { sub ->
            billingDates(sub, from, to, now).sumOf { date -> recordedRub(sub, date) ?: toRub(sub.amount, sub.currency) }
        }

    /** Steady-state year cost: active spending projected over 12 months. */
    fun annualForecast(): Pair<Double, List<AnnualCost>> {
        val items = active
            .map { AnnualCost(it, toRub(it.amount, it.currency) * it.billingPeriod.monthlyEquivalent * 12) }
            .sortedByDescending { it.perYearRub }
        return items.sumOf { it.perYearRub } to items.take(3)
    }

    /** Likely duplicates: same service domain, or same category with one name
     * containing the other ("Netflix" vs "Netflix Premium"). A hint, not a verdict. */
    fun duplicateGroups(): List<List<Subscription>> {
        val pool = notCancelled
        val groups = mutableListOf<List<Subscription>>()
        val byDomain = HashMap<String, MutableList<Subscription>>()
        for (sub in pool) {
            val domain = sub.domain?.lowercase()
            if (!domain.isNullOrEmpty()) byDomain.getOrPut(domain) { mutableListOf() }.add(sub)
        }
        groups += byDomain.values.filter { it.size > 1 }
        val used = HashSet(groups.flatten().map { it.id })

        for (peers in pool.groupBy { it.categoryId }.values) {
            for (seed in peers) {
                if (used.contains(seed.id)) continue
                val matches = peers.filter { other ->
                    if (other.id == seed.id || used.contains(other.id)) return@filter false
                    val a = normalized(seed.name)
                    val b = normalized(other.name)
                    if (minOf(a.length, b.length) < 3) return@filter false
                    a.contains(b) || b.contains(a)
                }
                if (matches.isEmpty()) continue
                val group = listOf(seed) + matches
                groups.add(group)
                used.addAll(group.map { it.id })
            }
        }
        return groups
    }

    private fun normalized(name: String): String =
        java.text.Normalizer.normalize(name.lowercase(), java.text.Normalizer.Form.NFD)
            .replace(Regex("\\p{M}+"), "").trim()

    // MARK: - Helpers

    private fun totals(buckets: List<LocalDate>, end: LocalDate, current: LocalDate, now: LocalDate, bucketOf: (LocalDate) -> LocalDate): List<PeriodTotal> {
        val sums = HashMap<LocalDate, Double>(buckets.associateWith { 0.0 })
        for (sub in chargeable) {
            for (date in billingDates(sub, buckets.first(), end, now)) {
                val bucket = bucketOf(date)
                sums[bucket] = (sums[bucket] ?: 0.0) + (recordedRub(sub, date) ?: toRub(sub.amount, sub.currency))
            }
        }
        return buckets.map { PeriodTotal(it, sums[it] ?: 0.0, it >= current) }
    }

    fun billingDates(sub: Subscription, from: LocalDate, to: LocalDate, now: LocalDate = LocalDate.now()): List<LocalDate> =
        Schedule.dates(sub, from, to, now)
}

/** System-side reminder scheduling (AlarmManager on Android). Kept as an interface
 * so the pure store logic stays testable. */
interface ReminderScheduler {
    fun apply(plans: List<Reminders.Plan>) {}
    fun canSchedule(): Boolean = true
    /** Whether the user will actually see notifications (POST_NOTIFICATIONS). */
    fun notificationsAllowed(): Boolean = true
    fun requestPermission(onResult: (Boolean) -> Unit) {
        onResult(true)
    }
}
