package ru.kiper.android

import android.app.Application
import ru.kiper.android.data.AppStore

/** Application + singleton store (matches iOS `AppStore` attached at the app entry). */
class KiperApp : Application() {

    companion object {
        lateinit var store: AppStore
            private set
    }

    override fun onCreate() {
        super.onCreate()
        // Demo subscriptions on first launch mirror the iOS DEBUG behaviour.
        store = AppStore(this, seedDemoData = BuildConfig.DEBUG)
    }
}
