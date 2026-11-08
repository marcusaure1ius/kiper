package ru.kiper.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The lock state machine mirrors `LockPolicy.swift` (fully tested on iOS) — the
 * same grace window must behave identically on Android.
 */
class LockPolicyTest {

    @Test
    fun disabledNeverLocks() {
        val policy = LockPolicy()
        policy.isEnabled = false
        policy.onEnterBackground(0)
        policy.onEnterForeground(60_000) // away way past the grace window
        assertFalse(policy.isLocked)
    }

    @Test
    fun enabledStartsUnlocked() {
        val policy = LockPolicy()
        policy.isEnabled = true
        assertFalse(policy.isLocked)
        // Foreground without a prior background visit never locks.
        policy.onEnterForeground(0)
        assertFalse(policy.isLocked)
    }

    @Test
    fun briefInterruptionDoesNotLock() {
        val policy = LockPolicy().apply { isEnabled = true }
        policy.onEnterBackground(1_000)
        policy.onEnterForeground(1_000 + LockPolicy.ARM_DELAY_MS - 1)
        assertFalse(policy.isLocked) // 3 s grace: a quick app switch stays unlocked
    }

    @Test
    fun longerAbsenceLocks() {
        val policy = LockPolicy().apply { isEnabled = true }
        policy.onEnterBackground(1_000)
        policy.onEnterForeground(1_000 + LockPolicy.ARM_DELAY_MS)
        assertTrue(policy.isLocked)
    }

    @Test
    fun unlockClearsAndForegroundResetsTheWindow() {
        val policy = LockPolicy().apply { isEnabled = true }
        policy.onEnterBackground(0)
        policy.onEnterForeground(10_000)
        assertTrue(policy.isLocked)
        policy.unlock()
        assertFalse(policy.isLocked)

        // While the app stays in the foreground it must not re-lock on its own.
        policy.onEnterForeground(20_000)
        assertFalse(policy.isLocked)
    }
}
