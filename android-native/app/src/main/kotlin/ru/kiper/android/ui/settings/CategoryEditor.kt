package ru.kiper.android.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Apps
import androidx.compose.material.icons.rounded.CellTower
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Cloud
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PlayCircle
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.ShoppingBag
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import ru.kiper.android.KiperApp
import ru.kiper.android.data.Category
import ru.kiper.android.data.IconMap
import ru.kiper.android.data.newId
import ru.kiper.android.ui.components.categoryIcon
import ru.kiper.android.ui.theme.colorHex

/** Category CRUD sheet (mirrors `CategoryEditorSheet`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoryEditorSheet(onDismiss: () -> Unit) {
    val store = KiperApp.store
    var editing by remember { mutableStateOf<Category?>(null) }
    var creating by remember { mutableStateOf(false) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        val open = editing != null || creating
        if (open) {
            CategoryForm(category = editing) {
                editing = null
                creating = false
            }
        } else {
            LazyColumn(Modifier.padding(horizontal = 16.dp)) {
                item {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            "Категории",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.weight(1f),
                        )
                        IconButton(onClick = { creating = true }) {
                            Icon(Icons.Rounded.Add, contentDescription = "Добавить")
                        }
                    }
                }
                for (cat in store.categories) {
                    item {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                        ) {
                            Box(
                                Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(colorHex(cat.colorHex).copy(alpha = 0.2f)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    categoryIcon(cat.symbol),
                                    null,
                                    tint = colorHex(cat.colorHex),
                                    modifier = Modifier.size(20.dp),
                                )
                            }
                            Text(
                                cat.name,
                                style = MaterialTheme.typography.bodyLarge,
                                modifier = Modifier.weight(1f).padding(start = 12.dp),
                            )
                            IconButton(onClick = { editing = cat }) {
                                Icon(Icons.Rounded.Edit, contentDescription = "Изменить")
                            }
                            IconButton(onClick = {
                                store.deleteCategory(cat.id)
                                store.show("Категория удалена")
                            }) {
                                Icon(
                                    Icons.Rounded.Delete,
                                    contentDescription = "Удалить",
                                    tint = MaterialTheme.colorScheme.error,
                                )
                            }
                        }
                    }
                }
                item { Box(Modifier.size(32.dp)) }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CategoryForm(category: Category?, onDone: () -> Unit) {
    val store = KiperApp.store
    var name by remember { mutableStateOf(category?.name ?: "") }
    var selectedHex by remember { mutableStateOf(category?.colorHex ?: 0x7C4DFF) }
    var symbol by remember { mutableStateOf(category?.symbol ?: IconMap.FALLBACK_SYMBOL) }

    val palette = listOf(
        0x7C4DFF, 0x2196F3, 0xFF6B35, 0xE50914, 0x9E9E9E,
        0x0E9F7E, 0xD13F8A, 0xE8553A, 0x1E7FD9, 0x4A505C,
    )
    val symbols = listOf(
        "play.tv.fill", "sparkles", "antenna.radiowaves.left.and.right",
        "gamecontroller.fill", "square.grid.2x2.fill", "music.note",
        "book.fill", "cloud.fill", "lock.shield.fill", "bag.fill",
    )

    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            if (category == null) "Новая категория" else "Редактирование",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            placeholder = { Text("Название") },
            singleLine = true,
            shape = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth(),
        )
        FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            for (hex in palette) {
                Box(
                    Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(colorHex(hex))
                        .clickable { selectedHex = hex },
                    contentAlignment = Alignment.Center,
                ) {
                    if (selectedHex == hex) {
                        Icon(
                            Icons.Rounded.Check,
                            null,
                            tint = Color.White,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                }
            }
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (sf in symbols) {
                FilterChip(
                    selected = symbol == sf,
                    onClick = { symbol = sf },
                    label = { Text("") },
                    leadingIcon = {
                        Icon(categoryIcon(sf), null, tint = colorHex(selectedHex), modifier = Modifier.size(18.dp))
                    },
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(bottom = 24.dp)) {
            TextButton(onClick = onDone) { Text("Отмена") }
            Button(
                onClick = {
                    val saved = category ?: Category(newId(), name, selectedHex, symbol)
                    saved.name = name
                    saved.colorHex = selectedHex
                    saved.symbol = symbol
                    store.upsertCategory(saved)
                    store.show(if (category == null) "Категория добавлена" else "Категория сохранена")
                    onDone()
                },
                enabled = name.trim().isNotEmpty(),
                modifier = Modifier.weight(1f),
            ) { Text("Сохранить") }
        }
    }
}
