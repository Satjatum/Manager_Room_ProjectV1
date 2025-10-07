import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:uuid/uuid.dart'; // เพิ่ม UUID package

class ImageService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  // Supported image formats
  static const List<String> _supportedFormats = ['jpg', 'jpeg', 'png', 'webp'];

  // Maximum file size (5MB)
  static const int _maxFileSize = 5 * 1024 * 1024;

  /// Generate unique filename with UUID and additional context
  static String _generateUniqueFileName({
    required String extension,
    String? prefix,
    String? context, // เพิ่ม context เพื่อความชัดเจน
  }) {
    final uuid = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String fileName = '';

    if (prefix != null) {
      fileName += '${prefix}_';
    }

    if (context != null) {
      fileName += '${context}_';
    }

    fileName += '${timestamp}_${uuid.substring(0, 8)}.$extension';

    return fileName;
  }

  /// Check if file exists in storage
  static Future<bool> _fileExists(String bucket, String path) async {
    try {
      final files = await _supabase.storage.from(bucket).list(
            path: path.contains('/')
                ? path.substring(0, path.lastIndexOf('/'))
                : '',
          );

      final fileName =
          path.contains('/') ? path.substring(path.lastIndexOf('/') + 1) : path;
      return files.any((file) => file.name == fileName);
    } catch (e) {
      return false; // ถ้าเกิดข้อผิดพลาด ให้ถือว่าไฟล์ไม่มี
    }
  }

  /// Upload image to Supabase Storage
  static Future<Map<String, dynamic>> uploadImage(
    File imageFile,
    String bucket, {
    String? folder,
    String? customFileName,
    String? prefix, // เพิ่ม prefix สำหรับจำแนกประเภทไฟล์
    String? context, // เพิ่ม context สำหรับข้อมูลเพิ่มเติม
  }) async {
    try {
      // Check file size
      int fileSize;
      try {
        fileSize = await imageFile.length();
      } catch (e) {
        return {
          'success': false,
          'message': 'ไม่สามารถอ่านไฟล์ได้',
        };
      }

      if (fileSize > _maxFileSize) {
        return {
          'success': false,
          'message': 'ขนาดไฟล์เกิน 5MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า',
        };
      }

      if (fileSize == 0) {
        return {
          'success': false,
          'message': 'ไฟล์เสียหาย',
        };
      }

      // Validate file format
      final extension =
          path.extension(imageFile.path).toLowerCase().substring(1);
      if (!_supportedFormats.contains(extension)) {
        return {
          'success': false,
          'message': 'รองรับเฉพาะไฟล์ JPG, PNG, WebP เท่านั้น',
        };
      }

      // Generate unique filename
      String fileName;
      if (customFileName != null) {
        fileName = customFileName;
      } else {
        fileName = _generateUniqueFileName(
          extension: extension,
          prefix: prefix,
          context: context,
        );
      }

      // Create full path
      String fullPath = fileName;
      if (folder != null && folder.isNotEmpty) {
        fullPath = '$folder/$fileName';
      }

      // Check if file already exists and generate new name if needed
      int attempt = 0;
      String originalFullPath = fullPath;
      while (await _fileExists(bucket, fullPath) && attempt < 5) {
        attempt++;
        final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
        final ext = fileName.substring(fileName.lastIndexOf('.'));
        fileName = '${nameWithoutExt}_${attempt}$ext';
        fullPath = folder != null ? '$folder/$fileName' : fileName;
      }

      // Read file bytes
      Uint8List fileBytes;
      try {
        fileBytes = await imageFile.readAsBytes();
      } catch (e) {
        return {
          'success': false,
          'message': 'ไม่สามารถอ่านข้อมูลไฟล์ได้',
        };
      }

      // Upload to Supabase Storage
      try {
        await _supabase.storage.from(bucket).uploadBinary(fullPath, fileBytes);

        // Get public URL
        final publicUrl = _supabase.storage.from(bucket).getPublicUrl(fullPath);

        return {
          'success': true,
          'message': 'อัปโหลดรูปภาพสำเร็จ',
          'url': publicUrl,
          'path': fullPath,
          'fileName': fileName,
          'fileSize': fileSize,
          'originalPath': originalFullPath, // เก็บ path เดิมไว้เปรียบเทียบ
          'renamed':
              fullPath != originalFullPath, // บอกว่ามีการเปลี่ยนชื่อหรือไม่
        };
      } on StorageException catch (e) {
        String message = 'เกิดข้อผิดพลาดในการอัปโหลด: ${e.message}';

        if (e.statusCode == '413') {
          message = 'ขนาดไฟล์เกินที่อนุญาต';
        } else if (e.statusCode == '400') {
          message = 'รูปแบบไฟล์ไม่ถูกต้อง';
        } else if (e.statusCode == '409') {
          // Conflict - try with different name
          return await uploadImage(
            imageFile,
            bucket,
            folder: folder,
            prefix: prefix,
            context:
                '${context ?? ''}_retry_${DateTime.now().millisecondsSinceEpoch}',
          );
        }

        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e',
      };
    }
  }

  /// Upload image from bytes with improved naming
  static Future<Map<String, dynamic>> uploadImageFromBytes(
    Uint8List imageBytes,
    String originalFileName,
    String bucket, {
    String? folder,
    String? prefix,
    String? context,
  }) async {
    try {
      // Check file size
      if (imageBytes.length > _maxFileSize) {
        return {
          'success': false,
          'message': 'ขนาดไฟล์เกิน 5MB',
        };
      }

      // Validate file format from filename
      String extension;
      try {
        final parts = originalFileName.split('.');
        if (parts.length < 2) {
          return {
            'success': false,
            'message': 'ไฟล์ต้องมีนามสกุล',
          };
        }
        extension = parts.last.toLowerCase();
      } catch (e) {
        return {
          'success': false,
          'message': 'ไม่สามารถตรวจสอบนามสกุลไฟล์ได้',
        };
      }

      if (!_supportedFormats.contains(extension)) {
        return {
          'success': false,
          'message': 'รองรับเฉพาะไฟล์ JPG, PNG, WebP เท่านั้น',
        };
      }

      // Generate unique filename
      final fileName = _generateUniqueFileName(
        extension: extension,
        prefix: prefix,
        context: context,
      );

      // Create full path
      String fullPath = fileName;
      if (folder != null && folder.isNotEmpty) {
        fullPath = '$folder/$fileName';
      }

      // Check if file already exists and generate new name if needed
      int attempt = 0;
      String originalFullPath = fullPath;
      while (await _fileExists(bucket, fullPath) && attempt < 5) {
        attempt++;
        final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
        final ext = fileName.substring(fileName.lastIndexOf('.'));
        final newFileName = '${nameWithoutExt}_${attempt}$ext';
        fullPath = folder != null ? '$folder/$newFileName' : newFileName;
      }

      // Upload to Supabase Storage
      await _supabase.storage.from(bucket).uploadBinary(fullPath, imageBytes);

      // Get public URL
      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(fullPath);

      return {
        'success': true,
        'message': 'อัปโหลดรูปภาพสำเร็จ',
        'url': publicUrl,
        'path': fullPath,
        'fileName': fullPath.split('/').last,
        'fileSize': imageBytes.length,
        'originalPath': originalFullPath,
        'renamed': fullPath != originalFullPath,
      };
    } on StorageException catch (e) {
      if (e.statusCode == '409') {
        // Conflict - try again with different context
        return await uploadImageFromBytes(
          imageBytes,
          originalFileName,
          bucket,
          folder: folder,
          prefix: prefix,
          context:
              '${context ?? ''}_retry_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปโหลด: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e',
      };
    }
  }

  // ... เก็บ methods อื่นๆ เหมือนเดิม

  /// Delete image from storage
  static Future<Map<String, dynamic>> deleteImage(String imageUrl) async {
    try {
      final urlParts = _parseImageUrl(imageUrl);
      if (urlParts == null) {
        return {
          'success': false,
          'message': 'URL รูปภาพไม่ถูกต้อง',
        };
      }

      await _supabase.storage
          .from(urlParts['bucket']!)
          .remove([urlParts['path']!]);

      return {
        'success': true,
        'message': 'ลบรูปภาพสำเร็จ',
      };
    } on StorageException catch (e) {
      if (e.statusCode == '404') {
        return {
          'success': true,
          'message': 'ไฟล์ไม่พบ (อาจถูกลบไปแล้ว)',
        };
      }

      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบรูปภาพ: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบรูปภาพ: $e',
      };
    }
  }

  /// Parse image URL to extract bucket and path
  static Map<String, String>? _parseImageUrl(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 5 &&
          pathSegments[0] == 'storage' &&
          pathSegments[1] == 'v1' &&
          pathSegments[2] == 'object' &&
          pathSegments[3] == 'public') {
        final bucket = pathSegments[4];
        final path = pathSegments.skip(5).join('/');

        return {
          'bucket': bucket,
          'path': path,
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generate random string for filename
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // ... methods อื่นๆ เหมือนเดิม
}
