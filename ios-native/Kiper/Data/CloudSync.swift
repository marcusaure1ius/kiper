import CloudKit
import SwiftUI

// CloudKit sync for the private database. One CKRecord per model row
// (recordName = local id), whole-set push on change, whole-set pull with
// id-upsert merge on launch. Last writer wins on the record level; deleted
// categories leave tombstones so another device can't resurrect them.

/// Pure mapping and merge policy (unit-tested, no CloudKit account needed —
/// CKRecord is a plain object until it hits a database).
enum CloudSync {
    static let containerId = "iCloud.ru.kiper.ios"
    static let zone = CKRecordZone.ID(zoneName: "KiperZone", ownerName: CKCurrentUserDefaultName)

    enum RecordType {
        static let subscription = "Subscription"
        static let category = "Category"
        static let payment = "Payment"
    }

    // MARK: - Record mapping

    static func record(for sub: Subscription, now: Date = .now) -> CKRecord {
        let record = CKRecord(recordType: RecordType.subscription, recordID: .init(recordName: sub.id, zoneID: zone))
        record["name"] = sub.name
        record["amount"] = sub.amount
        record["currency"] = sub.currency.rawValue
        record["billingPeriod"] = sub.billingPeriod.rawValue
        record["customPeriodDays"] = sub.customPeriodDays
        record["categoryId"] = sub.categoryId
        record["nextBillingDate"] = sub.nextBillingDate
        record["startDate"] = sub.startDate
        record["reminderDaysBefore"] = sub.reminderDaysBefore
        record["status"] = sub.status.rawValue
        record["trialEndDate"] = sub.trialEndDate
        record["note"] = sub.note
        record["domain"] = sub.domain
        record["icon"] = sub.icon
        record["createdAt"] = sub.createdAt
        record["editedAt"] = now
        return record
    }

    static func record(for category: Category, now: Date = .now) -> CKRecord {
        let record = CKRecord(recordType: RecordType.category, recordID: .init(recordName: category.id, zoneID: zone))
        record["name"] = category.name
        record["colorHex"] = Int(category.colorHex)
        record["symbol"] = category.symbol
        record["editedAt"] = now
        return record
    }

    static func record(for payment: PaymentRecord, now: Date = .now) -> CKRecord {
        let record = CKRecord(recordType: RecordType.payment, recordID: .init(recordName: payment.id, zoneID: zone))
        record["subscriptionId"] = payment.subscriptionId
        record["date"] = payment.date
        record["amount"] = payment.amount
        record["currency"] = payment.currency.rawValue
        record["amountRub"] = payment.amountRub
        record["kind"] = payment.kind.rawValue
        record["source"] = payment.source.rawValue
        record["editedAt"] = now
        return record
    }

    static func subscription(from record: CKRecord) -> Subscription? {
        guard let name = record["name"] as? String,
              let amount = record["amount"] as? Double,
              let currency = record["currency"] as? String,
              let period = record["billingPeriod"] as? String,
              let next = record["nextBillingDate"] as? Date,
              let start = record["startDate"] as? Date else { return nil }
        return Subscription(
            id: record.recordID.recordName, name: name, amount: amount,
            currency: Currency(rawValue: currency) ?? .rub,
            billingPeriod: BillingPeriod(rawValue: period) ?? .monthly,
            customPeriodDays: record["customPeriodDays"] as? Int,
            categoryId: record["categoryId"] as? String,
            nextBillingDate: next, reminderDaysBefore: record["reminderDaysBefore"] as? Int ?? 1,
            status: (record["status"] as? String).flatMap(SubscriptionStatus.init(rawValue:)) ?? .active,
            trialEndDate: record["trialEndDate"] as? Date,
            startDate: start, note: record["note"] as? String,
            domain: record["domain"] as? String,
            createdAt: record["createdAt"] as? Date ?? .now,
            icon: record["icon"] as? String
        )
    }

    static func category(from record: CKRecord) -> Category? {
        guard let name = record["name"] as? String,
              let color = record["colorHex"] as? Int,
              let symbol = record["symbol"] as? String else { return nil }
        return Category(id: record.recordID.recordName, name: name, colorHex: UInt32(truncatingIfNeeded: color) & 0xFF_FFFF, symbol: symbol)
    }

    static func payment(from record: CKRecord) -> PaymentRecord? {
        guard let subscriptionId = record["subscriptionId"] as? String,
              let date = record["date"] as? Date,
              let amount = record["amount"] as? Double,
              let currency = record["currency"] as? String,
              let amountRub = record["amountRub"] as? Double else { return nil }
        return PaymentRecord(
            subscriptionId: subscriptionId, date: date, amount: amount,
            currency: Currency(rawValue: currency) ?? .rub, amountRub: amountRub,
            kind: (record["kind"] as? String).flatMap(PaymentRecord.Kind.init(rawValue:)) ?? .charge,
            source: (record["source"] as? String).flatMap(PaymentRecord.Source.init(rawValue:)) ?? .auto
        )
    }

    // MARK: - Pull merge

