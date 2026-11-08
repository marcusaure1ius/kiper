package ru.kiper.android.data

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.mutableStateOf
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Automatic backups into a folder the user picked once (SAF document tree, e.g.
 * Google Drive or a synced folder — the Android counterpart of the iOS
 * Files-folder bookmark). Each run overwrites `Кипер — копия.json` and keeps one
 * dated copy per day for the last `KEEP_DAYS` days.
 */
class AutoBackup(private val context: Context?, private val prefs: android.content.SharedPreferences?) {

    companion object {
        const val LATEST_NAME = "Кипер — копия.json"
        const val DATED_PREFIX = "Кипер "
        const val KEEP_DAYS = 7
        const val KEY_TREE = "autobackup.tree"
        const val KEY_LAST = "autobackup.last"

        val NONE = AutoBackup(null, null)
    }

    // Created lazily: unit tests run without an Android Looper.
    private val handler: Handler? by lazy {
        try {
            Handler(Looper.getMainLooper())
        } catch (_: Exception) {
            null
        }
    }
    private var pending: Runnable? = null

    val treeUri = mutableStateOf<Uri?>(null)
    val lastBackup = mutableStateOf<LocalDate?>(null)
    val lastError = mutableStateOf<String?>(null)

    init {
        @Suppress("USELESS_ELVIS")
        treeUri.value = prefs?.getString(KEY_TREE, null)?.let(Uri::parse)
        val last = prefs?.getLong(KEY_LAST, 0L) ?: 0L
        if (last > 0) {
            lastBackup.value = Instant.ofEpochMilli(last).atZone(ZoneId.systemDefault()).toLocalDate()
        }
    }

    val isEnabled: Boolean get() = treeUri.value != null

    val folderName: String?
        get() = treeUri.value?.let { uri ->
            try {
                DocumentsContract.getTreeDocumentId(uri).split(':').lastOrNull()?.ifEmpty { null }
                    ?: uri.lastPathSegment
            } catch (_: Exception) {
                uri.lastPathSegment
            }
        }

    /** Remembers a folder picked via `ACTION_OPEN_DOCUMENT_TREE`. */
    fun setTree(uri: Uri) {
        context?.contentResolver?.takePersistableUriPermission(
            uri,
            android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
        prefs?.edit()?.putString(KEY_TREE, uri.toString())?.apply()
        treeUri.value = uri
        lastError.value = null
    }

    fun disable() {
        handler?.let { pending?.let(it::removeCallbacks) }
        prefs?.edit()?.remove(KEY_TREE)?.apply()
        treeUri.value = null
        lastError.value = null
    }

    /** Debounced: many quick edits produce one write. */
    fun schedule(makeFile: () -> BackupFile) {
        if (!isEnabled) return
        val handler = handler ?: return
        pending?.let(handler::removeCallbacks)
        pending = Runnable { run(makeFile()) }
        handler.postDelayed(pending!!, 2_000)
    }

    fun run(file: BackupFile, now: LocalDate = LocalDate.now()): Boolean {
        val resolver = context?.contentResolver ?: return false
        val tree = treeUri.value ?: return false
        return try {
            val data = BackupMapper.encode(file).toByteArray(Charsets.UTF_8)
            write(resolver, tree, LATEST_NAME, data)
            write(resolver, tree, datedName(now), data)
            prune(resolver, tree, now)
            lastBackup.value = now
            prefs?.edit()?.putLong(KEY_LAST, System.currentTimeMillis())?.apply()
            lastError.value = null
            true
        } catch (e: Exception) {
            lastError.value = "Не удалось сохранить копию: ${e.message}"
            false
        }
    }

    private val DATED = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    fun datedName(date: LocalDate): String = "$DATED_PREFIX${date.format(DATED)}.json"

    /** Finds a document in the tree by display name (null when absent). */
    private fun find(resolver: android.content.ContentResolver, tree: Uri, name: String): Uri? = try {
        val folder = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        resolver.query(
            DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree)),
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(1) == name) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0))
                }
            }
        }
        null
    } catch (_: Exception) {
        null
    }

    private fun write(resolver: android.content.ContentResolver, tree: Uri, name: String, data: ByteArray) {
        val existing = find(resolver, tree, name)
        val target = existing ?: DocumentsContract.createDocument(resolver, tree, "application/json", name)
            ?: throw IllegalStateException("Не удалось создать файл $name")
        resolver.openOutputStream(target, "wt")?.use { it.write(data) }
            ?: throw IllegalStateException("Не удалось открыть $name")
    }

    /** Keeps dated copies of the last `KEEP_DAYS` days. */
    private fun prune(resolver: android.content.ContentResolver, tree: Uri, now: LocalDate) {
        val keep = (0 until KEEP_DAYS).map { datedName(now.minusDays(it.toLong())) }.toSet()
        try {
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            resolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    val doomed = mutableListOf<Uri>()
                    while (cursor.moveToNext()) {
                        val name = cursor.getString(1)
                        if (name.startsWith(DATED_PREFIX) && name != LATEST_NAME && name.endsWith(".json") && !keep.contains(name)) {
                            doomed.add(DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0)))
                        }
                    }
                    for (uri in doomed) try {
                        DocumentsContract.deleteDocument(resolver, uri)
                    } catch (_: Exception) {
                    }
                }
        } catch (_: Exception) {
        }
    }
}
