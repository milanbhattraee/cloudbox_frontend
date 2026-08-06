import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';

enum ConnectivityStatus {
  online,
  offline,
  serverDown,
  checking,
}

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._internal();

  static final ConnectivityService instance = ConnectivityService._internal();

  ConnectivityStatus _status = ConnectivityStatus.offline; // Default to offline
  DateTime? _lastSuccessfulCheck;
  Timer? _healthCheckTimer;
  int _consecutiveFailures = 0;

  ConnectivityStatus get status => _status;
  DateTime? get lastSuccessfulCheck => _lastSuccessfulCheck;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isOffline => _status == ConnectivityStatus.offline;
  bool get isServerDown => _status == ConnectivityStatus.serverDown;

  /// Checks if device has internet connectivity
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('[ConnectivityService] Internet check failed: $e');
      return false;
    }
  }

  /// Checks server health via the /health endpoint
  Future<bool> _checkServerHealth() async {
    try {
      final response = await ApiClient.instance.dio
          .get(
            '/health',
            options: Options(
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          )
          .timeout(const Duration(seconds: 6));

      final isHealthy = response.statusCode == 200 &&
          response.data != null &&
          response.data['success'] == true;
      
      debugPrint('[ConnectivityService] Server health check: $isHealthy');
      return isHealthy;
    } catch (e) {
      debugPrint('[ConnectivityService] Server health check failed: $e');
      return false;
    }
  }

  /// Performs a full connectivity check
  Future<ConnectivityStatus> checkConnectivity() async {
    final hasInternet = await _hasInternetConnection();

    if (!hasInternet) {
      _consecutiveFailures++;
      return ConnectivityStatus.offline;
    }

    final serverHealthy = await _checkServerHealth();

    if (serverHealthy) {
      _consecutiveFailures = 0;
      _lastSuccessfulCheck = DateTime.now();
      return ConnectivityStatus.online;
    } else {
      _consecutiveFailures++;
      // Only mark as server down after multiple consecutive failures
      // to avoid false positives from temporary network hiccups
      return _consecutiveFailures >= 2
          ? ConnectivityStatus.serverDown
          : ConnectivityStatus.offline;
    }
  }

  /// Updates the connectivity status and notifies listeners
  Future<void> updateStatus() async {
    final oldStatus = _status;
    _status = ConnectivityStatus.checking;
    if (oldStatus != _status) notifyListeners();

    try {
      final newStatus = await checkConnectivity().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[ConnectivityService] Check timed out, assuming offline');
          return ConnectivityStatus.offline;
        },
      );
      
      _status = newStatus;

      if (oldStatus != _status) {
        debugPrint('[ConnectivityService] Status changed: $oldStatus -> $newStatus');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ConnectivityService] Error updating status: $e');
      _status = ConnectivityStatus.offline;
      notifyListeners();
    }
  }

  /// Starts periodic health checks (every 5 minutes when app is active)
  /// Only call this if you need continuous monitoring
  void startPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    // Initial check
    updateStatus();
    // Periodic checks - every 5 minutes to reduce load
    _healthCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => updateStatus(),
    );
  }
  
  /// Stop periodic health checks
  void stopPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Force an immediate connectivity check
  Future<void> forceCheck() => updateStatus();

  /// Call when app resumes from background
  void onAppResumed() {
    debugPrint('[ConnectivityService] App resumed, checking connectivity...');
    forceCheck();
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}
