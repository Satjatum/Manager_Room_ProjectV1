import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user_model.dart';

class AuthService {
  static UserModel? _currentUser;
  static const String _userSessionKey = 'user_session';
  static const String _isLoggedInkey = 'is_logged_in';

  // Hash password using SHA256
  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Convert file to base64
  static Future<String> fileToBase64(File file) async {
    try {
      List<int> imageBytes = await file.readAsBytes();
      return base64Encode(imageBytes);
    } catch (e) {
      throw Exception('Error converting file to base64: $e');
    }
  }

  // Save user session to SharedPreferences
  static Future<void> _saveUserSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.toJson());
      await prefs.setString(_userSessionKey, userJson);
      await prefs.setBool(_isLoggedInkey, true);
    } catch (e) {
      throw Exception('Error saving user session: $e');
    }
  }

  // Load user session from SharedPreferences
  static Future<UserModel?> _loadUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userSessionKey);
      final isLoggedIn = prefs.getBool(_isLoggedInkey) ?? false;

      if (userJson != null && isLoggedIn) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return UserModel.fromJson(userMap);
      }
      return null;
    } catch (e) {
      throw Exception('Error loading user session: $e');
    }
  }

  // Clear User session from SharedPreferences (PRIVATE)
  static Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userSessionKey);
      await prefs.setBool(_isLoggedInkey, false);
      print('Session cleared successfully');
    } catch (e) {
      throw Exception('Error clearing user session: $e');
    }
  }

  // PUBLIC method to clear user session - ADD THIS METHOD
  static Future<void> clearUserSession() async {
    try {
      print('Clearing user session...');
      _currentUser = null;
      await _clearUserSession();
      print('User session cleared successfully');
    } catch (e) {
      print('Error clearing user session: $e');
      rethrow;
    }
  }

  // Update last login time
  static Future<void> _updateLastLogin(String userId) async {
    try {
      await supabase.from('users').update({
        'last_login': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  // Initialize AuthService
  static Future<void> initializeSession() async {
    try {
      print('Initializing AuthService session...');

      final saveUser = await _loadUserSession();
      if (saveUser != null) {
        print('Found saved user session: ${saveUser.userId}');

        final response = await supabase
            .from('users')
            .select()
            .eq('user_id', saveUser.userId)
            .maybeSingle();

        if (response != null) {
          final user = UserModel.fromJson(response);
          if (user.userStatus == UserStatus.active) {
            _currentUser = user;
            print('Session restored for user: ${user.displayName}');
          } else {
            print('User no longer active, clearing session');
            await _clearUserSession();
            _currentUser = null; // เพิ่มบรรทัดนี้
          }
        } else {
          print('User not found in database, clearing session');
          await _clearUserSession();
          _currentUser = null; // เพิ่มบรรทัดนี้
        }
      } else {
        print('No saved user session found');
        _currentUser = null; // เพิ่มบรรทัดนี้
      }
    } catch (e) {
      print('Error initializing session: $e');
      await _clearUserSession();
      _currentUser = null; // เพิ่มบรรทัดนี้
    }
  }

  // Set current user and save session
  static Future<void> setCurrentUser(UserModel? user) async {
    _currentUser = user;
    if (user != null) {
      await _saveUserSession(user);
      // Update last login time
      await _updateLastLogin(user.userId);
    } else {
      await _clearUserSession();
    }
  }

  // Get current user
  static UserModel? getCurrentUser() {
    return _currentUser;
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    return _currentUser != null;
  }

  // Check if current user is super admin
  static bool isSuperAdmin() {
    return _currentUser?.userRole == UserRole.superAdmin;
  }

  // Check if current user is admin (including super admin)
  static bool isAdmin() {
    return _currentUser?.userRole == UserRole.admin || isSuperAdmin();
  }

  // Check if current user is tenant
  static bool isTenant() {
    return _currentUser?.userRole == UserRole.tenant;
  }

  // Sign in with email or username
  static Future<Map<String, dynamic>> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      if (emailOrUsername.trim().isEmpty || password.isEmpty) {
        return {
          'success': false,
          'message': 'Email/Username และ Password จำเป็นต้องกรอก'
        };
      }

      // Hash the input password
      String hashedPassword = hashPassword(password);

      // Query user by email or username with hashed password
      final response = await supabase
          .from('users')
          .select()
          .or('user_email.eq.${emailOrUsername.trim()},username.eq.${emailOrUsername.trim()}')
          .eq('user_pass', hashedPassword)
          .maybeSingle();

      print('Database response: $response'); // Debug log

      if (response != null) {
        final user = UserModel.fromJson(response);

        print('User role from DB: ${response['user_role']}'); // Debug log
        print('Parsed user role: ${user.userRole}'); // Debug log

        if (user.userStatus != UserStatus.active) {
          return {
            'success': false,
            'message':
                'บัญชีถูก ${user.userStatus.toString().split('.').last} กรุณาติดต่อผู้ดูแลระบบ'
          };
        }

        await setCurrentUser(user);

        return {
          'success': true,
          'user': user,
          'message': 'เข้าสู่ระบบสำเร็จ',
          'userType': user.userRole.toString().split('.').last,
        };
      } else {
        print('No user found with provided credentials'); // Debug log
        return {
          'success': false,
          'message': 'Email/Username หรือ Password ไม่ถูกต้อง'
        };
      }
    } catch (e) {
      print('Login error: $e'); // Debug log
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ: ${e.toString()}'
      };
    }
  }

  static Future<Map<String, dynamic>> signOut() async {
    try {
      await setCurrentUser(null);
      return {
        'success': true,
        'message': 'ออกจากระบบสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการออกจากระบบ: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> refreshUserData() async {
    try {
      if (_currentUser == null) {
        return {'success': false, 'message': 'ไม่มีผู้ใช้ที่เข้าสู่ระบบ'};
      }

      final response = await supabase
          .from('users')
          .select()
          .eq('user_id', _currentUser!.userId)
          .maybeSingle();

      if (response != null) {
        final updatedUser = UserModel.fromJson(response);

        if (updatedUser.userStatus != UserStatus.active) {
          await setCurrentUser(null);
          return {
            'success': false,
            'message': 'บัญชีของคุณถูกระงับ กรุณาติดต่อผู้ดูแลระบบ',
            'forceLogout': true
          };
        }

        await setCurrentUser(updatedUser);

        return {
          'success': true,
          'user': updatedUser,
          'message': 'อัพเดทข้อมูลผู้ใช้สำเร็จ'
        };
      } else {
        await setCurrentUser(null);
        return {
          'success': false,
          'message': 'ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่',
          'forceLogout': true
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.toString()}'};
    }
  }

  static Future<bool> isSessionValid() async {
    try {
      if (_currentUser == null) return false;

      final response = await supabase
          .from('users')
          .select('user_id, user_status')
          .eq('user_id', _currentUser!.userId)
          .maybeSingle();

      if (response != null) {
        final status = response['user_status'];
        return status == 'active';
      }
      return false;
    } catch (e) {
      print('Error checking session validity: $e');
      return false;
    }
  }

  // Sign up new user (Super Admin only function)
  static Future<Map<String, dynamic>> signUpUser({
    required String userEmail,
    required String username,
    required String password,
    required UserRole userRole,
    required UserStatus userStatus,
    String? branchId,
    String? branchName,
    List<String>? userPermission,
    File? profileImage,
  }) async {
    try {
      if (!isSuperAdmin()) {
        return {
          'success': false,
          'message': 'เฉพาะ Super Admin เท่านั้นที่สามารถสร้าง User ใหม่ได้'
        };
      }

      if (userEmail.trim().isEmpty ||
          username.trim().isEmpty ||
          password.isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน'
        };
      }

      // Check if email or username already exists
      final existingUser = await supabase
          .from('users')
          .select('user_id')
          .or('user_email.eq.${userEmail.trim()},username.eq.${username.trim()}')
          .maybeSingle();

      if (existingUser != null) {
        return {
          'success': false,
          'message': 'Email หรือ Username นี้มีอยู่แล้ว'
        };
      }

      String hashedPassword = hashPassword(password);

      String? profileImageBase64;
      if (profileImage != null) {
        profileImageBase64 = await fileToBase64(profileImage);
      }

      final now = DateTime.now();
      final currentUser = getCurrentUser();

      // Set default permissions
      final permissions = userPermission ?? _getDefaultPermissions(userRole);

      final response = await supabase.from('users').insert({
        'user_email': userEmail.trim(),
        'username': username.trim(),
        'user_pass': hashedPassword,
        'user_role': userRole.toString().split('.').last.toLowerCase(),
        'user_status': userStatus.toString().split('.').last.toLowerCase(),
        'branch_id': branchId,
        'branch_name': branchName,
        'user_profile': profileImageBase64,
        'user_permission': permissions,
        'created_by': currentUser?.userId,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).select();

      if (response.isNotEmpty) {
        return {'success': true, 'message': 'สร้าง User สำเร็จแล้ว'};
      } else {
        return {'success': false, 'message': 'ไม่สามารถสร้าง User ได้'};
      }
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.toString()}'};
    }
  }

  // Get default permissions based on role
  static List<String> _getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return [
          'view_tenants',
          'manage_tenants',
          'view_rooms',
          'manage_rooms',
          'view_bills',
          'manage_bills',
          'view_reports',
          'manage_notifications',
          'manage_users',
          'manage_branches'
        ];
      case UserRole.admin:
        return [
          'view_tenants',
          'manage_tenants',
          'view_rooms',
          'manage_rooms',
          'view_bills',
          'manage_bills',
          'view_reports',
          'manage_notifications'
        ];
      case UserRole.user:
        return ['view_tenants', 'view_rooms', 'view_bills'];
      case UserRole.tenant:
        return ['view_own_data'];
    }
  }

  // Get all users (Super Admin only)
  static Future<List<UserModel>> getAllUsers() async {
    try {
      if (!isSuperAdmin()) {
        throw Exception(
            'เฉพาะ Super Admin เท่านั้นที่สามารถดู User ทั้งหมดได้');
      }

      final response = await supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);

      return response
          .map<UserModel>((json) => UserModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการดึงข้อมูล User: ${e.toString()}');
    }
  }

  // Update user status (Super Admin only)
  static Future<Map<String, dynamic>> updateUserStatus({
    required String userId,
    required UserStatus newStatus,
  }) async {
    try {
      if (!isSuperAdmin()) {
        return {
          'success': false,
          'message': 'เฉพาะ Super Admin เท่านั้นที่สามารถแก้ไขสถานะ User ได้'
        };
      }

      await supabase.from('users').update({
        'user_status': newStatus.toString().split('.').last.toLowerCase(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      return {'success': true, 'message': 'อัพเดทสถานะ User สำเร็จแล้ว'};
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.toString()}'};
    }
  }

  // Delete user (Super Admin only)
  static Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      if (!isSuperAdmin()) {
        return {
          'success': false,
          'message': 'เฉพาะ Super Admin เท่านั้นที่สามารถลบ User ได้'
        };
      }

      if (_currentUser?.userId == userId) {
        return {'success': false, 'message': 'ไม่สามารถลบบัญชีของตัวเองได้'};
      }

      await supabase.from('users').delete().eq('user_id', userId);

      return {'success': true, 'message': 'ลบ User สำเร็จแล้ว'};
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.toString()}'};
    }
  }
}
