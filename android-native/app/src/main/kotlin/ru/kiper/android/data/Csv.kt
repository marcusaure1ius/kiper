package ru.kiper.android.data

import java.time.LocalDate

/** Same columns and quoting as `CSVCodec.swift` on iOS — CSV files are interchangeable. */
object CsvCodec {
    val headers = listOf(
        "id", "name", "amount", "currency", "billingPeriod",
        "customPeriodDays", "categoryId", "nextBillingDate",
        "startDate", "status", "reminderDaysBefore", "note", "trialEndDate",
    )

    fun encode(subscriptions: List<Subscription>): String {
        val lines = mutableListOf(headers.joinToString(","))
        for (s in subscriptions) {
            val d = BackupMapper.dto(s)
            val values = listOf(
                d.id, d.name, number(d.amount), d.currency, d.billingPeriod,
                d.customPeriodDays?.toString() ?: "", d.categoryId ?: "", d.nextBillingDate,
                d.startDate, d.status ?: "", d.reminderDaysBefore?.toString() ?: "", d.note ?: "",
                d.trialEndDate ?: "",
            )
            lines.add(values.joinToString(",") { escape(it) })
        }
        return lines.joinToString("\n") + "\n"
    }

    /** Rows that have at least `id` and `name`; invalid rows are skipped. */
    fun decode(text: String): List<Subscription> {
        val rows = parse(text)
        val header = rows.firstOrNull() ?: return emptyList()
        return rows.drop(1).mapNotNull { row ->
            val map = HashMap<String, String>()
            header.forEachIndexed { i, key ->
                if (i < row.size && row[i].isNotEmpty()) map[key.trim()] = row[i]
            }
            val id = map["id"] ?: return@mapNotNull null
            val name = map["name"] ?: return@mapNotNull null
            val dto = SubscriptionDTO(
                id = id,
                name = name,
                icon = null,
                amount = map["amount"]?.toDoubleOrNull() ?: 0.0,
                currency = map["currency"] ?: "RUB",
                billingPeriod = map["billingPeriod"] ?: "monthly",
                customPeriodDays = map["customPeriodDays"]?.toIntOrNull(),
                categoryId = map["categoryId"],
                nextBillingDate = map["nextBillingDate"] ?: BackupMapper.string(LocalDate.now().plusDays(30)),
                startDate = map["startDate"] ?: BackupMapper.string(LocalDate.now()),
                status = map["status"],
                reminderDaysBefore = map["reminderDaysBefore"]?.toIntOrNull(),
                note = map["note"],
                createdAt = null,
                domain = null,
                trialEndDate = map["trialEndDate"],
            )
            BackupMapper.subscription(dto)
        }
    }

    private fun number(value: Double): String =
        if (value == Math.rint(value)) String.format("%.1f", value) else value.toString()

    private fun escape(value: String): String =
        if (!value.contains(",") && !value.contains("\"") && !value.contains("\n")) value
        else "\"" + value.replace("\"", "\"\"") + "\""

    /** RFC 4180-ish parser: quoted fields, escaped quotes, newlines inside quotes. */
    fun parse(text: String): List<List<String>> {
        val rows = mutableListOf<List<String>>()
        var row = mutableListOf<String>()
        val field = StringBuilder()
        var inQuotes = false
        val chars = text.replace("\r\n", "\n").let { if (it.startsWith("\uFEFF")) it.substring(1) else it }
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
                    ',' -> { row.add(field.toString()); field.clear() }
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
}
