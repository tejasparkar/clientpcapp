// ===== services/socket_io_service.dart =====
import 'dart:async';
import 'dart:io';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketIOService {
  IO.Socket? _socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  // Check if server is reachable
  Future<bool> checkServerAvailability() async {
    try {
      final result = await InternetAddress.lookup('localhost');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // Try to connect to port 3000
        final socket = await Socket.connect('localhost', 3000, timeout: Duration(seconds: 3));
        socket.destroy();
        return true;
      }
    } catch (e) {
      print('Server availability check failed: $e');
      return false;
    }
    return false;
  }

  // Connect to Socket.IO server
  Future<void> connect(String pcId, String pcName, String deviceId) async {
    // Check if server is available first
    bool serverAvailable = await checkServerAvailability();
    if (!serverAvailable) {
      print('Server not available. PC will operate in offline mode.');
      _messageController.add({
        'type': 'server_unavailable',
        'pc_id': pcId,
        'pc_name': pcName,
        'device_id': deviceId,
      });
      return;
    }

    _socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'timeout': 5000, // 5 second timeout
      'forceNew': true,
    });

    // Set up event listeners
    _socket!.onConnect((_) {
      print('Connected to Socket.IO server');

      // Send PC registration info on connection
      _socket!.emit('pc_register', {
        'pc_id': pcId,
        'pc_name': pcName,
        'device_id': deviceId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    _socket!.onDisconnect((_) {
      print('Disconnected from Socket.IO server');
    });

    _socket!.onConnectError((error) {
      print('Socket.IO connection error: $error');
      _messageController.add({
        'type': 'connection_error',
        'error': error.toString(),
      });
    });

    _socket!.onError((error) {
      print('Socket.IO error: $error');
      _messageController.add({
        'type': 'socket_error',
        'error': error.toString(),
      });
    });

    _socket!.onConnecting((_) {
      print('Socket.IO connecting...');
    });

    _socket!.onConnectTimeout((_) {
      print('Socket.IO connection timeout');
      _messageController.add({
        'type': 'connection_timeout',
      });
    });

    // Listen for server events
    _socket!.on('admin_command', (data) {
      _messageController.add({
        'type': 'admin_command',
        'command': data['command'],
        'data': data,
      });
    });

    _socket!.on('balance_update', (data) {
      _messageController.add({
        'type': 'balance_update',
        'balance': data['balance'],
      });
    });

    _socket!.on('force_logout', (data) {
      _messageController.add({
        'type': 'force_logout',
      });
    });

    _socket!.on('pc_assigned', (data) {
      _messageController.add({
        'type': 'pc_assigned',
        'pc_number': data['pc_number'],
      });
    });

    // Connect to server
    _socket!.connect();
  }

  // Send PC status
  void sendPCStatus(String status, Map<String, dynamic> data) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('pc_status', {
        'status': status,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Send system metrics
  void sendSystemMetrics(Map<String, dynamic> metrics) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('system_metrics', {
        'metrics': metrics,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Send session start
  void sendSessionStart(String sessionId, String userId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('session_start', {
        'session_id': sessionId,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Send session end
  void sendSessionEnd(String sessionId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('session_end', {
        'session_id': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Send custom message
  void sendMessage(String event, Map<String, dynamic> data) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, data);
    }
  }

  // Check connection status
  bool get isConnected => _socket?.connected ?? false;

  // Disconnect
  void disconnect() {
    _socket?.disconnect();
    _messageController.close();
  }
}
