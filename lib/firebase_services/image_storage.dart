// ✅ OPTIMIZED VERSION OF image_storage.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:synchronized/synchronized.dart';

class ImageStorage {
  static final _lock = Lock();
  static final _storage = FirebaseStorage.instance;

  /// Uploads image to Firebase Storage and also saves a local copy.
  // static Future<String?> moveToPermStorage(String originalPath) async {
  //   try {
  //     if (!await File(originalPath).exists()) {
  //       print('Original file does not exist: $originalPath');
  //       return null;
  //     }
  //
  //     // ✅ Upload image and get Firebase URL + local path
  //     final uploadResult = await uploadImageWithUrl(originalPath);
  //     if (uploadResult == null) return null;
  //
  //     // ✅ You can choose to copy original or compressed file
  //     final String finalLocalPath = uploadResult['localPath']!;
  //
  //     final Directory appDir = await getApplicationDocumentsDirectory();
  //     final storageDir = Directory('${appDir.path}/product_images');
  //     if (!await storageDir.exists()) await storageDir.create(recursive: true);
  //
  //     final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}${path.extension(finalLocalPath)}';
  //     final permanentPath = path.join(storageDir.path, fileName);
  //
  //     await File(finalLocalPath).copy(permanentPath);
  //
  //     return permanentPath;
  //   } catch (e, stacktrace) {
  //     print('Error in moveToPermStorage: $e');
  //     print(stacktrace);
  //     return null;
  //   }
  // }


  /// Uploads a compressed image to Firebase and returns its download URL.
  static Future<Map<String, String>?> uploadImageWithUrl(String localPath) async {
    return await _lock.synchronized(() async {
      try {
        // 1. Compress image
        final compressedFile = await _compressImage(localPath);
        if (compressedFile == null) {
          print('❌ Compression failed for: $localPath');
          return null;
        }

        // 2. Create unique file name and Firebase Storage ref
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}${path.extension(localPath)}';
        final ref = _storage.ref().child('products/$fileName');

        // 3. Set metadata (safe default to 'image/jpeg' if unknown)
        final extension = path.extension(localPath).toLowerCase().replaceAll('.', '');
        final mimeType = ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
            ? 'image/$extension'
            : 'image/jpeg';

        final metadata = SettableMetadata(
          contentType: mimeType,
          cacheControl: 'public, max-age=31536000',
        );

        // 4. Upload file
        final uploadTask = await ref.putFile(compressedFile, metadata);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        print('✅ Uploaded $fileName to Firebase Storage');
        print('📎 Download URL: $downloadUrl');

        // 5. Clean up temp compressed file
        await _cleanupCompressedFile(compressedFile);

        return {
          'localPath': compressedFile.path,
          'downloadUrl': downloadUrl,
        };
      } catch (e, stack) {
        print('❌ Error uploading image: $e');
        print(stack);
        return null;
      }
    });
  }


  /// Compresses the image to a temporary file.
  static Future<File?> _compressImage(String imagePath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(tempDir.path, 'compressed_\${path.basename(imagePath)}');

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        minWidth: 800,
        minHeight: 800,
        quality: 85,
      );

      return result != null ? File(result.path) : null;
    } catch (e, stacktrace) {
      print('Error compressing image: \$e');
      print(stacktrace);
      return null;
    }
  }

  /// Deletes the temporary compressed file if it exists.
  static Future<void> _cleanupCompressedFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      print('Error deleting compressed file: \$e');
    }
  }

  /// Deletes an image from Firebase Storage using its download URL.
  static Future<bool> deleteFromFirebase(String imageUrl) async {
    return await _lock.synchronized(() async {
      try {
        if (!imageUrl.startsWith('http')) return false;
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
        return true;
      } catch (e, stacktrace) {
        print('Error deleting image from Firebase: \$e');
        print(stacktrace);
        return false;
      }
    });
  }
}