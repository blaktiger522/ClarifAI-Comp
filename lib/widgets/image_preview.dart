import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ImagePreview extends StatelessWidget {
  final String imagePath;

  const ImagePreview({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: FutureBuilder<File>(
        future: _getCompressedImage(imagePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
            );
          }

          final file = snapshot.data!;
          return Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 64,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<File> _getCompressedImage(String path) async {
    try {
      final originalFile = File(path);
      final originalBytes = await originalFile.readAsBytes();
      final originalImage = img.decodeImage(originalBytes);

      if (originalImage == null) {
        return originalFile;
      }

      // Resize if too large (max 1920x1920)
      int targetWidth = originalImage.width;
      int targetHeight = originalImage.height;

      if (originalImage.width > 1920 || originalImage.height > 1920) {
        final aspectRatio = originalImage.width / originalImage.height;

        if (aspectRatio > 1) {
          // Landscape
          targetWidth = 1920;
          targetHeight = (1920 / aspectRatio).round();
        } else {
          // Portrait
          targetHeight = 1920;
          targetWidth = (1920 * aspectRatio).round();
        }
      }

      final resizedImage = img.copyResize(
        originalImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.average,
      );

      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);

      // Create compressed file in temp directory
      final compressedFile = File('${originalFile.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      // If compression fails, return original file
      return File(path);
    }
  }
}