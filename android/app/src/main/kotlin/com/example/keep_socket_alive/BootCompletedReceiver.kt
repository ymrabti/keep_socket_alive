// File: android/app/src/main/kotlin/com/example/flutter_socketio_background/BootCompletedReceiver.kt
package com.example.keep_socket_alive

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            
            Log.d("BootReceiver", "Boot completed, starting socket service")
            
            // Start the service
            SocketBackgroundService.startService(context)
        }
    }
}
