package ru.kiper.android.ui.subs

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import ru.kiper.android.KiperApp
import ru.kiper.android.data.BillingPeriod
import ru.kiper.android.data.CatalogEntry
import ru.kiper.android.data.Currency
import ru.kiper.android.data.Fmt
import ru.kiper.android.data.Subscription
import ru.kiper.android.data.SubscriptionStatus
import ru.kiper.android.data.newId
import ru.kiper.android.ui.components.SubscriptionLogo
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** Prefill for a new subscription: a catalog entry, or just a typed name. */
data class FormPreset(val entry: CatalogEntry? = null, val name: String? = null)

/** Editing an existing subscription: the form in its own sheet with Cancel. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SubscriptionFormSheet(editing: Subscription, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        SubscriptionForm(editing = editing, showsCancel = true, onDone = onDismiss)
    }
}

/** The single "add subscription" flow: search-first catalog, then the form
 * inside the same sheet (mirrors `AddSubscriptionFlow`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddSubscriptionSheet(onDismiss: () -> Unit) {
    var search by remember { mutableStateOf("") }
    var preset by remember { mutableStateOf<FormPreset?>(null) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        val chosen = preset
        if (chosen == null) {
            CatalogStep(
                search = search,
                onSearch = { search = it },
                onPick = { preset = it },
            )
        } else {
            SubscriptionForm(
                preset = chosen,
                showsCancel = true,
                onDone = onDismiss,
            )
        }
    }
}

@Composable
private fun CatalogStep(search: String, onSearch: (String) -> Unit, onPick: (FormPreset) -> Unit) {
    val store = KiperApp.store
    val query = search.trim()
    val matches = if (query.isEmpty()) CatalogEntry.all
    else CatalogEntry.all.filter { it.name.contains(query, ignoreCase = true) }

    Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
        OutlinedTextField(
            value = search,
            onValueChange = onSearch,
            placeholder = { Text("Название сервиса") },
            singleLine = true,
            shape = RoundedCornerShape(18.dp),
            modifier = Modifier.fillMaxWidth(),
        )
        Row(
            Modifier.fillMaxWidth().padding(vertical = 10.dp)
                .clickable { onPick(FormPreset(name = query.ifEmpty { null })) },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                if (query.isEmpty()) Icons.Rounded.Edit else Icons.Rounded.Add,
                null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Text(
                if (query.isEmpty()) "Своя подписка" else "Создать «$query»",
                modifier = Modifier.padding(start = 12.dp),
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
            )
        }
        if (query.isEmpty()) {
            Text(
                "Или выберите сервис — название, валюта и период подставятся сами.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        for ((categoryId, groupName) in CatalogEntry.groups) {
            val items = matches.filter { it.categoryId == categoryId }
            if (items.isEmpty()) continue
            Text(
                groupName,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(top = 14.dp, bottom = 4.dp),
            )
            for (entry in items) {
                Row(
                    Modifier.fillMaxWidth()
                        .clickable { onPick(FormPreset(entry = entry)) }
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SubscriptionLogo(entry.asSubscription(), store.category(entry.categoryId), size = 36.dp)
                    Text(
                        entry.name,
                        modifier = Modifier.padding(start = 12.dp).weight(1f),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Text(entry.currency.symbol, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        Column(Modifier.height(24.dp)) {}
    }
}

/**
 * Form body (mirrors `SubscriptionForm`): name, amount+currency, period,
 * category, dates, trial, reminder, note. Mutations bump a version counter so
 * Compose recomposes (the draft is a mutable domain object).
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun SubscriptionForm(
    editing: Subscription? = null,
    preset: FormPreset? = null,
    showsCancel: Boolean = false,
    onDone: () -> Unit,
) {
    val store = KiperApp.store
    val draft = remember {
        editing ?: Subscription(
            id = newId(),
            name = "",
            amount = 0.0,
            currency = Currency.RUB,
            billingPeriod = BillingPeriod.MONTHLY,
            nextBillingDate = LocalDate.now().plusMonths(1),
            startDate = LocalDate.now(),
        ).also { d ->
            preset?.entry?.let { e ->
                d.name = e.name
                d.currency = e.currency
                d.billingPeriod = e.period
                d.categoryId = e.categoryId
                d.domain = e.domain
            }
            preset?.name?.let { d.name = it }
        }
    }
    var version by remember { mutableIntStateOf(0) }
    fun mutate(update: (Subscription) -> Unit) {
        update(draft)
        version += 1
    }

    var amountText by remember { mutableStateOf(if (draft.amount == 0.0) "" else trimAmount(draft.amount)) }
    var trialOn by remember { mutableStateOf(draft.status == SubscriptionStatus.TRIAL) }
    var openDateField by remember { mutableStateOf<String?>(null) } // "next" | "trialEnd"

    LaunchedEffect(Unit) {
        // A category from the catalog may have been deleted by the user.
        val id = draft.categoryId
        if (id != null && store.category(id) == null) mutate { it.categoryId = null }
    }

    val amount = amountText.replace(",", ".").toDoubleOrNull()
    val isValid = draft.name.trim().isNotEmpty() && (amount ?: 0.0) > 0

    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            if (editing == null) "Новая подписка" else "Редактирование",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )
        OutlinedTextField(
            value = draft.name,
            onValueChange = { value -> mutate { it.name = value } },
            placeholder = { Text("Название") },
            singleLine = true,
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedTextField(
                value = amountText,
                onValueChange = { amountText = it },
                placeholder = { Text("Сумма") },
                singleLine = true,
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.weight(1f),
            )
            Row(
                Modifier.background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(16.dp)).padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                for (currency in Currency.entries) {
                    FilterChip(
                        selected = draft.currency == currency,
                        onClick = { mutate { it.currency = currency } },
                        label = { Text(currency.symbol) },
                    )
                }
            }
        }
        if (amount != null && draft.currency != Currency.RUB) {
            Text(
                "В рублях ≈ ${Fmt.rub(store.toRub(amount, draft.currency))}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        // Period picker as chips.
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Период", style = MaterialTheme.typography.titleSmall)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (period in BillingPeriod.entries) {
                    FilterChip(
                        selected = draft.billingPeriod == period,
                        onClick = { mutate { it.billingPeriod = period } },
                        label = { Text(period.label) },
                    )
                }
            }
            if (draft.billingPeriod == BillingPeriod.CUSTOM) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Каждые", style = MaterialTheme.typography.bodyMedium)
                    OutlinedTextField(
                        value = (draft.customPeriodDays ?: 30).toString(),
                        onValueChange = { value ->
                            val days = value.toIntOrNull() ?: return@OutlinedTextField
                            mutate { it.customPeriodDays = days.coerceIn(1, 365) }
                        },
                        singleLine = true,
                        modifier = Modifier.width(90.dp),
                    )
                    Text("дн.", style = MaterialTheme.typography.bodyMedium)
                }
            }
        }

        // Category picker.
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Категория", style = MaterialTheme.typography.titleSmall)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = draft.categoryId == null,
                    onClick = { mutate { it.categoryId = null } },
                    label = { Text("Без категории") },
                )
                for (cat in store.categories) {
                    FilterChip(
                        selected = draft.categoryId == cat.id,
                        onClick = { mutate { it.categoryId = cat.id } },
                        label = { Text(cat.name) },
                    )
                }
            }
        }

        // Trial + dates.
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Триал (бесплатный период)", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
            Switch(
                checked = trialOn,
                onCheckedChange = { on ->
                    trialOn = on
                    if (on) {
                        mutate { d ->
                            d.status = SubscriptionStatus.TRIAL
                            if (d.trialEndDate == null) d.trialEndDate = LocalDate.now().plusDays(7)
                            val end = d.trialEndDate
                            if (editing == null && end != null) d.nextBillingDate = end
                        }
                    } else if (draft.status == SubscriptionStatus.TRIAL) {
                        mutate { d ->
                            d.status = SubscriptionStatus.ACTIVE
                            d.trialEndDate = null
                        }
                    }
                },
            )
        }
        if (trialOn) {
            DateRow(
                title = "Окончание триала",
                date = draft.trialEndDate ?: LocalDate.now(),
                isOpen = openDateField == "trialEnd",
                onToggle = { openDateField = if (openDateField == "trialEnd") null else "trialEnd" },
                onPick = { newDate ->
                    mutate { d ->
                        val old = d.trialEndDate
                        d.trialEndDate = newDate
                        // Moving the trial end moves the first charge along, unless
                        // it was set apart.
                        if (old != null && d.nextBillingDate == old) d.nextBillingDate = newDate
                    }
                },
            )
            DateRow(
                title = "Первое списание",
                date = draft.nextBillingDate,
                isOpen = openDateField == "next",
                onToggle = { openDateField = if (openDateField == "next") null else "next" },
                onPick = { newDate -> mutate { it.nextBillingDate = newDate } },
            )
        } else {
            DateRow(
                title = "Дата списания",
                date = draft.nextBillingDate,
                isOpen = openDateField == "next",
                onToggle = { openDateField = if (openDateField == "next") null else "next" },
                onPick = { newDate -> mutate { it.nextBillingDate = newDate } },
            )
        }

        // Reminder picker.
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Напоминание", style = MaterialTheme.typography.titleSmall)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val options = listOf(0 to "Выключено", 1 to "За 1 день", 3 to "За 3 дня", 7 to "За 7 дней")
                for ((days, label) in options) {
                    FilterChip(
                        selected = draft.reminderDaysBefore == days,
                        onClick = { mutate { it.reminderDaysBefore = days } },
                        label = { Text(label) },
                    )
                }
            }
        }

        OutlinedTextField(
            value = draft.note ?: "",
            onValueChange = { value -> mutate { it.note = value.ifEmpty { null } } },
            placeholder = { Text("Заметка (необязательно)") },
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth(),
            minLines = 2,
            maxLines = 5,
        )

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(bottom = 24.dp)) {
            if (showsCancel) {
                TextButton(onClick = onDone) { Text("Отмена") }
            }
            Button(
                onClick = {
                    draft.amount = amount ?: 0.0
                    // No separate start date in the form: a new subscription starts
                    // with its first charge (a trial starts today); an edited one
                    // never starts after its next charge.
                    if (editing == null || draft.nextBillingDate < draft.startDate) {
                        draft.startDate = if (draft.status == SubscriptionStatus.TRIAL) LocalDate.now() else draft.nextBillingDate
                    }
                    store.upsert(draft)
                    store.show(if (editing == null) "Подписка добавлена" else "Изменения сохранены")
                    onDone()
                },
                enabled = isValid,
                modifier = Modifier.weight(1f).height(52.dp),
            ) {
                Text(if (editing == null) "Добавить" else "Сохранить", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

private fun trimAmount(amount: Double): String =
    if (amount == amount.toLong().toDouble()) amount.toLong().toString() else amount.toString()

/** Date-app style row: full date, tap to expand an inline calendar. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DateRow(title: String, date: LocalDate, isOpen: Boolean, onToggle: () -> Unit, onPick: (LocalDate) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            Modifier.fillMaxWidth().clickable(onClick = onToggle),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(title, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
            Text(
                Fmt.smartDate(date),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = if (isOpen) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (isOpen) {
            val state = rememberDatePickerState(
                initialSelectedDateMillis = date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli(),
            )
            DatePicker(state = state, modifier = Modifier.fillMaxWidth(), title = null, headline = null)
            LaunchedEffect(state.selectedDateMillis) {
                val millis = state.selectedDateMillis ?: return@LaunchedEffect
                onPick(Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate())
            }
        }
    }
}
