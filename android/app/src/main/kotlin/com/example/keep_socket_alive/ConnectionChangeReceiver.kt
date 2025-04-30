
// File: android/app/src/main/kotlin/com/example/flutter_socketio_background/ConnectionChangeReceiver.kt
package com.example.keep_socket_alive

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.os.Build
import android.util.Log

class ConnectionChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ConnectivityManager.CONNECTIVITY_ACTION) {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val activeNetwork = cm.activeNetworkInfo
            val isConnected = activeNetwork != null && activeNetwork.isConnected
            
            Log.d("ConnectionReceiver", "Network state changed. Connected: $isConnected")
            
            if (isConnected) {
                // Start or restart the service when connection is available
                SocketBackgroundService.startService(context)
            }
        }
    }
}