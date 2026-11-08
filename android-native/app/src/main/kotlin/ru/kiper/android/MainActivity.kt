package ru.kiper.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import ru.kiper.android.data.Reminders
import ru.kiper.android.notifications.ReminderAlarmScheduler
import ru.kiper.android.ui.AppRoot
import ru.kiper.android.ui.theme.BackgroundStyle
import ru.kiper.android.ui.theme.KiperTheme

/**
 * Single-activity Compose app. FragmentActivity base is required by
 * BiometricPrompt (the Face ID counterpart). A deep link from a reminder carries
 * the `subscriptionId` extra.
 */
class MainActivity : FragmentActivity() {

    private val lockPolicy = LockPolicy()
    private val lockedState = mutableStateOf(false)
    private val deepLink = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val store = KiperApp.store
        store.reminderScheduler = ReminderAlarmScheduler(this)
        store.autoBackup = ru.kiper.android.data.AutoBackup(this, getSharedPreferences("kiper", MODE_PRIVATE))
        store.onWidgetsChanged = { ru.kiper.android.widgets.WidgetData.refresh(this) }
        store.scheduleReminders()

        // Notification permission (Android 13+); reminders fall back silently.
        if (android.os.Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
        }

        lockPolicy.isEnabled = getSharedPreferences("kiper", MODE_PRIVATE)
            .getBoolean("appLock.enabled", false)
        lockPolicy.onEnterForeground()
        lockedState.value = lockPolicy.isLocked
        deepLink.value = subscriptionId(intent)

        setContent {
            val style = BackgroundStyle.of(store.backgroundStyle.value)
            KiperTheme(style = style, themeMode = store.themeMode.value) {
                Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
                    ru.kiper.android.ui.theme.FlowingBackdrop(
                        style = BackgroundStyle.of(store.backgroundStyle.value),
                    )
                    AppRoot(deepLinkSubscriptionId = deepLink.value)
                }
                if (lockedState.value) {
                    LockOverlay(onRetry = {
                        authenticate { lockedState.value = lockPolicy.isLocked }
                    })
                }
            }

            // Refresh on foreground (matches iOS `refreshOnForeground`).
            LaunchedEffect(Unit) {
                store.refreshOnForeground()
                store.scheduleReminders()
            }
            // Biometric challenge when locked.
            LaunchedEffect(lockedState.value) {
                if (lockedState.value) {
                    authenticate { lockedState.value = lockPolicy.isLocked }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deepLink.value = subscriptionId(intent)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            // Re-evaluate the "reminders blocked" badge now that the user answered.
            KiperApp.store.scheduleReminders()
        }
    }

    override fun onResume() {
        super.onResume()
        lockPolicy.isEnabled = getSharedPreferences("kiper", MODE_PRIVATE)
            .getBoolean("appLock.enabled", false)
        lockPolicy.onEnterForeground()
        lockedState.value = lockPolicy.isLocked
    }

    override fun onPause() {
        lockPolicy.onEnterBackground()
        super.onPause()
    }

    private fun subscriptionId(intent: Intent?): String? =
        intent?.getStringExtra(Reminders.SUBSCRIPTION_ID_KEY)

    private fun authenticate(onResult: () -> Unit) {
        val manager = BiometricManager.from(this)
        val authenticators = BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL
        if (manager.canAuthenticate(authenticators) != BiometricManager.BIOMETRIC_SUCCESS) {
            // Nothing to authenticate with (emulator without a lock) — let the user in.
            lockPolicy.unlock()
            onResult()
            return
        }
        val prompt = BiometricPrompt(
            this,
            ContextCompat.getMainExecutor(this),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    lockPolicy.unlock()
                    onResult()
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    // Stay locked; the overlay offers a retry button.
                    onResult()
                }
            },
        )
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Кипер заблокирован")
            .setSubtitle("Подтвердите, что это вы")
            .setAllowedAuthenticators(authenticators)
            .build()
        prompt.authenticate(info)
    }
}

/** Dimmed cover shown while the lock is armed. */
@Composable
private fun LockOverlay(onRetry: () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(Color(0xF20B0B0E)),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Кипер заблокирован", color = Color.White, style = MaterialTheme.typography.titleLarge)
            Text(
                "Подтвердите, что это вы",
                color = Color.White.copy(alpha = 0.7f),
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 6.dp, bottom = 20.dp),
            )
            Button(onClick = onRetry, modifier = Modifier.fillMaxWidth().padding(horizontal = 48.dp)) {
                Text("Разблокировать")
            }
        }
    }
}
