// ===== screens/session_screen.dart =====
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/system_monitor_service.dart';
import 'login_screen.dart';

class SessionScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;

  const SessionScreen({Key? key, required this.sessionData}) : super(key: key);

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  final SystemMonitorService _systemMonitor = SystemMonitorService();
  
  late Timer _sessionTimer;
  int _remainingMinutes = 0;
  int _elapsedSeconds = 0;
  Map<String, dynamic> _systemMetrics = {};
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  void _initializeSession() {
    _userName = widget.sessionData['userName'] ?? 'User';
    _remainingMinutes = widget.sessionData['walletBalance'] ?? 0;
    
    _wsService.connect(widget.sessionData['pcId']);
    _wsService.messages.listen(_handleWebSocketMessage);
    
    _systemMonitor.startMonitoring((metrics) {
      setState(() => _systemMetrics = metrics);
      _wsService.sendSystemMetrics(metrics);
    });

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
        if (_elapsedSeconds >= 60) {
          _remainingMinutes--;
          _elapsedSeconds = 0;
          
          if (_remainingMinutes <= 0) {
            _endSession();
          } else if (_remainingMinutes <= 5) {
            _showLowBalanceWarning();
          }
        }
      });
    });
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'admin_command':
        _handleAdminCommand(message['command']);
        break;
      case 'balance_update':
        setState(() {
          _remainingMinutes = message['balance'];
        });
        break;
      case 'force_logout':
        _endSession(forced: true);
        break;
    }
  }

  void _handleAdminCommand(String command) {
    switch (command) {
      case 'restart':
        _showDialog('Restart Requested', 'Admin has requested to restart this PC');
        break;
      case 'message':
        _showDialog('Message from Admin', 'Please wrap up your session');
        break;
    }
  }

  void _showLowBalanceWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Low balance warning: $_remainingMinutes minutes remaining'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _endSession({bool forced = false}) async {
    _sessionTimer.cancel();
    _systemMonitor.stopMonitoring();
    
    try {
      await _apiService.endSession(widget.sessionData['sessionId']);
    } catch (e) {
      print('Error ending session: $e');
    }

    _wsService.disconnect();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  String _formatTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  void dispose() {
    _sessionTimer.cancel();
    _systemMonitor.stopMonitoring();
    _wsService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Image.asset( 'assets/images/logodark.png', height: 120),
        elevation: 10,
        toolbarHeight: 100,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $_userName',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'Session Active',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _remainingMinutes <= 5 ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(_remainingMinutes),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  children: [
                    _buildStatCard(
                      'Session Duration',
                      '${_elapsedSeconds ~/ 3600}h ${(_elapsedSeconds % 3600) ~/ 60}m',
                      Icons.timer,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'CPU Usage',
                      '${_systemMetrics['cpuUsage']?.toStringAsFixed(1) ?? '0'}%',
                      Icons.memory,
                      Colors.purple,
                    ),
                    _buildStatCard(
                      'Memory Usage',
                      '${_systemMetrics['memoryUsage']?['percent']?.toStringAsFixed(1) ?? '0'}%',
                      Icons.storage,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      'Status',
                      'Active',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _endSession(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'END SESSION',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
