import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

class ContractService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// ดึงสัญญาทั้งหมด
  static Future<List<Map<String, dynamic>>> getAllContracts({
    String? tenantId,
    String? roomId,
    String? branchId,
    String? status,
    int offset = 0,
    int limit = 100,
  }) async {
    try {
      var query = _supabase.from('rental_contracts').select('''
        *,
        tenants!inner(tenant_id, tenant_fullname, tenant_phone, tenant_idcard),
        rooms!inner(room_id, room_number, branch_id, branches!inner(branch_name))
      ''');

      // กรองตามผู้เช่า
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }

      // กรองตามห้อง
      if (roomId != null && roomId.isNotEmpty) {
        query = query.eq('room_id', roomId);
      }

      // กรองตามสาขา
      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('rooms.branch_id', branchId);
      }

      // กรองตามสถานะ
      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.eq('contract_status', status);
      }

      final result = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result).map((contract) {
        return {
          ...contract,
          'tenant_name': contract['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': contract['tenants']?['tenant_phone'] ?? '-',
          'room_number': contract['rooms']?['room_number'] ?? '-',
          'branch_name': contract['rooms']?['branches']?['branch_name'] ?? '-',
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลสัญญา: $e');
    }
  }

  /// ดึงข้อมูลสัญญาตาม ID
  static Future<Map<String, dynamic>?> getContractById(
      String contractId) async {
    try {
      final result = await _supabase.from('rental_contracts').select('''
        *,
        tenants!inner(tenant_id, tenant_fullname, tenant_phone, tenant_idcard, gender),
        rooms!inner(room_id, room_number, room_price, room_deposit, branch_id, 
          branches!inner(branch_name, branch_code))
      ''').eq('contract_id', contractId).maybeSingle();

      if (result != null) {
        return {
          ...result,
          'tenant_name': result['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': result['tenants']?['tenant_phone'] ?? '-',
          'room_number': result['rooms']?['room_number'] ?? '-',
          'branch_name': result['rooms']?['branches']?['branch_name'] ?? '-',
        };
      }

      return null;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลสัญญา: $e');
    }
  }

  /// สร้างสัญญาใหม่
  static Future<Map<String, dynamic>> createContract(
      Map<String, dynamic> contractData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // ตรวจสอบสิทธิ์
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageContracts,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการสร้างสัญญา'};
      }

      // ตรวจสอบว่าห้องยังว่างอยู่หรือไม่
      final room = await _supabase
          .from('rooms')
          .select('room_id, room_status')
          .eq('room_id', contractData['room_id'])
          .maybeSingle();

      if (room == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลห้อง'};
      }

      if (room['room_status'] != 'available') {
        return {'success': false, 'message': 'ห้องนี้ไม่ว่างแล้ว'};
      }

      // ตรวจสอบว่าผู้เช่ามีสัญญาที่ active อยู่หรือไม่
      final existingContract = await _supabase
          .from('rental_contracts')
          .select('contract_id')
          .eq('tenant_id', contractData['tenant_id'])
          .eq('contract_status', 'active')
          .maybeSingle();

      if (existingContract != null) {
        return {
          'success': false,
          'message': 'ผู้เช่ารายนี้มีสัญญาที่ใช้งานอยู่แล้ว'
        };
      }

      // สร้างเลขที่สัญญา
      final contractNum = await _generateContractNumber();

      // เตรียมข้อมูลสำหรับบันทึก
      final insertData = {
        'contract_num': contractNum,
        'tenant_id': contractData['tenant_id'],
        'room_id': contractData['room_id'],
        'start_date': contractData['start_date'],
        'end_date': contractData['end_date'],
        'contract_price': contractData['contract_price'],
        'contract_deposit': contractData['contract_deposit'],
        'payment_day': contractData['payment_day'],
        'contract_note': contractData['contract_note'],
        'contract_status': 'pending', // เริ่มต้นเป็น pending
        'created_by': currentUser.userId,
      };

      // บันทึกสัญญา
      final result = await _supabase
          .from('rental_contracts')
          .insert(insertData)
          .select()
          .single();

      // อัปเดตสถานะห้องเป็น reserved
      await _supabase.from('rooms').update({'room_status': 'reserved'}).eq(
          'room_id', contractData['room_id']);

      return {
        'success': true,
        'message': 'สร้างสัญญาสำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการสร้างสัญญา: $e',
      };
    }
  }

  /// อัปเดตสัญญา
  static Future<Map<String, dynamic>> updateContract(
    String contractId,
    Map<String, dynamic> contractData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // ตรวจสอบสิทธิ์
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageContracts,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการแก้ไขสัญญา'};
      }

      // เตรียมข้อมูลสำหรับอัปเดต
      final updateData = {
        'start_date': contractData['start_date'],
        'end_date': contractData['end_date'],
        'contract_price': contractData['contract_price'],
        'contract_deposit': contractData['contract_deposit'],
        'payment_day': contractData['payment_day'],
        'contract_note': contractData['contract_note'],
      };

      // ลบค่า null ออก
      updateData.removeWhere((key, value) => value == null);

      final result = await _supabase
          .from('rental_contracts')
          .update(updateData)
          .eq('contract_id', contractId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'อัปเดตสัญญาสำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตสัญญา: $e',
      };
    }
  }

  /// เปิดใช้งานสัญญา (Activate)
  static Future<Map<String, dynamic>> activateContract(
      String contractId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageContracts,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการเปิดใช้งานสัญญา'};
      }

      // ดึงข้อมูลสัญญา
      final contract = await _supabase
          .from('rental_contracts')
          .select('contract_id, room_id, contract_status')
          .eq('contract_id', contractId)
          .maybeSingle();

      if (contract == null) {
        return {'success': false, 'message': 'ไม่พบสัญญาที่ต้องการ'};
      }

      if (contract['contract_status'] == 'active') {
        return {'success': false, 'message': 'สัญญานี้เปิดใช้งานอยู่แล้ว'};
      }

      // อัปเดตสถานะสัญญาเป็น active
      await _supabase
          .from('rental_contracts')
          .update({'contract_status': 'active'}).eq('contract_id', contractId);

      // อัปเดตสถานะห้องเป็น occupied
      await _supabase.from('rooms').update({'room_status': 'occupied'}).eq(
          'room_id', contract['room_id']);

      return {
        'success': true,
        'message': 'เปิดใช้งานสัญญาสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  /// ยกเลิกสัญญา (Terminate)
  static Future<Map<String, dynamic>> terminateContract(
    String contractId,
    String reason,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageContracts,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการยกเลิกสัญญา'};
      }

      // ดึงข้อมูลสัญญา
      final contract = await _supabase
          .from('rental_contracts')
          .select('contract_id, room_id')
          .eq('contract_id', contractId)
          .maybeSingle();

      if (contract == null) {
        return {'success': false, 'message': 'ไม่พบสัญญาที่ต้องการ'};
      }

      // อัปเดตสถานะสัญญาเป็น terminated
      await _supabase.from('rental_contracts').update({
        'contract_status': 'terminated',
        'contract_note': reason,
      }).eq('contract_id', contractId);

      // อัปเดตสถานะห้องกลับเป็น available
      await _supabase.from('rooms').update({'room_status': 'available'}).eq(
          'room_id', contract['room_id']);

      return {
        'success': true,
        'message': 'ยกเลิกสัญญาสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  /// ต่ออายุสัญญา
  static Future<Map<String, dynamic>> renewContract(
    String contractId,
    DateTime newEndDate,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageContracts,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการต่อสัญญา'};
      }

      await _supabase.from('rental_contracts').update({
        'end_date': newEndDate.toIso8601String().split('T')[0],
        'contract_status': 'active',
      }).eq('contract_id', contractId);

      return {
        'success': true,
        'message': 'ต่อสัญญาสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  /// สร้างเลขที่สัญญาอัตโนมัติ
  static Future<String> _generateContractNumber() async {
    final now = DateTime.now();
    final prefix = 'CT${now.year}${now.month.toString().padLeft(2, '0')}';

    // หาเลขที่สุดท้าย
    final lastContract = await _supabase
        .from('rental_contracts')
        .select('contract_num')
        .like('contract_num', '$prefix%')
        .order('contract_num', ascending: false)
        .limit(1)
        .maybeSingle();

    int nextNumber = 1;
    if (lastContract != null) {
      final lastNum = lastContract['contract_num'].toString();
      final numPart = lastNum.substring(prefix.length);
      nextNumber = (int.tryParse(numPart) ?? 0) + 1;
    }

    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }
}
