package ru.kiper.android.notifications

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import ru.kiper.android.BuildConfig
import ru.kiper.android.MainActivity
import ru.kiper.android.R
import ru.kiper.android.data.AppStore
import ru.kiper.android.data.Reminders
import ru.kiper.android.data.ReminderScheduler
import java.time.ZoneId

/** AlarmManager-backed scheduler; replaces the whole set on every `apply`, like
 * `Reminders.apply` on iOS. */
class ReminderAlarmScheduler(private val context: Context) : ReminderScheduler {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prefs = context.getSharedPreferences("kiper", Context.MODE_PRIVATE)

    override fun apply(plans: List<Reminders.Plan>) {
        cancelAll()
        val scheduled = mutableSetOf<Int>()
        for (plan in plans) {
            val intent = Intent(context, ReminderReceiver::class.java).apply {
                action = ReminderReceiver.ACTION_FIRE
                putExtra(Reminders.SUBSCRIPTION_ID_KEY, plan.subscriptionId)
                putExtra(EXTRA_TITLE, plan.title)
                putExtra(EXTRA_BODY, plan.body)
                putExtra(EXTRA_REQUEST_ID, plan.id)
            }
            val code = plan.id.hashCode()
            val pending = PendingIntent.getBroadcast(
                context,
                code,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            scheduled.add(code)
            val triggerAt = plan.fireDate.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            val exact = if (Build.VERSION.SDK_INT >= 31) alarmManager.canScheduleExactAlarms() else true
            if (exact) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            } else {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
        }
        prefs.getStringSet(KEY_SCHEDULED, null)?.forEach { codeStr ->
            codeStr.toIntOrNull()?.let { code ->
                if (!scheduled.contains(code)) {
                    alarmManager.cancel(
                        PendingIntent.getBroadcast(
                            context, code,
                            Intent(context, ReminderReceiver::class.java),
                            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
                        )
                    )
                }
            }
        }
        prefs.edit().putStringSet(KEY_SCHEDULED, scheduled.map { it.toString() }.toSet()).apply()
    }

    override fun canSchedule(): Boolean =
        if (Build.VERSION.SDK_INT >= 31) alarmManager.canScheduleExactAlarms() else true

    override fun notificationsAllowed(): Boolean =
        if (Build.VERSION.SDK_INT >= 33) {
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else true

    override fun requestPermission(onResult: (Boolean) -> Unit) {
        // The notification permission is granted via the runtime prompt in
        // MainActivity; alarms fall back to inexact silently. The store treats the
        // result as "reminders visible?" — notifications only.
        val granted = if (Build.VERSION.SDK_INT >= 33) {
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else true
        onResult(granted)
    }

    private fun cancelAll() {
        for (codeStr in prefs.getStringSet(KEY_SCHEDULED, null).orEmpty()) {
            val code = codeStr.toIntOrNull() ?: continue
            val pending = PendingIntent.getBroadcast(
                context, code,
                Intent(context, ReminderReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pending != null) alarmManager.cancel(pending)
        }
        prefs.edit().remove(KEY_SCHEDULED).apply()
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_REQUEST_ID = "requestId"
        const val CHANNEL_ID = "reminders"
        const val KEY_SCHEDULED = "reminders.scheduled"
    }
}

/** Posts the reminder notification; tap deep-links into the subscription. */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_FIRE) return
        val title = intent.getStringExtra(ReminderAlarmScheduler.EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(ReminderAlarmScheduler.EXTRA_BODY) ?: return
        val subscriptionId = intent.getStringExtra(Reminders.SUBSCRIPTION_ID_KEY)

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Напоминания о подписках", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val tap = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(Reminders.SUBSCRIPTION_ID_KEY, subscriptionId)
        }
        val contentIntent = PendingIntent.getActivity(
            context, (subscriptionId ?: "kiper").hashCode(), tap,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        manager.notify((intent.getStringExtra(ReminderAlarmScheduler.EXTRA_REQUEST_ID) ?: "kiper").hashCode(), notification)
    }

    companion object {
        const val ACTION_FIRE = "ru.kiper.android.FIRE_REMINDER"
        const val CHANNEL_ID = ReminderAlarmScheduler.CHANNEL_ID
    }
}

/** Re-arms everything after a reboot. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences("kiper", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("reminders.enabled", true)) return
        val store = AppStore(context, seedDemoData = BuildConfig.DEBUG)
        store.reminderScheduler = ReminderAlarmScheduler(context)
        store.scheduleReminders()
    }
}
