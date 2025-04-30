// File: android/app/src/main/kotlin/com/example/flutter_socketio_background/SocketBackgroundService.kt
package com.example.keep_socket_alive

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.socket.client.IO
import io.socket.client.Socket
import org.json.JSONObject
import java.net.URISyntaxException

class SocketBackgroundService : Service() {
    private val TAG = "SocketBackgroundService"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "socket_service_channel"
    private var socket: Socket? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private lateinit var sharedPreferences: SharedPreferences
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate")
        sharedPreferences = getSharedPreferences("socket_prefs", Context.MODE_PRIVATE)
        initializeWakeLock()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification("Socket Service Running", "Maintaining connection..."))
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand")
        
        // Initialize and connect Socket
        initializeSocket()
        
        return START_STICKY
    }
    
    override fun onDestroy() {
        Log.d(TAG, "Service onDestroy")
        disconnectSocket()
        releaseWakeLock()
        
        // Request a restart of the service
        val restartIntent = Intent(applicationContext, SocketBackgroundService::class.java)
        startService(restartIntent)
        
        super.onDestroy()
    }
    
    private fun initializeWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SocketBackgroundService::WakeLock"
        ).apply {
            acquire(30 * 60 * 1000L) // 30 minutes
        }
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Socket.io Background Service"
            val descriptionText = "Maintains socket.io connection in background"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(title: String, content: String): Notification {
        // Intent to open the app when notification is clicked
        val pendingIntent = Intent(this, MainActivity::class.java).let { notificationIntent ->
            PendingIntent.getActivity(
                this, 0, notificationIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun initializeSocket() {
        try {
            val deviceId = sharedPreferences.getString("deviceId", null) ?: 
                           System.currentTimeMillis().toString().also {
                               sharedPreferences.edit().putString("deviceId", it).apply()
                           }
            
            val serverUrl = "http://10.0.2.2:3000" // Change this to your server URL
            
            val options = IO.Options().apply {
                reconnection = true
                reconnectionAttempts = Int.MAX_VALUE
                reconnectionDelay = 1000
                reconnectionDelayMax = 5000
                timeout = 20000
            }
            
            socket = IO.socket(serverUrl, options)
            
            socket?.on(Socket.EVENT_CONNECT) {
                Log.d(TAG, "Socket connected")
                // Register device
                socket?.emit("register", deviceId)
                updateNotification("Socket Connected", "Active connection maintained")
            }
            
            socket?.on(Socket.EVENT_DISCONNECT) {
                Log.d(TAG, "Socket disconnected")
                updateNotification("Socket Disconnected", "Attempting to reconnect...")
            }
            
            socket?.on(Socket.EVENT_CONNECT_ERROR) { args ->
                Log.e(TAG, "Connection error: ${args[0]}")
                updateNotification("Connection Error", "Attempting to reconnect...")
            }
            
            socket?.on("notification") { args ->
                try {
                    val data = args[0] as JSONObject
                    val title = data.optString("title", "New Notification")
                    val body = data.optString("body", "You have a new notification")
                    
                    // Send to Flutter via broadcast
                    val intent = Intent("socket.notification.received")
                    intent.putExtra("title", title)
                    intent.putExtra("body", body)
                    intent.putExtra("timestamp", data.optString("timestamp", ""))
                    sendBroadcast(intent)
                    
                    // Also show notification directly from native side
                    showNotification(title, body)
                    
                    Log.d(TAG, "Notification received: $title - $body")
                } catch (e: Exception) {
                    Log.e(TAG, "Error handling notification", e)
                }
            }
            
            // Connect socket
            socket?.connect()
            
        } catch (e: URISyntaxException) {
            Log.e(TAG, "Socket initialization error", e)
        }
    }
    
    private fun disconnectSocket() {
        socket?.disconnect()
        socket?.off()
        socket = null
    }
    
    private fun updateNotification(title: String, content: String) {
        val notification = createNotification(title, content)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun showNotification(title: String, body: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val notification = NotificationCompat.Builder(this, "socket_notifications_channel")
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        
        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
    
    companion object {
        fun startService(context: Context) {
            val intent = Intent(context, SocketBackgroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, SocketBackgroundService::class.java)
            context.stopService(intent)
        }
    }
}