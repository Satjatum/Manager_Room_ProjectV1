import 'package:flutter/material.dart';
import 'package:manager_room_project/views/login_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/services/auth_service.dart';

// Logout Service Class
class LogoutService {
  static final LogoutService _instance = LogoutService._internal();
  factory LogoutService() => _instance;
  LogoutService._internal();

  // ไม่ต้องมี final supabase = Supabase.instance.client; แล้ว
  // เพราะจะเรียกใช้ Supabase.instance.client โดยตรง

  /// ออกจากระบบและล้างข้อมูลทั้งหมด
  Future<bool> logout() async {
    try {
      print('Starting logout process...');

      // 1. อัพเดท last_login ใน database ก่อนออกจากระบบ
      final currentUser = AuthService.getCurrentUser();
      if (currentUser != null) {
        print('Updating last logout for user: ${currentUser.userId}');
        await _updateLastLogout(currentUser.userId);
      }

      // 2. ล้างข้อมูลใน AuthService ก่อน
      print('Clearing AuthService data...');
      await AuthService.setCurrentUser(null);

      // 3. ล้างข้อมูลใน SharedPreferences
      print('Clearing SharedPreferences...');
      await _clearLocalStorage();

      // 4. Sign out จาก Supabase
      print('Signing out from Supabase...');
      await Supabase.instance.client.auth.signOut(); // แก้ไขตรงนี้

      // 5. ตรวจสอบว่าล้างข้อมูลสำเร็จหรือไม่
      final isStillLoggedIn = AuthService.isLoggedIn();
      final session =
          Supabase.instance.client.auth.currentSession; // แก้ไขตรงนี้

      print('Logout verification:');
      print('- AuthService.isLoggedIn(): $isStillLoggedIn');
      print('- Supabase session: ${session != null ? 'exists' : 'null'}');

      if (isStillLoggedIn || session != null) {
        print('WARNING: Logout may not be complete!');
        // Force clear again
        await _forceClearAll();
      }

      print('Logout completed successfully');
      return true;
    } catch (e) {
      print('Error during logout: $e');
      // ถ้า logout ปกติไม่สำเร็จ ให้ force clear
      await _forceClearAll();
      return false;
    }
  }

  /// Force clear ทุกอย่าง (สำหรับกรณีฉุกเฉิน)
  Future<void> _forceClearAll() async {
    try {
      print('Force clearing all data...');

      // Force clear AuthService
      await AuthService.setCurrentUser(null);

      // Force clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // ล้างทั้งหมด

      // Force sign out from Supabase
      try {
        await Supabase.instance.client.auth.signOut(); // แก้ไขตรงนี้
      } catch (e) {
        print('Force Supabase signout error: $e');
      }

      print('Force clear completed');
    } catch (e) {
      print('Force clear error: $e');
    }
  }

  /// อัพเดท last_login ในฐานข้อมูล
  Future<void> _updateLastLogout(String userId) async {
    try {
      await Supabase.instance.client.from('users').update({
        'last_login': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      print('Error updating last logout: $e');
    }
  }

  /// ล้างข้อมูลใน SharedPreferences
  Future<void> _clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      print('Clearing SharedPreferences keys...');

      // ล้างข้อมูลที่เกี่ยวข้องกับ user session
      final keysToRemove = [
        'user_session', // AuthService key
        'is_logged_in', // AuthService key
        'user_id',
        'user_email',
        'username',
        'user_role',
        'user_token',
        'branch_id',
        'branch_name',
        'tenant_id',
        'user_permissions',
        'last_login',
        'remember_me',
        'auto_login',
        // เพิ่ม Supabase keys
        'supabase.auth.token',
        'supabase.session',
        'flutter.supabase_auth',
      ];

      for (String key in keysToRemove) {
        final removed = await prefs.remove(key);
        if (removed) {
          print('Removed key: $key');
        }
      }

      // ตรวจสอบว่ายังมี keys ที่เกี่ยวข้องเหลือหรือไม่
      final allKeys = prefs.getKeys();
      final remainingAuthKeys = allKeys
          .where((key) =>
              key.contains('user') ||
              key.contains('auth') ||
              key.contains('login') ||
              key.contains('supabase'))
          .toList();

      if (remainingAuthKeys.isNotEmpty) {
        print('WARNING: Remaining auth-related keys: $remainingAuthKeys');
        // ลบ keys ที่เหลือ
        for (String key in remainingAuthKeys) {
          await prefs.remove(key);
          print('Force removed remaining key: $key');
        }
      }

      print('Local storage cleared successfully');
    } catch (e) {
      print('Error clearing local storage: $e');
      rethrow;
    }
  }

  /// ตรวจสอบสถานะการล็อกอิน
  Future<bool> isLoggedIn() async {
    try {
      final session =
          Supabase.instance.client.auth.currentSession; // แก้ไขตรงนี้
      return session != null && AuthService.getCurrentUser() != null;
    } catch (e) {
      return false;
    }
  }
}

