package com.gorush.driver.gorush_driver

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.os.*
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.gorush.driver/notifications"
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var _ringActive = false
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> {
                        requestNotificationPermission(result)
                    }
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

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        if (notificationPermissionResult != null) {
            result.success(false)
            return
        }
        notificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            notificationPermissionResult?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            )
            notificationPermissionResult = null
        }
    }

    private fun playRideRing() {
        try {
            stopRideRing() // stop any previous

            val resId = resources.getIdentifier("ride_request", "raw", packageName)
            if (resId == 0) {
                android.util.Log.e("GoRush", "ride_request not found in res/raw/")
            } else {
                _ringActive = true
                _startMediaPlayer(resId)
                // Auto-stop after exactly 30 seconds
                Handler(mainLooper).postDelayed({
                    _ringActive = false
                    stopRideRing()
                }, 30_000L)
            }

            // Vibration pattern repeating for 30s
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            val pattern = longArrayOf(0, 500, 300, 500, 300, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            android.util.Log.e("GoRush", "playRideRing error: ${e.message}")
        }
    }

    private fun _startMediaPlayer(resId: Int) {
        try {
            val mp = MediaPlayer.create(this, resId) ?: return
            mp.setOnCompletionListener {
                it.release()
                if (_ringActive) {
                    // Restart for looping — works with all audio formats including MPEG
                    _startMediaPlayer(resId)
                }
            }
            mp.setOnErrorListener { it, _, _ ->
                it.release()
                false
            }
            mediaPlayer = mp
            mp.start()
        } catch (e: Exception) {
            android.util.Log.e("GoRush", "MediaPlayer error: ${e.message}")
        }
    }

    private fun stopRideRing() {
        try {
            _ringActive = false
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

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 9142
    }
}
