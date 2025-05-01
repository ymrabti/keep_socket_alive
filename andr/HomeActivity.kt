// package com.example.keep_socket_alive

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL_NAME = "com.example.keep_socket_alive/service"
    private val EVENT_CHANNEL_NAME = "com.example.keep_socket_alive/notifications"
    
    private var notificationReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Method channel for controlling the service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    SocketBackgroundService.startService(this)
                    result.success(true)
                }
                "stopService" -> {
                    SocketBackgroundService.stopService(this)
                    result.success(true)
                }
                "isServiceRunning" -> {
                    // Check if the service is running
                    val isRunning = isServiceRunning()
                    result.success(isRunning)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Event channel for notification updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerNotificationReceiver()
                }
                
                override fun onCancel(arguments: Any?) {
                    unregisterNotificationReceiver()
                    eventSink = null
                }
            }
        )
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Start the service when the app is launched
        SocketBackgroundService.startService(this)
    }
    
    private fun registerNotificationReceiver() {
        notificationReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "socket.notification.received") {
                    val title = intent.getStringExtra("title") ?: "New Notification"
                    val body = intent.getStringExtra("body") ?: "You have a new notification"
                    val timestamp = intent.getStringExtra("timestamp") ?: ""
                    
                    val notification = HashMap<String, String>()
                    notification["title"] = title
                    notification["body"] = body
                    notification["timestamp"] = timestamp
                    
                    eventSink?.success(notification)
                }
            }
        }
        
        registerReceiver(
            notificationReceiver,
            IntentFilter("socket.notification.received")
        )
    }
    
    private fun unregisterNotificationReceiver() {
        notificationReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver might not be registered
            }
        }
        notificationReceiver = null
    }
    
    private fun isServiceRunning(): Boolean {
        // This is a simple check and might not be 100% accurate
        // A more robust implementation would use ActivityManager to check service status
        return try {
            val sharedPreferences = getSharedPreferences("socket_service_status", Context.MODE_PRIVATE)
            sharedPreferences.getBoolean("is_running", false)
        } catch (e: Exception) {
            false
        }
    }
    
    override fun onDestroy() {
        unregisterNotificationReceiver()
        super.onDestroy()
    }
}