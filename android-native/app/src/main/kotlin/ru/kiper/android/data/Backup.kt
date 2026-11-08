package ru.kiper.android.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

/**
 * Backup / storage format. Same shape as `BackupData` in the Flutter app
 * shared by all Kiper apps (iOS `BackupFile.swift`, Android `Backup.kt`),
 * so files move between platforms both ways.
 */
@Serializable
data class BackupFile(
    val version: Int = 1,
    val exportedAt: String,
    val subscriptions: List<SubscriptionDTO> = emptyList(),
    val categories: List<CategoryDTO> = emptyList(),
    val settings: Map<String, String> = emptyMap(),
    val payments: List<PaymentRecordDTO>? = null,
) {
    companion object {
        const val CURRENT_VERSION = 1
    }
}

@Serializable
data class SubscriptionDTO(
    val id: String,
    val name: String,
    val icon: String? = null,
    val amount: Double,
    val currency: String,
    val billingPeriod: String,
    val customPeriodDays: Int? = null,
    val categoryId: String? = null,
    val nextBillingDate: String,
    val startDate: String,
    val status: String? = null,
    val reminderDaysBefore: Int? = null,
    val note: String? = null,
    val createdAt: String? = null,
    val domain: String? = null,
    /** Trial end of the free period (status "trial"). */
    val trialEndDate: String? = null,
)

@Serializable
data class CategoryDTO(
    val id: String,
    val name: String,
    /** ARGB long, e.g. 4278190080 = 0xFF7C4DFF. */
    val color: Long,
    /** Material icon name (Android) or SF Symbol name (iOS). */
    val icon: String,
)

/** `id` is derived from `subscriptionId` + `date`, so it isn't stored. */
@Serializable
data class PaymentRecordDTO(
    val subscriptionId: String,
    val date: String,
    val amount: Double,
    val currency: String,
    val amountRub: Double,
    val kind: String,
    val source: String,
)

class BackupException(message: String) : Exception(message)

/**
 * Mapping between domain models and DTOs, plus the tolerant local-date codec
 * shared with `BackupMapper.swift` / the Dart exporter.
 */