    /// Merges pulled records into the store's current sets: id-upsert, tombstoned
    /// ids are skipped (deleted on this device must not come back).
    @MainActor
    static func merge(
        subscriptions incomingSubs: [Subscription],
        categories incomingCats: [Category],
        payments incomingPays: [PaymentRecord],
        categoryTombstones: Set<String>,
        into store: AppStore
    ) {
        for cat in incomingCats where !categoryTombstones.contains(cat.id) {
            store.upsertCategorySilently(cat)
        }
        for sub in incomingSubs {
            store.upsertSilently(sub)
        }
        for payment in incomingPays {
            store.upsertPaymentSilently(payment)
        }
    }
}

// MARK: - Engine

/// Owns the CloudKit conversation. The toggle is off by default; enabling
/// checks the iCloud account first. Requires a signed build with the iCloud
/// entitlement (unsigned simulator runs must keep it off).
@MainActor
@Observable
final class CloudSyncEngine {
    enum Status: Equatable {
        case idle
        case syncing
        case upToDate(Date)
        case error(String)
    }

    private static let enabledKey = "cloud.enabled"
    private static let tombstoneKey = "cloud.tombstones.categories"

    private(set) var isEnabled: Bool
    private(set) var status: Status = .idle
    private var pushTask: Task<Void, Never>?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    /// Category ids deleted locally; skipped on pull, removed from the cloud on push.
    /// Recorded even while sync is off — a category deleted before enabling must
    /// not resurrect from the cloud afterwards.
    private var categoryTombstones: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.tombstoneKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: Self.tombstoneKey) }
    }

    func recordTombstone(categoryId: String) {
        categoryTombstones.insert(categoryId)
    }

    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        guard enabled else { return }
        do {
            let account = try await CKContainer(identifier: CloudSync.containerId).accountStatus()
            if account != .available {
                status = .error(accountMessage(account))
            }
        } catch {
            status = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func accountMessage(_ status: CKAccountStatus) -> String {
        switch status {
        case .noAccount: "Нет аккаунта iCloud — войдите в системные настройки."
        case .restricted, .temporarilyUnavailable: "Доступ к iCloud ограничен системой."
        case .couldNotDetermine: "Не удалось определить состояние iCloud."
        default: "iCloud недоступен."
        }
    }

    /// Debounced push after any data change (called from the store's `didChange`).
    func schedulePush(_ store: AppStore) {
        guard isEnabled else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, self.isEnabled else { return }
            await self.push(store)
        }
    }

    func sync(_ store: AppStore) async {
        guard isEnabled else { return }
        await pull(store)
        await push(store)
    }

    private func push(_ store: AppStore) async {
        status = .syncing
        do {
            let database = try await database()
            var toSave = store.subscriptions.map { CloudSync.record(for: $0) }
            toSave += store.categories.map { CloudSync.record(for: $0) }
            toSave += store.payments.map { CloudSync.record(for: $0) }
            let toDelete = categoryTombstones.map { CKRecord.ID(recordName: $0, zoneID: CloudSync.zone) }
            _ = try await database.modifyRecords(saving: toSave, deleting: toDelete, savePolicy: .changedKeys, atomically: false)
            status = .upToDate(.now)
        } catch {
            status = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func pull(_ store: AppStore) async {
        status = .syncing
        do {
            let database = try await database()
            let records = try await allRecords(in: database)
            var subs: [Subscription] = [], cats: [Category] = [], pays: [PaymentRecord] = []
            for record in records {
                switch record.recordType {
                case CloudSync.RecordType.subscription: CloudSync.subscription(from: record).map { subs.append($0) }
                case CloudSync.RecordType.category: CloudSync.category(from: record).map { cats.append($0) }
                case CloudSync.RecordType.payment: CloudSync.payment(from: record).map { pays.append($0) }
                default: break
                }
            }
            CloudSync.merge(subscriptions: subs, categories: cats, payments: pays,
                            categoryTombstones: categoryTombstones, into: store)
            store.finishCloudMerge()
        } catch {
            status = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Whole-zone fetch through paged queries — the data set is small, so this
    /// beats change tokens and survives token invalidation.
    private func allRecords(in database: CKDatabase) async throws -> [CKRecord] {
        var result: [CKRecord] = []
        for type in [CloudSync.RecordType.subscription, CloudSync.RecordType.category, CloudSync.RecordType.payment] {
            let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
            var matches: [(CKRecord.ID, Result<CKRecord, any Error>)] = []
            var cursor: CKQueryOperation.Cursor?
            var page = try await database.records(matching: query, inZoneWith: CloudSync.zone)
            matches = page.matchResults
            cursor = page.queryCursor
            while true {
                for (_, info) in matches {
                    if let record = try? info.get() { result.append(record) }
                }
                guard let current = cursor else { break }
                page = try await database.records(continuingMatchFrom: current)
                matches = page.matchResults
                cursor = page.queryCursor
            }
        }
        return result
    }

    private func database() async throws -> CKDatabase {
        CKContainer(identifier: CloudSync.containerId).privateCloudDatabase
    }
}
