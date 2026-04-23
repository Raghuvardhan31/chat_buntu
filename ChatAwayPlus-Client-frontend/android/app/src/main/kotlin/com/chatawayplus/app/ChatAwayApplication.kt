package com.chatawayplus.app

import android.app.Application
import android.content.Context

class ChatAwayApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val prefs = getSharedPreferences(
            "io.flutter.firebase.messaging.callback",
            Context.MODE_PRIVATE
        )
        prefs.edit()
            .remove("callback_handle")
            .remove("user_callback_handle")
            .apply()
    }
}