object BackupMapper {

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = true
        prettyPrintIndent = "  "
    }

    /** Dart's `DateTime.toIso8601String()` for local times: `2024-03-01T00:00:00.000`. */
    private val LOCAL_OUT: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS")

    fun string(date: LocalDate): String = date.atStartOfDay().format(LOCAL_OUT)

    /**
     * Accepts Dart local ISO strings (with or without millis/micros), plain dates
     * and full ISO 8601 with a zone. Only strings carrying a zone are absolute
     * (converted to the device zone, like an instant would be); everything else is
     * local time — a bare "2026-10-13" is already a local day.
     */
    fun date(raw: String): LocalDate? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return null
        val hasZone = trimmed.length > 10 && Regex("(Z|[+-]\\d{2}:?\\d{2})$").containsMatchIn(trimmed)
        if (hasZone) {
            return try {
                OffsetDateTime.parse(trimmed).atZoneSameInstant(java.time.ZoneId.systemDefault()).toLocalDate()
            } catch (_: Exception) {
                null
            }
        }
        // Local time without zone; Dart may emit 3 or 6 fractional digits (keep the date).
        return try {
            LocalDate.parse(trimmed.take(10))
        } catch (_: Exception) {
            null
        }
    }

    fun dto(s: Subscription): SubscriptionDTO = SubscriptionDTO(
        id = s.id,
        name = s.name,
        icon = s.icon,
        amount = s.amount,
        currency = s.currency.code,
        billingPeriod = s.billingPeriod.raw,
        customPeriodDays = s.customPeriodDays,
        categoryId = s.categoryId,
        nextBillingDate = string(s.nextBillingDate),
        startDate = string(s.startDate),
        status = s.status.raw,
        reminderDaysBefore = s.reminderDaysBefore,
        note = s.note,
        createdAt = string(s.createdAt),
        domain = s.domain,
        trialEndDate = s.trialEndDate?.let { string(it) },
    )

    fun subscription(d: SubscriptionDTO): Subscription? {
        val next = date(d.nextBillingDate) ?: return null
        val start = date(d.startDate) ?: return null
        return Subscription(
            id = d.id,
            name = d.name,
            amount = d.amount,
            currency = Currency.of(d.currency),
            billingPeriod = BillingPeriod.of(d.billingPeriod),
            customPeriodDays = d.customPeriodDays,
            categoryId = d.categoryId,
            nextBillingDate = next,
            reminderDaysBefore = d.reminderDaysBefore ?: 1,
            status = SubscriptionStatus.of(d.status),
            trialEndDate = d.trialEndDate?.let(::date),
            startDate = start,
            note = d.note,
            domain = d.domain ?: CatalogEntry.all.firstOrNull { it.name.equals(d.name, ignoreCase = true) }?.domain,
            createdAt = d.createdAt?.let(::date) ?: LocalDate.now(),
            icon = d.icon,
        )
    }

    fun dto(c: Category): CategoryDTO = CategoryDTO(
        id = c.id,
        name = c.name,
        color = 0xFF000000L or (c.colorHex.toLong() and 0xFFFFFF),
        icon = IconMap.material(c.symbol),
    )

    fun category(d: CategoryDTO): Category = Category(
        id = d.id,
        name = d.name,
        colorHex = (d.color and 0xFFFFFF).toInt(),
        symbol = IconMap.symbol(d.icon),
    )

    fun dto(p: PaymentRecord): PaymentRecordDTO = PaymentRecordDTO(
        subscriptionId = p.subscriptionId,
        date = string(p.date),
        amount = p.amount,
        currency = p.currency.code,
        amountRub = p.amountRub,
        kind = p.kind.raw,
        source = p.source.raw,
    )

    fun payment(d: PaymentRecordDTO): PaymentRecord? {
        val date = date(d.date) ?: return null
        return PaymentRecord(
            subscriptionId = d.subscriptionId,
            date = date,
            amount = d.amount,
            currency = Currency.of(d.currency),
            amountRub = d.amountRub,
            kind = if (d.kind == "skip") PaymentRecord.Kind.SKIP else PaymentRecord.Kind.CHARGE,
            source = when (d.source) {
                "manual" -> PaymentRecord.Source.MANUAL
                "bank" -> PaymentRecord.Source.BANK
                else -> PaymentRecord.Source.AUTO
            },
        )
    }

    fun file(
        subscriptions: List<Subscription>,
        categories: List<Category>,
        settings: Map<String, String> = emptyMap(),
        payments: List<PaymentRecord> = emptyList(),
        now: LocalDate = LocalDate.now(),
    ): BackupFile = BackupFile(
        exportedAt = string(now),
        subscriptions = subscriptions.map(::dto),
        categories = categories.map(::dto),
        settings = settings,
        payments = payments.map(::dto),
    )

    fun encode(file: BackupFile): String = json.encodeToString(BackupFile.serializer(), file)

    fun decode(text: String): BackupFile {
        return try {
            val file = json.decodeFromString(BackupFile.serializer(), text)
            if (file.version > BackupFile.CURRENT_VERSION) {
                throw BackupException("Файл из более новой версии приложения (формат ${file.version}).")
            }
            file
        } catch (e: BackupException) {
            throw e
        } catch (e: Exception) {
            throw BackupException("Не удалось прочитать файл. Нужен JSON или CSV, экспортированный из Кипера.")
        }
    }
}

/** Material icon names used by the Android app ↔ SF Symbols used on iOS. */
object IconMap {
    private val pairs = listOf(
        "movie" to "play.tv.fill",
        "smart_toy" to "sparkles",
        "phone_android" to "antenna.radiowaves.left.and.right",
        "sports_esports" to "gamecontroller.fill",
        "category" to "square.grid.2x2.fill",
        "music_note" to "music.note",
        "book" to "book.fill",
        "cloud" to "cloud.fill",
        "security" to "lock.shield.fill",
        "shopping_bag" to "bag.fill",
    )

    const val FALLBACK_SYMBOL = "square.grid.2x2.fill"

    fun material(symbol: String): String =
        pairs.firstOrNull { it.second == symbol }?.first ?: symbol

    fun symbol(icon: String): String =
        pairs.firstOrNull { it.first == icon }?.second ?: FALLBACK_SYMBOL
}
