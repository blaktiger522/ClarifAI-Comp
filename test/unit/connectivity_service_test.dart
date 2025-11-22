import 'package:flutter_test/flutter_test.dart';
import '../mocks/mock_connectivity.dart';

void main() {
  group('ConnectivityService Tests', () {
    late MockConnectivityService connectivityService;

    setUp(() {
      connectivityService = MockConnectivityService();
    });

    test('should initialize with connected status', () async {
      // Act
      await connectivityService.startMonitoring();

      // Assert
      expect(connectivityService.currentStatus.isConnected, isTrue);
    });

    test('should detect when connection is lost', () async {
      // Arrange
      await connectivityService.startMonitoring();
      bool connectivityChanged = false;

      connectivityService.connectivityStream.listen((status) {
        if (!status.isConnected) {
          connectivityChanged = true;
        }
      });

      // Act
      connectivityService.simulateDisconnection();

      // Assert
      expect(connectivityChanged, isTrue);
      expect(connectivityService.currentStatus.isConnected, isFalse);
    });

    test('should detect when connection is restored', () async {
      // Arrange
      await connectivityService.startMonitoring();
      connectivityService.simulateDisconnection();
      bool connectivityRestored = false;

      connectivityService.connectivityStream.listen((status) {
        if (status.isConnected) {
          connectivityRestored = true;
        }
      });

      // Act
      connectivityService.simulateConnection();

      // Assert
      expect(connectivityRestored, isTrue);
      expect(connectivityService.currentStatus.isConnected, isTrue);
    });

    test('should wait for connection with timeout', () async {
      // Arrange
      await connectivityService.startMonitoring();
      connectivityService.simulateDisconnection();

      // Act
      final result = await connectivityService.waitForConnection(
        timeout: const Duration(seconds: 1),
      );

      // Assert
      expect(result, isFalse);
    });

    test('should return true immediately if already connected', () async {
      // Arrange
      await connectivityService.startMonitoring();

      // Act
      final result = await connectivityService.waitForConnection();

      // Assert
      expect(result, isTrue);
    });

    tearDown(() {
      connectivityService.dispose();
    });
  });
}