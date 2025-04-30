// File: lib/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? socket;
  final String serverUrl = 'http://192.168.1.65:3000';
  Function(Map<String, dynamic>)? onNotification;

  Future<void> init() async {
    // Initialize socket configurations
  }

  void connect() {
    // Disconnect if already connected
    socket?.disconnect();

    // Create new socket connection
    socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
      'reconnectionAttempts': 5,
    });

    // Set up event listeners
    socket?.on('notification', (data) {
      if (onNotification != null) {
        onNotification!(data);
      }
    });

    // Connect to the server
    socket?.connect();
  }

  void register(String deviceId) {
    socket?.emit('register', deviceId);
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
  }
}
