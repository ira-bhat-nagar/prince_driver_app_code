package com.gorush.driver.gorush_driver

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
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
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> requestNotificationPermission(result)
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: "GoRush Captain"
                    val body = call.argument<String>("body") ?: ""
                    val channelId = call.argument<String>("channelId") ?: "gorush_driver_status"
                    showNotification(id, title, body, channelId)
                    result.success(null)
                }
                "showRideNotification" -> {
                    val id = call.argument<Int>("id") ?: 2001
                    val title = call.argument<String>("title") ?: "New Ride Request"
                    val body = call.argument<String>("body") ?: ""
                    val channelId = call.argument<String>("channelId") ?: "gorush_driver_status"
                    showRideNotificationWithActions(id, title, body, channelId)
                    result.success(null)
                }
                "playRideRing" -> { playRideRing(); result.success(null) }
                "stopRideRing" -> { stopRideRing(); result.success(null) }
                "dismissNotification" -> {
                    val id = call.argument<Int>("id") ?: 2001
                    NotificationManagerCompat.from(this).cancel(id)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Handle any pending ride action from a cold start via notification
        handleRideActionIntent(intent)
    }

    /** Called when app is already running and a notification action is tapped */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleRideActionIntent(intent)
    }

    private fun handleRideActionIntent(intent: Intent?) {
        val action = intent?.getStringExtra("ride_action") ?: return
        // Dismiss the ride notification
        NotificationManagerCompat.from(this).cancel(2001)
        // Send action to Flutter
        methodChannel?.invokeMethod("rideAction", action)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true); return
        }
        if (notificationPermissionResult != null) { result.success(false); return }
        notificationPermissionResult = result
        ActivityCompat.requestPermissions(this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            notificationPermissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            notificationPermissionResult = null
        }
    }

    private fun playRideRing() {
        try {
            stopRideRing()
            val resId = resources.getIdentifier("ride_request", "raw", packageName)
            if (resId == 0) {
                android.util.Log.e("GoRush", "ride_request not found in res/raw/")
            } else {
                _ringActive = true
                _startMediaPlayer(resId)
                Handler(mainLooper).postDelayed({
                    _ringActive = false
                    stopRideRing()
                }, 30_000L)
            }
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
                if (_ringActive) _startMediaPlayer(resId)
            }
            mp.setOnErrorListener { it, _, _ -> it.release(); false }
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
                "gorush_driver_status", "Driver Status Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "GoRush Captain alerts"
                enableVibration(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    /** Generic notification — tapping opens app */
    private fun showNotification(id: Int, title: String, body: String, channelId: String) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        val contentIntent = PendingIntent.getActivity(this, id, launchIntent, pendingFlags)

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)

        try {
            NotificationManagerCompat.from(this).notify(id, builder.build())
        } catch (_: SecurityException) {}
    }

    /** Ride request notification WITH ✅ Accept and ❌ Reject action buttons */
    private fun showRideNotificationWithActions(id: Int, title: String, body: String, channelId: String) {
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

        // Tap notification → open app → see dialog
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPI = PendingIntent.getActivity(this, 2000, openIntent, pendingFlags)

        // Accept action
        val acceptIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("ride_action", "accept")
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val acceptPI = PendingIntent.getActivity(this, 2001, acceptIntent, pendingFlags)

        // Reject action
        val rejectIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("ride_action", "reject")
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val rejectPI = PendingIntent.getActivity(this, 2002, rejectIntent, pendingFlags)

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .setContentIntent(openPI)
            .addAction(android.R.drawable.ic_media_play, "✅ Accept", acceptPI)
            .addAction(android.R.drawable.ic_delete, "❌ Reject", rejectPI)

        try {
            NotificationManagerCompat.from(this).notify(id, builder.build())
        } catch (_: SecurityException) {}
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 9142
    }
}
