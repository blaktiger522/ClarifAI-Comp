import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OcrResult {
  final bool success;
  final String text;
  final String? error;
  final double? confidence;
  final int? processingTimeMs;

  OcrResult({
    required this.success,
    required this.text,
    this.error,
    this.confidence,
    this.processingTimeMs,
  });

  factory OcrResult.success(String text, {double? confidence, int? processingTimeMs}) {
    return OcrResult(
      success: true,
      text: text,
      confidence: confidence,
      processingTimeMs: processingTimeMs,
    );
  }

  factory OcrResult.error(String error) {
    return OcrResult(
      success: false,
      text: '',
      error: error,
    );
  }
}

class OcrApiException implements Exception {
  final String message;
  final int? statusCode;

  OcrApiException(this.message, {this.statusCode});

  @override
  String toString() => 'OcrApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class OcrApiService {
  static const String _defaultBaseUrl = 'https://api.clarifai-app.com';
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int _maxRetries = 3;

  final String _baseUrl;
  final Duration _timeout;
  final http.Client _client;

  OcrApiService({
    String? baseUrl,
    Duration? timeout,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? _defaultBaseUrl,
        _timeout = timeout ?? _defaultTimeout,
        _client = client ?? http.Client();

  Future<OcrResult> processImage(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      return OcrResult.error('Image file not found');
    }

    final fileSize = await file.length();
    if (fileSize > _maxFileSizeBytes) {
      return OcrResult.error('Image file is too large (max 10MB)');
    }

    if (!_isSupportedImageFormat(imagePath)) {
      return OcrResult.error('Unsupported image format. Please use JPEG, PNG, or WebP');
    }

    return await _executeWithRetry(() => _processImageRequest(file));
  }

  Future<OcrResult> _processImageRequest(File file) async {
    try {
      final stopwatch = Stopwatch()..start();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/ocr/process'),
      );

      // Add the image file
      final imageBytes = await file.readAsBytes();
      final imageStream = http.ByteStream.fromBytes(imageBytes);
      final multipartFile = http.MultipartFile(
        'file',
        imageStream,
        imageBytes.length,
        filename: file.path.split('/').last,
      );

      request.files.add(multipartFile);

      // Add headers
      request.headers.addAll(_getHeaders());

      // Send request
      final response = await _client.send(request).timeout(_timeout);

      // Get response body
      final responseBody = await response.stream.bytesToString();
      stopwatch.stop();

      if (kDebugMode) {
        print('OCR Response (${response.statusCode}): ${responseBody.substring(0, responseBody.length > 500 ? 500 : responseBody.length)}');
      }

      return _parseResponse(response.statusCode, responseBody, stopwatch.elapsedMilliseconds);
    } on SocketException catch (e) {
      throw OcrApiException('Network error: ${e.message}');
    } on TimeoutException catch (e) {
      throw OcrApiException('Request timeout: ${e.message}');
    } catch (e) {
      throw OcrApiException('Unexpected error: ${e.toString()}');
    }
  }

  Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    OcrApiException? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await operation();
      } on OcrApiException catch (e) {
        lastException = e;

        // Don't retry on client errors (4xx)
        if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          break;
        }

        // Exponential backoff for retries
        if (attempt < _maxRetries) {
          final delay = Duration(milliseconds: 1000 * (1 << (attempt - 1)));
          await Future.delayed(delay);
        }
      }
    }

    // Return error result for API exceptions
    return OcrResult.error(_getErrorMessage(lastException)) as T;
  }

  OcrResult _parseResponse(int statusCode, String responseBody, int processingTimeMs) {
    try {
      final responseData = jsonDecode(responseBody);

      if (statusCode == 200) {
        final text = responseData['text'] as String? ?? '';
        final confidence = responseData['confidence'] as double?;

        if (text.isEmpty) {
          return OcrResult.error('No readable text found in image');
        }

        return OcrResult.success(
          text,
          confidence: confidence,
          processingTimeMs: processingTimeMs,
        );
      } else {
        final error = responseData['error'] as String? ?? responseData['message'] as String?;
        final errorCode = responseData['error_code'] as String?;

        return OcrResult.error(error ?? 'Processing failed with status code $statusCode');
      }
    } catch (e) {
      if (statusCode == 200) {
        return OcrResult.error('Invalid response format from server');
      } else {
        return OcrResult.error('Server error ($statusCode): ${responseBody.substring(0, 200)}');
      }
    }
  }

  Map<String, String> _getHeaders() {
    return {
      'User-Agent': 'ClarifAI-Flutter/1.0.0',
      'Accept': 'application/json',
    };
  }

  bool _isSupportedImageFormat(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp'].contains(extension);
  }

  String _getErrorMessage(OcrApiException? exception) {
    if (exception == null) {
      return 'Unknown error occurred';
    }

    switch (exception.statusCode) {
      case 400:
        return 'Invalid image or request format';
      case 401:
        return 'Authentication failed';
      case 413:
        return 'Image file is too large';
      case 429:
        return 'Too many requests. Please wait and try again';
      case 500:
        return 'Server is temporarily unavailable';
      case 503:
        return 'OCR service is temporarily unavailable';
      default:
        if (exception.message.contains('Network')) {
          return 'Network error. Please check your internet connection';
        } else if (exception.message.contains('timeout')) {
          return 'Request timed out. Please try again';
        } else {
          return exception.message;
        }
    }
  }

  void dispose() {
    _client.close();
  }
}