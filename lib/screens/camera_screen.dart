import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spinkit/spinkit.dart';
import '../services/camera_service.dart';
import '../services/ocr_api_service.dart';
import '../widgets/image_preview.dart';

class CameraScreen extends StatefulWidget {
  final String? galleryImagePath;

  const CameraScreen({super.key, this.galleryImagePath});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _hasFlash = false;
  bool _isFlashOn = false;
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // If gallery image is provided, process it directly
    if (widget.galleryImagePath != null) {
      _processImage(widget.galleryImagePath!);
    } else {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraService = CameraService();
      final camera = await cameraService.getAvailableCamera();

      if (camera == null) {
        _showErrorDialog('No camera available', 'Unable to access camera. Please check your device settings.');
        return;
      }

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      // Check if flash is available
      if (_controller != null) {
        _hasFlash = await _controller!.getFlashMode() != null;
      }

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _showErrorDialog('Camera Error', 'Failed to initialize camera: ${e.toString()}');
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      // Provide haptic feedback
      HapticFeedback.lightImpact();

      final XFile image = await _controller!.takePicture();

      if (mounted) {
        setState(() {
          _capturedImagePath = image.path;
        });
      }
    } catch (e) {
      _showErrorDialog('Capture Error', 'Failed to capture photo: ${e.toString()}');
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_hasFlash) {
      return;
    }

    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.auto);
      }

      if (mounted) {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      }
    } catch (e) {
      // Flash toggle failed, ignore for better UX
    }
  }

  Future<void> _processImage(String imagePath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final ocrService = OcrApiService();
      final result = await ocrService.processImage(imagePath);

      if (mounted) {
        if (result.success && result.text.isNotEmpty) {
          // Navigate to result screen with extracted text
          context.go('/result', extra: result.text);
        } else {
          _showErrorDialog(
            'Processing Failed',
            result.error ?? 'Unable to extract text from image. Please try again with a clearer image.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Processing Error',
          'Failed to process image: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            if (title != 'No camera available')
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/');
                },
                child: const Text('Go Back'),
              ),
          ],
        );
      },
    );
  }

  void _retakePhoto() {
    setState(() {
      _capturedImagePath = null;
    });
  }

  void _useGalleryImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _capturedImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Text'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isCameraInitialized && _hasFlash)
            IconButton(
              onPressed: _toggleFlash,
              icon: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview or captured image
          _buildMainContent(),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SpinKitFoldingCube(
                      color: Colors.blue,
                      size: 60.0,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Converting handwriting...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This may take a few seconds',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _capturedImagePath != null
          ? _buildCapturedImageActions()
          : _buildCameraActions(),
    );
  }

  Widget _buildMainContent() {
    if (_capturedImagePath != null) {
      return ImagePreview(imagePath: _capturedImagePath!);
    }

    if (_isCameraInitialized && _controller != null) {
      return CameraPreview(_controller!);
    }

    if (widget.galleryImagePath != null) {
      return ImagePreview(imagePath: widget.galleryImagePath!);
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery button
          IconButton(
            onPressed: _useGalleryImage,
            icon: const Icon(
              Icons.photo_library,
              color: Colors.white,
              size: 32,
            ),
          ),

          // Capture button
          GestureDetector(
            onTap: _isCameraInitialized ? _capturePhoto : null,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: _isCameraInitialized ? Colors.white : Colors.grey,
              ),
              child: _isCameraInitialized
                  ? Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                    )
                  : null,
            ),
          ),

          // Spacer for symmetry
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCapturedImageActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Retake button
          ElevatedButton.icon(
            onPressed: _retakePhoto,
            icon: const Icon(Icons.refresh),
            label: const Text('Retake'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),

          // Process button
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _processImage(_capturedImagePath!),
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_isProcessing ? 'Processing...' : 'Use Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}