package ru.kiper.android.data

import java.io.File

/**
 * Local storage: one JSON file in the app's files dir, in the same format as
 * backups. The data set is small (dozens of rows), so a whole-file atomic write
 * on each change is simpler and safer than a database.
 */
class Persistence(private val file: File) {

    companion object {
        fun live(filesDir: File): Persistence {
            filesDir.mkdirs()
            return Persistence(File(filesDir, "kiper.json"))
        }
    }

    /** `null` on first launch (no file yet). Throws when the file exists but is broken. */
    fun load(): BackupFile? {
        if (!file.exists()) return null
        return BackupMapper.decode(file.readText(Charsets.UTF_8))
    }

    /** Moves an unreadable file aside (`kiper.broken-<timestamp>.json`) and returns it. */
    fun quarantine(): File {
        val stamp = System.currentTimeMillis() / 1000
        val target = File(file.parentFile, "kiper.broken-$stamp.json")
        file.renameTo(target)
        return target
    }

    fun save(fileData: BackupFile) {
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(BackupMapper.encode(fileData), Charsets.UTF_8)
        if (!tmp.renameTo(file)) {
            // rename can fail across mount points; fall back to a direct write
            file.writeText(BackupMapper.encode(fileData), Charsets.UTF_8)
            tmp.delete()
        }
    }
}
