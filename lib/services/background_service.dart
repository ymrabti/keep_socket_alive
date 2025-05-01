// File: lib/services/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';
import 'socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Add missing imports
import 'dart:io';
// File: lib/services/background_service.dart (update existing file)

// Top level function that will be called by the native foreground service
@pragma('vm:entry-point')
void socketBackgroundMain() {
  // This ensures we have a properly initialized WidgetsBinding
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize socket connection
  final socketService = SocketService();
  socketService.init();
  socketService.connect();

  // Set up notification handling
  final notificationService = NotificationService();
  notificationService.init();

  socketService.onNotification = (notification) {
    notificationService.showNotification(
      notification['title'] ?? 'New Notification',
      notification['body'] ?? 'You have a new notification',
    );
  };

  // Get device ID
  SharedPreferences.getInstance().then((prefs) {
    String? deviceId = prefs.getString('deviceId');
    if (deviceId != null) {
      socketService.register(deviceId);
    }
  });
}

class BackgroundService {
  // Store callback handle for later use by the foreground service
  static Future<void> startBackgroundService() async {
    // Get the handle for the background function
    final callback = PluginUtilities.getCallbackHandle(socketBackgroundMain);
    if (callback != null) {
      // Store it in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('background_callback_handle', callback.toRawHandle());

      // Start the foreground service on Android
      if (Platform.isAndroid) {
        const methodChannel = MethodChannel('com.example.keep_socket_alive/service');
        await methodChannel.invokeMethod('startService');
      }
    }
  }

  static Future<void> stopBackgroundService() async {
    if (Platform.isAndroid) {
      const methodChannel = MethodChannel('com.example.keep_socket_alive/service');
      await methodChannel.invokeMethod('stopService');
    }
  }
}
