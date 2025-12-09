// ===== services/system_monitor_service.dart =====
import 'dart:async';
import 'package:system_info2/system_info2.dart';

class SystemMonitorService {
  Timer? _monitorTimer;
  
  Map<String, dynamic> getSystemInfo() {
    return {
      'cpuUsage': _getCPUUsage(),
      'memoryUsage': _getMemoryUsage(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  double _getCPUUsage() {
    // Simplified CPU usage calculation
    return 45.0; // Mock value
  }

  Map<String, dynamic> _getMemoryUsage() {
    final totalMemory = SysInfo.getTotalPhysicalMemory();
    final freeMemory = SysInfo.getFreePhysicalMemory();
    final usedMemory = totalMemory - freeMemory;
    final usagePercent = (usedMemory / totalMemory) * 100;

    return {
      'total': totalMemory,
      'used': usedMemory,
      'free': freeMemory,
      'percent': usagePercent,
    };
  }

  void startMonitoring(Function(Map<String, dynamic>) onUpdate) {
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      onUpdate(getSystemInfo());
    });
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
  }
}
