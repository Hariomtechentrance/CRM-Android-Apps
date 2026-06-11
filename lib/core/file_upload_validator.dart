import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// File upload validator for secure file handling
class FileUploadValidator {
  /// Maximum file size (50 MB)
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  /// Allowed file extensions
  static const List<String> allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'jpg',
    'jpeg',
    'png',
    'gif',
    'txt',
    'csv'
  ];

  /// Blocked executable extensions
  static const List<String> blockedExtensions = [
    'exe',
    'bat',
    'cmd',
    'com',
    'pif',
    'scr',
    'vbs',
    'js',
    'jar',
    'zip',
    'rar',
    '7z',
    'app',
    'deb',
    'sh',
    'bin'
  ];

  /// File magic numbers (signatures) for validation
  static const Map<String, List<int>> fileMagicNumbers = {
    'pdf': [0x25, 0x50, 0x44, 0x46], // %PDF
    'jpg': [0xFF, 0xD8, 0xFF],
    'png': [0x89, 0x50, 0x4E, 0x47], // PNG
    'gif': [0x47, 0x49, 0x46],
    'xlsx': [0x50, 0x4B, 0x03, 0x04], // ZIP format
    'docx': [0x50, 0x4B, 0x03, 0x04], // ZIP format
  };

  /// Validate file for upload
  static Future<FileValidationResult> validateFile(File file) async {
    try {
      // Check if file exists
      if (!await file.exists()) {
        return FileValidationResult(
          isValid: false,
          message: 'File does not exist',
        );
      }

      // Get filename
      final filename = file.path.split('/').last;

      // Extract extension
      final extension = filename.split('.').last.toLowerCase();

      // Check extension is not blocked
      if (blockedExtensions.contains(extension)) {
        return FileValidationResult(
          isValid: false,
          message: 'File type not allowed: $extension',
        );
      }

      // Check extension is allowed
      if (!allowedExtensions.contains(extension)) {
        return FileValidationResult(
          isValid: false,
          message: 'File type not allowed. Allowed types: ${allowedExtensions.join(", ")}',
        );
      }

      // Validate filename
      try {
        _validateFilename(filename);
      } catch (e) {
        return FileValidationResult(
          isValid: false,
          message: 'Invalid filename: $e',
        );
      }

      // Check file size
      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        return FileValidationResult(
          isValid: false,
          message: 'File size exceeds maximum allowed size (50 MB)',
        );
      }

      // Validate file content by magic numbers
      final magicValidation = await _validateMagicNumbers(file, extension);
      if (!magicValidation) {
        return FileValidationResult(
          isValid: false,
          message: 'File content does not match file extension',
        );
      }

      return FileValidationResult(
        isValid: true,
        message: 'File is valid',
        filename: filename,
        fileSize: fileSize,
      );
    } catch (e) {
      return FileValidationResult(
        isValid: false,
        message: 'Error validating file: $e',
      );
    }
  }

  /// Validate multiple files
  static Future<List<FileValidationResult>> validateFiles(List<File> files) async {
    final results = <FileValidationResult>[];
    for (final file in files) {
      results.add(await validateFile(file));
    }
    return results;
  }

  /// Validate filename for path traversal
  static void _validateFilename(String filename) {
    // Remove path traversal attempts
    if (filename.contains('..') || filename.contains('/') || filename.contains('\\')) {
      throw FormatException('Invalid filename: contains path characters');
    }

    // Check for null bytes
    if (filename.contains('\x00')) {
      throw FormatException('Invalid filename: contains null bytes');
    }

    // Check filename length
    if (filename.isEmpty || filename.length > 255) {
      throw FormatException('Invalid filename: length must be between 1 and 255');
    }
  }

  /// Validate file content using magic numbers
  static Future<bool> _validateMagicNumbers(File file, String extension) async {
    try {
      // If extension not in magic numbers map, skip validation
      if (!fileMagicNumbers.containsKey(extension)) {
        return true;
      }

      // Read first few bytes
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return false;
      }

      // Compare magic numbers
      final expectedMagic = fileMagicNumbers[extension]!;
      if (bytes.length < expectedMagic.length) {
        return false;
      }

      for (int i = 0; i < expectedMagic.length; i++) {
        if (bytes[i] != expectedMagic[i]) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create safe filename from user input
  static String createSafeFilename(String originalFilename, String? newExtension) {
    // Remove path characters
    String safe = originalFilename.replaceAll(RegExp(r'[/\\]'), '');

    // Remove special characters except dots and dashes
    safe = safe.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    // Remove leading/trailing dots
    safe = safe.replaceAll(RegExp(r'^\.+|\.+$'), '');

    // Limit length
    if (safe.length > 200) {
      final lastDot = safe.lastIndexOf('.');
      if (lastDot > 0) {
        final namePart = safe.substring(0, lastDot);
        final extPart = safe.substring(lastDot);
        safe = namePart.substring(0, 200 - extPart.length) + extPart;
      } else {
        safe = safe.substring(0, 200);
      }
    }

    // Add timestamp for uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final parts = safe.split('.');
    if (parts.length > 1) {
      final ext = parts.last;
      final name = parts.sublist(0, parts.length - 1).join('.');
      safe = '${name}_$timestamp.$ext';
    } else {
      safe = '${safe}_$timestamp';
    }

    // Override extension if provided
    if (newExtension != null) {
      final parts = safe.split('.');
      parts.removeLast();
      safe = '${parts.join(".")}.$newExtension';
    }

    return safe;
  }

  /// Get secure directory for storing uploads
  static Future<String> getSecureUploadDirectory() async {
    // Note: In production, use getTemporaryDirectory() from path_provider
    // and ensure proper permissions are set
    final tempDir = Directory.systemTemp;
    final uploadDir = Directory('${tempDir.path}/flowcrm_uploads');

    if (!await uploadDir.exists()) {
      await uploadDir.create(recursive: true);
    }

    return uploadDir.path;
  }

  /// Clean up upload directory (remove old files)
  static Future<void> cleanupUploadDirectory({Duration olderThan = const Duration(hours: 24)}) async {
    try {
      final uploadDir = await getSecureUploadDirectory();
      final dir = Directory(uploadDir);

      if (!await dir.exists()) {
        return;
      }

      final files = await dir.list().toList();
      final now = DateTime.now();

      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          final fileAge = now.difference(stat.modified);

          if (fileAge > olderThan) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Silently fail cleanup
      if (kDebugMode) {
        print('Cleanup error: $e');
      }
    }
  }
}

/// Result of file validation
class FileValidationResult {
  final bool isValid;
  final String message;
  final String? filename;
  final int? fileSize;

  FileValidationResult({
    required this.isValid,
    required this.message,
    this.filename,
    this.fileSize,
  });

  @override
  String toString() => 'FileValidationResult(isValid: $isValid, message: $message)';
}
