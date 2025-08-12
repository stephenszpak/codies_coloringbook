import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static Future<String> getApplicationDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<String> saveFile(
    String filename,
    Uint8List data, {
    String? subfolder,
  }) async {
    final appDir = await getApplicationDirectory();
    final dirPath = subfolder != null ? '$appDir/$subfolder' : appDir;
    
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File('$dirPath/$filename');
    await file.writeAsBytes(data);
    return file.path;
  }

  static Future<Uint8List?> loadFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      // File doesn't exist or can't be read
    }
    return null;
  }

  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      // File doesn't exist or can't be deleted
    }
    return false;
  }

  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync();
      
      for (final entity in tempFiles) {
        if (entity is File && entity.path.contains('coloring_temp_')) {
          try {
            await entity.delete();
          } catch (e) {
            // Ignore cleanup errors
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}