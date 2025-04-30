// File: lib/services/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'dart:isolate';
import 'notification_service.dart';
import 'socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Add missing imports
import 'dart:io';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  static const String isolateName = 'socketIsolate';
  final ReceivePort _receivePort = ReceivePort();

  Future<void> initializeService() async {
    // Register the service to be revived in the background
    if (Platform.isAndroid) {
      if (IsolateNameServer.lookupPortByName(isolateName) != null) {
        IsolateNameServer.removePortNameMapping(isolateName);
      }
      IsolateNameServer.registerPortWithName(_receivePort.sendPort, isolateName);
    }

    // Start listening for events
    _receivePort.listen((dynamic message) {
      // Handle message from the background isolate
    });
  }

  static Future<void> runBackgroundTask() async {
    // Initialize services
    final notificationService = NotificationService();
    await notificationService.init();

    final socketService = SocketService();
    await socketService.init();

    // Get device ID
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('deviceId');

    if (deviceId != null) {
      // Set up notification callback
      socketService.onNotification = (notification) {
        notificationService.showNotification(
          notification['title'] ?? 'New Notification',
          notification['body'] ?? 'You have a new notification',
        );
      };

      // Connect socket and register device
      socketService.connect();
      socketService.register(deviceId);

      // Keep the background task alive for some time
      await Future.delayed(const Duration(minutes: 5));

      // Clean up
      //   socketService.disco nnect();
    }
  }
}
