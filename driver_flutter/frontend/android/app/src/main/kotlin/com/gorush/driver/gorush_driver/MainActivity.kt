package com.gorush.driver.gorush_driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.*
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.gorush.driver/notifications"
    private var rideRingtone: Ringtone? = null
    private var vibrator: Vibrator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showNotification" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "GoRush Driver"
                        val body = call.argument<String>("body") ?: ""
                        val channelId = call.argument<String>("channelId") ?: "gorush_driver_status"
                        showNotification(id, title, body, channelId)
                        result.success(null)
                    }
                    "playRideRing" -> {
                        playRideRing()
                        result.success(null)
                    }
                    "stopRideRing" -> {
                        stopRideRing()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playRideRing() {
        try {
            // Stop any existing ring first
            rideRingtone?.stop()

            // Use phone's default ringtone — best quality sound
            val ringtoneUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            rideRingtone = RingtoneManager.getRingtone(applicationContext, ringtoneUri)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                rideRingtone?.isLooping = false
            }
            rideRingtone?.play()

            // Vibrate pattern: wait 0ms, vibrate 400ms, pause 200ms, vibrate 400ms
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            val pattern = longArrayOf(0, 400, 200, 400, 200, 400)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(pattern, -1)
                vibrator?.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            // Silently skip if ringtone not available
        }
    }

    private fun stopRideRing() {
        rideRingtone?.stop()
        rideRingtone = null
        vibrator?.cancel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "gorush_driver_status",
                "Driver Status Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when driver goes Online or Offline"
                enableVibration(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(id: Int, title: String, body: String, channelId: String) {
        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        try {
            NotificationManagerCompat.from(this).notify(id, builder.build())
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS permission not granted — silently skip
        }
    }
}
