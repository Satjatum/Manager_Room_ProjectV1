import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';
import 'dart:convert';

class UserService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all admin and superadmin users for branch owner selection
  static Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      // Check user permissions
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }

      // Only superadmin can see all admin users
      if (currentUser.userRole != UserRole.superAdmin) {
        throw Exception('ไม่มีสิทธิ์ในการดูข้อมูลผู้ดูแล');
      }

      // Query admin and superadmin users
      final result = await _supabase
          .from('users')
          .select(
              'user_id, user_name, user_email, role, created_at, last_login, is_active')
          .inFilter('role', ['admin', 'superadmin'])
          .eq('is_active', true)
          .order('role', ascending: false) // superadmin first
          .order('user_name', ascending: true);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ดูแล: $e');
    }
  }

  /// Get user by ID
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }

      final result = await _supabase
          .from('users')
          .select(
              'user_id, user_name, user_email, role, created_at, last_login, is_active')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      return result;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้: $e');
    }
  }

  /// Get all users (for superadmin only)
  static Future<List<Map<String, dynamic>>> getAllUsers({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    String? roleFilter,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }

      // Only superadmin can see all users
      if (currentUser.userRole != UserRole.superAdmin) {
        throw Exception('ไม่มีสิทธิ์ในการดูข้อมูลผู้ใช้ทั้งหมด');
      }

      // Build query
      var query = _supabase.from('users').select('*');

      // Add search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('user_name.ilike.%$searchQuery%,'
            'user_email.ilike.%$searchQuery%');
      }

      // Add role filter
      if (roleFilter != null && roleFilter.isNotEmpty) {
        query = query.eq('role', roleFilter);
      }

      // Add ordering and pagination
      final result = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้: $e');
    }
  }

  /// Create new user (for superadmin only)
  static Future<Map<String, dynamic>> createUser(
      Map<String, dynamic> userData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Only superadmin can create users
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการสร้างผู้ใช้ใหม่',
        };
      }

      // Validate required fields
      if (userData['user_name'] == null ||
          userData['user_name'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกชื่อผู้ใช้',
        };
      }

      if (userData['user_email'] == null ||
          userData['user_email'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกอีเมล',
        };
      }

      if (userData['user_pass'] == null ||
          userData['user_pass'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกรหัสผ่าน',
        };
      }

      // Check for duplicate username
      final existingUser = await _supabase
          .from('users')
          .select('user_id')
          .eq('user_name', userData['user_name'].toString().trim())
          .maybeSingle();

      if (existingUser != null) {
        return {
          'success': false,
          'message': 'ชื่อผู้ใช้นี้มีอยู่แล้วในระบบ',
        };
      }

      // Check for duplicate email
      final existingEmail = await _supabase
          .from('users')
          .select('user_id')
          .eq('user_email', userData['user_email'].toString().trim())
          .maybeSingle();

      if (existingEmail != null) {
        return {
          'success': false,
          'message': 'อีเมลนี้มีอยู่แล้วในระบบ',
        };
      }

      // Hash password
      final hashedPassword = await _supabase.rpc('hash_password', params: {
        'password': userData['user_pass'],
      });

      // Prepare data for insertion
// Prepare data for insertion
      final insertData = {
        'user_name': userData['user_name'].toString().trim(),
        'user_email': userData['user_email'].toString().trim(),
        'user_pass': hashedPassword,
        'role': userData['role'] ?? 'user',
        'permissions': userData['permissions'] != null
            ? jsonEncode(userData['permissions']) // แปลง list เป็น JSON string
            : '[]',
        'is_active': userData['is_active'] ?? true,
        'created_by': currentUser.userId,
      };
      final result =
          await _supabase.from('users').insert(insertData).select().single();

      return {
        'success': true,
        'message': 'สร้างผู้ใช้สำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        // Unique constraint violation
        if (e.message.contains('user_name')) {
          message = 'ชื่อผู้ใช้นี้มีอยู่แล้วในระบบ';
        } else if (e.message.contains('user_email')) {
          message = 'อีเมลนี้มีอยู่แล้วในระบบ';
        }
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการสร้างผู้ใช้: $e',
      };
    }
  }

  /// Update user (for superadmin only)
  static Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Only superadmin can update users (except own profile)
      if (currentUser.userRole != UserRole.superAdmin &&
          currentUser.userId != userId) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขข้อมูลผู้ใช้',
        };
      }

      // Prepare data for update
      final updateData = <String, dynamic>{};

      if (userData['user_name'] != null) {
        updateData['user_name'] = userData['user_name'].toString().trim();
      }

      if (userData['user_email'] != null) {
        updateData['user_email'] = userData['user_email'].toString().trim();
      }

      if (userData['role'] != null &&
          currentUser.userRole == UserRole.superAdmin) {
        updateData['role'] = userData['role'];
      }

      if (userData['permissions'] != null &&
          currentUser.userRole == UserRole.superAdmin) {
        updateData['permissions'] = userData['permissions'];
      }

      if (userData['is_active'] != null &&
          currentUser.userRole == UserRole.superAdmin) {
        updateData['is_active'] = userData['is_active'];
      }

      // Update password if provided
      if (userData['user_pass'] != null &&
          userData['user_pass'].toString().isNotEmpty) {
        final hashedPassword = await _supabase.rpc('hash_password', params: {
          'password': userData['user_pass'],
        });
        updateData['user_pass'] = hashedPassword;
      }

      if (updateData.isEmpty) {
        return {
          'success': false,
          'message': 'ไม่มีข้อมูลที่ต้องอัปเดต',
        };
      }

      final result = await _supabase
          .from('users')
          .update(updateData)
          .eq('user_id', userId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'อัปเดตข้อมูลผู้ใช้สำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        // Unique constraint violation
        if (e.message.contains('user_name')) {
          message = 'ชื่อผู้ใช้นี้มีอยู่แล้วในระบบ';
        } else if (e.message.contains('user_email')) {
          message = 'อีเมลนี้มีอยู่แล้วในระบบ';
        }
      } else if (e.code == 'PGRST116') {
        // Row not found
        message = 'ไม่พบผู้ใช้ที่ต้องการแก้ไข';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตข้อมูลผู้ใช้: $e',
      };
    }
  }

  /// Delete/Deactivate user (for superadmin only)
  static Future<Map<String, dynamic>> deactivateUser(String userId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Only superadmin can deactivate users
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการลบผู้ใช้',
        };
      }

      // Cannot deactivate self
      if (currentUser.userId == userId) {
        return {
          'success': false,
          'message': 'ไม่สามารถลบบัญชีของตัวเองได้',
        };
      }

      // Soft delete by setting is_active to false
      await _supabase
          .from('users')
          .update({'is_active': false}).eq('user_id', userId);

      // Also deactivate all sessions for this user
      await _supabase.from('user_sessions').delete().eq('user_id', userId);

      return {
        'success': true,
        'message': 'ปิดใช้งานผู้ใช้สำเร็จ',
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        // Row not found
        message = 'ไม่พบผู้ใช้ที่ต้องการลบ';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบผู้ใช้: $e',
      };
    }
  }

  /// Search users by name or email
  static Future<List<Map<String, dynamic>>> searchUsers(
      String searchQuery) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }

      if (searchQuery.trim().isEmpty) {
        return [];
      }

      final result = await _supabase
          .from('users')
          .select('user_id, user_name, user_email, role, is_active')
          .or('user_name.ilike.%$searchQuery%,'
              'user_email.ilike.%$searchQuery%')
          .eq('is_active', true)
          .order('user_name')
          .limit(20);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการค้นหาผู้ใช้: $e');
    }
  }
}
