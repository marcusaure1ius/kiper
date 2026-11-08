package ru.kiper.android.ui.subs

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Inbox
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.InputChip
import androidx.compose.material3.InputChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import ru.kiper.android.KiperApp
import ru.kiper.android.data.Fmt
import ru.kiper.android.data.Subscription
import ru.kiper.android.data.SubscriptionStatus
import ru.kiper.android.ui.components.SubscriptionLogo
import ru.kiper.android.ui.components.SubscriptionRow
import ru.kiper.android.ui.components.categoryColor
import ru.kiper.android.ui.components.categoryIcon
import ru.kiper.android.ui.theme.colorHex

/** All subscriptions with category filter chips (mirrors `SubscriptionsListScreen`). */
@Composable
fun SubscriptionsListScreen(onBack: () -> Unit, onOpenDetail: (String) -> Unit, onAdd: () -> Unit) {
    val store = KiperApp.store
    var filter by remember { mutableStateOf<String?>(null) }
    var search by remember { mutableStateOf("") }

    val items = store.subscriptions
        .filter { it.status != SubscriptionStatus.CANCELLED }
        .filter { filter == null || it.categoryId == filter }
        .filter { search.isEmpty() || it.name.contains(search, ignoreCase = true) }
        .sortedWith(compareBy({ rank(it) }, { it.nextBillingDate }))

    Column(Modifier.fillMaxSize()) {
        // Header: back, title, search, add.
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Назад")
            }
            Text("Подписки", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Box(Modifier.weight(1f))
            IconButton(onClick = onAdd) {
                Icon(Icons.Rounded.Add, contentDescription = "Добавить")
            }
        }
        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            placeholder = { Text("Поиск") },
            leadingIcon = { Icon(Icons.Rounded.Search, null) },
            singleLine = true,
            shape = RoundedCornerShape(18.dp),
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        )
        // Category filter chips.
        Row(
            Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            FilterChipKiper(id = null, title = "Все", symbol = null, selected = filter == null) { filter = null }
            for (cat in store.categories) {
                FilterChipKiper(id = cat.id, title = cat.name, symbol = cat.symbol, selected = filter == cat.id) {
                    filter = if (filter == cat.id) null else cat.id
                }
            }
        }

        LazyColumn(
            contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                val active = items.filter { it.status == SubscriptionStatus.ACTIVE }
                val monthly = active.sumOf { store.toRub(it.amount, it.currency) * it.billingPeriod.monthlyEquivalent }
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 6.dp, vertical = 6.dp),
                ) {
                    Text(
                        "${active.size} активных",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Box(Modifier.weight(1f))
                    Text(
                        "${Fmt.rub(monthly)} / мес",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            items(items.size, key = { items[it].id }) { i ->
                val sub = items[i]
                Box(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(22.dp))
                        .background(MaterialTheme.colorScheme.surface)
                        .clickable { onOpenDetail(sub.id) }
                        .padding(14.dp)
                        .let { if (sub.status == SubscriptionStatus.PAUSED) it.alpha(0.55f) else it }
                    ,
                ) {
                    SubscriptionRow(
                        subscription = sub,
                        category = store.category(sub.categoryId),
                        subtitle = subtitleFor(sub),
                        toRub = store::toRub,
                    )
                }
            }
            if (items.isEmpty()) {
                item {
                    Column(
                        Modifier.fillMaxWidth().padding(vertical = 48.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Icon(
                            Icons.Rounded.Inbox,
                            null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(36.dp),
                        )
                        Text(
                            when {
                                search.isNotEmpty() -> "Ничего не найдено"
                                filter != null -> "В этой категории пусто"
                                else -> "Пока нет подписок"
                            },
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                        if (filter != null) {
                            Text(
                                "Выберите другую категорию или добавьте подписку.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center,
                            )
                        }
                        if (search.isEmpty() && filter == null) {
                            Button(onClick = onAdd, modifier = Modifier.padding(top = 4.dp)) {
                                Icon(Icons.Rounded.Add, null, Modifier.size(18.dp))
                                androidx.compose.foundation.layout.Spacer(Modifier.size(6.dp))
                                Text("Добавить подписку")
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Active first, then trials (upcoming money), then paused.
private fun rank(sub: Subscription): Int = when (sub.status) {
    SubscriptionStatus.ACTIVE -> 0
    SubscriptionStatus.TRIAL -> 1
    else -> 2
}

private fun subtitleFor(sub: Subscription): String {
    if (sub.status == SubscriptionStatus.PAUSED) return "Приостановлена"
    if (sub.status == SubscriptionStatus.TRIAL) {
        val end = sub.trialEndDate
        if (end != null) return "Триал до ${Fmt.day(end)}"
    }
    return "${sub.billingPeriod.label} · ${Fmt.day(sub.nextBillingDate)}"
}

@Composable
private fun FilterChipKiper(id: String?, title: String, symbol: String?, selected: Boolean, onClick: () -> Unit) {
    val cat = KiperApp.store.categories.firstOrNull { it.id == id }
    val tint = cat?.let { colorHex(it.colorHex) }
    InputChip(
        selected = selected,
        onClick = onClick,
        label = { Text(title) },
        leadingIcon = if (symbol != null) {
            {
                Icon(
                    categoryIcon(symbol),
                    null,
                    tint = if (selected) (tint ?: MaterialTheme.colorScheme.primary) else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(16.dp),
                )
            }
        } else null,
        colors = InputChipDefaults.inputChipColors(
            selectedContainerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.14f),
        ),
    )
}

private fun Modifier.alphaCompat(a: Float): Modifier = this.alpha(a)
