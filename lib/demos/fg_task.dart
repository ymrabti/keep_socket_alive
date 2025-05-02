import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize port for communication between TaskHandler and UI.
  FlutterForegroundTask.initCommunicationPort();
  await startForegroundService();
  runApp(
    MaterialApp(
      home: HomeApp(),
    ),
  );
}

class HomeApp extends StatelessWidget {
  const HomeApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: InkWell(
          onTap: () async {
            await startForegroundService();
          },
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.red,
            ),
            child: Text('App'),
          ),
        ),
      ),
    );
  }
}

late IO.Socket socket;

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    log('Starting socket.io...');
    socket = IO.io('http://192.168.1.66:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.onConnect((_) {
      log('Connected to socket server');
    });
    socket.onDisconnect((_) {
      log('Disconnected from socket server');
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    log('Disposing socket...');
    socket.dispose();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    socket.emit('log', 'flutter_foreground');
  }
}

Future<void> startForegroundService() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'socket_channel_id',
      channelName: 'Keep Socket Alive',
      channelDescription: 'Maintient une connexion active',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.once(),
      autoRunOnBoot: false,
    ),
  );

  var serv = await FlutterForegroundTask.startService(
    notificationTitle: 'Socket actif',
    notificationText: 'Connexion en cours...',
    callback: startCallback,
  );
  log(serv.toString());
}

void stopForegroundService() {
  FlutterForegroundTask.stopService();
}

void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}
