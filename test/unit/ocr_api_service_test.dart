import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../../lib/services/ocr_api_service.dart';

// Generate mocks
@GenerateMocks([http.Client])
import 'ocr_api_service_test.mocks.dart';

void main() {
  group('OcrApiService Tests', () {
    late OcrApiService ocrService;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      ocrService = OcrApiService(client: mockClient);
    });

    test('should process image successfully', () async {
      // Arrange
      const testImagePath = 'test_assets/test_image.jpg';
      const mockResponse = '''
      {
        "success": true,
        "text": "Extracted text from image",
        "confidence": 0.95,
        "processing_time_ms": 1500
      }
      ''';

      when(mockClient.send(any))
          .thenAnswer((_) async => http.Response(mockResponse, 200));

      // Act
      final result = await ocrService.processImage(testImagePath);

      // Assert
      expect(result.success, isTrue);
      expect(result.text, equals('Extracted text from image'));
      expect(result.confidence, equals(0.95));
      expect(result.processingTimeMs, equals(1500));
    });

    test('should handle no text found response', () async {
      // Arrange
      const testImagePath = 'test_assets/blank_image.jpg';
      const mockResponse = '''
      {
        "success": true,
        "text": "",
        "confidence": 0.0,
        "processing_time_ms": 800
      }
      ''';

      when(mockClient.send(any))
          .thenAnswer((_) async => http.Response(mockResponse, 200));

      // Act
      final result = await ocrService.processImage(testImagePath);

      // Assert
      expect(result.success, isTrue);
      expect(result.text, isEmpty);
      expect(result.confidence, equals(0.0));
    });

    test('should handle API error response', () async {
      // Arrange
      const testImagePath = 'test_assets/invalid_image.jpg';
      const mockResponse = '''
      {
        "success": false,
        "error": "No readable text found in image",
        "error_code": "NO_TEXT_DETECTED"
      }
      ''';

      when(mockClient.send(any))
          .thenAnswer((_) async => http.Response(mockResponse, 400));

      // Act
      final result = await ocrService.processImage(testImagePath);

      // Assert
      expect(result.success, isFalse);
      expect(result.error, equals('No readable text found in image'));
    });

    test('should handle server error', () async {
      // Arrange
      const testImagePath = 'test_assets/test_image.jpg';
      when(mockClient.send(any))
          .thenAnswer((_) async => http.Response('Server Error', 500));

      // Act
      final result = await ocrService.processImage(testImagePath);

      // Assert
      expect(result.success, isFalse);
      expect(result.error, contains('Server error (500)'));
    });

    test('should handle network timeout', () async {
      // Arrange
      const testImagePath = 'test_assets/test_image.jpg';
      when(mockClient.send(any))
          .thenThrow(Exception('Network timeout'));

      // Act
      final result = await ocrService.processImage(testImagePath);

      // Assert
      expect(result.success, isFalse);
      expect(result.error, contains('Network error'));
    });

    test('should retry on server errors', () async {
      // Arrange
      const testImagePath = 'test_assets/test_image.jpg';

      // First call fails, second succeeds
      when(mockClient.send(any))
          .thenAnswer((_) async => http.Response('Server Error', 500))
          .thenAnswer((_) async => http.Response('''
      {
        "success": true,
        "text": "Extracted text after retry",
        "confidence": 0.92
      }
      ''', 200));

      // Act
      final result = await ocrService.processImage(testImagePath);

      // Assert
      expect(result.success, isTrue);
      expect(result.text, equals('Extracted text after retry'));
      verify(mockClient.send(any)).called(2); // Should be called twice
    });

    tearDown(() {
      ocrService.dispose();
    });
  });
}