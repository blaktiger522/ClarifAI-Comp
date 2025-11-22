import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';

class CameraService {
  Future<bool> checkPermissions() async {
    final cameraPermission = await Permission.camera.status;
    final storagePermission = await Permission.storage.status;

    return cameraPermission.isGranted && storagePermission.isGranted;
  }

  Future<bool> requestPermissions() async {
    final cameraPermission = await Permission.camera.request();
    final storagePermission = await Permission.storage.request();

    return cameraPermission.isGranted && storagePermission.isGranted;
  }

  Future<CameraDescription?> getAvailableCamera() async {
    try {
      final cameras = await availableCameras();

      // Prefer rear camera if available
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          return camera;
        }
      }

      // Fall back to first available camera
      if (cameras.isNotEmpty) {
        return cameras.first;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isCameraAvailable() async {
    try {
      final cameras = await availableCameras();
      return cameras.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}