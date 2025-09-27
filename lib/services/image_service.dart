import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

class ImageService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Supported image formats
  static const List<String> _supportedFormats = ['jpg', 'jpeg', 'png', 'webp'];

  // Maximum file size (5MB)
  static const int _maxFileSize = 5 * 1024 * 1024;

  /// Upload image to Supabase Storage
  ///
  /// [imageFile] - The image file to upload
  /// [bucket] - Storage bucket name (e.g., 'branch-images', 'room-images', 'user-profiles')
  /// [folder] - Optional folder path within bucket
  /// Returns Map with success status and image URL or error message
  static Future<Map<String, dynamic>> uploadImage(
    File imageFile,
    String bucket, {
    String? folder,
    String? customFileName,
  }) async {
    try {
      // Check file size without using file operations that might cause issues
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

      // Validate file format from path
      final extension =
          path.extension(imageFile.path).toLowerCase().substring(1);
      if (!_supportedFormats.contains(extension)) {
        return {
          'success': false,
          'message': 'รองรับเฉพาะไฟล์ JPG, PNG, WebP เท่านั้น',
        };
      }

      // Generate unique filename if not provided
      String fileName;
      if (customFileName != null) {
        fileName = customFileName;
      } else {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final random = _generateRandomString(8);
        fileName = '${timestamp}_${random}.$extension';
      }

      // Create full path
      String fullPath = fileName;
      if (folder != null && folder.isNotEmpty) {
        fullPath = '$folder/$fileName';
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
        };
      } on StorageException catch (e) {
        String message = 'เกิดข้อผิดพลาดในการอัปโหลด: ${e.message}';

        if (e.statusCode == '413') {
          message = 'ขนาดไฟล์เกินที่อนุญาต';
        } else if (e.statusCode == '400') {
          message = 'รูปแบบไฟล์ไม่ถูกต้อง';
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

  /// Upload image from bytes
  static Future<Map<String, dynamic>> uploadImageFromBytes(
    Uint8List imageBytes,
    String fileName,
    String bucket, {
    String? folder,
  }) async {
    try {
      // Check file size
      if (imageBytes.length > _maxFileSize) {
        return {
          'success': false,
          'message': 'ขนาดไฟล์เกิน 5MB',
        };
      }

      // Validate file format from filename using safer method
      String extension;
      try {
        final parts = fileName.split('.');
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

      // Create full path
      String fullPath = fileName;
      if (folder != null && folder.isNotEmpty) {
        fullPath = '$folder/$fileName';
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
        'fileName': fileName,
        'fileSize': imageBytes.length,
      };
    } on StorageException catch (e) {
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

  /// Delete image from storage
  ///
  /// [imageUrl] - Full URL of the image to delete
  /// Returns success status
  static Future<Map<String, dynamic>> deleteImage(String imageUrl) async {
    try {
      // Extract bucket and path from URL
      final urlParts = _parseImageUrl(imageUrl);
      if (urlParts == null) {
        return {
          'success': false,
          'message': 'URL รูปภาพไม่ถูกต้อง',
        };
      }

      // Delete from storage
      await _supabase.storage
          .from(urlParts['bucket']!)
          .remove([urlParts['path']!]);

      return {
        'success': true,
        'message': 'ลบรูปภาพสำเร็จ',
      };
    } on StorageException catch (e) {
      // If file doesn't exist, consider it a success
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

  /// Delete multiple images
  static Future<Map<String, dynamic>> deleteImages(
      List<String> imageUrls) async {
    try {
      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      for (String url in imageUrls) {
        final result = await deleteImage(url);
        if (result['success']) {
          successCount++;
        } else {
          failCount++;
          errors.add(result['message']);
        }
      }

      return {
        'success': failCount == 0,
        'message':
            'ลบรูปภาพสำเร็จ $successCount รูป${failCount > 0 ? ', ล้มเหลว $failCount รูป' : ''}',
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบรูปภาพ: $e',
      };
    }
  }

  /// Get image info
  static Future<Map<String, dynamic>?> getImageInfo(String imageUrl) async {
    try {
      final urlParts = _parseImageUrl(imageUrl);
      if (urlParts == null) return null;

      // This would require additional API calls to get file metadata
      // For now, return basic info from URL
      return {
        'bucket': urlParts['bucket'],
        'path': urlParts['path'],
        'url': imageUrl,
      };
    } catch (e) {
      return null;
    }
  }

  /// List images in a folder
  static Future<List<Map<String, dynamic>>> listImages(
    String bucket, {
    String? folder,
    int limit = 100,
  }) async {
    try {
      final files = await _supabase.storage.from(bucket).list(
            path: folder,
            searchOptions: const SearchOptions(
              limit: 100,
              sortBy: const SortBy(
                column: 'created_at',
                order: 'desc',
              ),
            ),
          );

      // Filter only image files using safer extension check
      final imageFiles = files.where((file) {
        try {
          final parts = file.name.split('.');
          if (parts.length < 2) return false;
          final extension = parts.last.toLowerCase();
          return _supportedFormats.contains(extension);
        } catch (e) {
          return false;
        }
      }).toList();

      // Convert to image info with URLs
      final result = imageFiles.map((file) {
        final publicUrl = _supabase.storage
            .from(bucket)
            .getPublicUrl(folder != null ? '$folder/${file.name}' : file.name);

        return {
          'name': file.name,
          'url': publicUrl,
          'path': folder != null ? '$folder/${file.name}' : file.name,
          'size': file.metadata?['size'],
          'created_at': file.createdAt,
          'updated_at': file.updatedAt,
        };
      }).toList();

      return result;
    } on StorageException catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดรายการรูปภาพ: ${e.message}');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดรายการรูปภาพ: $e');
    }
  }

  /// Generate optimized image URL with transformations
  ///
  /// [imageUrl] - Original image URL
  /// [width] - Target width
  /// [height] - Target height
  /// [quality] - Image quality (1-100)
  static String getOptimizedImageUrl(
    String imageUrl, {
    int? width,
    int? height,
    int? quality,
  }) {
    // Supabase doesn't have built-in image transformation
    // This method can be extended to work with image transformation services
    // For now, return the original URL
    return imageUrl;
  }

  /// Generate thumbnail URL
  static String getThumbnailUrl(String imageUrl, {int size = 150}) {
    // This would integrate with image transformation service
    // For now, return original URL
    return imageUrl;
  }

  /// Validate image file before upload - Simple version without problematic operations
  static Future<Map<String, dynamic>> validateImageFile(File imageFile) async {
    try {
      // Check file size first
      int fileSize;
      try {
        fileSize = await imageFile.length();
      } catch (e) {
        return {
          'valid': false,
          'message': 'ไม่สามารถตรวจสอบขนาดไฟล์ได้',
        };
      }

      if (fileSize > _maxFileSize) {
        return {
          'valid': false,
          'message':
              'ขนาดไฟล์เกิน ${(_maxFileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
        };
      }

      if (fileSize == 0) {
        return {
          'valid': false,
          'message': 'ไฟล์เสียหาย',
        };
      }

      // Check file format from filename using safer method
      String extension;
      try {
        final fileName = imageFile.path.split('/').last;
        final parts = fileName.split('.');
        if (parts.length < 2) {
          return {
            'valid': false,
            'message': 'ไฟล์ต้องมีนามสกุล',
          };
        }
        extension = parts.last.toLowerCase();
      } catch (e) {
        return {
          'valid': false,
          'message': 'ไม่สามารถตรวจสอบนามสกุลไฟล์ได้',
        };
      }

      if (!_supportedFormats.contains(extension)) {
        return {
          'valid': false,
          'message':
              'รองรับเฉพาะไฟล์ ${_supportedFormats.join(', ').toUpperCase()} เท่านั้น',
        };
      }

      return {
        'valid': true,
        'message': 'ไฟล์ถูกต้อง',
        'size': fileSize,
        'extension': extension,
      };
    } catch (e) {
      return {
        'valid': false,
        'message': 'เกิดข้อผิดพลาดในการตรวจสอบไฟล์: $e',
      };
    }
  }

  /// Parse image URL to extract bucket and path
  static Map<String, String>? _parseImageUrl(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Expected format: /storage/v1/object/public/{bucket}/{path}
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

  /// Check if image URL is valid and accessible
  static Future<bool> isImageAccessible(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 10);
      final request = await client.headUrl(uri);
      final response = await request.close();
      client.close();

      return response.statusCode == 200 &&
          response.headers.contentType?.mimeType.startsWith('image/') == true;
    } catch (e) {
      return false;
    }
  }

  /// Create storage bucket if it doesn't exist
  static Future<Map<String, dynamic>> createBucketIfNotExists(
    String bucketName, {
    bool isPublic = true,
  }) async {
    try {
      // Try to create bucket - if it exists, Supabase will return an error
      try {
        await _supabase.storage.createBucket(
          bucketName,
          BucketOptions(public: isPublic),
        );

        return {
          'success': true,
          'message': 'สร้าง bucket สำเร็จ',
          'exists': false,
        };
      } on StorageException catch (e) {
        // If bucket already exists, that's fine
        if (e.statusCode == '409' || e.message.contains('already exists')) {
          return {
            'success': true,
            'message': 'Bucket มีอยู่แล้ว',
            'exists': true,
          };
        } else {
          throw e;
        }
      }
    } on StorageException catch (e) {
      return {
        'success': false,
        'message': 'ไม่สามารถสร้าง bucket ได้: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการสร้าง bucket: $e',
      };
    }
  }
}
