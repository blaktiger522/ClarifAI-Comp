import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import '../../../lib/screens/home_screen.dart';
import '../../../lib/services/camera_service.dart';
import '../../../lib/services/connectivity_service.dart';

// Generate mocks
@GenerateMocks([CameraService, ConnectivityService])
import 'home_screen_test.mocks.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    late MockCameraService mockCameraService;
    late MockConnectivityService mockConnectivityService;

    setUp(() {
      mockCameraService = MockCameraService();
      mockConnectivityService = MockConnectivityService();

      // Setup default mock responses
      when(mockCameraService.checkPermissions())
          .thenAnswer((_) async => true);
      when(mockConnectivityService.currentStatus)
          .thenReturn(ConnectivityStatus(isConnected: true));
      when(mockConnectivityService.connectivityStream)
          .thenAnswer((_) => Stream.value(ConnectivityStatus(isConnected: true)));
    });

    Widget createHomeScreen({GoRouter? router}) {
      return MaterialApp(
        home: HomeScreen(),
      );
    }

    testWidgets('should display app title and description', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('ClarifAI'), findsOneWidget);
      expect(find.text('Convert handwritten text to digital text'), findsOneWidget);
    });

    testWidgets('should show camera and gallery buttons when connected', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Select from Gallery'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.photo_library), findsOneWidget);
    });

    testWidgets('should show connectivity warning when disconnected', (WidgetTester tester) async {
      // Arrange
      when(mockConnectivityService.currentStatus)
          .thenReturn(ConnectivityStatus(isConnected: false));
      when(mockConnectivityService.connectivityStream)
          .thenAnswer((_) => Stream.value(ConnectivityStatus(isConnected: false)));

      // Act
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should disable buttons when offline', (WidgetTester tester) async {
      // Arrange
      when(mockConnectivityService.currentStatus)
          .thenReturn(ConnectivityStatus(isConnected: false));
      when(mockConnectivityService.connectivityStream)
          .thenAnswer((_) => Stream.value(ConnectivityStatus(isConnected: false)));

      // Act
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      // Assert
      final takePhotoButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Take Photo')
      );
      expect(takePhotoButton.onPressed, isNull);

      final galleryButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Select from Gallery')
      );
      expect(galleryButton.onPressed, isNull);
    });

    testWidgets('should show permission warning when permissions denied', (WidgetTester tester) async {
      // Arrange
      when(mockCameraService.checkPermissions())
          .thenAnswer((_) async => false);

      // Act
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Camera permissions needed'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('should display instructions section', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('How to use:'), findsOneWidget);
      expect(find.text('1. Take a photo of handwritten text'), findsOneWidget);
      expect(find.text('2. Wait for processing'), findsOneWidget);
      expect(find.text('3. Copy or share the converted text'), findsOneWidget);
    });

    testWidgets('should show app icon', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.camera_alt), findsAtLeastNWidgets(2)); // One in app icon, one in button
    });
  });
}