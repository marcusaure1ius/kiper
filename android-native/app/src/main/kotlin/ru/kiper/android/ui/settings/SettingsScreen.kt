package ru.kiper.android.ui.settings

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Category
import androidx.compose.material.icons.rounded.CloudSync
import androidx.compose.material.icons.rounded.DeleteForever
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.FolderCopy
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Savings
import androidx.compose.material.icons.rounded.UploadFile
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import ru.kiper.android.KiperApp
import ru.kiper.android.data.AppStore
import ru.kiper.android.data.BackupMapper
import ru.kiper.android.data.Category
import ru.kiper.android.data.CsvCodec
import ru.kiper.android.data.Fmt
import ru.kiper.android.data.Ics
import ru.kiper.android.data.StatementImporter
import ru.kiper.android.ui.theme.BackgroundStyle
import java.time.LocalDate

/** Settings tab (mirrors `SettingsScreen`): appearance, reminders, budget,
 * privacy, categories, rates, auto-backup, data tools. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun SettingsScreen() {
    val store = KiperApp.store
    val context = LocalContext.current
    val prefs = context.getSharedPreferences("kiper", Context.MODE_PRIVATE)

    var showBudget by remember { mutableStateOf(false) }
    var showCategories by remember { mutableStateOf(false) }
    var showStatement by remember { mutableStateOf(false) }
    var showDeleteAll by remember { mutableStateOf(false) }
    var statementText by remember { mutableStateOf<String?>(null) }

    // Export launchers.
    val exportJson = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri != null) writeText(context, uri, BackupMapper.encode(store.backup()))
    }
    val exportCsv = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        if (uri != null) writeText(context, uri, CsvCodec.encode(store.notCancelled))
    }
    val exportIcs = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/calendar")) { uri ->
        if (uri != null) writeText(context, uri, Ics.calendar(store.futurePayments(365)))
    }
    val importFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            val text = readText(context, uri) ?: return@rememberLauncherForActivityResult
            if (text.trimStart().startsWith("{")) {
                try {
                    val result = store.importBackup(BackupMapper.decode(text), AppStore.ImportMode.MERGE)
                    store.show("Импортировано: подписки ${result.subscriptions}, категории ${result.categories}" +
                        if (result.skipped > 0) ", пропущено ${result.skipped}" else "")
                } catch (e: Exception) {
                    store.show(e.message ?: "Не удалось прочитать файл", isError = true)
                }
            } else {
                val result = store.importCsv(text)
                store.show("Импортировано из CSV: ${result.subscriptions}")
            }
        }
    }
    val statementFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            val text = readText(context, uri) ?: return@rememberLauncherForActivityResult
            statementText = text
            showStatement = true
        }
    }
    val backupFolder = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri != null) {
            store.autoBackup.setTree(uri)
            store.autoBackup.run(store.backup())
            store.show("Автобэкап включён")
        }
    }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 16.dp, end = 16.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text(
                    "Настройки",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 18.dp, bottom = 2.dp),
                )
            }

            // loadError banner (quarantined file).
            store.loadError.value?.let { error ->
                item {
                    SectionCard("Проблема с данными") {
                        Text(
                            error,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                }
            }

            item {
                SectionCard("Внешний вид", Icons.Rounded.Palette) {
                    Text("Фон и акцент", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                        for (style in BackgroundStyle.entries) {
                            FilterChip(
                                selected = BackgroundStyle.of(store.backgroundStyle.value) == style,
                                onClick = { store.setBackgroundStyle(style.name) },
                                label = { Text(style.title) },
                                leadingIcon = {
                                    Box(
                                        Modifier.size(18.dp).clip(RoundedCornerShape(9.dp))
                                            .background(style.accent(dark = false)),
                                    )
                                },
                            )
                        }
                    }
                    Text("Тема", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 12.dp))
                    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(top = 8.dp)) {
                        SegmentedButton(
                            selected = store.themeMode.value == "system",
                            onClick = { store.setThemeMode("system") },
                            shape = SegmentedButtonDefaults.itemShape(index = 0, count = 3),
                        ) { Text("Системная") }
                        SegmentedButton(
                            selected = store.themeMode.value == "light",
                            onClick = { store.setThemeMode("light") },
                            shape = SegmentedButtonDefaults.itemShape(index = 1, count = 3),
                        ) { Text("Светлая") }
                        SegmentedButton(
                            selected = store.themeMode.value == "dark",
                            onClick = { store.setThemeMode("dark") },
                            shape = SegmentedButtonDefaults.itemShape(index = 2, count = 3),
                        ) { Text("Тёмная") }
                    }
                }
            }

            item {
                SectionCard("Напоминания", Icons.Rounded.Notifications) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Напоминать о списаниях", modifier = Modifier.weight(1f))
                        Switch(
                            checked = store.remindersEnabled,
                            onCheckedChange = { store.remindersEnabled = it },
                        )
                    }
                    if (store.remindersBlocked.value) {
                        Text(
                            "Уведомления запрещены в настройках системы",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFFEF6C00),
                        )
                    }
                    Text(
                        "Напоминания приходят в ${String.format("%02d:%02d", store.reminderHour, store.reminderMinute)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }

            item {
                SectionCard("Бюджет", Icons.Rounded.Savings) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("Лимит трат в месяц")
                            Text(
                                store.monthlyBudgetRub?.let { Fmt.rub(it) } ?: "Не задан",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        TextButton(onClick = { showBudget = true }) { Text("Изменить") }
                    }
                }
            }

            item {
                SectionCard("Приватность", Icons.Rounded.Lock) {
                    val locked = prefs.getBoolean("appLock.enabled", false)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("Биометрический замок")
                            Text(
                                "Запрашивать отпечаток/лицо при открытии",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Switch(
                            checked = locked,
                            onCheckedChange = { on ->
                                prefs.edit().putBoolean("appLock.enabled", on).apply()
                            },
                        )
                    }
                }
            }

            item {
                SectionCard("Категории", Icons.Rounded.Category) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            "${store.categories.size} категорий",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f),
                        )
                        TextButton(onClick = { showCategories = true }) { Text("Редактировать") }
                    }
                }
            }

            item {
                SectionCard("Курсы валют", Icons.Rounded.CloudSync) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        val snapshot = store.rateSnapshot.value
                        Column(Modifier.weight(1f)) {
                            Text("USD ${Fmt.money(snapshot.rate(ru.kiper.android.data.Currency.USD), ru.kiper.android.data.Currency.RUB, 2)} · EUR ${Fmt.money(snapshot.rate(ru.kiper.android.data.Currency.EUR), ru.kiper.android.data.Currency.RUB, 2)}")
                            Text(
                                if (snapshot.isFallback) "резервные курсы" else "ЦБ РФ",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        TextButton(
                            onClick = { store.refreshRates() },
                            enabled = !store.isRefreshingRates.value,
                        ) { Text("Обновить") }
                    }
                }
            }

            item {
                SectionCard("Резервная копия", Icons.Rounded.FolderCopy) {
                    val backup = store.autoBackup
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(if (backup.isEnabled) "Папка: ${backup.folderName ?: "выбрана"}" else "Копия в выбранную папку")
                            Text(
                                backup.lastError.value
                                    ?: backup.lastBackup.value?.let { "Последняя: ${Fmt.smartDate(it)}" }
                                    ?: "Не включён",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        TextButton(
                            onClick = {
                                if (backup.isEnabled) {
                                    backup.disable()
                                } else {
                                    backupFolder.launch(null)
                                }
                            },
                        ) { Text(if (backup.isEnabled) "Выключить" else "Включить") }
                    }
                }
            }

            item {
                SectionCard("Данные", Icons.Rounded.Description) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 4.dp)) {
                        TextButton(onClick = { exportJson.launch("kiper-backup.json") }) { Text("JSON") }
                        TextButton(onClick = { exportCsv.launch("kiper.csv") }) { Text("CSV") }
                        TextButton(onClick = { exportIcs.launch("kiper.ics") }) { Text("Календарь") }
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 4.dp)) {
                        TextButton(onClick = { importFile.launch(arrayOf("application/json", "text/csv", "text/plain", "application/csv")) }) {
                            Text("Импорт файла")
                        }
                        TextButton(onClick = { statementFile.launch(arrayOf("text/csv", "text/plain", "application/csv", "text/comma-separated-values")) }) {
                            Text("Импорт выписки")
                        }
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
                        Text(
                            "Удалить все данные",
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.weight(1f),
                        )
                        TextButton(onClick = { showDeleteAll = true }) {
                            Text("Сброс", color = MaterialTheme.colorScheme.error)
                        }
                    }
                }
            }
        }
    }

    if (showBudget) {
        BudgetDialog(onDismiss = { showBudget = false })
    }
    if (showCategories) {
        CategoryEditorSheet(onDismiss = { showCategories = false })
    }
    if (showStatement && statementText != null) {
        StatementImportSheet(statementText!!, onDismiss = { showStatement = false })
    }
    if (showDeleteAll) {
        AlertDialog(
            onDismissRequest = { showDeleteAll = false },
            title = { Text("Удалить все данные?") },
            text = { Text("Все подписки и платежи будут удалены. Категории вернутся к стандартным.") },
            confirmButton = {
                TextButton(onClick = {
                    store.resetAll()
                    store.show("Данные удалены")
                    showDeleteAll = false
                }) { Text("Удалить", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { showDeleteAll = false }) { Text("Отмена") } },
        )
    }
}

@Composable
private fun SectionCard(title: String, icon: ImageVector? = null, content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (icon != null) {
                Icon(icon, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                Spacer(Modifier.size(8.dp))
            }
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        }
        content()
    }
}

@Composable
private fun BudgetDialog(onDismiss: () -> Unit) {
    val store = KiperApp.store
    var text by remember { mutableStateOf(store.monthlyBudgetRub?.toInt()?.toString() ?: "") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Бюджет на месяц") },
        text = {
            Column {
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it.filter { c -> c.isDigit() }.take(9) },
                    placeholder = { Text("Сумма в рублях") },
                    singleLine = true,
                )
                if (text.isEmpty()) {
                    TextButton(onClick = {
                        store.monthlyBudgetRub = null
                        onDismiss()
                    }) { Text("Убрать бюджет") }
                }
            }
        },
        confirmButton = {
            Button(onClick = {
                store.monthlyBudgetRub = text.toDoubleOrNull()
                onDismiss()
            }) { Text("Сохранить") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Отмена") } },
    )
}

private fun writeText(context: Context, uri: Uri, text: String) {
    try {
        context.contentResolver.openOutputStream(uri, "wt")?.use { it.write(text.toByteArray(Charsets.UTF_8)) }
    } catch (_: Exception) {
    }
}

private fun readText(context: Context, uri: Uri): String? = try {
    context.contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.readText()
} catch (_: Exception) {
    null
}
