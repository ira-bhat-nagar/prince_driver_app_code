package com.gorush.driver.gorush_driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.MediaPlayer
import android.os.*
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.gorush.driver/notifications"
    private var mediaPlayer: MediaPlayer? = null
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
            stopRideRing() // stop any previous

            // Use res/raw/ride_request.mp3 — most reliable, always works
            val resId = resources.getIdentifier("ride_request", "raw", packageName)
            if (resId != 0) {
                mediaPlayer = MediaPlayer.create(this, resId)
                mediaPlayer?.isLooping = false
                mediaPlayer?.start()
                mediaPlayer?.setOnCompletionListener { stopRideRing() }
            } else {
                android.util.Log.e("GoRush", "ride_request.mp3 not found in res/raw/")
            }

            // Vibration pattern: 400ms ON, 200ms OFF, 400ms ON
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            val pattern = longArrayOf(0, 400, 200, 400, 200, 400)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            android.util.Log.e("GoRush", "playRideRing error: ${e.message}")
        }
    }

    private fun stopRideRing() {
        try {
            if (mediaPlayer?.isPlaying == true) mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
            vibrator?.cancel()
        } catch (_: Exception) {}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "gorush_driver_status",
                "Driver Status Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "GoRush Driver alerts"
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
        } catch (_: SecurityException) {}
    }
}
