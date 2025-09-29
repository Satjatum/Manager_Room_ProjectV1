import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

class TenantService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getAllTenants({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    String? branchId,
    bool? isActive,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      var query = _supabase.from('tenants').select('''
      *,
      branches(branch_id, branch_name, branch_code)
    ''');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('tenant_fullname.ilike.%$searchQuery%,'
            'tenant_idcard.ilike.%$searchQuery%,'
            'tenant_phone.ilike.%$searchQuery%');
      }

      // กรองตาม branch_id
      if (branchId != null && branchId.isNotEmpty) {
        if (branchId == 'null') {
          // แสดงเฉพาะผู้เช่าที่ไม่มีสาขา
          query = query.isFilter('branch_id', null);
        } else {
          query = query.eq('branch_id', branchId);
        }
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final result = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result).map((tenant) {
        return {
          ...tenant,
          'branch_name': tenant['branches']?['branch_name'] ?? 'ไม่ระบุสาขา',
          'branch_code': tenant['branches']?['branch_code'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้เช่า: $e');
    }
  }

  /// Get tenants by user role and permissions
  static Future<List<Map<String, dynamic>>> getTenantsByUser({
    String? branchId,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();

      // Anonymous users cannot see tenants
      if (currentUser == null) {
        return [];
      }

      // If user has manage tenants permission, return all tenants
      if (currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageTenants,
      ])) {
        return getAllTenants(isActive: true);
      }

      // For other users with view tenants permission
      if (currentUser.hasPermission(DetailedPermission.viewTenants)) {
        var query = _supabase.from('tenants').select('*').eq('is_active', true);

        final result = await query.order('tenant_fullname');
        return List<Map<String, dynamic>>.from(result);
      }

      return [];
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้เช่า: $e');
    }
  }

  /// Get tenant by ID
  static Future<Map<String, dynamic>?> getTenantById(String tenantId) async {
    try {
      final result = await _supabase
          .from('tenants')
          .select('*')
          .eq('tenant_id', tenantId)
          .maybeSingle();

      return result;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้เช่า: $e');
    }
  }

  /// Create new tenant
  static Future<Map<String, dynamic>> createTenant(
      Map<String, dynamic> tenantData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Check permissions
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageTenants,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการสร้างผู้เช่าใหม่',
        };
      }

      // Validate required fields

      if (tenantData['branch_id'] == null ||
          tenantData['branch_id'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณาเลือกสาขา',
        };
      }

      if (tenantData['tenant_idcard'] == null ||
          tenantData['tenant_idcard'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกเลขบัตรประชาชน',
        };
      }

      if (tenantData['tenant_fullname'] == null ||
          tenantData['tenant_fullname'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกชื่อ-นามสกุล',
        };
      }

      if (tenantData['tenant_phone'] == null ||
          tenantData['tenant_phone'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกเบอร์โทรศัพท์',
        };
      }

      // Check for duplicate ID card
      final existingIdCard = await _supabase
          .from('tenants')
          .select('tenant_id')
          .eq('tenant_idcard', tenantData['tenant_idcard'].toString().trim())
          .maybeSingle();

      if (existingIdCard != null) {
        return {
          'success': false,
          'message': 'เลขบัตรประชาชนนี้มีอยู่แล้วในระบบ',
        };
      }

      // Prepare data for insertion
      final insertData = {
        'branch_id': tenantData['branch_id'], // เพิ่มบรรทัดนี้
        'tenant_idcard': tenantData['tenant_idcard'].toString().trim(),
        'tenant_fullname': tenantData['tenant_fullname'].toString().trim(),
        'tenant_phone': tenantData['tenant_phone'].toString().trim(),
        'gender': tenantData['gender'],
        'tenant_profile': tenantData['tenant_profile'],
        'is_active': tenantData['is_active'] ?? true,
        'created_by': currentUser.userId,
      };

      // If user_id is provided, validate it exists
      if (tenantData['user_id'] != null &&
          tenantData['user_id'].toString().isNotEmpty) {
        final userExists = await _supabase
            .from('users')
            .select('user_id')
            .eq('user_id', tenantData['user_id'])
            .eq('role', 'tenant')
            .eq('is_active', true)
            .maybeSingle();

        if (userExists == null) {
          return {
            'success': false,
            'message': 'ไม่พบบัญชีผู้ใช้ที่เชื่อมโยง',
          };
        }

        insertData['user_id'] = tenantData['user_id'];
      }

      final result =
          await _supabase.from('tenants').insert(insertData).select().single();

      return {
        'success': true,
        'message': 'สร้างผู้เช่าสำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        if (e.message.contains('tenant_idcard')) {
          message = 'เลขบัตรประชาชนนี้มีอยู่แล้วในระบบ';
        }
      } else if (e.code == '23503') {
        if (e.message.contains('user_id')) {
          message = 'ไม่พบบัญชีผู้ใช้ที่เชื่อมโยง';
        }
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการสร้างผู้เช่า: $e',
      };
    }
  }

  /// Update tenant
  static Future<Map<String, dynamic>> updateTenant(
    String tenantId,
    Map<String, dynamic> tenantData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Check permissions
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageTenants,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขข้อมูลผู้เช่า',
        };
      }

      // Check for duplicate ID card (exclude current tenant)
      if (tenantData['tenant_idcard'] != null) {
        final existingIdCard = await _supabase
            .from('tenants')
            .select('tenant_id')
            .eq('tenant_idcard', tenantData['tenant_idcard'].toString().trim())
            .neq('tenant_id', tenantId)
            .maybeSingle();

        if (existingIdCard != null) {
          return {
            'success': false,
            'message': 'เลขบัตรประชาชนนี้มีอยู่แล้วในระบบ',
          };
        }
      }

      // Prepare data for update
      final updateData = {
        'branch_id': tenantData['branch_id'],
        'tenant_idcard': tenantData['tenant_idcard']?.toString().trim(),
        'tenant_fullname': tenantData['tenant_fullname']?.toString().trim(),
        'tenant_phone': tenantData['tenant_phone']?.toString().trim(),
        'gender': tenantData['gender'],
        'tenant_profile': tenantData['tenant_profile'],
        'is_active': tenantData['is_active'],
      };

      // Remove null values
      updateData.removeWhere((key, value) => value == null);

      final result = await _supabase
          .from('tenants')
          .update(updateData)
          .eq('tenant_id', tenantId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'อัปเดตข้อมูลผู้เช่าสำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        if (e.message.contains('tenant_idcard')) {
          message = 'เลขบัตรประชาชนนี้มีอยู่แล้วในระบบ';
        }
      } else if (e.code == 'PGRST116') {
        message = 'ไม่พบผู้เช่าที่ต้องการแก้ไข';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตข้อมูลผู้เช่า: $e',
      };
    }
  }

  /// Toggle tenant status (active/inactive)
  static Future<Map<String, dynamic>> toggleTenantStatus(
      String tenantId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      if (tenantId.isEmpty) {
        return {
          'success': false,
          'message': 'ไม่พบรหัสผู้เช่า',
        };
      }

      // Check permissions
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageTenants,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการเปลี่ยนสถานะผู้เช่า',
        };
      }

      // Get current status
      final existingTenant = await _supabase
          .from('tenants')
          .select('tenant_id, tenant_fullname, is_active')
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (existingTenant == null) {
        return {
          'success': false,
          'message': 'ไม่พบผู้เช่าที่ต้องการ',
        };
      }

      final currentStatus = existingTenant['is_active'] ?? false;
      final newStatus = !currentStatus;

      // Update status
      final result = await _supabase
          .from('tenants')
          .update({
            'is_active': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('tenant_id', tenantId)
          .select()
          .single();

      return {
        'success': true,
        'message': newStatus
            ? 'เปิดใช้งานผู้เช่า "${existingTenant['tenant_fullname']}" สำเร็จ'
            : 'ปิดใช้งานผู้เช่า "${existingTenant['tenant_fullname']}" สำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        message = 'ไม่พบผู้เช่าที่ต้องการ';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเปลี่ยนสถานะผู้เช่า: $e',
      };
    }
  }

  /// Delete tenant permanently (SuperAdmin only)
  static Future<Map<String, dynamic>> deleteTenant(String tenantId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      if (tenantId.isEmpty) {
        return {
          'success': false,
          'message': 'ไม่พบรหัสผู้เช่า',
        };
      }

      // Only superadmin can delete permanently
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการลบผู้เช่าถาวร',
        };
      }

      // Check if tenant exists
      final existingTenant = await _supabase
          .from('tenants')
          .select('tenant_id, tenant_fullname')
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (existingTenant == null) {
        return {
          'success': false,
          'message': 'ไม่พบผู้เช่าที่ต้องการลบ',
        };
      }

      // Check for active contracts
      final activeContracts = await _supabase
          .from('rental_contracts')
          .select('contract_id')
          .eq('tenant_id', tenantId)
          .inFilter('contract_status', ['active', 'pending']);

      if (activeContracts.isNotEmpty) {
        return {
          'success': false,
          'message':
              'ไม่สามารถลบผู้เช่าได้ เนื่องจากยังมีสัญญาเช่าที่ใช้งานอยู่ ${activeContracts.length} สัญญา',
        };
      }

      // Delete permanently
      await _supabase.from('tenants').delete().eq('tenant_id', tenantId);

      return {
        'success': true,
        'message':
            'ลบผู้เช่า "${existingTenant['tenant_fullname']}" ถาวรสำเร็จ',
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        message = 'ไม่พบผู้เช่าที่ต้องการลบ';
      } else if (e.code == '23503') {
        message = 'ไม่สามารถลบผู้เช่าได้ เนื่องจากยังมีข้อมูลที่เกี่ยวข้อง';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบผู้เช่า: $e',
      };
    }
  }

  /// Get branches for tenant filter
  static Future<List<Map<String, dynamic>>> getBranchesForTenantFilter() async {
    try {
      final currentUser = await AuthService.getCurrentUser();

      var query = _supabase
          .from('branches')
          .select('branch_id, branch_name, branch_code')
          .eq('is_active', true);

      // If user has specific branch, show only that branch
      if (currentUser != null && currentUser.branchId != null) {
        query = query.eq('branch_id', currentUser.branchId!);
      }

      final result = await query.order('branch_name');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
    }
  }

  /// Search tenants
  static Future<List<Map<String, dynamic>>> searchTenants(
      String searchQuery) async {
    try {
      if (searchQuery.trim().isEmpty) {
        return [];
      }

      final result = await _supabase
          .from('tenants')
          .select('*')
          .or('tenant_fullname.ilike.%$searchQuery%,'
              'tenant_idcard.ilike.%$searchQuery%,'
              'tenant_phone.ilike.%$searchQuery%')
          .eq('is_active', true)
          .order('tenant_fullname')
          .limit(20);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการค้นหาผู้เช่า: $e');
    }
  }

  /// Get tenant statistics
  static Future<Map<String, dynamic>> getTenantStatistics(
      String tenantId) async {
    try {
      final tenant = await getTenantById(tenantId);
      if (tenant == null) {
        return {};
      }

      // Get contract history
      final contractHistory = await _supabase
          .from('rental_contracts')
          .select('contract_id, contract_status, start_date, end_date')
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      // Get active contract
      final activeContract = await _supabase
          .from('rental_contracts')
          .select('''
            *,
            rooms!inner(room_number, branches!inner(branch_name))
          ''')
          .eq('tenant_id', tenantId)
          .eq('contract_status', 'active')
          .maybeSingle();

      // Get payment history
      final payments = await _supabase
          .from('payments')
          .select('payment_id, payment_amount, payment_date, payment_status')
          .eq('tenant_id', tenantId)
          .order('payment_date', ascending: false)
          .limit(10);

      // Get pending invoices
      final pendingInvoices = await _supabase
          .from('invoices')
          .select('invoice_id')
          .eq('tenant_id', tenantId)
          .inFilter('invoice_status', ['pending', 'overdue']);

      return {
        'total_contracts': contractHistory.length,
        'active_contract': activeContract,
        'current_room': activeContract != null
            ? activeContract['rooms']['room_number']
            : null,
        'current_branch': activeContract != null
            ? activeContract['rooms']['branches']['branch_name']
            : null,
        'recent_payments': payments,
        'pending_invoices_count': pendingInvoices.length,
      };
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสถิติผู้เช่า: $e');
    }
  }

  /// Get active tenants for room assignment
  static Future<List<Map<String, dynamic>>>
      getActiveTenantsForAssignment() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return [];
      }

      // Check permissions
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageTenants,
        DetailedPermission.manageContracts,
      ])) {
        return [];
      }

      final result = await _supabase
          .from('tenants')
          .select('tenant_id, tenant_fullname, tenant_phone')
          .eq('is_active', true)
          .order('tenant_fullname');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้เช่า: $e');
    }
  }

  /// Check if tenant has active contract
  static Future<bool> hasActiveContract(String tenantId) async {
    try {
      final activeContract = await _supabase
          .from('rental_contracts')
          .select('contract_id')
          .eq('tenant_id', tenantId)
          .eq('contract_status', 'active')
          .maybeSingle();

      return activeContract != null;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการตรวจสอบสัญญาเช่า: $e');
    }
  }
}
