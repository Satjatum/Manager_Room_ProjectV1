import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _sessionKey = 'user_session';
  static const String _userIdKey = 'current_user_id';

  // Initialize session on app start
  static Future<void> initializeSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString(_sessionKey);

      if (sessionData != null) {
        final isValid = await validateSession();
        if (!isValid) {
          await clearUserSession();
        }
      }
    } catch (e) {
      print('Error initializing session: $e');
      await clearUserSession();
    }
  }

  // Sign in with email/username and password
  static Future<Map<String, dynamic>> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      // Query user by email or username
      final userQuery = await _supabase
          .from('users')
          .select('*')
          .or('user_email.eq.$emailOrUsername,user_name.eq.$emailOrUsername')
          .eq('is_active', true)
          .single();

      // Verify password using database function
      final passwordCheck = await _supabase.rpc('verify_password', params: {
        'password': password,
        'hash': userQuery['user_pass'],
      });

      if (!passwordCheck) {
        return {
          'success': false,
          'message': 'รหัสผ่านไม่ถูกต้อง',
        };
      }

      // Update last_login timestamp
      await _supabase.from('users').update({
        'last_login': DateTime.now().toIso8601String(),
      }).eq('user_id', userQuery['user_id']);

      // Generate new session token
      final sessionToken = await _generateSessionToken();
      final expiresAt = DateTime.now().add(const Duration(days: 7));

      // Create session in database with additional tracking info
      await _supabase.from('user_sessions').insert({
        'user_id': userQuery['user_id'],
        'token': sessionToken,
        'expires_at': expiresAt.toIso8601String(),
        'last_activity': DateTime.now().toIso8601String(),
        'user_agent': await _getUserAgent(),
        'ip_address': await _getClientIP(),
      });

      // Get user data and create UserModel
      final userData = await _getUserWithInfo(userQuery['user_id']);
      final user = UserModel.fromDatabase(userData);

      // Store session locally
      await _storeUserSession(user.userId, sessionToken);

      return {
        'success': true,
        'user': user,
        'message': 'เข้าสู่ระบบสำเร็จ',
      };
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return {
          'success': false,
          'message': 'ไม่พบผู้ใช้งานนี้ในระบบ',
        };
      }
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ: $e',
      };
    }
  }

  // Get user with additional info
  static Future<Map<String, dynamic>> _getUserWithInfo(String userId) async {
    final userResponse = await _supabase
        .from('users')
        .select('*')
        .eq('user_id', userId)
        .eq('is_active', true)
        .single();

    // If user is tenant, get tenant info
    if (userResponse['role'] == 'tenant') {
      try {
        final tenantResponse = await _supabase
            .from('tenants')
            .select('*')
            .eq('user_id', userId)
            .eq('is_active', true)
            .single();

        return {
          ...userResponse,
          'tenant_info': tenantResponse,
        };
      } catch (e) {
        return userResponse;
      }
    }

    return userResponse;
  }

  // Generate session token
  static Future<String> _generateSessionToken() async {
    final result = await _supabase.rpc('generate_token');
    return result as String;
  }

  // Get user agent (simplified for Flutter)
  static Future<String> _getUserAgent() async {
    try {
      // You can implement device info here
      return 'Flutter App';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Get client IP (placeholder - would need proper implementation)
  static Future<String?> _getClientIP() async {
    try {
      // This would require proper IP detection implementation
      return null;
    } catch (e) {
      return null;
    }
  }

  // Store session locally
  static Future<void> _storeUserSession(
      String userId, String sessionToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, sessionToken);
    await prefs.setString(_userIdKey, userId);
  }

  // Get current user from session
  static Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);

      if (userId == null) return null;

      final userData = await _getUserWithInfo(userId);
      return UserModel.fromDatabase(userData);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Validate current session
  static Future<bool> validateSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString(_sessionKey);
      final userId = prefs.getString(_userIdKey);

      if (sessionToken == null || userId == null) return false;

      // Check session in database
      final sessionResponse = await _supabase
          .from('user_sessions')
          .select('*')
          .eq('token', sessionToken)
          .eq('user_id', userId)
          .gte('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (sessionResponse == null) {
        await clearUserSession();
        return false;
      }

      // Update last activity
      await _supabase.from('user_sessions').update({
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('token', sessionToken);

      // Check if user is still active
      final userResponse = await _supabase
          .from('users')
          .select('is_active')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (userResponse == null) {
        await clearUserSession();
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating session: $e');
      await clearUserSession();
      return false;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString(_sessionKey);

      if (sessionToken != null) {
        await _supabase
            .from('user_sessions')
            .delete()
            .eq('token', sessionToken);
      }
    } catch (e) {
      print('Error during sign out: $e');
    } finally {
      await clearUserSession();
    }
  }

  // Clear user session locally
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_userIdKey);
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    return await validateSession();
  }

  // Update password
  static Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Get current password hash
      final userQuery = await _supabase
          .from('users')
          .select('user_pass')
          .eq('user_id', currentUser.userId)
          .single();

      // Verify current password
      final passwordCheck = await _supabase.rpc('verify_password', params: {
        'password': currentPassword,
        'hash': userQuery['user_pass'],
      });

      if (!passwordCheck) {
        return {
          'success': false,
          'message': 'รหัสผ่านปัจจุบันไม่ถูกต้อง',
        };
      }

      // Hash new password
      final hashedPassword = await _supabase.rpc('hash_password', params: {
        'password': newPassword,
      });

      // Update password
      await _supabase.from('users').update({'user_pass': hashedPassword}).eq(
          'user_id', currentUser.userId);

      return {
        'success': true,
        'message': 'เปลี่ยนรหัสผ่านสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  // Update user permissions (admin function)
  static Future<Map<String, dynamic>> updateUserPermissions({
    required String userId,
    required List<String> permissions,
  }) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null ||
          !currentUser.hasPermission(DetailedPermission.manageUsers)) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขข้อมูลผู้ใช้',
        };
      }

      // Update user permissions
      await _supabase.from('users').update({
        'permissions': permissions,
      }).eq('user_id', userId);

      return {
        'success': true,
        'message': 'อัปเดตสิทธิ์การใช้งานสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  // Get user login history
  static Future<List<Map<String, dynamic>>> getUserLoginHistory({
    String? userId,
    int limit = 10,
  }) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) return [];

      final targetUserId = userId ?? currentUser.userId;

      // Only allow users to see their own history unless they're admin
      if (targetUserId != currentUser.userId &&
          !currentUser.hasPermission(DetailedPermission.manageUsers)) {
        return [];
      }

      final sessions = await _supabase
          .from('user_sessions')
          .select('created_at, last_activity, user_agent, ip_address')
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(limit);

      return sessions;
    } catch (e) {
      print('Error getting login history: $e');
      return [];
    }
  }

  // Clean expired sessions
  static Future<void> cleanExpiredSessions() async {
    try {
      await _supabase
          .from('user_sessions')
          .delete()
          .lt('expires_at', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error cleaning expired sessions: $e');
    }
  }

  // Get active sessions count for current user
  static Future<int> getActiveSessionsCount() async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) return 0;

      final sessions = await _supabase
          .from('user_sessions')
          .select('session_id')
          .eq('user_id', currentUser.userId)
          .gte('expires_at', DateTime.now().toIso8601String());

      return sessions.length;
    } catch (e) {
      print('Error getting active sessions count: $e');
      return 0;
    }
  }

  // Terminate all other sessions (keep current one)
  static Future<Map<String, dynamic>> terminateOtherSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSessionToken = prefs.getString(_sessionKey);
      final currentUser = await getCurrentUser();

      if (currentUser == null || currentSessionToken == null) {
        return {
          'success': false,
          'message': 'ไม่พบเซสชันปัจจุบัน',
        };
      }

      await _supabase
          .from('user_sessions')
          .delete()
          .eq('user_id', currentUser.userId)
          .neq('token', currentSessionToken);

      return {
        'success': true,
        'message': 'ยกเลิกเซสชันอื่นทั้งหมดสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }
}
