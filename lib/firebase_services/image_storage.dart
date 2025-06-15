import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:synchronized/synchronized.dart';

class ImageStorage {
  static final _lock = Lock();
  static final _storage = FirebaseStorage.instance;

  // Keep existing moveToPermStorage for backward compatibility
  static Future<String?> moveToPermStorage(String originalPath) async {
    try {
      // First upload to Firebase Storage
      final firebaseUrl = await uploadToFirebase(originalPath);
      if (firebaseUrl == null) {
        return null;
      }

      // For backward compatibility, also save locally
      final File originalFile = File(originalPath);
      if (!await originalFile.exists()) {
        print('Original file does not exist: $originalPath');
        return null;
      }

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String storageDir = '${appDir.path}/product_images';

      final Directory storageDirRef = Directory(storageDir);
      if (!await storageDirRef.exists()) {
        await storageDirRef.create(recursive: true);
      }

      final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}${path.extension(originalPath)}';
      final String permanentPath = '$storageDir/$fileName';

      await originalFile.copy(permanentPath);

      // Return local path to maintain compatibility
      return permanentPath;
    } catch (e) {
      print('Error moving image to permanent storage: $e');
      return null;
    }
  }

  // New method for Firebase Storage
  static Future<String?> uploadToFirebase(String localPath) async {
    return await _lock.synchronized(() async {
      try {
        // Compress image before upload
        final compressedFile = await _compressImage(localPath);
        if (compressedFile == null) return null;

        // Generate unique filename
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}${path.extension(localPath)}';
        final storageRef = _storage.ref().child('products/$fileName');

        // Upload with metadata
        final metadata = SettableMetadata(
          contentType: 'image/${path.extension(localPath).replaceAll('.', '')}',
          cacheControl: 'public, max-age=31536000',
        );

        // Upload compressed file
        final uploadTask = await storageRef.putFile(
          File(compressedFile.path),
          metadata,
        );

        // Clean up compressed file
        await _cleanupCompressedFile(compressedFile);

        // Return download URL
        return await uploadTask.ref.getDownloadURL();
      } catch (e) {
        print('Error uploading to Firebase Storage: $e');
        return null;
      }
    });
  }

  // Helper method for image compression
  static Future<File?> _compressImage(String imagePath) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${path.basename(imagePath)}';

      final result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        minWidth: 800,
        minHeight: 800,
        quality: 85,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  // Helper method to clean up compressed files
  static Future<void> _cleanupCompressedFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error cleaning up compressed file: $e');
    }
  }

  // Helper method to delete Firebase Storage image
  static Future<bool> deleteFromFirebase(String imageUrl) async {
    return await _lock.synchronized(() async {
      try {
        if (imageUrl.startsWith('http')) {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
          return true;
        }
        return false;
      } catch (e) {
        print('Error deleting from Firebase Storage: $e');
        return false;
      }
    });
  }
}