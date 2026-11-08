package ru.kiper.android.ui.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import ru.kiper.android.KiperApp
import ru.kiper.android.data.Fmt
import ru.kiper.android.data.StatementCandidate
import ru.kiper.android.data.StatementImporter
import ru.kiper.android.ui.components.Card

/** Review screen for detected recurring charges (mirrors `StatementImportScreen`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatementImportSheet(statementText: String, onDismiss: () -> Unit) {
    val store = KiperApp.store
    val candidates = remember(statementText) { StatementImporter.parse(statementText) }
    var attachFor by remember { mutableStateOf<StatementCandidate?>(null) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                Text(
                    "Импорт выписки",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    if (candidates.isEmpty()) "Регулярных платежей не найдено — нужен CSV/TXT банка с колонками даты, суммы и описания."
                    else "Найдено регулярных платежей: ${candidates.size}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            for (candidate in candidates) {
                item {
                    Card {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(
                                    candidate.name,
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Text(
                                    "${candidate.occurrences.size} платежей · каждые ${candidate.medianIntervalDays} дн.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                Text(
                                    "${Fmt.money(candidate.medianAmount, ru.kiper.android.data.Currency.RUB)} · далее ${Fmt.smartDate(candidate.nextCharge())}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Spacer(Modifier.width(8.dp))
                            TextButton(onClick = {
                                store.createFromCandidate(candidate)
                                onDismiss()
                            }) { Text("Создать") }
                        }
                        HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
                        TextButton(onClick = { attachFor = candidate }) {
                            Text("Присоединить к существующей подписке")
                        }
                    }
                }
            }
            item { Spacer(Modifier.padding(bottom = 24.dp)) }
        }
    }

    attachFor?.let { candidate ->
        AlertDialog(
            onDismissRequest = { attachFor = null },
            title = { Text("Присоединить «${candidate.name}»") },
            text = {
                LazyColumn {
                    for (sub in store.notCancelled) {
                        item {
                            Text(
                                sub.name,
                                Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        store.attachStatement(candidate, sub.id)
                                        attachFor = null
                                        onDismiss()
                                    }
                                    .padding(vertical = 12.dp),
                                style = MaterialTheme.typography.bodyLarge,
                            )
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { attachFor = null }) { Text("Отмена") }
            },
        )
    }
}
