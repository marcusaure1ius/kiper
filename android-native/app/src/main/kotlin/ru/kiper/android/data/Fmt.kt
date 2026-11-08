package ru.kiper.android.data

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

/** Russian formatting — mirrors `Formatting.swift` (space thousands, comma decimals). */
object Fmt {

    private val RU = Locale("ru")

    /** `1 234,56 $` / `1 234 ₽` — NBSP thousands separator, comma decimals. */
    fun money(amount: Double, currency: Currency, decimals: Int? = null): String {
        val d = decimals ?: if (amount == Math.rint(amount)) 0 else 2
        val scaled = Math.round(Math.abs(amount) * pow10(d))
        val whole = scaled / pow10(d)
        var frac = scaled % pow10(d)
        val digits = whole.toString()
        val sb = StringBuilder()
        if (amount < 0 && scaled != 0L) sb.append('-')
        sb.append(digits)
        var i = digits.length
        while (i > 3) {
            i -= 3
            sb.insert(i, "\u00A0")
        }
        if (d > 0) {
            val fracStr = StringBuilder()
            while (frac > 0) {
                fracStr.insert(0, (frac % 10))
                frac /= 10
            }
            while (fracStr.length < d) fracStr.insert(0, '0')
            sb.append(',').append(fracStr)
        }
        sb.append('\u00A0').append(currency.symbol)
        return sb.toString()
    }

    private fun pow10(d: Int): Long {
        var r = 1L
        repeat(d) { r *= 10 }
        return r
    }

    fun rub(amount: Double): String = money(amount, Currency.RUB, decimals = 0)

    private val DAY = DateTimeFormatter.ofPattern("d MMMM", RU)
    private val FULL = DateTimeFormatter.ofPattern("d MMMM yyy 'г.'", RU)
    private val MONTH_SHORT = DateTimeFormatter.ofPattern("LLL", RU)
    private val MONTH_STANDALONE = DateTimeFormatter.ofPattern("LLLL", RU)

    /** «12 ноября». */
    fun day(date: LocalDate): String = date.format(DAY)

    /** «12 ноября 2027 г.». */
    fun fullDate(date: LocalDate): String = date.format(FULL)

    /** «12 ноября», or «12 ноября 2027 г.» when not the current year. */
    fun smartDate(date: LocalDate): String =
        if (date.year == LocalDate.now().year) day(date) else fullDate(date)

    /** «Ноябрь» — nominative (standalone) month name. */
    fun monthName(date: LocalDate): String =
        date.format(MONTH_STANDALONE).replaceFirstChar { it.uppercase(RU) }

    /** «октябре» — for phrases like «оплачено в октябре». */
    fun monthPrepositional(date: LocalDate): String {
        val names = arrayOf("январе", "феврале", "марте", "апреле", "мае", "июне",
            "июле", "августе", "сентябре", "октябре", "ноябре", "декабре")
        return names[date.monthValue - 1]
    }

    fun monthShort(date: LocalDate): String = date.format(MONTH_SHORT)

    /** Russian plural: plural(5, "списание", "списания", "списаний") → «списаний». */
    fun plural(n: Int, one: String, few: String, many: String): String {
        val n10 = n % 10
        val n100 = n % 100
        return if (n10 == 1 && n100 != 11) one
        else if (n10 in 2..4 && n100 !in 12..14) few
        else many
    }

    /** «Сегодня», «Завтра», «Через 5 дн.», «3 дн. назад». */
    fun relative(date: LocalDate, now: LocalDate = LocalDate.now()): String {
        val days = ChronoUnit.DAYS.between(now, date).toInt()
        return when {
            days == 0 -> "Сегодня"
            days == 1 -> "Завтра"
            days == -1 -> "Вчера"
            days >= 2 -> "Через $days дн."
            else -> "${-days} дн. назад"
        }
    }

    /** Localized date for sheet headers etc. */
    fun mediumDate(date: LocalDate): String =
        date.format(java.time.format.DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(RU))
}
