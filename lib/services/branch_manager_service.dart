import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

class BranchManagerService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get all managers for a branch
  static Future<List<Map<String, dynamic>>> getBranchManagers(
      String branchId) async {
    try {
      final result = await _supabase
          .from('branch_managers')
          .select('''
            *,
            users:user_id (
              user_id,
              user_name,
              user_email,
              role
            )
          ''')
          .eq('branch_id', branchId)
          .order('is_primary', ascending: false)
          .order('assigned_at');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดผู้ดูแล: $e');
    }
  }

  // Add manager to branch
  static Future<Map<String, dynamic>> addBranchManager({
    required String branchId,
    required String userId,
    bool isPrimary = false,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบ'};
      }

      // Check permissions
      if (currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์เพิ่มผู้ดูแล'};
      }

      // Validate user is admin or superadmin
      final userData = await _supabase
          .from('users')
          .select('user_name, role, is_active')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (userData == null) {
        return {'success': false, 'message': 'ไม่พบผู้ใช้ที่เลือก'};
      }

      if (userData['role'] != 'admin' && userData['role'] != 'superadmin') {
        return {
          'success': false,
          'message': 'ผู้ดูแลต้องเป็น Admin หรือ SuperAdmin'
        };
      }

      // Check if already a manager
      final existing = await _supabase
          .from('branch_managers')
          .select('id')
          .eq('branch_id', branchId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        return {'success': false, 'message': 'ผู้ใช้นี้เป็นผู้ดูแลอยู่แล้ว'};
      }

      // If setting as primary, remove primary from others
      if (isPrimary) {
        await _supabase
            .from('branch_managers')
            .update({'is_primary': false}).eq('branch_id', branchId);
      }

      // Add manager
      final result = await _supabase.from('branch_managers').insert({
        'branch_id': branchId,
        'user_id': userId,
        'is_primary': isPrimary,
        'assigned_by': currentUser.userId,
      }).select('''
            *,
            users:user_id (
              user_id,
              user_name,
              user_email,
              role
            )
          ''').single();

      return {
        'success': true,
        'message': 'เพิ่มผู้ดูแลสำเร็จ',
        'data': result,
      };
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  // Remove manager from branch
  static Future<Map<String, dynamic>> removeBranchManager({
    required String branchId,
    required String userId,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบ'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ลบผู้ดูแล'};
      }

      // Check if this is the last manager
      final managerCount = await _supabase
          .from('branch_managers')
          .select('id')
          .eq('branch_id', branchId);

      if (managerCount.length <= 1) {
        return {
          'success': false,
          'message': 'ไม่สามารถลบได้ ต้องมีผู้ดูแลอย่างน้อย 1 คน'
        };
      }

      await _supabase
          .from('branch_managers')
          .delete()
          .eq('branch_id', branchId)
          .eq('user_id', userId);

      return {'success': true, 'message': 'ลบผู้ดูแลสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  // Set primary manager
  static Future<Map<String, dynamic>> setPrimaryManager({
    required String branchId,
    required String userId,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบ'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์เปลี่ยนผู้ดูแลหลัก'};
      }

      // Remove primary from all others
      await _supabase
          .from('branch_managers')
          .update({'is_primary': false}).eq('branch_id', branchId);

      // Set new primary
      await _supabase
          .from('branch_managers')
          .update({'is_primary': true})
          .eq('branch_id', branchId)
          .eq('user_id', userId);

      return {'success': true, 'message': 'เปลี่ยนผู้ดูแลหลักสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }
}
