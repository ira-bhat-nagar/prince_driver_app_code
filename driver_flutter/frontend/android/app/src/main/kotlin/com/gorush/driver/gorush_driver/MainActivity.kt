package com.gorush.driver.gorush_driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.res.AssetFileDescriptor
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
            // Stop any existing playback
            stopRideRing()

            // Play custom GoRush ride request sound from Flutter assets
            val afd: AssetFileDescriptor = assets.openFd("flutter_assets/assets/sounds/ride_request.mp3")
            mediaPlayer = MediaPlayer().apply {
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                isLooping = false
                prepare()
                start()
            }

            // Vibration: 400ms ON, 200ms OFF, 400ms ON, 200ms OFF, 400ms ON
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
            android.util.Log.e("GoRush", "playRideRing error: ${e.message}")
        }
    }

    private fun stopRideRing() {
        try {
            mediaPlayer?.stop()
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
