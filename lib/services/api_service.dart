// ===== services/api_service.dart =====
import 'package:dio/dio.dart';


class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';
  final Dio _dio = Dio();
  
  Future<Map<String, dynamic>> validateSession(String sessionToken) async {
    // Provide a local dummy session for testing without backend
    if (sessionToken == 'DUMMY_SESSION') {
      return Future.value({
        'success': true,
        'session': {
          'sessionId': 'dummy-session-001',
          'userName': 'Test User',
          'walletBalance': 120, // minutes
          'pcId': 'PC01',
        }
      });
    }

    try {
      final response = await _dio.post(
        '$baseUrl/sessions/validate-qr',
        data: {'sessionToken': sessionToken},
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to validate session: $e');
    }
  }

  Future<void> startSession(String sessionId) async {
    try {
      await _dio.post('$baseUrl/sessions/start');
    } catch (e) {
      throw Exception('Failed to start session: $e');
    }
  }

  Future<void> endSession(String sessionId) async {
    try {
      await _dio.post(
        '$baseUrl/sessions/end',
        data: {'sessionId': sessionId},
      );
    } catch (e) {
      throw Exception('Failed to end session: $e');
    }
  }

  Future<void> sendLog(Map<String, dynamic> logData) async {
    try {
      await _dio.post(
        '$baseUrl/logs',
        data: logData,
      );
    } catch (e) {
      print('Failed to send log: $e');
    }
  }

  Future<Map<String, dynamic>> getSessionDetails(String sessionId) async {
    try {
      final response = await _dio.get('$baseUrl/sessions/$sessionId');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get session details: $e');
    }
  }
}