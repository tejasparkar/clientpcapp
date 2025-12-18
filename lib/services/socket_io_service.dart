// ===== services/socket_io_service.dart =====
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketIOService {
  IO.Socket? _socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String pcId, String pcName, String deviceId) async {
    // Disconnect if already connected
    disconnect();

    _socket = IO.io('http://localhost:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'query': {
        'pcId': pcId,
        'pcName': pcName,
        'deviceId': deviceId,
      },
    });

    _socket!.onConnect((_) {
      print('Socket.IO connected to port 5000');
      _messageController.add({'type': 'connected'});
    });

    _socket!.onDisconnect((_) {
      print('Socket.IO disconnected');
      _messageController.add({'type': 'disconnected'});
    });

    _socket!.onConnectError((error) {
      print('Socket.IO connection error: $error');
      _messageController.add({'type': 'connection_error', 'error': error});
    });

    _socket!.onError((error) {
      print('Socket.IO error: $error');
      _messageController.add({'type': 'error', 'error': error});
    });

    // Listen for custom events
    _socket!.on('message', (data) {
      print('Received message: $data');
      _messageController.add({
        'type': 'message',
        'data': data,
      });
    });

    _socket!.on('pc_command', (data) {
      print('Received PC command: $data');
      _messageController.add({
        'type': 'pc_command',
        'data': data,
      });
    });

    _socket!.on('system_request', (data) {
      print('Received system request: $data');
      _messageController.add({
        'type': 'system_request',
        'data': data,
      });
    });

    // Connect to the server
    _socket!.connect();
  }

  void sendMessage(String event, dynamic data) {
    if (_socket != null && isConnected) {
      _socket!.emit(event, data);
      print('Sent $event: $data');
    } else {
      print('Socket.IO not connected, cannot send message');
    }
  }

  void sendPCStatus(String status, Map<String, dynamic> data) {
    sendMessage('pc_status', {
      'status': status,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void sendSystemMetrics(Map<String, dynamic> metrics) {
    sendMessage('system_metrics', {
      'metrics': metrics,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void sendSessionStart(String sessionId, String userId) {
    sendMessage('session_start', {
      'sessionId': sessionId,
      'userId': userId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void sendSessionEnd(String sessionId) {
    sendMessage('session_end', {
      'sessionId': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void sendCommandResponse(String commandId, Map<String, dynamic> response) {
    sendMessage('command_response', {
      'commandId': commandId,
      'response': response,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
