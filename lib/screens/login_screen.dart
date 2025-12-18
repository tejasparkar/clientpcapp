// ===== screens/login_screen.dart =====
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'dart:async';
import '../services/api_service.dart';
import '../services/socket_io_service.dart';
import 'session_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  final SocketIOService _socketService = SocketIOService();
  final TextEditingController _tokenController = TextEditingController(text: 'DUMMY_SESSION');
  bool _isLoading = false;
  String _qrData = '';
  Timer? _qrRefreshTimer;

  @override
  void initState() {
    super.initState();

    // Listen for PC assignment from server first
    _socketService.messages.listen(_handleSocketIOMessage);

    // Connect to server and get PC number immediately
    _connectToServerAndGetPCNumber();
  }

  Future<void> _connectToServerAndGetPCNumber() async {
    try {
      // Get system/computer name
      String pcName = Platform.localHostname;

      // Get existing PC number (if already assigned)
      final prefs = await SharedPreferences.getInstance();
      String pcNumber = prefs.getString('pc_number') ?? '';

      // Get or create device ID
      String deviceId = await _getDeviceId();

      // Connect to Socket.IO server
      await _socketService.connect(pcNumber.isNotEmpty ? pcNumber : deviceId, pcName, deviceId);

      // If we already have a PC number, generate QR immediately
      if (pcNumber.isNotEmpty) {
        await _generateQRCode();
        _startQRRefresh();
      }
      // Otherwise, wait for server to assign PC number (handled in _handlePCAssignment)

    } catch (e) {
      print('Error connecting to server: $e');
      // Fallback: generate QR code even if server connection fails
      await _generateQRCode();
      _startQRRefresh();
    }
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId!;
  }

  Future<void> _generateQRCode() async {
    // Get PC info
    String pcName = Platform.localHostname;
    String pcNumber = await _getStoredPCNumber();
    String deviceId = await _getDeviceId();

    final data = {
      'pc_name': pcName,
      'pc_number': pcNumber,
      'device_id': deviceId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _qrData = data.toString();
    });
  }

  Future<String> _getStoredPCNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pc_number') ?? '';
  }

  void _startQRRefresh() {
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _generateQRCode();
    });
  }

  void _handleSocketIOMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'pc_assigned':
        _handlePCAssignment(message['pc_number']);
        break;
      case 'server_unavailable':
        _handleServerUnavailable(message);
        break;
      case 'connection_error':
        _handleConnectionError(message['error']);
        break;
      case 'connection_timeout':
        _handleConnectionTimeout();
        break;
      default:
        print('Unhandled Socket.IO message: ${message['type']}');
    }
  }

  void _handleServerUnavailable(Map<String, dynamic> data) {
    print('Server is unavailable. Operating in offline mode.');
    // Generate QR code with available info (empty PC number)
    _generateQRCode();
    _startQRRefresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server unavailable. Operating in offline mode.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _handleConnectionError(String error) {
    print('Socket.IO connection error: $error');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $error'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleConnectionTimeout() {
    print('Socket.IO connection timeout');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection timeout. Retrying...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handlePCAssignment(String pcNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pc_number', pcNumber);

    print('PC number assigned by server: $pcNumber');

    // Regenerate QR code with the new PC number
    await _generateQRCode();

    // Start QR refresh timer if not already started
    if (_qrRefreshTimer == null) {
      _startQRRefresh();
    }

    // Show confirmation to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PC assigned with number: $pcNumber'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _validateToken() async {
    if (_tokenController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.validateSession(_tokenController.text);
      
      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SessionScreen(
              sessionData: result['session'],
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Invalid session token');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    _tokenController.dispose();
    _socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(40),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(40),
                color: const Color.fromARGB(255, 253, 253, 253),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', height: 150
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PC Station 01',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 200,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Scan with Gamers Den App',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Text(
                            'OR',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300])),
                      ],
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _tokenController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Enter Session Token',
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.key, color: Colors.blue),
                      ),
                      onSubmitted: (_) => _validateToken(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _validateToken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'START SESSION',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
