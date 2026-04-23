package com.chatawayplus.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "com.chatawayplus.app/battery"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Force clear old broken callbacks and let Flutter re-register fresh ones
        clearAndResetFirebaseCallbacks()
    }

    private fun clearAndResetFirebaseCallbacks() {
        try {
            val prefs = getSharedPreferences(
                "io.flutter.firebase.messaging.callback",
                Context.MODE_PRIVATE
            )
            // Only clear if callbacks exist but are potentially corrupted
            if (prefs.contains("callback_handle")) {
                prefs.edit().clear().apply()
                android.util.Log.d("MainActivity", "Cleared old Firebase callbacks - will re-register")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error clearing callbacks: ${e.message}")
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Battery optimization method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "openBatterySettings" -> {
                    openBatterySettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            return powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }

    private fun openBatterySettings() {
        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to general settings
            val intent = Intent(Settings.ACTION_SETTINGS)
            startActivity(intent)
        }
    }

    override fun onPostResume() {
        super.onPostResume()

        // Opt in to edge-to-edge so Flutter content can draw behind system bars.
        // Flutter's Scaffold/SafeArea widgets handle the window insets.
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun onDestroy() {
        super.onDestroy()
        android.util.Log.d("MainActivity", "🔴 MainActivity destroyed")
    }
}
