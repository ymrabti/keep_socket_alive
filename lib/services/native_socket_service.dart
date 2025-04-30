// File: lib/services/native_socket_service.dart
import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';

class NativeSocketService {
  static const MethodChannel _methodChannel = MethodChannel('com.example.flutter_socketio_background/service');
  static const EventChannel _eventChannel = EventChannel('com.example.flutter_socketio_background/notifications');

  // Stream controller for notification events
  final StreamController<Map<String, dynamic>> _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  NativeSocketService() {
    // Listen to notification events from native code
    _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final Map<String, dynamic> notification = Map<String, dynamic>.from(event);
        _notificationController.add(notification);
      }
    }, onError: (dynamic error) {
      log('Error from event channel: $error');
    });
  }

  // Start the native socket service
  Future<bool> startService() async {
    try {
      final bool result = await _methodChannel.invokeMethod('startService');
      return result;
    } on PlatformException catch (e) {
      log('Failed to start service: ${e.message}');
      return false;
    }
  }

  // Stop the native socket service
  Future<bool> stopService() async {
    try {
      final bool result = await _methodChannel.invokeMethod('stopService');
      return result;
    } on PlatformException catch (e) {
      log('Failed to stop service: ${e.message}');
      return false;
    }
  }

  // Check if the service is running
  Future<bool> isServiceRunning() async {
    try {
      final bool result = await _methodChannel.invokeMethod('isServiceRunning');
      return result;
    } on PlatformException catch (e) {
      log('Failed to check service status: ${e.message}');
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    _notificationController.close();
  }
}
