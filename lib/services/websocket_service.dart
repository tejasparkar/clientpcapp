// ===== services/websocket_service.dart =====
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  
  void connect(String pcId) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:3000/ws?pcId=$pcId'),
    );
    
    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        _messageController.add(data);
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket closed');
      },
    );
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void sendPCStatus(String status, Map<String, dynamic> data) {
    sendMessage({
      'type': 'pc_status',
      'status': status,
      'data': data,
    });
  }

  void sendSystemMetrics(Map<String, dynamic> metrics) {
    sendMessage({
      'type': 'system_metrics',
      'metrics': metrics,
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _messageController.close();
  }
}