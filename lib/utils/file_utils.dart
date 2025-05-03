import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class FileUtils {
  // Consolidate file extension handling
  static String ensureFileExtension(String filename, String contentType) {
    if (filename.contains('.')) return filename;

    final extensions = {
      'image/': '.jpg',
      'application/pdf': '.pdf',
      'text/': '.txt',
      'audio/': '.mp3',
      'video/': '.mp4',
      'application/msword': '.doc',
      'application/vnd.openxmlformats': '.docx',
      'application/vnd.ms-excel': '.xls',
      'application/zip': '.zip',
    };

    // Try to match content type
    for (final entry in extensions.entries) {
      if (contentType.contains(entry.key)) return '$filename${entry.value}';
    }

    return '$filename.bin';
  }

  // Clean filename for safe storage
  static String getSafeFilename(String filename, String contentType) {
    var safe = filename.replaceAll(RegExp(r'[\/\\\:\*\?\"\<\>\|]'), '_');
    return ensureFileExtension(safe, contentType);
  }

  // Handle base64 data from Gmail API
  static Future<File> writeBase64ToFile(
    String base64Data,
    String path, {
    bool normalize = true,
  }) async {
    try {
      var data = base64Data;
      if (normalize) {
        // Fix URL-safe base64 encoding
        data = data.replaceAll('-', '+').replaceAll('_', '/');
        // Add padding if needed
        while (data.length % 4 != 0) data += '=';
      }

      final bytes = base64Decode(data);
      final file = File(path);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      throw Exception('Failed to write file: $e');
    }
  }
}
