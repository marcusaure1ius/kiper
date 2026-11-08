package ru.kiper.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Apps
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CellTower
import androidx.compose.material.icons.rounded.Cloud
import androidx.compose.material.icons.rounded.CreditCard
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material.icons.rounded.Movie
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.ShoppingBag
import androidx.compose.material.icons.rounded.SmartToy
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import ru.kiper.android.data.Category
import ru.kiper.android.data.Currency
import ru.kiper.android.data.Fmt
import ru.kiper.android.data.Subscription
import ru.kiper.android.ui.theme.colorHex

/** SF Symbol (cross-platform storage name) → Material icon for rendering. */
fun categoryIcon(symbol: String?): ImageVector = when (symbol) {
    "play.tv.fill", "movie" -> Icons.Rounded.Movie
    "sparkles", "smart_toy" -> Icons.Rounded.AutoAwesome
    "antenna.radiowaves.left.and.right", "phone_android" -> Icons.Rounded.CellTower
    "gamecontroller.fill", "sports_esports" -> Icons.Rounded.SportsEsports
    "square.grid.2x2.fill", "category" -> Icons.Rounded.Apps
    "music.note", "music_note" -> Icons.Rounded.MusicNote
    "book.fill", "book" -> Icons.Rounded.MenuBook
    "cloud.fill", "cloud" -> Icons.Rounded.Cloud
    "lock.shield.fill", "security" -> Icons.Rounded.Shield
    "bag.fill", "shopping_bag" -> Icons.Rounded.ShoppingBag
    else -> Icons.Rounded.CreditCard
}

fun categoryColor(category: Category?): Color =
    category?.let { colorHex(it.colorHex) } ?: Color(0xFF9E9E9E)

/** Service favicon with a category-coloured icon fallback. */
@Composable
fun SubscriptionLogo(subscription: Subscription, category: Category?, size: Dp = 44.dp) {
    val tint = categoryColor(category)
    Column(
        modifier = Modifier
            .size(size)
            .clip(RoundedCornerShape(size * 0.28f))
            .background(tint.copy(alpha = 0.18f)),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        val url = subscription.logoUrl
        if (url != null) {
            AsyncImage(
                model = url,
                contentDescription = null,
                modifier = Modifier.size(size * 0.62f),
            )
        } else {
            Icon(
                categoryIcon(category?.symbol),
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(size * 0.42f),
            )
        }
    }
}

/** Original amount + RUB equivalent (CLAUDE.md: always show both). */
@Composable
fun AmountLabel(amount: Double, currency: Currency, toRub: (Double, Currency) -> Double, alignEnd: Boolean = true) {
    Column(
        horizontalAlignment = if (alignEnd) Alignment.End else Alignment.Start,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            Fmt.money(amount, currency),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold,
            textAlign = if (alignEnd) TextAlign.End else TextAlign.Start,
        )
        if (currency != Currency.RUB) {
            Text(
                "≈ ${Fmt.rub(toRub(amount, currency))}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** A row used in payment lists and the subscriptions list. */
@Composable
fun SubscriptionRow(subscription: Subscription, category: Category?, subtitle: String, toRub: (Double, Currency) -> Double) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth(),
    ) {
        SubscriptionLogo(subscription, category)
        Spacer(Modifier.width(16.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(
                subscription.name,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
            )
            Text(
                subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
        Spacer(Modifier.width(8.dp))
        AmountLabel(subscription.amount, subscription.currency, toRub)
    }
}

/** Rounded content card. Content stays on a solid-ish surface; translucent
 * controls sit on the flowing backdrop. */
@Composable
fun Card(content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(26.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
    ) {
        content()
    }
}

/** Section header inside a card (bold first line, muted second). */
@Composable
fun CardTitle(title: String, caption: String? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        if (caption != null) {
            Text(caption, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun VerticalSpace(height: Dp) {
    Spacer(Modifier.height(height))
}
