// File: android/app/src/main/kotlin/com/example/keep_socket_alive/SocketForegroundService.kt
package com.example.keep_socket_alive

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.FlutterInjector
import io.flutter.view.FlutterCallbackInformation

class SocketForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var isServiceStarted = false
    private var flutterEngine: FlutterEngine? = null

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val action = intent.action
            when (action) {
                ACTION_START -> startService()
                ACTION_STOP -> stopService()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        flutterEngine?.destroy()
    }

    private fun startService() {
        if (isServiceStarted) return
        isServiceStarted = true

        // Wake lock to keep CPU running
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SocketIOService::lock"
        )
        wakeLock?.acquire(WAKE_LOCK_TIMEOUT)

        // Initialize Flutter engine
        initializeFlutterEngine()
    }

    private fun stopService() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        stopForeground(true)
        stopSelf()
        isServiceStarted = false
    }

    private fun initializeFlutterEngine() {
        // Get the stored Dart callback handle
        val prefs = getSharedPreferences("socket_io_prefs", Context.MODE_PRIVATE)
        val callbackHandle = prefs.getLong("background_callback_handle", 0)
        if (callbackHandle == 0L) {
            stopSelf()
            return
        }

        // Initialize Flutter engine
        flutterEngine = FlutterEngine(this)
        
        // Get the callback info and start executing Dart code
        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
        if (callbackInfo != null) {
            flutterEngine?.dartExecutor?.executeDartCallback(
                DartExecutor.DartCallback(
                    assets,
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    callbackInfo
                )
            )
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Socket.IO Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background service for Socket.IO connections"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Socket.IO Service")
            .setContentText("Maintaining background connection")
            .setSmallIcon(R.drawable.notification_icon)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "SocketIOServiceChannel"
        private const val WAKE_LOCK_TIMEOUT = 10 * 60 * 1000L // 10 minutes

        const val ACTION_START = "START"
        const val ACTION_STOP = "STOP"
    }
}