package ru.kiper.android.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * Everything a widget needs, written by the app on every data change. Kept tiny
 * on purpose — the widget never reads the full store file. The JSON schema is the
 * same as `WidgetSnapshot.swift` (ISO 8601 dates); on Android both processes live
 * in one APK and share the app's internal storage.
 */
@Serializable
data class WidgetSnapshot(
    /** Upcoming charges, soonest first (up to three). */
    val upcoming: List<Charge>,
    /** Steady-state monthly spending in RUB. */
    val monthlyTotalRub: Double,
    /** Already charged this month / still to come (RUB). */
    val paidRub: Double,
    val remainingRub: Double,
    /** Monthly budget, when set. */
    val budgetRub: Double?,
    /** Palette accent as 0xRRGGBB, so widgets match the app tint in both themes. */
    val accentHexLight: Int,
    val accentHexDark: Int,
    val generatedAt: String,
) {
    @Serializable
    data class Charge(
        val name: String,
        val domain: String?,
        val date: String,
        val amount: Double,
        val currency: String,
    ) {
        val localDate: LocalDate get() = LocalDate.parse(date.take(10))
    }

    companion object {
        const val FILE_NAME = "widget-snapshot.json"
        private val ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME

        private fun fileOf(filesDir: File): File = File(filesDir, FILE_NAME)

        /** Silently does nothing when no directory is available (tests). */
        fun store(filesDir: File?, snapshot: WidgetSnapshot) {
            filesDir ?: return
            try {
                val json = Json { }
                fileOf(filesDir).writeText(json.encodeToString(serializer(), snapshot))
            } catch (_: Exception) {
            }
        }

        fun load(filesDir: File): WidgetSnapshot? = try {
            val json = Json { ignoreUnknownKeys = true }
            json.decodeFromString(serializer(), fileOf(filesDir).readText())
        } catch (_: Exception) {
            null
        }

        fun nowIso(): String = DateTimeFormatter.ISO_INSTANT.format(Instant.now())

        fun toInstant(iso: String): Instant = try {
            Instant.parse(iso)
        } catch (_: Exception) {
            Instant.EPOCH
        }

        fun isoOf(date: LocalDate): String = ISO.format(date.atStartOfDay())
    }
}
