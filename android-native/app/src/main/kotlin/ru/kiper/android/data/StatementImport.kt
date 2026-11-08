package ru.kiper.android.data

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/** One charge spotted in a bank statement. */
data class StatementOccurrence(val date: LocalDate, val amount: Double)

/**
 * A recurring payment detected in a bank export: at least three charges of a
 * similar merchant, evenly spaced, within ±10 % of the median amount.
 */
data class StatementCandidate(
    val id: String,
    val name: String,
    /** Sorted by date, oldest first. */
    val occurrences: List<StatementOccurrence>,
    val medianAmount: Double,
    val medianIntervalDays: Int,
) {
    val lastDate: LocalDate get() = occurrences.last().date

    val billingPeriod: Pair<BillingPeriod, Int?>
        get() = when (medianIntervalDays) {
            in Int.MIN_VALUE..10 -> BillingPeriod.WEEKLY to null
            in 11..20 -> BillingPeriod.CUSTOM to 14
            in 21..45 -> BillingPeriod.MONTHLY to null
            in 46..120 -> BillingPeriod.QUARTERLY to null
            in 121..250 -> BillingPeriod.SEMIANNUAL to null
            else -> BillingPeriod.ANNUAL to null
        }

    /** The next expected charge after the last one seen in the statement. */
    fun nextCharge(now: LocalDate = LocalDate.now()): LocalDate {
        val (period, customDays) = billingPeriod
        var next = period.next(lastDate, customDays)
        while (next < now) next = period.next(next, customDays)
        return next
    }
}

/**
 * Turns a bank CSV/TXT export into `StatementCandidate`s. Column layout varies
 * per bank, so columns are detected by content: a date-looking column, a
 * number-looking column and the longest free-text column for the merchant.
 */
object StatementImporter {

    fun parse(text: String): List<StatementCandidate> {
        // Banks use commas or semicolons as the delimiter.
        val sample = text.lineSequence().firstOrNull() ?: ""
        val delimiter = if (sample.count { it == ';' } > sample.count { it == ',' }) ';' else ','
        val rows = split(text, delimiter)
        if (rows.size < 4) return emptyList() // header + at least 3 charges
        val body = rows.drop(1)
        val width = body.minOfOrNull { it.size } ?: 0
        if (width < 3) return emptyList()

        // Column roles by content, voting over the body.
        val dateVotes = HashMap<Int, Int>()
        val amountVotes = HashMap<Int, Int>()
        val textScore = HashMap<Int, Int>()
        for (row in body.take(60)) {
            row.forEachIndexed { i, cell ->
                if (i >= width) return@forEachIndexed
                if (date(cell) != null) dateVotes[i] = (dateVotes[i] ?: 0) + 1
                if (number(cell) != null) amountVotes[i] = (amountVotes[i] ?: 0) + 1
                textScore[i] = (textScore[i] ?: 0) + (cell.length - cell.count { it.isDigit() })
            }
        }
        val dateCol = dateVotes.maxByOrNull { it.value }?.takeIf { it.value >= body.size / 2 }?.key ?: return emptyList()
        val amountCol = amountVotes.filterKeys { it != dateCol }.maxByOrNull { it.value }?.key ?: return emptyList()
        val textCol = textScore.filterKeys { it != dateCol && it != amountCol }.maxByOrNull { it.value }?.key ?: return emptyList()

        // Group charges by normalized merchant name.
        val groups = LinkedHashMap<String, Pair<String, MutableList<StatementOccurrence>>>()
        for (row in body) {
            if (row.size <= maxOf(dateCol, maxOf(amountCol, textCol))) continue
            val date = date(row[dateCol]) ?: continue
            val amount = number(row[amountCol]) ?: continue
            if (amount <= 0) continue
            val raw = row[textCol].trim()
            if (raw.isEmpty()) continue
            val key = normalize(raw)
            if (key.isEmpty()) continue
            val entry = groups.getOrPut(key) { raw to mutableListOf() }
            entry.second.add(StatementOccurrence(date, amount))
        }

        val candidates = groups.mapNotNull { (key, group) ->
            val items = group.second.sortedBy { it.date }
            if (items.size < 3) return@mapNotNull null
            val amounts = items.map { it.amount }.sorted()
            val median = amounts[amounts.size / 2]
            // Amounts must stay within ±10 % of the median (no price spikes here).
            if (!amounts.all { kotlin.math.abs(it - median) <= median * 0.1 }) return@mapNotNull null
            val gaps = items.zipWithNext { a, b -> ChronoUnit.DAYS.between(a.date, b.date).toInt() }.sorted()
            val interval = gaps[gaps.size / 2]
            // Even spacing near a plausible billing period.
            if (listOf(7, 14, 30, 31, 90, 365).none { kotlin.math.abs(interval - it) <= 3 }) return@mapNotNull null
            StatementCandidate(id = key, name = group.first, occurrences = items, medianAmount = median, medianIntervalDays = interval)
        }
        return candidates.sortedByDescending { it.medianAmount * 12 / maxOf(it.medianIntervalDays, 1) }
    }

