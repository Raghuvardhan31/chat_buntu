package com.chatawayplus.app

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Typeface
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Native Firebase Messaging Service (Android)
 *
 * IMPORTANT:
 * - Shows notifications ONLY when app is terminated/killed
 *   (i.e., when Flutter's Dart isolate can't start)
 * - Flutter (NotificationLocalService) handles notifications when app is
 *   in foreground or background.
 *
 * This service is responsible for:
 * - Receiving data-only FCM
 * - Showing FALLBACK notifications ONLY when app is terminated
 * - Ensuring the notification channel exists for Flutter
 */
class ChatAwayFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        const val TAG = "ChatAwayFCM"
        const val CHANNEL_ID = "chat_messages"
        const val CHANNEL_NAME = "Chat Messages"
        private const val PENDING_QUEUE_KEY = "flutter.pending_fcm_chat_queue"
        private const val PENDING_LIKES_QUEUE_KEY = "flutter.pending_fcm_likes_queue"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "🔥 Native FCM Service created")
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        Log.d(TAG, "")
        Log.d(TAG, "═══════════════════════════════════════════════════════")
        Log.d(TAG, "🔔 FCM DATA MESSAGE RECEIVED (NATIVE KOTLIN)")
        Log.d(TAG, "═══════════════════════════════════════════════════════")
        Log.d(TAG, "📩 [DEVICE_B_FCM] Raw data keys: ${remoteMessage.data.keys}")
        Log.d(TAG, "📩 [DEVICE_B_FCM] Raw data: ${remoteMessage.data}")
        Log.d(TAG, "📩 [DEVICE_B_FCM] Type field: ${remoteMessage.data["type"]}")
        
        // Enhanced debugging for notification types
        val allTypeFields = listOf("type", "chatType", "notificationType", "notification_type", "messageType", "message_type")
        for (field in allTypeFields) {
            val value = remoteMessage.data[field]
            if (value != null) {
                Log.d(TAG, "🔍 [DEVICE_B_FCM] Found type field '$field' = '$value'")
            }
        }

        // CRITICAL: Only show native notification if Flutter CAN'T handle it
        // When app is in foreground or background with Flutter engine running, let Flutter handle it
        if (isFlutterEngineRunning()) {
            Log.d(TAG, "📱 Flutter engine is running - letting Flutter handle notification")
            return
        }

        Log.d(TAG, "💀 Flutter engine NOT running - showing native fallback notification")
        // Show notification directly from native code
        // This ensures notifications appear even when Flutter can't handle them
        showNotificationFromData(remoteMessage.data)
    }

    /**
     * Check if Flutter engine is actually running and can handle notifications.
     * When app is "terminated" by user, FCM wakes up the process but only the
     * FCM service runs - Flutter's Dart isolate doesn't start automatically.
     *
     * We check if MainActivity is in the task stack (meaning Flutter is alive).
     */
    private fun isFlutterEngineRunning(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

        // Method 1: Check if our MainActivity is in any task
        try {
            val tasks = activityManager.getRunningTasks(10)
            for (task in tasks) {
                val componentName = task.baseActivity ?: continue
                if (componentName.packageName == packageName &&
                    componentName.className.contains("MainActivity")) {
                    Log.d(TAG, "✅ MainActivity found in task stack - Flutter is running")
                    return true
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "⚠️ Could not check running tasks: ${e.message}")
        }

        // Method 2: Check process importance - if FOREGROUND or VISIBLE, Flutter is likely running
        val appProcesses = activityManager.runningAppProcesses ?: return false
        for (processInfo in appProcesses) {
            if (processInfo.processName == packageName) {
                val importance = processInfo.importance
                Log.d(TAG, "📊 App process importance: $importance")

                // FOREGROUND = 100, FOREGROUND_SERVICE = 125, VISIBLE = 200
                // Only trust these levels - SERVICE (300) might just be FCM service
                if (importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE) {
                    Log.d(TAG, "✅ App is VISIBLE or FOREGROUND - Flutter should be running")
                    return true
                }
            }
        }

        Log.d(TAG, "❌ Flutter engine not detected - will show native notification")
        return false
    }

    /**
     * Show notification directly from native Android code.
     * This is a FALLBACK for when Flutter's background handler can't run.
     * The notification will be simple (no profile picture) but will still show.
     */
    private fun showNotificationFromData(data: Map<String, String>) {
        try {
            val type = (data["type"]
                ?: data["notification_type"]
                ?: data["chatType"]
                ?: data["notificationType"]
                ?: data["messageType"]
                ?: data["message_type"]
                ?: "unknown").trim()

            Log.d(TAG, "📨 Notification type: $type")
            if (type == "profile_update" || type == "profileUpdated" || type == "profile-updated") {
                handleProfileUpdateSilently(data)
                return
            }

            // Handle chat picture like notifications
            if (type == "chat_picture_like" || type == "chatPictureLike") {
                Log.d(TAG, "❤️ [DEVICE_B_FCM] MATCHED chat_picture_like type! Showing notification...")
                showChatPictureLikeNotification(data)
                return
            } else {
                Log.d(TAG, "🔍 [DEVICE_B_FCM] Type '$type' did NOT match chat_picture_like")
            }

            // Handle status like notifications (Share Your Voice)
            if (type == "status_like" || type == "statusLike" || type == "share_your_voice_like" || type == "shareYourVoiceLike") {
                Log.d(TAG, "❤️ [DEVICE_B_FCM] MATCHED status_like type! Showing notification...")
                showStatusLikeNotification(data)
                return
            } else {
                Log.d(TAG, "🔍 [DEVICE_B_FCM] Type '$type' did NOT match status_like")
            }

            // Only show notifications for chat messages
            if (type != "chat_message" && type != "message" && type != "private_message") {
                Log.d(TAG, "⏭️ Skipping non-chat notification type: $type")
                return
            }

            // Extract sender info
            val senderName = data["senderFirstName"]
                ?: data["senderName"]
                ?: data["sender_name"]
                ?: "New Message"

            val senderId = data["senderId"]
                ?: data["sender_id"]
                ?: ""

            val cachedContactName = try {
                getContactNameFromFlutterPrefs(senderId)
            } catch (_: Exception) {
                null
            }

            val resolvedSenderName = if (!cachedContactName.isNullOrEmpty()) {
                cachedContactName
            } else {
                senderName
            }

            val messageIds = mutableListOf<String>()
            try {
                val rawIds = data["messageIds"]
                    ?: data["message_ids"]
                    ?: data["message_ids_json"]
                    ?: data["messageIdsJson"]
                if (!rawIds.isNullOrEmpty()) {
                    val trimmed = rawIds.trim()
                    if (trimmed.startsWith("[")) {
                        val arr = JSONArray(trimmed)
                        for (i in 0 until arr.length()) {
                            val v = arr.optString(i)
                            if (v.isNotEmpty()) messageIds.add(v)
                        }
                    } else if (trimmed.contains(",")) {
                        trimmed.split(",").map { it.trim() }.forEach { v ->
                            if (v.isNotEmpty()) messageIds.add(v)
                        }
                    } else {
                        if (trimmed.isNotEmpty()) messageIds.add(trimmed)
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "⚠️ Failed to parse messageIds array: ${e.message}")
            }

            if (messageIds.isEmpty()) {
                // IMPORTANT: Prefer actual message ID keys. chatId is often a conversation id.
                val singleId = data["messageId"]
                    ?: data["message_id"]
                    ?: data["messageUuid"]
                    ?: data["message_uuid"]
                    ?: data["id"]
                    ?: data["chatId"]
                if (!singleId.isNullOrEmpty()) {
                    messageIds.add(singleId)
                }
            }

            val rawIdsLog = data["messageIds"]
                ?: data["message_ids"]
                ?: data["message_ids_json"]
            val msgIdLog = data["messageId"]
                ?: data["message_id"]
                ?: data["messageUuid"]
                ?: data["message_uuid"]
                ?: data["id"]
            val chatIdLog = data["chatId"]
            Log.d(TAG, "🆔 Extracted messageIds=$messageIds (raw=$rawIdsLog, messageId=$msgIdLog, chatId=$chatIdLog)")

            val senderProfilePic = data["sender_profile_pic"]
                ?: data["senderProfilePic"]
                ?: data["profile_pic"]
                ?: data["profilePic"]
                ?: data["sender_chat_picture"]
                ?: data["senderChatPicture"]
                ?: data["chatPicture"]
                ?: data["chat_picture"]
                ?: data["avatar"]
                ?: data["senderAvatar"]
                ?: data["sender_avatar"]

            val hasSenderProfilePicKey = data.containsKey("sender_profile_pic") ||
                data.containsKey("senderProfilePic") ||
                data.containsKey("profile_pic") ||
                data.containsKey("profilePic") ||
                data.containsKey("sender_chat_picture") ||
                data.containsKey("senderChatPicture") ||
                data.containsKey("chatPicture") ||
                data.containsKey("chat_picture") ||
                data.containsKey("avatar") ||
                data.containsKey("senderAvatar") ||
                data.containsKey("sender_avatar")

            if (senderId.isNotEmpty() && hasSenderProfilePicKey && isBlankOrNullString(senderProfilePic)) {
                try { deleteCachedAvatar(senderId) } catch (_: Exception) {}
            }

            Log.d(TAG, "🖼️ Profile pic URL from FCM: $senderProfilePic")
            Log.d(TAG, "📦 All FCM data keys: ${data.keys}")

            // Extract message text - handle JSON format from backend
            var messageText = "New message"
            val messageTextRaw = data["messageText"] ?: data["message"] ?: data["body"]
            if (messageTextRaw != null) {
                try {
                    // Try to parse as JSON (backend sends JSON string)
                    val json = JSONObject(messageTextRaw)
                    val candidates = listOf(
                        json.optString("messageText", ""),
                        json.optString("message_text", ""),
                        json.optString("message", ""),
                        json.optString("text", ""),
                        json.optString("body", ""),
                    )
                    for (c in candidates) {
                        if (!isBlankOrNullString(c)) {
                            messageText = c
                            break
                        }
                    }
                    if (isBlankOrNullString(messageText)) {
                        val rawTrimmed = messageTextRaw.trim()
                        // If raw is JSON and contains no real message text, keep empty so fallback can apply.
                        messageText = if (!isBlankOrNullString(rawTrimmed) &&
                            !(rawTrimmed.startsWith("{") && rawTrimmed.endsWith("}"))) {
                            rawTrimmed
                        } else {
                            ""
                        }
                    }
                } catch (e: Exception) {
                    // Not JSON, use raw string
                    messageText = messageTextRaw
                }
            }

            val rawMessageType = data["messageType"] ?: data["message_type"] ?: ""
            if (isBlankOrNullString(messageText)) {
                messageText = when (rawMessageType.trim().lowercase()) {
                    "image", "photo" -> "📷 Photo"
                    "video" -> "🎥 Video"
                    "document", "pdf" -> "📄 Document"
                    "contact" -> "👤 Contact"
                    "audio", "voice" -> "🎵 Audio"
                    else -> "New message"
                }
            }

            try {
                enqueuePendingChatPayload(data)
            } catch (_: Exception) {
            }

            Log.d(TAG, "📱 Showing native notification: $resolvedSenderName - $messageText")
            Log.d(TAG, "👤 Sender ID: $senderId")

            // Create intent to open app when notification is tapped
            val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("notification_sender_id", senderId)
                putExtra("notification_type", "chat_message")
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                senderId.hashCode(),
                intent,
                pendingIntentFlags
            )

            val notificationId = senderId.hashCode()

            val cachedBitmap = try {
                getCachedAvatar(senderId)
            } catch (_: Exception) {
                null
            }

            val initialIconBitmap: Bitmap? = if (cachedBitmap != null) {
                try { getCircularBitmap(cachedBitmap) } catch (_: Exception) { cachedBitmap }
            } else {
                try { createLetterAvatar(resolvedSenderName) } catch (_: Exception) { null }
            }

            val initialStyle = if (initialIconBitmap != null) {
                try {
                    val person = Person.Builder()
                        .setName(resolvedSenderName)
                        .setIcon(IconCompat.createWithBitmap(initialIconBitmap))
                        .build()

                    NotificationCompat.MessagingStyle(person)
                        .addMessage(messageText, System.currentTimeMillis(), person)
                } catch (_: Exception) {
                    null
                }
            } else {
                null
            }

            // Build notification
            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(resolvedSenderName)
                .setContentText(messageText)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setDefaults(NotificationCompat.DEFAULT_ALL)

            if (initialIconBitmap != null) {
                builder.setLargeIcon(initialIconBitmap)
            }

            if (initialStyle != null) {
                builder.setStyle(initialStyle)
            }

            val notification = builder.build()

            try {
                NotificationManagerCompat.from(this).notify(notificationId, notification)
                Log.d(TAG, "✅ Native notification shown successfully")
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ Permission denied for notification: ${e.message}")
            }

            if (initialIconBitmap == null) {
                val urlToDownload = senderProfilePic?.trim()?.takeIf { it.isNotEmpty() }
                if (urlToDownload != null) {
                    Thread {
                        try {
                            val authToken = readAuthTokenFromEncryptedPrefs()
                            val downloaded = downloadBitmap(urlToDownload, authToken)
                            if (downloaded != null) {
                                try {
                                    cacheAvatar(senderId, downloaded)
                                } catch (_: Exception) {
                                }

                                val circularDownloaded = try {
                                    getCircularBitmap(downloaded)
                                } catch (_: Exception) { downloaded }

                                val updatedStyle = try {
                                    val person = Person.Builder()
                                        .setName(resolvedSenderName)
                                        .setIcon(IconCompat.createWithBitmap(circularDownloaded))
                                        .build()

                                    NotificationCompat.MessagingStyle(person)
                                        .addMessage(messageText, System.currentTimeMillis(), person)
                                } catch (_: Exception) {
                                    null
                                }

                                val updatedBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
                                    .setSmallIcon(R.mipmap.ic_launcher)
                                    .setContentTitle(resolvedSenderName)
                                    .setContentText(messageText)
                                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                                    .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                                    .setAutoCancel(true)
                                    .setContentIntent(pendingIntent)
                                    .setDefaults(NotificationCompat.DEFAULT_ALL)
                                    .setLargeIcon(circularDownloaded)

                                if (updatedStyle != null) {
                                    updatedBuilder.setStyle(updatedStyle)
                                }

                                try {
                                    NotificationManagerCompat.from(this)
                                        .notify(notificationId, updatedBuilder.build())
                                } catch (_: SecurityException) {
                                }
                            }
                        } catch (_: Exception) {
                        }
                    }.start()
                }
            }

            if (messageIds.isNotEmpty()) {
                val ackThread = Thread {
                    try {
                        sendDeliveredAck(messageIds)
                    } catch (e: Exception) {
                        Log.d(TAG, "⚠️ sendDeliveredAck crashed: ${e.message}")
                    }
                }
                ackThread.start()
                // Give the ACK thread some time to execute before the service is stopped.
                try {
                    ackThread.join(6000)
                } catch (_: Exception) {
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show native notification: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun readAuthTokenFromEncryptedPrefs(): String? {
        return try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                return null
            }

            val masterKey = MasterKey.Builder(this)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val prefs = EncryptedSharedPreferences.create(
                this,
                "secure_token_storage",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

            // FlutterSecureStorage (AndroidOptions with preferencesKeyPrefix='secure_')
            // writes legacy key 'token' as 'secure_token'. Prefer that.
            val legacy = prefs.getString("secure_token", null)
            if (!legacy.isNullOrEmpty()) {
                Log.d(TAG, "🔑 Token found via key=secure_token (len=${legacy.length})")
                return legacy
            }

            // Fallback: scan for any token-like entry (multi-account key: secure_auth_token_<phone>)
            // Avoid logging token content.
            try {
                val all = prefs.all
                for ((k, v) in all) {
                    if (v is String) {
                        val sv = v.trim()
                        val looksLikeJwt = sv.length > 40 && sv.count { it == '.' } >= 2
                        val keyLooksToken = k.contains("auth_token", ignoreCase = true) ||
                            k.contains("token", ignoreCase = true)
                        if (keyLooksToken && (looksLikeJwt || sv.length > 40)) {
                            Log.d(TAG, "🔑 Token fallback selected key=$k (len=${sv.length})")
                            return sv
                        }
                    }
                }
            } catch (_: Exception) {
            }

            Log.d(TAG, "❌ Token not found in secure_token_storage")
            null
        } catch (e: Exception) {
            Log.d(TAG, "⚠️ readAuthTokenFromEncryptedPrefs failed: ${e.message}")
            null
        }
    }

    private fun sendDeliveredAck(messageIds: List<String>) {
        Log.d(TAG, "📤 sendDeliveredAck called with ${messageIds.size} message(s): $messageIds")
        
        val token = readAuthTokenFromEncryptedPrefs()?.trim()
        if (token.isNullOrEmpty()) {
            Log.d(TAG, "❌ No auth token found, skipping delivered ack")
            return
        }
        if (messageIds.isEmpty()) {
            Log.d(TAG, "❌ No message IDs, skipping delivered ack")
            return
        }

        Log.d(TAG, "🔑 Auth token found, sending delivered ack...")

        val url = URL("https://chatawayplus.com/api/mobile/chat/messages/delivered")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "PUT"
            connectTimeout = 5000
            readTimeout = 5000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
        }

        val body = JSONObject()
            .put("messageIds", JSONArray().apply {
                for (id in messageIds) {
                    if (id.isNotEmpty()) put(id)
                }
            })
            .toString()

        Log.d(TAG, "📦 Delivered ack body: $body")

        try {
            conn.outputStream.use { os ->
                os.write(body.toByteArray(Charsets.UTF_8))
                os.flush()
            }

            val responseCode = conn.responseCode
            Log.d(TAG, "📥 Delivered ack response code: $responseCode")

            try {
                val response = conn.inputStream.use { it.readBytes() }
                Log.d(TAG, "✅ Delivered ack response: ${String(response)}")
            } catch (e: Exception) {
                val errorResponse = conn.errorStream?.use { it.readBytes() }
                Log.d(TAG, "⚠️ Delivered ack error: ${errorResponse?.let { String(it) }}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Delivered ack failed: ${e.message}")
        } finally {
            conn.disconnect()
        }
    }

    private fun downloadBitmap(urlString: String, authToken: String? = null): Bitmap? {
        return try {
            val url = URL(urlString)
            val connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 4000
                readTimeout = 6000
                instanceFollowRedirects = true
                setRequestProperty("User-Agent", "ChatAwayPlus")
                if (!authToken.isNullOrEmpty()) {
                    setRequestProperty("Authorization", "Bearer $authToken")
                }
            }
            val responseCode = connection.responseCode
            if (responseCode != HttpURLConnection.HTTP_OK) {
                Log.d(TAG, "⚠️ Avatar download failed with code: $responseCode")
                return null
            }
            connection.inputStream.use { input ->
                BitmapFactory.decodeStream(input)
            }
        } catch (e: Exception) {
            Log.d(TAG, "⚠️ Avatar download exception: ${e.message}")
            null
        }
    }

    private fun getCachedAvatar(senderId: String): Bitmap? {
        if (senderId.isEmpty()) return null
        val f = File(cacheDir, "notif_avatar_$senderId.png")
        Log.d(TAG, "🔍 Looking for cached avatar: ${f.absolutePath}")
        if (!f.exists()) {
            Log.d(TAG, "❌ Cached avatar not found for: $senderId")
            return null
        }
        Log.d(TAG, "✅ Found cached avatar for: $senderId (${f.length()} bytes)")
        return BitmapFactory.decodeFile(f.absolutePath)
    }

    private fun deleteCachedAvatar(senderId: String) {
        if (senderId.isEmpty()) return
        val f = File(cacheDir, "notif_avatar_$senderId.png")
        if (f.exists()) {
            try {
                val deleted = f.delete()
                Log.d(TAG, "🗑️ Deleted cached avatar for: $senderId (deleted=$deleted)")
            } catch (_: Exception) {}
        }
    }

    private fun createLetterAvatar(displayName: String): Bitmap {
        val letter: String? = try {
            displayName.trim()
                .firstOrNull { it.isLetterOrDigit() }
                ?.uppercaseChar()
                ?.toString()
        } catch (_: Exception) {
            null
        }

        val sizePx = 128
        val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)

        val bgPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#9CA3AF")
        }
        canvas.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f, bgPaint)

        if (!letter.isNullOrEmpty()) {
            val textPaint = Paint().apply {
                isAntiAlias = true
                color = Color.WHITE
                textAlign = Paint.Align.CENTER
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textSize = sizePx * 0.56f
            }

            val fm = textPaint.fontMetrics
            val textY = sizePx / 2f - (fm.ascent + fm.descent) / 2f
            canvas.drawText(letter, sizePx / 2f, textY, textPaint)
        } else {
            val iconPaint = Paint().apply {
                isAntiAlias = true
                color = Color.WHITE
                style = Paint.Style.FILL
            }

            val cx = sizePx / 2f
            val headRadius = sizePx * 0.18f
            val headCenterY = sizePx * 0.38f
            canvas.drawCircle(cx, headCenterY, headRadius, iconPaint)

            val bodyLeft = sizePx * 0.26f
            val bodyRight = sizePx * 0.74f
            val bodyTop = sizePx * 0.56f
            val bodyBottom = sizePx * 0.90f
            val rect = RectF(bodyLeft, bodyTop, bodyRight, bodyBottom)
            canvas.drawRoundRect(rect, sizePx * 0.22f, sizePx * 0.22f, iconPaint)
        }

        return bmp
    }

    private fun isBlankOrNullString(value: String?): Boolean {
        val v = value?.trim() ?: return true
        if (v.isEmpty()) return true
        return v.equals("null", ignoreCase = true)
    }

    private fun enqueuePendingChatPayload(data: Map<String, String>) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString(PENDING_QUEUE_KEY, null)
            var arr = try {
                if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)
            } catch (_: Exception) {
                JSONArray()
            }

            val obj = JSONObject()
            for ((k, v) in data) {
                obj.put(k, v)
            }
            obj.put("_receivedAt", System.currentTimeMillis())
            arr.put(obj)

            val max = 50
            if (arr.length() > max) {
                val trimmed = JSONArray()
                val start = arr.length() - max
                for (i in start until arr.length()) {
                    trimmed.put(arr.get(i))
                }
                arr = trimmed
            }

            prefs.edit().putString(PENDING_QUEUE_KEY, arr.toString()).apply()
        } catch (_: Exception) {
        }
    }

    private fun handleProfileUpdateSilently(data: Map<String, String>) {
        try {
            val userId = data["userId"]
                ?: data["user_id"]
                ?: data["uid"]
                ?: ""
            if (userId.isEmpty()) return

            var sawChatPictureField = false
            var chatPictureValue: String? = null
            var sawChatPictureVersionField = false

            val updatedDataRaw = data["updatedData"]
                ?: data["updated_data"]

            if (!updatedDataRaw.isNullOrEmpty()) {
                try {
                    val parsed = JSONObject(updatedDataRaw)
                    val userObj = parsed.optJSONObject("user")

                    if (userObj != null) {
                        if (userObj.has("chat_picture")) {
                            sawChatPictureField = true
                            chatPictureValue = if (userObj.isNull("chat_picture")) "" else userObj.optString("chat_picture", "")
                        }
                        if (userObj.has("chat_picture_version")) {
                            sawChatPictureVersionField = true
                        }
                    }

                    if (!sawChatPictureField && parsed.has("chat_picture")) {
                        sawChatPictureField = true
                        chatPictureValue = if (parsed.isNull("chat_picture")) "" else parsed.optString("chat_picture", "")
                    }
                    if (!sawChatPictureVersionField && parsed.has("chat_picture_version")) {
                        sawChatPictureVersionField = true
                    }
                } catch (_: Exception) {
                }
            }

            if (!sawChatPictureField) {
                // Some payloads may put fields directly on the root data.
                if (data.containsKey("chat_picture") || data.containsKey("chatPicture") ||
                    data.containsKey("profile_pic") || data.containsKey("profilePic")) {
                    sawChatPictureField = true
                    chatPictureValue = data["chat_picture"]
                        ?: data["chatPicture"]
                        ?: data["profile_pic"]
                        ?: data["profilePic"]
                }
            }

            if (!sawChatPictureVersionField) {
                if (data.containsKey("chat_picture_version") || data.containsKey("chatPictureVersion") ||
                    data.containsKey("profile_pic_version") || data.containsKey("profilePicVersion")) {
                    sawChatPictureVersionField = true
                }
            }

            val shouldClear = (sawChatPictureField && isBlankOrNullString(chatPictureValue)) || sawChatPictureVersionField
            if (shouldClear) {
                deleteCachedAvatar(userId)
            }
        } catch (_: Exception) {
        }
    }

    private fun cacheAvatar(senderId: String, bitmap: Bitmap) {
        if (senderId.isEmpty()) return
        val f = File(cacheDir, "notif_avatar_$senderId.png")
        FileOutputStream(f).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.flush()
        }
    }

    private fun getCircularBitmap(bitmap: Bitmap): Bitmap {
        val size = minOf(bitmap.width, bitmap.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint().apply {
            isAntiAlias = true
            isFilterBitmap = true
        }
        val radius = size / 2f
        canvas.drawCircle(radius, radius, radius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        val left = (bitmap.width - size) / 2f
        val top = (bitmap.height - size) / 2f
        canvas.drawBitmap(bitmap, -left, -top, paint)
        return output
    }

    private fun showChatPictureLikeNotification(data: Map<String, String>) {
        try {
            Log.d(TAG, "❤️ [DEVICE_B_FCM] showChatPictureLikeNotification() ENTRY")
            Log.d(TAG, "❤️ [DEVICE_B_FCM] Full payload: $data")
            
            val likerName = data["fromUserName"]
                ?: data["from_user_name"]
                ?: data["likerName"]
                ?: data["liker_name"]
                ?: data["senderName"]
                ?: data["sender_name"]
                ?: data["senderFirstName"]
                ?: "Someone"

            val likerId = data["fromUserId"]
                ?: data["from_user_id"]
                ?: data["likerId"]
                ?: data["liker_id"]
                ?: data["senderId"]
                ?: data["sender_id"]
                ?: ""

            val likerProfilePic = data["from_user_chat_picture"]
                ?: data["fromUserChatPicture"]
                ?: data["from_user_profile_pic"]
                ?: data["fromUserProfilePic"]
                ?: data["likerProfilePic"]
                ?: data["liker_profile_pic"]
                ?: data["senderProfilePic"]
                ?: data["sender_profile_pic"]
                ?: data["profile_pic"]
                ?: data["profilePic"]

            val hasLikerProfilePicKey = data.containsKey("from_user_chat_picture") ||
                data.containsKey("fromUserChatPicture") ||
                data.containsKey("from_user_profile_pic") ||
                data.containsKey("fromUserProfilePic") ||
                data.containsKey("likerProfilePic") ||
                data.containsKey("liker_profile_pic") ||
                data.containsKey("senderProfilePic") ||
                data.containsKey("sender_profile_pic") ||
                data.containsKey("profile_pic") ||
                data.containsKey("profilePic")

            if (likerId.isNotEmpty() && hasLikerProfilePicKey && isBlankOrNullString(likerProfilePic)) {
                try { deleteCachedAvatar(likerId) } catch (_: Exception) {}
            }

            Log.d(TAG, "❤️ Chat picture like from: $likerName ($likerId)")
            Log.d(TAG, "🖼️ Liker profile pic URL: $likerProfilePic")

            val cachedContactName = try {
                getContactNameFromFlutterPrefs(likerId)
            } catch (_: Exception) { null }

            val title = if (!cachedContactName.isNullOrEmpty()) cachedContactName else likerName
            val body = "New like on your chat picture! ❤️"

            val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("notification_type", "chat_picture_like")
                putExtra("notification_liker_id", likerId)
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                "chat_picture_like_$likerId".hashCode(),
                intent,
                pendingIntentFlags
            )

            val notificationId = "chat_picture_like_$likerId".hashCode()

            val cachedBitmap = try {
                getCachedAvatar(likerId)
            } catch (_: Exception) { null }

            val circularBitmap: Bitmap? = if (cachedBitmap != null) {
                try { getCircularBitmap(cachedBitmap) } catch (_: Exception) { cachedBitmap }
            } else {
                try { createLetterAvatar(title) } catch (_: Exception) { null }
            }

            val style = if (circularBitmap != null) {
                try {
                    val person = Person.Builder()
                        .setName(title)
                        .setIcon(IconCompat.createWithBitmap(circularBitmap))
                        .build()

                    NotificationCompat.MessagingStyle(person)
                        .setConversationTitle(body)
                        .addMessage(body, System.currentTimeMillis(), person)
                } catch (_: Exception) { null }
            } else null

            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_SOCIAL)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setDefaults(NotificationCompat.DEFAULT_ALL)

            if (circularBitmap != null) {
                builder.setLargeIcon(circularBitmap)
            }

            if (style != null) {
                builder.setStyle(style)
            }

            try {
                NotificationManagerCompat.from(this).notify(notificationId, builder.build())
                Log.d(TAG, "✅ Chat picture like notification shown")
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ Permission denied for notification: ${e.message}")
            }

            // Enqueue for Flutter to save to Likes Hub DB on next startup
            try {
                enqueuePendingLikePayload(data)
            } catch (_: Exception) {}

            // Try to download avatar if not cached
            if (circularBitmap == null && !likerProfilePic.isNullOrEmpty()) {
                Thread {
                    try {
                        val authToken = readAuthTokenFromEncryptedPrefs()
                        val downloaded = downloadBitmap(likerProfilePic, authToken)
                        if (downloaded != null) {
                            try { cacheAvatar(likerId, downloaded) } catch (_: Exception) {}

                            val circularDownloaded = try {
                                getCircularBitmap(downloaded)
                            } catch (_: Exception) { downloaded }

                            val updatedStyle = try {
                                val person = Person.Builder()
                                    .setName(title)
                                    .setIcon(IconCompat.createWithBitmap(circularDownloaded))
                                    .build()

                                NotificationCompat.MessagingStyle(person)
                                    .setConversationTitle(body)
                                    .addMessage(body, System.currentTimeMillis(), person)
                            } catch (_: Exception) { null }

                            val updatedBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
                                .setSmallIcon(R.mipmap.ic_launcher)
                                .setContentTitle(title)
                                .setContentText(body)
                                .setPriority(NotificationCompat.PRIORITY_HIGH)
                                .setCategory(NotificationCompat.CATEGORY_SOCIAL)
                                .setAutoCancel(true)
                                .setContentIntent(pendingIntent)
                                .setDefaults(NotificationCompat.DEFAULT_ALL)
                                .setLargeIcon(circularDownloaded)

                            if (updatedStyle != null) {
                                updatedBuilder.setStyle(updatedStyle)
                            }

                            try {
                                NotificationManagerCompat.from(this)
                                    .notify(notificationId, updatedBuilder.build())
                                Log.d(TAG, "✅ Chat picture like notification updated with avatar")
                            } catch (_: SecurityException) {}
                        }
                    } catch (_: Exception) {}
                }.start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show chat picture like notification: ${e.message}")
        }
    }

    private fun showStatusLikeNotification(data: Map<String, String>) {
        try {
            Log.d(TAG, "❤️ [DEVICE_B_FCM] showStatusLikeNotification() ENTRY")
            Log.d(TAG, "❤️ [DEVICE_B_FCM] Full payload: $data")
            
            val likerName = data["fromUserName"]
                ?: data["from_user_name"]
                ?: data["likerName"]
                ?: data["liker_name"]
                ?: data["senderName"]
                ?: data["sender_name"]
                ?: data["senderFirstName"]
                ?: "Someone"

            val likerId = data["fromUserId"]
                ?: data["from_user_id"]
                ?: data["likerId"]
                ?: data["liker_id"]
                ?: data["senderId"]
                ?: data["sender_id"]
                ?: ""

            val likerProfilePic = data["from_user_chat_picture"]
                ?: data["fromUserChatPicture"]
                ?: data["from_user_profile_pic"]
                ?: data["fromUserProfilePic"]
                ?: data["likerProfilePic"]
                ?: data["liker_profile_pic"]
                ?: data["senderProfilePic"]
                ?: data["sender_profile_pic"]
                ?: data["profile_pic"]
                ?: data["profilePic"]

            val hasLikerProfilePicKey = data.containsKey("from_user_chat_picture") ||
                data.containsKey("fromUserChatPicture") ||
                data.containsKey("from_user_profile_pic") ||
                data.containsKey("fromUserProfilePic") ||
                data.containsKey("likerProfilePic") ||
                data.containsKey("liker_profile_pic") ||
                data.containsKey("senderProfilePic") ||
                data.containsKey("sender_profile_pic") ||
                data.containsKey("profile_pic") ||
                data.containsKey("profilePic")

            if (likerId.isNotEmpty() && hasLikerProfilePicKey && isBlankOrNullString(likerProfilePic)) {
                try { deleteCachedAvatar(likerId) } catch (_: Exception) {}
            }

            Log.d(TAG, "❤️ Status like from: $likerName ($likerId)")
            Log.d(TAG, "🖼️ Liker profile pic URL: $likerProfilePic")

            val cachedContactName = try {
                getContactNameFromFlutterPrefs(likerId)
            } catch (_: Exception) { null }

            val title = if (!cachedContactName.isNullOrEmpty()) cachedContactName else likerName
            val body = "New like on your Share Your Voice! ❤️"

            val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("notification_type", "status_like")
                putExtra("notification_liker_id", likerId)
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                "status_like_$likerId".hashCode(),
                intent,
                pendingIntentFlags
            )

            val notificationId = "status_like_$likerId".hashCode()

            val cachedBitmap = try {
                getCachedAvatar(likerId)
            } catch (_: Exception) { null }

            val circularBitmap: Bitmap? = if (cachedBitmap != null) {
                try { getCircularBitmap(cachedBitmap) } catch (_: Exception) { cachedBitmap }
            } else {
                try { createLetterAvatar(title) } catch (_: Exception) { null }
            }

            val style = if (circularBitmap != null) {
                try {
                    val person = Person.Builder()
                        .setName(title)
                        .setIcon(IconCompat.createWithBitmap(circularBitmap))
                        .build()

                    NotificationCompat.MessagingStyle(person)
                        .setConversationTitle(body)
                        .addMessage(body, System.currentTimeMillis(), person)
                } catch (_: Exception) { null }
            } else null

            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_SOCIAL)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setDefaults(NotificationCompat.DEFAULT_ALL)

            if (circularBitmap != null) {
                builder.setLargeIcon(circularBitmap)
            }

            if (style != null) {
                builder.setStyle(style)
            }

            try {
                NotificationManagerCompat.from(this).notify(notificationId, builder.build())
                Log.d(TAG, "✅ Status like notification shown")
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ Permission denied for notification: ${e.message}")
            }

            // Enqueue for Flutter to save to Likes Hub DB on next startup
            try {
                enqueuePendingLikePayload(data)
            } catch (_: Exception) {}

            // Try to download avatar if not cached
            if (circularBitmap == null && !likerProfilePic.isNullOrEmpty()) {
                Thread {
                    try {
                        val authToken = readAuthTokenFromEncryptedPrefs()
                        val downloaded = downloadBitmap(likerProfilePic, authToken)
                        if (downloaded != null) {
                            try { cacheAvatar(likerId, downloaded) } catch (_: Exception) {}

                            val circularDownloaded = try {
                                getCircularBitmap(downloaded)
                            } catch (_: Exception) { downloaded }

                            val updatedStyle = try {
                                val person = Person.Builder()
                                    .setName(title)
                                    .setIcon(IconCompat.createWithBitmap(circularDownloaded))
                                    .build()

                                NotificationCompat.MessagingStyle(person)
                                    .setConversationTitle(body)
                                    .addMessage(body, System.currentTimeMillis(), person)
                            } catch (_: Exception) { null }

                            val updatedBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
                                .setSmallIcon(R.mipmap.ic_launcher)
                                .setContentTitle(title)
                                .setContentText(body)
                                .setPriority(NotificationCompat.PRIORITY_HIGH)
                                .setCategory(NotificationCompat.CATEGORY_SOCIAL)
                                .setAutoCancel(true)
                                .setContentIntent(pendingIntent)
                                .setDefaults(NotificationCompat.DEFAULT_ALL)
                                .setLargeIcon(circularDownloaded)

                            if (updatedStyle != null) {
                                updatedBuilder.setStyle(updatedStyle)
                            }

                            try {
                                NotificationManagerCompat.from(this)
                                    .notify(notificationId, updatedBuilder.build())
                                Log.d(TAG, "✅ Status like notification updated with avatar")
                            } catch (_: SecurityException) {}
                        }
                    } catch (_: Exception) {}
                }.start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show status like notification: ${e.message}")
        }
    }

    private fun enqueuePendingLikePayload(data: Map<String, String>) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString(PENDING_LIKES_QUEUE_KEY, null)
            var arr = try {
                if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)
            } catch (_: Exception) {
                JSONArray()
            }

            val obj = JSONObject()
            for ((k, v) in data) {
                obj.put(k, v)
            }
            obj.put("_receivedAt", System.currentTimeMillis())
            arr.put(obj)

            val max = 50
            if (arr.length() > max) {
                val trimmed = JSONArray()
                val start = arr.length() - max
                for (i in start until arr.length()) {
                    trimmed.put(arr.get(i))
                }
                arr = trimmed
            }

            prefs.edit().putString(PENDING_LIKES_QUEUE_KEY, arr.toString()).apply()
            Log.d(TAG, "✅ Like payload enqueued for Flutter (queue size=${arr.length()})")
        } catch (e: Exception) {
            Log.d(TAG, "⚠️ Failed to enqueue like payload: ${e.message}")
        }
    }

    private fun getContactNameFromFlutterPrefs(userId: String): String? {
        if (userId.isEmpty()) return null
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.contact_name_map_by_user_id", null) ?: return null
            val json = JSONObject(raw)
            val v = json.optString(userId, "").trim()
            if (v.isNotEmpty()) v else null
        } catch (_: Exception) {
            null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Chat message notifications"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
                setShowBadge(true)

                // Use custom sound (must exist in res/raw as notification_sound1.mp3)
                val soundUri = Uri.parse(
                    "android.resource://" + packageName + "/" + R.raw.notification_sound1
                )
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(soundUri, attrs)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "📢 Notification channel created")
        }
    }
}
