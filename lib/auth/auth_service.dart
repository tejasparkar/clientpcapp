import 'dart:async';
import 'package:flutter/material.dart';

class UserSession {
  final String userId;
  double walletBalance;
  DateTime lastActivity;

  UserSession({
    required this.userId,
    this.walletBalance = 0.0,
    required this.lastActivity,
  });

  // Method to update last activity
  void updateActivity() {
    lastActivity = DateTime.now();
  }
}

class AuthService extends ChangeNotifier {
  UserSession? _currentUserSession;
  Timer? _balanceCheckTimer;

  UserSession? get currentUserSession => _currentUserSession;
  bool get isLoggedIn => _currentUserSession != null;

  Future<bool> login(String email, String password) async {
    // Simulate API call for login
    await Future.delayed(const Duration(seconds: 2));

    if (email == "test@example.com" && password == "password") {
      _currentUserSession = UserSession(
        userId: "user_123",
        walletBalance: 100.0, // Initial balance
        lastActivity: DateTime.now(),
      );
      _startBalanceCheckTimer();
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _balanceCheckTimer?.cancel();
    _currentUserSession = null;
    notifyListeners();
  }

  Future<void> _fetchWalletBalance() async {
    // Simulate API call to get wallet balance
    await Future.delayed(const Duration(seconds: 1));
    if (_currentUserSession != null) {
      // For demonstration, let's decrease balance over time
      _currentUserSession!.walletBalance -= 5.0; 
      _currentUserSession!.updateActivity();
      notifyListeners();

      if (_currentUserSession!.walletBalance <= 0) {
        logout();
      }
    }
  }

  void _startBalanceCheckTimer() {
    _balanceCheckTimer?.cancel(); // Cancel any existing timer
    _balanceCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchWalletBalance();
    });
  }

  @override
  void dispose() {
    _balanceCheckTimer?.cancel();
    super.dispose();
  }
}
