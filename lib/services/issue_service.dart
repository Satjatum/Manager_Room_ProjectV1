import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

class IssueService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all issues with pagination and filtering
  static Future<List<Map<String, dynamic>>> getAllIssues({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    String? branchId,
    String? issueType,
    String? issueStatus,
    String? issuePriority,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      var query = _supabase.from('issue_reports').select('''
        *,
        rooms!inner(
          room_id,
          room_number,
          branches!inner(branch_id, branch_name, branch_code)
        ),
        tenants(tenant_id, tenant_fullname, tenant_phone),
        assigned_user:assigned_to(user_id, user_name, user_email),
        created_user:created_by(user_id, user_name)
      ''');

      // Add filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'issue_num.ilike.%$searchQuery%,'
          'issue_title.ilike.%$searchQuery%,'
          'issue_desc.ilike.%$searchQuery%',
        );
      }

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('rooms.branch_id', branchId);
      }

      if (issueType != null && issueType.isNotEmpty) {
        query = query.eq('issue_type', issueType);
      }

      if (issueStatus != null && issueStatus.isNotEmpty) {
        query = query.eq('issue_status', issueStatus);
      }

      if (issuePriority != null && issuePriority.isNotEmpty) {
        query = query.eq('issue_priority', issuePriority);
      }

      final result = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result).map((issue) {
        return {
          ...issue,
          'room_number': issue['rooms']?['room_number'],
          'branch_id': issue['rooms']?['branches']?['branch_id'],
          'branch_name': issue['rooms']?['branches']?['branch_name'],
          'branch_code': issue['rooms']?['branches']?['branch_code'],
          'tenant_fullname': issue['tenants']?['tenant_fullname'],
          'tenant_phone': issue['tenants']?['tenant_phone'],
          'assigned_user_name': issue['assigned_user']?['user_name'],
          'created_user_name': issue['created_user']?['user_name'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลปัญหา: $e');
    }
  }

  /// Get issues by user role and permissions
  static Future<List<Map<String, dynamic>>> getIssuesByUser({
    String? branchId,
    String? issueStatus,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();

      if (currentUser == null) {
        return [];
      }

      // SuperAdmin can see all issues across all branches
      if (currentUser.userRole == UserRole.superAdmin) {
        return getAllIssues(branchId: branchId, issueStatus: issueStatus);
      }

      // Admin: only see issues in branches they manage (from branch_managers)
      if (currentUser.userRole == UserRole.admin) {
        final managedBranchIds = await _getManagedBranchIds(currentUser.userId);

        if (managedBranchIds.isEmpty) {
          return [];
        }

        // If a specific branch is requested, ensure it's managed by the admin
        if (branchId != null && branchId.isNotEmpty) {
          if (!managedBranchIds.contains(branchId)) {
            return [];
          }
          // Return issues only for that managed branch
          return getAllIssues(branchId: branchId, issueStatus: issueStatus);
        }

        // Otherwise, fetch all and filter to managed branches in-memory
        final issues = await getAllIssues(issueStatus: issueStatus);
        return issues
            .where((i) => managedBranchIds.contains(i['branch_id']))
            .toList();
      }

      // Tenant can only see their own issues
      if (currentUser.userRole == UserRole.tenant &&
          currentUser.tenantId != null) {
        var query = _supabase
            .from('issue_reports')
            .select('''
          *,
          rooms!inner(
            room_id,
            room_number,
            branches!inner(branch_id, branch_name, branch_code)
          ),
          tenants(tenant_id, tenant_fullname, tenant_phone),
          assigned_user:assigned_to(user_id, user_name, user_email)
        ''')
            .eq('tenant_id', currentUser.tenantId!);

        if (issueStatus != null && issueStatus.isNotEmpty) {
          query = query.eq('issue_status', issueStatus);
        }

        final result = await query.order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(result).map((issue) {
          return {
            ...issue,
            'room_number': issue['rooms']?['room_number'],
            'branch_name': issue['rooms']?['branches']?['branch_name'],
            'assigned_user_name': issue['assigned_user']?['user_name'],
          };
        }).toList();
      }

      // Other users with view permission can see issues in their assigned branch
      if (currentUser.branchId != null) {
        return getAllIssues(
          branchId: currentUser.branchId,
          issueStatus: issueStatus,
        );
      }

      return [];
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลปัญหา: $e');
    }
  }

  /// Get list of branch IDs that the user manages
  static Future<List<String>> _getManagedBranchIds(String userId) async {
    try {
      final rows = await _supabase
          .from('branch_managers')
          .select('branch_id')
          .eq('user_id', userId);
      return rows
          .map<String>((r) => r['branch_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get issue by ID
  static Future<Map<String, dynamic>?> getIssueById(String issueId) async {
    try {
      final result =
          await _supabase
              .from('issue_reports')
              .select('''
        *,
        rooms!inner(
          room_id,
          room_number,
          branches!inner(branch_id, branch_name, branch_code, branch_address)
        ),
        tenants(tenant_id, tenant_fullname, tenant_phone),
        assigned_user:assigned_to(user_id, user_name, user_email),
        created_user:created_by(user_id, user_name)
      ''')
              .eq('issue_id', issueId)
              .maybeSingle();

      if (result == null) return null;

      return {
        ...result,
        'room_number': result['rooms']?['room_number'],
        'branch_id': result['rooms']?['branches']?['branch_id'],
        'branch_name': result['rooms']?['branches']?['branch_name'],
        'tenant_fullname': result['tenants']?['tenant_fullname'],
        'assigned_user_name': result['assigned_user']?['user_name'],
        'created_user_name': result['created_user']?['user_name'],
      };
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลปัญหา: $e');
    }
  }

  /// Create new issue
  static Future<Map<String, dynamic>> createIssue(
    Map<String, dynamic> issueData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // Check permissions
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageIssues,
        DetailedPermission.createIssues,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการรายงานปัญหา'};
      }

      // Validate required fields
      if (issueData['room_id'] == null ||
          issueData['room_id'].toString().trim().isEmpty) {
        return {'success': false, 'message': 'กรุณาเลือกห้องพัก'};
      }

      if (issueData['issue_type'] == null ||
          issueData['issue_type'].toString().trim().isEmpty) {
        return {'success': false, 'message': 'กรุณาเลือกประเภทปัญหา'};
      }

      if (issueData['issue_title'] == null ||
          issueData['issue_title'].toString().trim().isEmpty) {
        return {'success': false, 'message': 'กรุณากรอกหัวข้อปัญหา'};
      }

      if (issueData['issue_desc'] == null ||
          issueData['issue_desc'].toString().trim().isEmpty) {
        return {'success': false, 'message': 'กรุณากรอกรายละเอียดปัญหา'};
      }

      // Generate issue number
      final issueNum = await _generateIssueNumber();

      // Prepare data for insertion
      final insertData = {
        'issue_num': issueNum,
        'room_id': issueData['room_id'],
        'tenant_id': issueData['tenant_id'] ?? currentUser.tenantId,
        'issue_type': issueData['issue_type'],
        'issue_priority': issueData['issue_priority'] ?? 'medium',
        'issue_title': issueData['issue_title'].toString().trim(),
        'issue_desc': issueData['issue_desc'].toString().trim(),
        'issue_status': 'pending',
        'created_by': currentUser.userId,
      };

      final result =
          await _supabase
              .from('issue_reports')
              .insert(insertData)
              .select()
              .single();

      return {'success': true, 'message': 'รายงานปัญหาสำเร็จ', 'data': result};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.message}'};
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการรายงานปัญหา: $e',
      };
    }
  }

  /// Update issue
  static Future<Map<String, dynamic>> updateIssue(
    String issueId,
    Map<String, dynamic> issueData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // Check permissions
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageIssues,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขข้อมูลปัญหา',
        };
      }

      // Prepare data for update
      final updateData = {
        'issue_type': issueData['issue_type'],
        'issue_priority': issueData['issue_priority'],
        'issue_title': issueData['issue_title']?.toString().trim(),
        'issue_desc': issueData['issue_desc']?.toString().trim(),
        'issue_status': issueData['issue_status'],
        'assigned_to': issueData['assigned_to'],
        'resolution_notes': issueData['resolution_notes'],
      };

      // Remove null values
      updateData.removeWhere((key, value) => value == null);

      // If status is resolved, set resolved_date
      if (issueData['issue_status'] == 'resolved') {
        updateData['resolved_date'] = DateTime.now().toIso8601String();
      }

      final result =
          await _supabase
              .from('issue_reports')
              .update(updateData)
              .eq('issue_id', issueId)
              .select()
              .single();

      return {
        'success': true,
        'message': 'อัปเดตข้อมูลปัญหาสำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.message}'};
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตข้อมูลปัญหา: $e',
      };
    }
  }

  /// Assign issue to user
  static Future<Map<String, dynamic>> assignIssue(
    String issueId,
    String userId,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageIssues,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการมอบหมายงาน'};
      }

      await _supabase
          .from('issue_reports')
          .update({'assigned_to': userId, 'issue_status': 'in_progress'})
          .eq('issue_id', issueId);

      return {'success': true, 'message': 'มอบหมายงานสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการมอบหมายงาน: $e'};
    }
  }

  /// Update issue status
  static Future<Map<String, dynamic>> updateIssueStatus(
    String issueId,
    String status, {
    String? resolutionNotes,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageIssues,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการเปลี่ยนสถานะ'};
      }

      final updateData = {'issue_status': status};

      if (status == 'resolved') {
        updateData['resolved_date'] = DateTime.now().toIso8601String();
        if (resolutionNotes != null) {
          updateData['resolution_notes'] = resolutionNotes;
        }
      }

      await _supabase
          .from('issue_reports')
          .update(updateData)
          .eq('issue_id', issueId);

      return {'success': true, 'message': 'อัปเดตสถานะสำเร็จ'};
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตสถานะ: $e',
      };
    }
  }

  /// Get issue images
  static Future<List<Map<String, dynamic>>> getIssueImages(
    String issueId,
  ) async {
    try {
      final result = await _supabase
          .from('issue_images')
          .select('*')
          .eq('issue_id', issueId)
          .order('created_at');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดรูปภาพ: $e');
    }
  }

  /// Add issue image
  static Future<Map<String, dynamic>> addIssueImage(
    String issueId,
    String imageUrl, {
    String? description,
  }) async {
    try {
      await _supabase.from('issue_images').insert({
        'issue_id': issueId,
        'image_url': imageUrl,
        'description': description,
      });

      return {'success': true, 'message': 'เพิ่มรูปภาพสำเร็จ'};
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเพิ่มรูปภาพ: $e',
      };
    }
  }

  /// Generate issue number
  static Future<String> _generateIssueNumber() async {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');

    // Get count of issues this month
    final startOfMonth = DateTime(now.year, now.month, 1);
    final count = await _supabase
        .from('issue_reports')
        .select('issue_id')
        .gte('created_at', startOfMonth.toIso8601String());

    final sequence = (count.length + 1).toString().padLeft(4, '0');

    return 'ISS$year$month$sequence';
  }

  /// Get issue statistics
  static Future<Map<String, dynamic>> getIssueStatistics({
    String? branchId,
  }) async {
    try {
      var query = _supabase.from('issue_reports').select('issue_status');

      if (branchId != null) {
        query = query.eq('rooms.branch_id', branchId);
      }

      final allIssues = await query;

      final pending =
          allIssues.where((i) => i['issue_status'] == 'pending').length;
      final inProgress =
          allIssues.where((i) => i['issue_status'] == 'in_progress').length;
      final resolved =
          allIssues.where((i) => i['issue_status'] == 'resolved').length;
      final cancelled =
          allIssues.where((i) => i['issue_status'] == 'cancelled').length;

      return {
        'total': allIssues.length,
        'pending': pending,
        'in_progress': inProgress,
        'resolved': resolved,
        'cancelled': cancelled,
      };
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสถิติ: $e');
    }
  }

  /// Search issues
  static Future<List<Map<String, dynamic>>> searchIssues(
    String searchQuery,
  ) async {
    try {
      if (searchQuery.trim().isEmpty) {
        return [];
      }

      final result = await _supabase
          .from('issue_reports')
          .select('''
        *,
        rooms!inner(room_number, branches!inner(branch_name))
      ''')
          .or(
            'issue_num.ilike.%$searchQuery%,'
            'issue_title.ilike.%$searchQuery%,'
            'issue_desc.ilike.%$searchQuery%',
          )
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(result).map((issue) {
        return {
          ...issue,
          'room_number': issue['rooms']?['room_number'],
          'branch_name': issue['rooms']?['branches']?['branch_name'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการค้นหาปัญหา: $e');
    }
  }
}
