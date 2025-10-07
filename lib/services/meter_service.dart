import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';
import '../models/user_models.dart';
import 'dart:io';

class MeterReadingService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// ดึงรายการบันทึกค่ามิเตอร์ทั้งหมด
  static Future<List<Map<String, dynamic>>> getAllMeterReadings({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    String? branchId,
    String? roomId,
    String? tenantId,
    String? status,
    int? readingMonth,
    int? readingYear,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      var query = _supabase.from('meter_readings').select('''
        *,
        rooms!inner(room_id, room_number, branch_id, 
          branches!inner(branch_name, branch_code)),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone),
        rental_contracts!inner(contract_id, contract_num)
      ''');

      // Add filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('reading_number.ilike.%$searchQuery%');
      }

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('rooms.branch_id', branchId);
      }

      if (roomId != null && roomId.isNotEmpty) {
        query = query.eq('room_id', roomId);
      }

      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }

      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.eq('reading_status', status);
      }

      if (readingMonth != null) {
        query = query.eq('reading_month', readingMonth);
      }

      if (readingYear != null) {
        query = query.eq('reading_year', readingYear);
      }

      // Add ordering and pagination
      final result = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result).map((reading) {
        return {
          ...reading,
          'tenant_name': reading['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': reading['tenants']?['tenant_phone'] ?? '-',
          'room_number': reading['rooms']?['room_number'] ?? '-',
          'branch_name': reading['rooms']?['branches']?['branch_name'] ?? '-',
          'contract_num': reading['rental_contracts']?['contract_num'] ?? '-',
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลค่ามิเตอร์: $e');
    }
  }

  /// ดึงข้อมูลค่ามิเตอร์ตาม ID
  static Future<Map<String, dynamic>?> getMeterReadingById(
      String readingId) async {
    try {
      final result = await _supabase.from('meter_readings').select('''
        *,
        rooms!inner(room_id, room_number, room_price, branch_id,
          branches!inner(branch_name, branch_code)),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone, tenant_idcard),
        rental_contracts!inner(contract_id, contract_num, contract_price)
      ''').eq('reading_id', readingId).maybeSingle();

      if (result != null) {
        return {
          ...result,
          'tenant_name': result['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': result['tenants']?['tenant_phone'] ?? '-',
          'room_number': result['rooms']?['room_number'] ?? '-',
          'branch_name': result['rooms']?['branches']?['branch_name'] ?? '-',
          'contract_num': result['rental_contracts']?['contract_num'] ?? '-',
        };
      }

      return null;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลค่ามิเตอร์: $e');
    }
  }

  /// ดึงค่ามิเตอร์ล่าสุดของห้อง (สำหรับใช้เป็นค่าก่อนหน้า)
  static Future<Map<String, dynamic>?> getLastMeterReading(
      String roomId) async {
    try {
      final result = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('reading_status', 'confirmed')
          .order('reading_year', ascending: false)
          .order('reading_month', ascending: false)
          .limit(1)
          .maybeSingle();

      return result;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดค่ามิเตอร์ล่าสุด: $e');
    }
  }

  /// ตรวจสอบว่ามีการบันทึกค่ามิเตอร์สำหรับเดือนและปีนี้แล้วหรือไม่
  static Future<bool> hasReadingForMonth(
      String roomId, int month, int year) async {
    try {
      final result = await _supabase
          .from('meter_readings')
          .select('reading_id')
          .eq('room_id', roomId)
          .eq('reading_month', month)
          .eq('reading_year', year)
          .limit(1);

      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// ดึงค่ามิเตอร์ตามสาขาและเดือน/ปี
  static Future<List<Map<String, dynamic>>> getMeterReadingsByBranchAndMonth(
    String branchId,
    int month,
    int year,
  ) async {
    try {
      final result = await _supabase
          .from('meter_readings')
          .select('''
        *,
        rooms!inner(room_id, room_number, branch_id),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone)
      ''')
          .eq('rooms.branch_id', branchId)
          .eq('reading_month', month)
          .eq('reading_year', year)
          .order('rooms.room_number');

      return List<Map<String, dynamic>>.from(result).map((reading) {
        return {
          ...reading,
          'tenant_name': reading['tenants']?['tenant_fullname'] ?? '-',
          'room_number': reading['rooms']?['room_number'] ?? '-',
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลค่ามิเตอร์: $e');
    }
  }

  // ============================================
  // CREATE OPERATION
  // ============================================

  /// สร้างบันทึกค่ามิเตอร์ใหม่
  static Future<Map<String, dynamic>> createMeterReading(
      Map<String, dynamic> readingData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // ตรวจสอบสิทธิ์
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageMeterReadings,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการบันทึกค่ามิเตอร์'
        };
      }

      // Validate required fields
      if (readingData['room_id'] == null || readingData['room_id'].isEmpty) {
        return {'success': false, 'message': 'กรุณาเลือกห้อง'};
      }

      if (readingData['tenant_id'] == null ||
          readingData['tenant_id'].isEmpty) {
        return {'success': false, 'message': 'กรุณาเลือกผู้เช่า'};
      }

      if (readingData['reading_month'] == null) {
        return {'success': false, 'message': 'กรุณาระบุเดือนที่บันทึก'};
      }

      if (readingData['reading_year'] == null) {
        return {'success': false, 'message': 'กรุณาระบุปีที่บันทึก'};
      }

      // ตรวจสอบว่ามีการบันทึกสำหรับเดือนนี้แล้วหรือไม่
      final hasExisting = await hasReadingForMonth(
        readingData['room_id'],
        readingData['reading_month'],
        readingData['reading_year'],
      );

      if (hasExisting) {
        return {
          'success': false,
          'message': 'มีการบันทึกค่ามิเตอร์สำหรับเดือนนี้แล้ว'
        };
      }

      // ดึงค่ามิเตอร์ก่อนหน้า
      final lastReading = await getLastMeterReading(readingData['room_id']);

      final waterPrevious = lastReading?['water_current_reading'] ?? 0.0;
      final electricPrevious = lastReading?['electric_current_reading'] ?? 0.0;

      final waterCurrent = readingData['water_current_reading'] ?? 0.0;
      final electricCurrent = readingData['electric_current_reading'] ?? 0.0;

      // คำนวณการใช้งาน
      final waterUsage = waterCurrent - waterPrevious;
      final electricUsage = electricCurrent - electricPrevious;

      // สร้างเลขที่บันทึก
      final readingNumber = await _generateReadingNumber();

      // เตรียมข้อมูลสำหรับบันทึก
      final insertData = {
        'reading_number': readingNumber,
        'room_id': readingData['room_id'],
        'tenant_id': readingData['tenant_id'],
        'contract_id': readingData['contract_id'],
        'reading_month': readingData['reading_month'],
        'reading_year': readingData['reading_year'],
        'water_previous_reading': waterPrevious,
        'water_current_reading': waterCurrent,
        'water_usage': waterUsage,
        'water_meter_image': readingData['water_meter_image'],
        'electric_previous_reading': electricPrevious,
        'electric_current_reading': electricCurrent,
        'electric_usage': electricUsage,
        'electric_meter_image': readingData['electric_meter_image'],
        'reading_status': 'draft',
        'reading_date': readingData['reading_date'] ??
            DateTime.now().toIso8601String().split('T')[0],
        'reading_notes': readingData['reading_notes'],
        'created_by': currentUser.userId,
      };

      final result = await _supabase
          .from('meter_readings')
          .insert(insertData)
          .select()
          .single();

      return {
        'success': true,
        'message': 'บันทึกค่ามิเตอร์สำเร็จ',
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
        'message': 'เกิดข้อผิดพลาดในการบันทึกค่ามิเตอร์: $e',
      };
    }
  }

  /// อัปโหลดรูปมิเตอร์
  static Future<Map<String, dynamic>> uploadMeterImage(
    File imageFile,
    String meterType, // 'water' หรือ 'electric'
    String roomNumber,
    int month,
    int year,
  ) async {
    try {
      // สร้างชื่อไฟล์ใหม่
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      final fileName =
          '${roomNumber}_${meterType}_${year}_${month.toString().padLeft(2, '0')}_$timestamp.$extension';

      // อัปโหลดไปยัง bucket meter-image
      final result = await ImageService.uploadImage(
        imageFile,
        'meter-image',
        folder: '$year/${month.toString().padLeft(2, '0')}',
        customFileName: fileName,
      );

      return result;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e');
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e',
      };
    }
  }

  // ============================================
  // UPDATE OPERATIONS
  // ============================================

  /// อัปเดตค่ามิเตอร์
  static Future<Map<String, dynamic>> updateMeterReading(
    String readingId,
    Map<String, dynamic> readingData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // ตรวจสอบสิทธิ์
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageMeterReadings,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการแก้ไขค่ามิเตอร์'};
      }

      // ตรวจสอบสถานะ - ไม่ให้แก้ไขถ้า confirmed แล้ว
      final existing = await getMeterReadingById(readingId);
      if (existing == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลค่ามิเตอร์'};
      }

      if (existing['reading_status'] == 'confirmed') {
        return {
          'success': false,
          'message': 'ไม่สามารถแก้ไขค่ามิเตอร์ที่ยืนยันแล้ว'
        };
      }

      // คำนวณการใช้งานใหม่
      final waterUsage = (readingData['water_current_reading'] ??
              existing['water_current_reading']) -
          existing['water_previous_reading'];
      final electricUsage = (readingData['electric_current_reading'] ??
              existing['electric_current_reading']) -
          existing['electric_previous_reading'];

      // เตรียมข้อมูลสำหรับอัปเดต
      final updateData = {
        'water_current_reading': readingData['water_current_reading'],
        'water_usage': waterUsage,
        'water_meter_image': readingData['water_meter_image'],
        'electric_current_reading': readingData['electric_current_reading'],
        'electric_usage': electricUsage,
        'electric_meter_image': readingData['electric_meter_image'],
        'reading_date': readingData['reading_date'],
        'reading_notes': readingData['reading_notes'],
      };

      // ลบค่า null ออก
      updateData.removeWhere((key, value) => value == null);

      final result = await _supabase
          .from('meter_readings')
          .update(updateData)
          .eq('reading_id', readingId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'อัปเดตค่ามิเตอร์สำเร็จ',
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
        'message': 'เกิดข้อผิดพลาดในการอัปเดตค่ามิเตอร์: $e',
      };
    }
  }

  /// ยืนยันค่ามิเตอร์
  static Future<Map<String, dynamic>> confirmMeterReading(
      String readingId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageMeterReadings,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการยืนยันค่ามิเตอร์'
        };
      }

      await _supabase.from('meter_readings').update({
        'reading_status': 'confirmed',
        'confirmed_by': currentUser.userId,
        'confirmed_at': DateTime.now().toIso8601String(),
      }).eq('reading_id', readingId);

      return {
        'success': true,
        'message': 'ยืนยันค่ามิเตอร์สำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการยืนยันค่ามิเตอร์: $e',
      };
    }
  }

  /// ยกเลิกค่ามิเตอร์
  static Future<Map<String, dynamic>> cancelMeterReading(
      String readingId, String reason) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageMeterReadings,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการยกเลิกค่ามิเตอร์'
        };
      }

      await _supabase.from('meter_readings').update({
        'reading_status': 'cancelled',
        'reading_notes': reason,
      }).eq('reading_id', readingId);

      return {
        'success': true,
        'message': 'ยกเลิกค่ามิเตอร์สำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการยกเลิกค่ามิเตอร์: $e',
      };
    }
  }

  // ============================================
  // DELETE OPERATION
  // ============================================

  /// ลบค่ามิเตอร์ (เฉพาะ draft)
  static Future<Map<String, dynamic>> deleteMeterReading(
      String readingId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการลบค่ามิเตอร์'};
      }

      // ตรวจสอบสถานะ
      final existing = await getMeterReadingById(readingId);
      if (existing == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลค่ามิเตอร์'};
      }

      if (existing['reading_status'] == 'confirmed') {
        return {
          'success': false,
          'message': 'ไม่สามารถลบค่ามิเตอร์ที่ยืนยันแล้ว'
        };
      }

      if (existing['reading_status'] == 'billed') {
        return {
          'success': false,
          'message': 'ไม่สามารถลบค่ามิเตอร์ที่ออกบิลแล้ว'
        };
      }

      // ลบรูปภาพจาก storage
      if (existing['water_meter_image'] != null) {
        await ImageService.deleteImage(existing['water_meter_image']);
      }
      if (existing['electric_meter_image'] != null) {
        await ImageService.deleteImage(existing['electric_meter_image']);
      }

      // ลบข้อมูล
      await _supabase
          .from('meter_readings')
          .delete()
          .eq('reading_id', readingId);

      return {
        'success': true,
        'message': 'ลบค่ามิเตอร์สำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบค่ามิเตอร์: $e',
      };
    }
  }

  // ============================================
  // UTILITY FUNCTIONS
  // ============================================

  /// สร้างเลขที่บันทึกอัตโนมัติ
  static Future<String> _generateReadingNumber() async {
    final now = DateTime.now();
    final prefix = 'MR${now.year}${now.month.toString().padLeft(2, '0')}';

    // หาเลขที่สุดท้าย
    final lastReading = await _supabase
        .from('meter_readings')
        .select('reading_number')
        .like('reading_number', '$prefix%')
        .order('reading_number', ascending: false)
        .limit(1)
        .maybeSingle();

    int nextNumber = 1;
    if (lastReading != null) {
      final lastNum = lastReading['reading_number'].toString();
      final numPart = lastNum.substring(prefix.length);
      nextNumber = (int.tryParse(numPart) ?? 0) + 1;
    }

    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }

  /// ดึงห้องที่มีสัญญาเช่าใช้งานอยู่
  static Future<List<Map<String, dynamic>>> getActiveRoomsForMeterReading({
    String? branchId,
  }) async {
    try {
      var query = _supabase.from('rental_contracts').select('''
        contract_id,
        rooms!inner(room_id, room_number, branch_id,
          branches!inner(branch_name)),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone)
      ''').eq('contract_status', 'active');

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('rooms.branch_id', branchId);
      }

      final result = await query;

      // เรียงลำดับหลังจากได้ข้อมูลแล้ว
      final sortedResult = List<Map<String, dynamic>>.from(result);
      sortedResult.sort((a, b) {
        final roomNumberA = a['rooms']?['room_number']?.toString() ?? '';
        final roomNumberB = b['rooms']?['room_number']?.toString() ?? '';
        return roomNumberA.compareTo(roomNumberB);
      });

      return sortedResult.map((contract) {
        return {
          'contract_id': contract['contract_id'],
          'room_id': contract['rooms']['room_id'],
          'room_number': contract['rooms']['room_number'],
          'branch_name': contract['rooms']['branches']['branch_name'],
          'tenant_id': contract['tenants']['tenant_id'],
          'tenant_name': contract['tenants']['tenant_fullname'],
          'tenant_phone': contract['tenants']['tenant_phone'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดห้องที่ใช้งาน: $e');
    }
  }

  /// ดึงสถิติค่ามิเตอร์
  static Future<Map<String, dynamic>> getMeterReadingStats({
    String? branchId,
    int? month,
    int? year,
  }) async {
    try {
      var query = _supabase.from('meter_readings').select('reading_status');

      if (branchId != null) {
        query = _supabase.from('meter_readings').select('''
          reading_status,
          rooms!inner(branch_id)
        ''').eq('rooms.branch_id', branchId);
      }

      if (month != null) {
        query = query.eq('reading_month', month);
      }

      if (year != null) {
        query = query.eq('reading_year', year);
      }

      final result = await query;

      final total = result.length;
      final draft = result.where((r) => r['reading_status'] == 'draft').length;
      final confirmed =
          result.where((r) => r['reading_status'] == 'confirmed').length;
      final billed =
          result.where((r) => r['reading_status'] == 'billed').length;
      final cancelled =
          result.where((r) => r['reading_status'] == 'cancelled').length;

      return {
        'total': total,
        'draft': draft,
        'confirmed': confirmed,
        'billed': billed,
        'cancelled': cancelled,
      };
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสถิติ: $e');
    }
  }

  /// ตรวจสอบว่าค่ามิเตอร์ปัจจุบันมากกว่าค่าก่อนหน้าหรือไม่
  static bool validateMeterReading({
    required double previousReading,
    required double currentReading,
  }) {
    return currentReading >= previousReading;
  }
}
