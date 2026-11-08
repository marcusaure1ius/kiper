package ru.kiper.android.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class BackupTest {

    /** A v1 backup from another Kiper platform (cross-platform contract). */
    private val flutterJson = """
    {
      "version": 1,
      "exportedAt": "2026-11-08T10:00:00.000",
      "subscriptions": [
        {
          "id": "abc-1", "name": "Netflix", "icon": null, "amount": 22.99,
          "currency": "USD", "billingPeriod": "monthly", "customPeriodDays": null,
          "categoryId": "cat-streaming", "nextBillingDate": "2026-11-20T00:00:00.000",
          "startDate": "2024-03-01T00:00:00.000", "status": "active",
          "reminderDaysBefore": 1, "note": "Основной аккаунт", "createdAt": "2024-03-01T00:00:00.000",
          "domain": "netflix.com", "trialEndDate": null
        },
        {
          "id": "abc-2", "name": "Claude", "amount": 20.0, "currency": "usd",
          "billingPeriod": "monthly", "nextBillingDate": "2026-11-15T00:00:00.000",
          "startDate": "2026-11-15T00:00:00.000", "status": "trial",
          "trialEndDate": "2026-11-22T00:00:00.000"
        }
      ],
      "categories": [
        {"id": "cat-streaming", "name": "Стриминг", "color": 4286336511, "icon": "movie"}
      ],
      "settings": {"budgetRub": "12000"},
      "payments": [
        {"subscriptionId": "abc-1", "date": "2026-10-20T00:00:00.000", "amount": 22.99,
         "currency": "USD", "amountRub": 1892.0, "kind": "charge", "source": "auto"}
      ]
    }
    """.trimIndent()

    @Test
    fun decodesCrossPlatformFormat() {
        val file = BackupMapper.decode(flutterJson)
        assertEquals(1, file.version)
        assertEquals(2, file.subscriptions.size)
        assertEquals("12000", file.settings["budgetRub"])
        assertEquals(1, file.payments?.size)

        val netflix = BackupMapper.subscription(file.subscriptions[0])!!
        assertEquals(Currency.USD, netflix.currency)
        assertEquals(LocalDate.of(2026, 11, 20), netflix.nextBillingDate)
        assertEquals("Основной аккаунт", netflix.note)

        val claude = BackupMapper.subscription(file.subscriptions[1])!!
        assertEquals(SubscriptionStatus.TRIAL, claude.status)
        assertEquals(LocalDate.of(2026, 11, 22), claude.trialEndDate)

        val category = BackupMapper.category(file.categories[0])
        assertEquals("Стриминг", category.name)
        assertEquals(0x7C4DFF, category.colorHex)
        // Material name mapped back to the SF symbol storage form.
        assertEquals("play.tv.fill", category.symbol)

        val payment = BackupMapper.payment(file.payments!![0])!!
        assertEquals("abc-1-2026-10-20", payment.id)
    }

    @Test
    fun roundTripKeepsFields() {
        val sub = Subscription(
            id = "x-1", name = "Тест", amount = 499.0, currency = Currency.RUB,
            billingPeriod = BillingPeriod.QUARTERLY, categoryId = "cat-ai",
            nextBillingDate = LocalDate.of(2027, 1, 5), reminderDaysBefore = 3,
            status = SubscriptionStatus.PAUSED, trialEndDate = null,
            startDate = LocalDate.of(2025, 6, 1), note = "заметка",
            domain = "example.com", createdAt = LocalDate.of(2025, 6, 1), icon = null,
        )
        val dto = BackupMapper.dto(sub)
        val json = BackupMapper.encode(BackupFile(exportedAt = "", subscriptions = listOf(dto)))
        val decoded = BackupMapper.decode(json)
        val restored = BackupMapper.subscription(decoded.subscriptions[0])!!
        assertEquals(sub.id, restored.id)
        assertEquals(sub.billingPeriod, restored.billingPeriod)
        assertEquals(sub.reminderDaysBefore, restored.reminderDaysBefore)
        assertEquals(sub.status, restored.status)
        assertEquals(sub.note, restored.note)
        assertEquals(sub.domain, restored.domain)
        assertEquals(sub.nextBillingDate, restored.nextBillingDate)
    }

    @Test
    fun tolerantDateParsing() {
        // Dart emits 3 or 6 fractional digits; zoned ISO converts to the device zone.
        assertEquals(LocalDate.of(2026, 3, 1), BackupMapper.date("2026-03-01T00:00:00.000"))
        assertEquals(LocalDate.of(2026, 3, 1), BackupMapper.date("2026-03-01T00:00:00.000000"))
        assertEquals(LocalDate.of(2026, 3, 1), BackupMapper.date("2026-03-01T00:00:00"))
        assertEquals(LocalDate.of(2026, 3, 1), BackupMapper.date("2026-03-01"))
        // A zoned string is an absolute instant: converted to the device zone.
        val zoned = BackupMapper.date("2026-03-01T22:30:00Z")
        val expected = java.time.OffsetDateTime.parse("2026-03-01T22:30:00Z")
            .atZoneSameInstant(java.time.ZoneId.systemDefault()).toLocalDate()
        assertEquals(expected, zoned)
        assertNull(BackupMapper.date("мусор"))
    }

    @Test
    fun rejectsNewerVersion() {
        try {
            BackupMapper.decode("""{"version": 99, "exportedAt": "", "subscriptions": [], "categories": []}""")
            throw AssertionError("must throw")
        } catch (e: BackupException) {
            assertTrue(e.message!!.contains("версии"))
        }
    }

    @Test
    fun paymentIdIsSubscriptionPlusDay() {
        assertEquals(
            "sub-1-2026-11-08",
            PaymentRecord.makeId("sub-1", LocalDate.of(2026, 11, 8)),
        )
    }
}
