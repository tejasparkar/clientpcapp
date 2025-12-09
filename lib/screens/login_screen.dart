// ===== screens/login_screen.dart =====
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'session_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _tokenController = TextEditingController(text: 'DUMMY_SESSION');
  bool _isLoading = false;
  String _qrData = '';
  Timer? _qrRefreshTimer;

  @override
  void initState() {
    super.initState();
    _generateQRCode();
    _startQRRefresh();
  }

  void _generateQRCode() {
    setState(() {
      _qrData = 'GAMERSDEN_PC_01_${ DateTime.now().millisecondsSinceEpoch}';
    });
  }

  void _startQRRefresh() {
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _generateQRCode();
    });
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