    /** "ООО ЯНДЕКС.ТАКСИ (CARD 4111 **** 1234)" → "ЯНДЕКС.ТАКСИ" — letters only,
     * legal forms, card masks and noise words dropped. */
    fun normalize(raw: String): String {
        val noise = setOf(
            "ООО", "ОАО", "ЗАО", "ИП", "АО", "CARD", "КАРТА", "ПОКУПКА", "ОПЛАТА",
            "ИНТЕРНЕТ", "ONLINE", "RU", "RUB", "MOSCOW", "МОСКВА", "Г", "Г.",
        )
        val cleaned = raw.replace(Regex("\\d"), " ").replace(Regex("[*•]"), " ")
        val kept = mutableListOf<String>()
        for (word in cleaned.split(" ")) {
            val w = word.trim { it.isWhitespace() || it in ",.!?;:()[]{}<>\"'-" }
            if (w.isEmpty()) continue
            if (w.uppercase() in noise) continue
            kept.add(w)
        }
        return kept.joinToString(" ").uppercase()
    }

    /** RFC 4180-ish splitter with a configurable delimiter (quotes, escaped
     * quotes, newlines inside quotes). */
    fun split(text: String, delimiter: Char): List<List<String>> {
        val rows = mutableListOf<List<String>>()
        var row = mutableListOf<String>()
        val field = StringBuilder()
        var inQuotes = false
        val chars = text.replace("\r\n", "\n").replace("\r", "\n")
            .let { if (it.startsWith("\uFEFF")) it.substring(1) else it }
        var i = 0
        while (i < chars.length) {
            val ch = chars[i]
            if (inQuotes) {
                if (ch == '"') {
                    if (i + 1 < chars.length && chars[i + 1] == '"') {
                        field.append('"'); i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                when (ch) {
                    '"' -> inQuotes = true
                    delimiter -> { row.add(field.toString()); field.clear() }
                    '\n' -> {
                        row.add(field.toString()); field.clear()
                        if (!(row.size == 1 && row[0].isEmpty())) rows.add(row)
                        row = mutableListOf()
                    }
                    else -> field.append(ch)
                }
            }
            i += 1
        }
        if (field.isNotEmpty() || row.isNotEmpty()) {
            row.add(field.toString())
            rows.add(row)
        }
        return rows
    }

    // MARK: - Cell parsing

    private val formats = listOf(
        "dd.MM.yyyy", "dd.MM.yyyy HH:mm:ss", "dd.MM.yyyy HH:mm",
        "yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "dd/MM/yyyy", "MM/dd/yyyy",
    )

    fun date(cell: String): LocalDate? {
        val trimmed = cell.trim()
        for (format in formats) {
            try {
                val parsed = DateTimeFormatter.ofPattern(format).parseBest(trimmed, LocalDate::from, java.time.LocalDateTime::from)
                return when (val r = parsed) {
                    is LocalDate -> r
                    else -> (parsed as java.time.LocalDateTime).toLocalDate()
                }
            } catch (_: Exception) {
            }
        }
        return null
    }

    /** "1 234,56", "-1234.56", "1234.56 ₽", "(1234.56)" → positive magnitude. */
    fun number(cell: String): Double? {
        var s = cell.trim()
        if (s.isEmpty()) return null
        val negative = s.startsWith("-") || s.startsWith("(")
        s = s.replace(Regex("[^0-9,.-]"), "").replace("(", "").replace(")", "")
        // Both decimal separators accepted; thousands spaces already stripped.
        s = if (s.contains(",") && s.contains(".")) s.replace(",", "") // 1,234.56
        else s.replace(",", ".") // 1234,56
        val value = s.toDoubleOrNull() ?: return null
        if (value == 0.0) return null
        return kotlin.math.abs(if (negative) -value else value)
    }
}
