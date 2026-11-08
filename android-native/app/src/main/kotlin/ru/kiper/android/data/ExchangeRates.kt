package ru.kiper.android.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.Instant
import java.time.format.DateTimeFormatter
import javax.xml.parsers.SAXParserFactory
import org.xml.sax.Attributes
import org.xml.sax.helpers.DefaultHandler

/** Rates to RUB from the Central Bank of Russia daily XML, with cache and fallback
 * (mirrors `ExchangeRates.swift` on iOS). */
@Serializable
class RateSnapshot(
    val rates: Map<String, Double> = emptyMap(),
    /** Date of the CBR quote (from the XML `Date` attribute). */
    val quoteDate: String? = null,
    /** ISO-8601 instant of the fetch (String so kotlinx can serialize it). */
    val fetchedAt: String = "1970-01-01T00:00:00Z",
    val isFallback: Boolean = true,
) {
    val fetchedAtTime: Instant
        get() = try {
            Instant.parse(fetchedAt)
        } catch (_: Exception) {
            Instant.EPOCH
        }

    fun rate(currency: Currency): Double {
        if (currency == Currency.RUB) return 1.0
        return rates[currency.code] ?: ExchangeRates.fallback[currency] ?: 1.0
    }

    companion object {
        val fallback = RateSnapshot(
            rates = ExchangeRates.fallback.entries.associate { it.key.code to it.value },
            quoteDate = null,
            fetchedAt = "1970-01-01T00:00:00Z",
            isFallback = true,
        )
    }
}

object ExchangeRates {
    const val URL = "https://www.cbr.ru/scripts/XML_daily.asp"
    val fallback: Map<Currency, Double> = mapOf(Currency.USD to 90.0, Currency.EUR to 98.0)
    const val CACHE_KEY = "rates.snapshot"
    /** Refresh at most this often; CBR publishes once a day. */
    const val MAX_AGE_MS: Long = 6 * 3600L * 1000L

    private val json = Json { ignoreUnknownKeys = true }

    private val QUOTE_DATE: DateTimeFormatter = DateTimeFormatter.ofPattern("dd.MM.yyyy")

    fun cached(text: String?): RateSnapshot {
        if (text.isNullOrBlank()) return RateSnapshot.fallback
        return try {
            json.decodeFromString(RateSnapshot.serializer(), text)
        } catch (_: Exception) {
            RateSnapshot.fallback
        }
    }

    fun store(snapshot: RateSnapshot): String = json.encodeToString(RateSnapshot.serializer(), snapshot)

    @Throws(IOException::class)
    fun fetch(): RateSnapshot {
        val connection = URL(URL).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        connection.setRequestProperty("User-Agent", "Kiper/1.0 (Android)")
        try {
            if (connection.responseCode != 200) throw IOException("HTTP ${connection.responseCode}")
            val body = connection.inputStream.readBytes()
            val parsed = parse(body)
            if (parsed.rates.isEmpty()) throw IOException("Cannot parse CBR response")
            return RateSnapshot(
                rates = parsed.rates,
                quoteDate = parsed.date?.format(DateTimeFormatter.ISO_LOCAL_DATE),
                fetchedAt = Instant.now().toString(),
                isFallback = false,
            )
        } finally {
            connection.disconnect()
        }
    }

    /** Parses `ValCurs` XML. The feed is windows-1251; the SAX parser honours the
     * encoding declared in the prolog. Values use a decimal comma and a `Nominal`. */
    fun parse(data: ByteArray): Parsed {
        val handler = CBRParser()
        val factory = SAXParserFactory.newInstance()
        factory.isNamespaceAware = false
        factory.newSAXParser().parse(data.inputStream(), handler)
        return Parsed(handler.rates, handler.date)
    }

    class Parsed(val rates: Map<String, Double>, val date: LocalDate?)

    private class CBRParser : DefaultHandler() {
        val rates = HashMap<String, Double>()
        var date: LocalDate? = null

        private var code = ""
        private var nominal = ""
        private var value = ""
        private var element = ""
        private val wanted = Currency.entries.map { it.code }.toSet()

        override fun startElement(uri: String?, localName: String?, qName: String?, attributes: Attributes?) {
            element = qName ?: localName ?: ""
            if (element == "ValCurs") {
                attributes?.getValue("Date")?.let { raw ->
                    date = try {
                        LocalDate.parse(raw, QUOTE_DATE)
                    } catch (_: Exception) {
                        null
                    }
                }
            }
            if (element == "Valute") {
                code = ""; nominal = ""; value = ""
            }
        }

        override fun characters(ch: CharArray, start: Int, length: Int) {
            when (element) {
                "CharCode" -> code += String(ch, start, length)
                "Nominal" -> nominal += String(ch, start, length)
                "Value" -> value += String(ch, start, length)
            }
        }

        override fun endElement(uri: String?, localName: String?, qName: String?) {
            if (qName == "Valute" || localName == "Valute") {
                val c = code.trim()
                val n = nominal.trim().toDoubleOrNull() ?: 1.0
                val v = value.trim().replace(",", ".").toDoubleOrNull()
                if (c in wanted && v != null && n > 0) rates[c] = v / n
            }
            element = ""
        }
    }
}
