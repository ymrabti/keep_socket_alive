import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:get_it/get_it.dart';

// Global notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Socket service singleton
final getIt = GetIt.instance;

// Task names for WorkManager
const String socketBackgroundTask = 'socketBackgroundTask';

// Setup background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case socketBackgroundTask:
          await connectToSocketServer();
          break;
        default:
          log("Unknown task: $task");
      }
      return Future.value(true);
    } catch (e) {
      log("Error in background task: $e");
      return Future.value(false);
    }
  });
}

// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Run socket connection in the background service
  await connectToSocketServer();

  // Keep the service alive by periodically sending updates
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Socket Notification Service",
        content: "Running in background since ${DateTime.now().toString()}",
      );
    }

    // Send data to the Main app
    service.invoke('update', {
      'current_time': DateTime.now().toString(),
    });
  });
}

// Connect to socket server
Future<void> connectToSocketServer() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String serverUrl = prefs.getString('server_url') ?? 'http://192.168.8.100:3000';

  try {
    // Create the Socket.IO connection
    final socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
    });

    // Socket events
    socket.onConnect((_) {
      log('Socket connected');
      showNotification('Socket Connected', 'Connected to $serverUrl');
    });

    socket.onDisconnect((_) {
      log('Socket disconnected');
    });

    socket.on('notification', (data) {
      log('Received notification: $data');

      // Extract notification details from data
      String title = data['title'] ?? 'New Notification';
      String body = data['body'] ?? 'You have a new notification';

      showNotification(title, body);
    });

    socket.onError((err) {
      log('Socket error: $err');
      showNotification('Connection Error', 'Failed to connect to server');
    });

    // Keep reference to the socket
    getIt.registerSingleton<IO.Socket>(socket, instanceName: 'socket');
  } catch (e) {
    log('Socket connection error: $e');
    showNotification('Error', 'Failed to initialize socket: $e');
  }
}

// Show a notification
Future<void> showNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'socket_notifications_channel',
    'Socket Notifications',
    channelDescription: 'Notifications from Socket.IO connection',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecond, // Random ID
    title,
    body,
    platformDetails,
  );
}

// Initialize notifications
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

  final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      log('Notification clicked: ${details.payload}');
    },
  );
}

// Initialize background service
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'socket_service_channel',
      initialNotificationTitle: 'Socket Service',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await initializeNotifications();

  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  // Register periodic task
  await Workmanager().registerPeriodicTask(
    'socketBackgroundTaskId',
    socketBackgroundTask,
    frequency: Duration(minutes: 15), // Minimum interval for Android
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );

  // Initialize background service for continuous operation
  await initializeBackgroundService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Socket Notification App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _serverUrlController = TextEditingController();
  bool _isConnected = false;
  String _lastMessage = 'No messages yet';
  String _serviceStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
    _initializeSocket();
    _setupServiceListener();
  }

  Future<void> _loadServerUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString('server_url') ?? 'http://192.168.8.100:3000';
    setState(() {
      _serverUrlController.text = url;
    });
  }

  Future<void> _saveServerUrl(String url) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
  }

  void _setupServiceListener() {
    FlutterBackgroundService().on('update').listen((event) {
      if (event != null) {
        setState(() {
          _serviceStatus = 'Running since: ${event['current_time'] ?? 'unknown'}';
        });
      }
    });
  }

  Future<void> _initializeSocket() async {
    try {
      await connectToSocketServer();
      if (getIt.isRegistered<IO.Socket>(instanceName: 'socket')) {
        final socket = getIt<IO.Socket>(instanceName: 'socket');
        socket.on('notification', (data) {
          setState(() {
            _lastMessage = 'Notification: ${data.toString()}';
          });
        });
        setState(() {
          _isConnected = socket.connected;
        });
      }
    } catch (e) {
      log('Socket initialization error: $e');
    }
  }

  void _reconnectSocket() async {
    await _saveServerUrl(_serverUrlController.text);

    try {
      if (getIt.isRegistered<IO.Socket>(instanceName: 'socket')) {
        final socket = getIt<IO.Socket>(instanceName: 'socket');
        socket.disconnect();
        getIt.unregister<IO.Socket>(instanceName: 'socket');
      }

      await _initializeSocket();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconnecting to socket server...')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Socket Notification App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Socket Server URL',
                hintText: 'http://192.168.8.100:3000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _reconnectSocket,
              child: const Text('Connect to Server'),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Status: ${_isConnected ? 'Connected' : 'Disconnected'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text('Last Message: $_lastMessage'),
            const SizedBox(height: 16),
            Text('Background Service: $_serviceStatus'),
            const SizedBox(height: 24),
            const Divider(),
            const Text(
              'This app will continue to receive notifications even when closed.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }
}
