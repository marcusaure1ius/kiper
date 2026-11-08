package ru.kiper.android

/**
 * Pure lock policy state machine (mirrors `LockPolicy.swift`):
 * the app re-arms every time it goes to background and stays unlocked while used.
 */
class LockPolicy {
    var isEnabled: Boolean = false
    var isLocked: Boolean = false
        private set

    private var lastBackgroundMs = Long.MAX_VALUE / 2

    /** Called on app start and whenever the app returns to the foreground. */
    fun onEnterForeground(nowMs: Long = System.currentTimeMillis()) {
        if (isEnabled && nowMs - lastBackgroundMs >= ARM_DELAY_MS) isLocked = true
        lastBackgroundMs = Long.MAX_VALUE / 2
    }

    /** Called when the app goes to background. */
    fun onEnterBackground(nowMs: Long = System.currentTimeMillis()) {
        lastBackgroundMs = nowMs
    }

    fun unlock() {
        isLocked = false
    }

    companion object {
        /** Small grace window so brief app switches don't re-lock (like iOS). */
        const val ARM_DELAY_MS = 3_000L
    }
}