// Logout Mixin สำหรับใช้ใน Widget ต่างๆ
mixin LogoutMixin<T extends StatefulWidget> on State<T> {
  final LogoutService _logoutService = LogoutService();

  /// ฟังก์ชัน logout หลัก
  Future<void> performLogout({bool showConfirmation = true}) async {
    try {
      // แสดง confirmation dialog ถ้าต้องการ
      if (showConfirmation) {
        final shouldLogout = await _showLogoutConfirmation();
        if (!shouldLogout) return;
      }

      // แสดง loading
      _showLoadingDialog();

      // ทำการ logout
      final success = await _logoutService.logout();

      // ปิด loading dialog
      if (mounted) Navigator.of(context).pop();

      if (success) {
        // logout สำเร็จ - นำทางไปหน้า login
        await _navigateToLogin();
      } else {
        // logout ไม่สำเร็จ - แสดง error
        _showErrorMessage('เกิดข้อผิดพลาดในการออกจากระบบ กรุณาลองใหม่อีกครั้ง');
      }
    } catch (e) {
      // ปิด loading dialog ถ้ายังเปิดอยู่
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      _showErrorMessage('เกิดข้อผิดพลาดที่ไม่คาดคิด: ${e.toString()}');
    }
  }

  /// แสดง confirmation dialog
  Future<bool> _showLogoutConfirmation() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('ออกจากระบบ'),
                ],
              ),
              content: const Text(
                'คุณต้องการออกจากระบบหรือไม่?\n\nคุณจะต้องเข้าสู่ระบบใหม่อีกครั้ง',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ออกจากระบบ'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// แสดง loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('กำลังออกจากระบบ...'),
            ],
          ),
        );
      },
    );
  }

  /// แสดงข้อความ error
  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'ลองใหม่',
          textColor: Colors.white,
          onPressed: () => performLogout(showConfirmation: false),
        ),
      ),
    );
  }

  /// นำทางไปหน้า login - ใช้ pushReplacement
  Future<void> _navigateToLogin() async {
    if (!mounted) return;

    try {
      print('Navigating to login screen...');

      // ตรวจสอบอีกครั้งว่า logout สำเร็จหรือไม่
      final isStillLoggedIn = AuthService.isLoggedIn();
      final session =
          Supabase.instance.client.auth.currentSession; // แก้ไขตรงนี้

      print('Pre-navigation check:');
      print('- AuthService.isLoggedIn(): $isStillLoggedIn');
      print('- Supabase session: ${session != null ? 'exists' : 'null'}');

      if (isStillLoggedIn || session != null) {
        print('WARNING: User still appears to be logged in, force clearing...');
        await _logoutService._forceClearAll();
      }

      // แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ออกจากระบบสำเร็จ'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      // รอสักครู่แล้วนำทางไปหน้า login
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        print('Executing navigation...');
        // ใช้ pushAndRemoveUntil เพื่อให้แน่ใจว่าล้าง navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => _getLoginScreen(),
            settings: const RouteSettings(name: '/login'), // กำหนด route name
          ),
          (Route<dynamic> route) => false, // ล้าง stack ทั้งหมด
        );
        print('Navigation completed');
      }
    } catch (e) {
      print('Navigation error: $e');
      if (mounted) {
        _showErrorMessage('เกิดข้อผิดพลาดในการนำทาง กรุณาเปิดแอปใหม่');
      }
    }
  }

  /// Helper function เพื่อสร้าง Login Screen
  Widget _getLoginScreen() {
    return const LoginUi(); // ใช้ LoginUi class ที่มีอยู่แล้ว
  }
}

// Logout Helper Functions
class LogoutHelper {
  /// ตรวจสอบว่ามี session หมดอายุหรือไม่
  static Future<bool> isSessionExpired() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return true;

      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      return session.expiresAt != null && session.expiresAt! < now;
    } catch (e) {
      return true;
    }
  }

  /// Auto logout เมื่อ session หมดอายุ
  static Future<void> checkAndAutoLogout(BuildContext context) async {
    if (!context.mounted) return;

    try {
      final isExpired = await isSessionExpired();
      if (isExpired) {
        await LogoutService().logout();

        if (context.mounted) {
          // ใช้ pushReplacement สำหรับ auto logout
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => _getAutoLogoutLoginScreen(),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Auto logout error: $e');
    }
  }

  /// Helper function สำหรับ auto logout
  static Widget _getAutoLogoutLoginScreen() {
    return const LoginUi(); // ใช้ LoginUi class
  }

  /// Force logout (สำหรับกรณีฉุกเฉิน)
  static Future<void> forceLogout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await AuthService.setCurrentUser(null);

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => _getForceLogoutScreen(),
          ),
        );
      }
    } catch (e) {
      print('Force logout error: $e');
    }
  }

  /// Helper function สำหรับ force logout
  static Widget _getForceLogoutScreen() {
    return const LoginUi(); // ใช้ LoginUi class
  }
}
