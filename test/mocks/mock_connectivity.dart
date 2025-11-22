import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../lib/services/connectivity_service.dart';

class MockConnectivityService {
  bool _isConnected = true;
  bool _isMonitoring = false;
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  Stream<ConnectivityStatus> get connectivityStream => _statusController.stream;

  ConnectivityStatus get currentStatus =>
      ConnectivityStatus(isConnected: _isConnected);

  Future<void> startMonitoring() async {
    _isMonitoring = true;
    _statusController.add(ConnectivityStatus(isConnected: _isConnected));
  }

  void stopMonitoring() {
    _isMonitoring = false;
  }

  void simulateDisconnection() {
    _isConnected = false;
    _statusController.add(ConnectivityStatus(isConnected: false));
  }

  void simulateConnection() {
    _isConnected = true;
    _statusController.add(ConnectivityStatus(isConnected: true));
  }

  Future<bool> waitForConnection({Duration? timeout}) async {
    if (_isConnected) return true;

    final completer = Completer<bool>();
    late StreamSubscription subscription;

    subscription = connectivityStream.listen((status) {
      if (status.isConnected) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    // Timeout handling
    timeout ??= const Duration(seconds: 30);
    Timer(timeout, () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  void dispose() {
    stopMonitoring();
    _statusController.close();
  }
}