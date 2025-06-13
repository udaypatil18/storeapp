import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageStorage {
  static Future<String?> moveToPermStorage(String originalPath) async {
    try {
      final File originalFile = File(originalPath);
      if (!await originalFile.exists()) {
        print('Original file does not exist: $originalPath');
        return null;
      }

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String storageDir = '${appDir.path}/product_images';

      // Create storage directory if it doesn't exist
      final Directory storageDirRef = Directory(storageDir);
      if (!await storageDirRef.exists()) {
        await storageDirRef.create(recursive: true);
      }

      // Create unique filename using timestamp
      final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}${path.extension(originalPath)}';
      final String permanentPath = '$storageDir/$fileName';

      // Copy file to permanent storage
      await originalFile.copy(permanentPath);

      return permanentPath;
    } catch (e) {
      print('Error moving image to permanent storage: $e');
      return null;
    }
  }
}