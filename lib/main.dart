// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:async';
import 'services/socket_service.dart';
import 'services/notification_service.dart';

// This is the background task that will be executed periodically
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize services
    final notificationService = NotificationService();
    await notificationService.init();

    // Reconnect socket
    final socketService = SocketService();
    await socketService.init();
    socketService.connect();

    // Keep the task alive for a few seconds to allow socket connections
    await Future.delayed(const Duration(seconds: 5));

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize work manager for background tasks
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  // Register periodic task
  await Workmanager().registerPeriodicTask(
    'socketio.reconnect',
    'socketReconnectTask',
    frequency: const Duration(minutes: 15), // Every 15 minutes
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.init();

  // Initialize socket service
  final socketService = SocketService();
  await socketService.init();

  runApp(MyApp(
    notificationService: notificationService,
    socketService: socketService,
  ));
}

class MyApp extends StatelessWidget {
  final NotificationService notificationService;
  final SocketService socketService;

  const MyApp({super.key, required this.notificationService, required this.socketService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Socket.io Background Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: MyHomePage(
        title: 'Socket.io Background Notifications',
        notificationService: notificationService,
        socketService: socketService,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final NotificationService notificationService;
  final SocketService socketService;

  const MyHomePage({super.key, required this.title, required this.notificationService, required this.socketService});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool _isConnected = false;
  String _deviceId = '';
  List<String> _notifications = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectSocket();
    }
  }

  Future<void> _initializeApp() async {
    // Get device ID or create a new one
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('deviceId');
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('deviceId', deviceId);
    }

    setState(() {
      _deviceId = deviceId!;
    });

    // Load previous notifications
    List<String> notifs = prefs.getStringList('notifications') ?? [];
    setState(() {
      _notifications = notifs;
    });

    // Set up notification callback
    widget.socketService.onNotification = (notification) {
      _handleNotification(notification);
    };

    // Connect socket
    _connectSocket();
  }

  void _connectSocket() {
    widget.socketService.connect();
    widget.socketService.socket?.onConnect((_) {
      setState(() {
        _isConnected = true;
      });
      widget.socketService.register(_deviceId);
    });

    widget.socketService.socket?.onDisconnect((_) {
      setState(() {
        _isConnected = false;
      });
    });
  }

  void _handleNotification(Map<String, dynamic> notification) async {
    // Show notification
    widget.notificationService.showNotification(
      notification['title'] ?? 'New Notification',
      notification['body'] ?? 'You have a new notification',
    );

    // Save notification
    String notifText = "${notification['title']} - ${notification['body']} (${notification['timestamp']})";
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> notifs = [..._notifications, notifText];
    await prefs.setStringList('notifications', notifs);

    setState(() {
      _notifications = notifs;
    });
  }

  void _clearNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notifications', []);
    setState(() {
      _notifications = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: _isConnected ? Colors.green : Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device ID: $_deviceId', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.error,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notifications History:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: _clearNotifications,
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(child: Text('No notifications yet'))
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[_notifications.length - 1 - index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.notifications),
                            title: Text(notification),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _connectSocket,
        tooltip: 'Reconnect',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
