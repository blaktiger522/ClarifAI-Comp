import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/camera_service.dart';
import '../services/connectivity_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CameraService _cameraService = CameraService();
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _hasPermissions = false;
  bool _isConnected = true;
  bool _isLoading = false;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _setupConnectivityMonitoring();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (status) {
        if (mounted) {
          setState(() {
            _isConnected = status.isConnected;
          });
        }
      },
    );
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
    });

    final hasPermissions = await _cameraService.checkPermissions();

    if (mounted) {
      setState(() {
        _hasPermissions = hasPermissions;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    final granted = await _cameraService.requestPermissions();

    if (mounted) {
      setState(() {
        _hasPermissions = granted;
        _isLoading = false;
      });

      if (!granted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
            'ClarifAI needs camera and storage permissions to capture and process images. Please enable permissions in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestPermissions();
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToCamera() {
    if (_hasPermissions) {
      context.go('/camera');
    } else {
      _requestPermissions();
    }
  }

  Future<void> _pickFromGallery() async {
    if (!_hasPermissions) {
      await _requestPermissions();
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // Navigate to camera screen with gallery image for processing
        context.go('/camera', extra: image.path);
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
      appBar: AppBar(
        title: const Text('ClarifAI'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Logo/Icon
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 60,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 32),

              // App Title
              const Text(
                'ClarifAI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 8),

              // App Description
              const Text(
                'Convert handwritten text to digital text',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 48),

              // Permission Status
              if (!_hasPermissions)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Camera permissions needed',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),

              if (!_hasPermissions) const SizedBox(height: 24),

              // Take Photo Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _navigateToCamera,
                icon: _isLoading
                    ? Container(
                        width: 16,
                        height: 16,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.camera_alt),
                label: const Text(
                  'Take Photo',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Select from Gallery Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text(
                  'Select from Gallery',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.grey[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'How to use:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInstructionRow('1. Take a photo of handwritten text'),
                    _buildInstructionRow('2. Wait for processing'),
                    _buildInstructionRow('3. Copy or share the converted text'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}