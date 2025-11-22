import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ConnectivityStatus {
  final bool isConnected;
  final String? connectionType;

  ConnectivityStatus({required this.isConnected, this.connectionType});

  @override
  String toString() => 'ConnectivityStatus(isConnected: $isConnected, type: $connectionType)';
}

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isConnected = true;
  Timer? _connectivityTimer;
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  Stream<ConnectivityStatus> get connectivityStream => _statusController.stream;

  ConnectivityStatus get currentStatus =>
      ConnectivityStatus(isConnected: _isConnected);

  Future<void> startMonitoring() async {
    // Initial check
    await _checkConnectivity();

    // Periodic checks every 30 seconds
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
    });
  }

  void stopMonitoring() {
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
  }

  Future<bool> _checkConnectivity() async {
    try {
      // Try multiple reliable hosts
      final hosts = [
        '8.8.8.8',      // Google DNS
        '1.1.1.1',      // Cloudflare DNS
        'google.com',   // HTTPS fallback
      ];

      for (final host in hosts) {
        if (await _canReachHost(host)) {
          _updateConnectionStatus(true);
          return true;
        }
      }

      _updateConnectionStatus(false);
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Connectivity check error: $e');
      }
      _updateConnectionStatus(false);
      return false;
    }
  }

  Future<bool> _canReachHost(String host) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // Try socket connection for more reliable check
        final socket = await Socket.connect(
          host.contains('.') ? host : result[0].address,
          host.contains('.') ? 53 : 443, // DNS or HTTPS port
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        return true;
      }
    } catch (e) {
      // Host unreachable
    }
    return false;
  }

  void _updateConnectionStatus(bool isConnected) {
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      _statusController.add(
        ConnectivityStatus(
          isConnected: isConnected,
          connectionType: isConnected ? 'unknown' : null,
        ),
      );

      if (kDebugMode) {
        print('Connectivity status changed: $isConnected');
      }
    }
  }

  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
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

    // Timeout
    Timer(timeout, () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    // Check one more time in case we missed the stream
    await _checkConnectivity();
    if (_isConnected && !completer.isCompleted) {
      completer.complete(true);
    }

    return completer.future;
  }

  void dispose() {
    stopMonitoring();
    _statusController.close();
  }
}