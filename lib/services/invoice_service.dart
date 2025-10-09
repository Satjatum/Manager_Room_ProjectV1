import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'package:manager_room_project/services/meter_service.dart';
import '../models/user_models.dart';

class InvoiceService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// ดึงรายการใบแจ้งหนี้ทั้งหมด
  static Future<List<Map<String, dynamic>>> getAllInvoices({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    String? branchId,
    String? roomId,
    String? tenantId,
    String? status,
    int? invoiceMonth,
    int? invoiceYear,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      var query = _supabase.from('invoices').select('''
        *,
        rooms!inner(room_id, room_number, branch_id,
          branches!inner(branch_name, branch_code)),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone),
        rental_contracts!inner(contract_id, contract_num)
      ''');

      // Add filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('invoice_number.ilike.%$searchQuery%');
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
        query = query.eq('invoice_status', status);
      }

      if (invoiceMonth != null) {
        query = query.eq('invoice_month', invoiceMonth);
      }

      if (invoiceYear != null) {
        query = query.eq('invoice_year', invoiceYear);
      }

      // Add ordering and pagination
      final result = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result).map((invoice) {
        return {
          ...invoice,
          'tenant_name': invoice['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': invoice['tenants']?['tenant_phone'] ?? '-',
          'room_number': invoice['rooms']?['room_number'] ?? '-',
          'branch_name': invoice['rooms']?['branches']?['branch_name'] ?? '-',
          'contract_num': invoice['rental_contracts']?['contract_num'] ?? '-',
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลใบแจ้งหนี้: $e');
    }
  }

  /// ดึงข้อมูลใบแจ้งหนี้ตาม ID
  static Future<Map<String, dynamic>?> getInvoiceById(String invoiceId) async {
    try {
      final result = await _supabase.from('invoices').select('''
        *,
        rooms!inner(room_id, room_number, room_price, branch_id,
          branches!inner(branch_name, branch_code)),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone, tenant_idcard),
        rental_contracts!inner(contract_id, contract_num, contract_price)
      ''').eq('invoice_id', invoiceId).maybeSingle();

      if (result != null) {
        // ดึงรายละเอียดค่าสาธารณูปโภค
        final utilities = await _supabase
            .from('invoice_utilities')
            .select('*')
            .eq('invoice_id', invoiceId);

        // ดึงค่าใช้จ่ายอื่นๆ
        final otherCharges = await _supabase
            .from('invoice_other_charges')
            .select('*')
            .eq('invoice_id', invoiceId);

        // ดึงประวัติการชำระเงิน
        final payments = await _supabase
            .from('payments')
            .select('*')
            .eq('invoice_id', invoiceId)
            .order('payment_date', ascending: false);

        return {
          ...result,
          'tenant_name': result['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': result['tenants']?['tenant_phone'] ?? '-',
          'tenant_idcard': result['tenants']?['tenant_idcard'] ?? '-',
          'room_number': result['rooms']?['room_number'] ?? '-',
          'room_price': result['rooms']?['room_price'] ?? 0,
          'branch_name': result['rooms']?['branches']?['branch_name'] ?? '-',
          'contract_num': result['rental_contracts']?['contract_num'] ?? '-',
          'utilities': utilities,
          'other_charges': otherCharges,
          'payments': payments,
        };
      }

      return null;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลใบแจ้งหนี้: $e');
    }
  }

  /// ดึงใบแจ้งหนี้ล่าสุดของห้อง
  static Future<Map<String, dynamic>?> getLatestInvoiceByRoom(
      String roomId) async {
    try {
      final result = await _supabase
          .from('invoices')
          .select('*')
          .eq('room_id', roomId)
          .order('invoice_year', ascending: false)
          .order('invoice_month', ascending: false)
          .limit(1)
          .maybeSingle();

      return result;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลใบแจ้งหนี้ล่าสุด: $e');
    }
  }

  /// ตรวจสอบว่ามีใบแจ้งหนี้สำหรับเดือนและปีนี้แล้วหรือไม่
  static Future<bool> hasInvoiceForMonth(
      String roomId, int month, int year) async {
    try {
      final result = await _supabase
          .from('invoices')
          .select('invoice_id')
          .eq('room_id', roomId)
          .eq('invoice_month', month)
          .eq('invoice_year', year)
          .limit(1);

      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // CREATE OPERATION
  // ============================================

  /// สร้างใบแจ้งหนี้ใหม่ (แบบ Manual)
  static Future<Map<String, dynamic>> createInvoice(
      Map<String, dynamic> invoiceData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // ตรวจสอบสิทธิ์
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageInvoices,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการสร้างใบแจ้งหนี้'};
      }

      // Validate required fields
      if (invoiceData['room_id'] == null || invoiceData['room_id'].isEmpty) {
        return {'success': false, 'message': 'กรุณาเลือกห้อง'};
      }

      if (invoiceData['tenant_id'] == null ||
          invoiceData['tenant_id'].isEmpty) {
        return {'success': false, 'message': 'กรุณาเลือกผู้เช่า'};
      }

      if (invoiceData['invoice_month'] == null) {
        return {'success': false, 'message': 'กรุณาระบุเดือนที่แจ้งหนี้'};
      }

      if (invoiceData['invoice_year'] == null) {
        return {'success': false, 'message': 'กรุณาระบุปีที่แจ้งหนี้'};
      }

      // ตรวจสอบว่ามีบิลสำหรับเดือนนี้แล้วหรือไม่
      final hasExisting = await hasInvoiceForMonth(
        invoiceData['room_id'],
        invoiceData['invoice_month'],
        invoiceData['invoice_year'],
      );

      if (hasExisting) {
        return {'success': false, 'message': 'มีใบแจ้งหนี้สำหรับเดือนนี้แล้ว'};
      }

      // สร้างเลขที่บิล
      final invoiceNumber = await _generateInvoiceNumber();

      // คำนวณยอดรวมจากข้อมูลที่ส่งมา
      final roomRent = invoiceData["room_rent"] ?? 0.0;
      final waterCost = invoiceData["water_cost"] ?? 0.0;
      final electricCost = invoiceData["electric_cost"] ?? 0.0;
      final otherExpenses = invoiceData["other_expenses"] ?? 0.0;
      final discount = invoiceData["discount"] ?? 0.0;

      final subTotal = roomRent + waterCost + electricCost + otherExpenses;
      final grandTotal = subTotal - discount;

      // เตรียมข้อมูลสำหรับบันทึก
      final insertData = {
        "invoice_number": invoiceNumber,
        "contract_id": invoiceData["contract_id"],
        "room_id": invoiceData["room_id"],
        "tenant_id": invoiceData["tenant_id"],
        "meter_reading_id":
            invoiceData["meter_reading_id"], // Link to meter reading
        "invoice_month": invoiceData["invoice_month"],
        "invoice_year": invoiceData["invoice_year"],
        "invoice_date": invoiceData["invoice_date"],
        "due_date": invoiceData["due_date"],
        "room_rent": roomRent,
        "water_usage": invoiceData["water_usage"],
        "water_rate": invoiceData["water_rate"],
        "water_cost": waterCost,
        "electric_usage": invoiceData["electric_usage"],
        "electric_rate": invoiceData["electric_rate"],
        "electric_cost": electricCost,
        "other_expenses": otherExpenses,
        "discount": discount,
        "sub_total": subTotal,
        "grand_total": grandTotal,
        "invoice_notes": invoiceData["notes"],
        "invoice_status": "pending",
        "paid_amount": 0.0,
        "created_by": currentUser.userId,
      };

      final result =
          await _supabase.from('invoices').insert(insertData).select().single();

      return {
        'success': true,
        'message': 'สร้างใบแจ้งหนี้สำเร็จ',
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
        'message': 'เกิดข้อผิดพลาดในการสร้างใบแจ้งหนี้: $e',
      };
    }
  }

  /// ออกบิลจากค่ามิเตอร์
  static Future<Map<String, dynamic>> generateInvoiceFromReading(
      String readingId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // ตรวจสอบสิทธิ์
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageInvoices,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการออกบิล'};
      }

      // เรียกใช้ Supabase RPC function เพื่อออกบิล
      final response = await _supabase.rpc(
          'generate_invoice_from_meter_reading',
          params: {'p_reading_id': readingId});

      if (response == null) {
        return {
          'success': false,
          'message': 'ไม่สามารถออกบิลได้ กรุณาตรวจสอบการตั้งค่าอัตราค่าน้ำ-ไฟ'
        };
      }

      return {
        'success': true,
        'invoice_id': response['invoice_id'],
        'invoice_number': response['invoice_number'],
        'message': 'ออกบิลสำเร็จ'
      };
    } on PostgrestException catch (e) {
      String errorMessage = 'เกิดข้อผิดพลาดในการออกบิล';

      if (e.code == 'P0001') {
        errorMessage = e.message;
      } else if (e.code == '23505') {
        errorMessage = 'มีบิลสำหรับเดือนนี้แล้ว';
      } else if (e.code == '23503') {
        errorMessage = 'ไม่พบข้อมูลที่เกี่ยวข้อง';
      }

      return {
        'success': false,
        'message': errorMessage,
        'error_code': e.code,
      };
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.toString()}'};
    }
  }

  // ============================================
  // UPDATE OPERATIONS
  // ============================================

  /// อัปเดตใบแจ้งหนี้
  static Future<Map<String, dynamic>> updateInvoice(
    String invoiceId,
    Map<String, dynamic> invoiceData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageInvoices,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการแก้ไขใบแจ้งหนี้'};
      }

      // ตรวจสอบสถานะ
      final existing = await getInvoiceById(invoiceId);
      if (existing == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลใบแจ้งหนี้'};
      }

      // ไม่ให้แก้ไขถ้าชำระเงินแล้ว
      if (existing['invoice_status'] == 'paid') {
        return {
          'success': false,
          'message': 'ไม่สามารถแก้ไขใบแจ้งหนี้ที่ชำระเงินแล้ว'
        };
      }

      // คำนวณยอดรวมใหม่
      final rentalAmount =
          invoiceData['rental_amount'] ?? existing['rental_amount'];
      final utilitiesAmount =
          invoiceData['utilities_amount'] ?? existing['utilities_amount'];
      final otherCharges =
          invoiceData['other_charges'] ?? existing['other_charges'];
      final discountAmount =
          invoiceData['discount_amount'] ?? existing['discount_amount'];
      final lateFeeAmount =
          invoiceData['late_fee_amount'] ?? existing['late_fee_amount'];

      final subtotal = rentalAmount + utilitiesAmount + otherCharges;
      final totalAmount = subtotal - discountAmount + lateFeeAmount;

      Map<String, dynamic> updateData = {
        'rental_amount': rentalAmount,
        'utilities_amount': utilitiesAmount,
        'other_charges': otherCharges,
        'discount_type': invoiceData['discount_type'],
        'discount_amount': discountAmount,
        'discount_reason': invoiceData['discount_reason'],
        'late_fee_amount': lateFeeAmount,
        'late_fee_days': invoiceData['late_fee_days'],
        'subtotal': subtotal,
        'total_amount': totalAmount,
        'due_date': invoiceData['due_date'],
        'invoice_notes': invoiceData['invoice_notes'],
      };

      updateData.removeWhere((key, value) => value == null);

      final result = await _supabase
          .from('invoices')
          .update(updateData)
          .eq('invoice_id', invoiceId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'อัปเดตใบแจ้งหนี้สำเร็จ',
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
        'message': 'เกิดข้อผิดพลาดในการอัปเดตใบแจ้งหนี้: $e',
      };
    }
  }

  /// ยกเลิกใบแจ้งหนี้
  static Future<Map<String, dynamic>> cancelInvoice(
      String invoiceId, String reason) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageInvoices,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการยกเลิกใบแจ้งหนี้'
        };
      }

      // ตรวจสอบสถานะ
      final existing = await getInvoiceById(invoiceId);
      if (existing == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลใบแจ้งหนี้'};
      }

      if (existing['invoice_status'] == 'paid') {
        return {
          'success': false,
          'message': 'ไม่สามารถยกเลิกใบแจ้งหนี้ที่ชำระเงินแล้ว'
        };
      }

      await _supabase.from('invoices').update({
        'invoice_status': 'cancelled',
        'invoice_notes': reason,
      }).eq('invoice_id', invoiceId);

      return {
        'success': true,
        'message': 'ยกเลิกใบแจ้งหนี้สำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการยกเลิกใบแจ้งหนี้: $e',
      };
    }
  }

  /// อัปเดตสถานะใบแจ้งหนี้เมื่อมีการชำระเงิน
  static Future<Map<String, dynamic>> updateInvoicePaymentStatus(
    String invoiceId,
    double paymentAmount,
  ) async {
    try {
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลใบแจ้งหนี้'};
      }

      final currentPaid = invoice['paid_amount'] ?? 0.0;
      final totalAmount = invoice['total_amount'] ?? 0.0;
      final newPaidAmount = currentPaid + paymentAmount;

      String newStatus;
      DateTime? paidDate;

      if (newPaidAmount >= totalAmount) {
        newStatus = 'paid';
        paidDate = DateTime.now();
      } else if (newPaidAmount > 0) {
        newStatus = 'partial';
      } else {
        newStatus = 'pending';
      }

      await _supabase.from('invoices').update({
        'paid_amount': newPaidAmount,
        'invoice_status': newStatus,
        'paid_date': paidDate?.toIso8601String(),
      }).eq('invoice_id', invoiceId);

      return {
        'success': true,
        'message': 'อัปเดตสถานะการชำระเงินสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตสถานะ: $e',
      };
    }
  }

  // ============================================
  // DELETE OPERATION
  // ============================================

  /// ลบใบแจ้งหนี้
  static Future<Map<String, dynamic>> deleteInvoice(String invoiceId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการลบใบแจ้งหนี้'};
      }

      final existing = await getInvoiceById(invoiceId);
      if (existing == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลใบแจ้งหนี้'};
      }

      // ไม่ให้ลบถ้าชำระเงินแล้ว
      if (existing['invoice_status'] == 'paid') {
        return {
          'success': false,
          'message': 'ไม่สามารถลบใบแจ้งหนี้ที่ชำระเงินแล้ว'
        };
      }

      // ลบรายละเอียดต่างๆ ก่อน
      await _supabase
          .from('invoice_utilities')
          .delete()
          .eq('invoice_id', invoiceId);

      await _supabase
          .from('invoice_other_charges')
          .delete()
          .eq('invoice_id', invoiceId);

      // ลบบิล
      await _supabase.from('invoices').delete().eq('invoice_id', invoiceId);

      return {
        'success': true,
        'message': 'ลบใบแจ้งหนี้สำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบใบแจ้งหนี้: $e',
      };
    }
  }

  // ============================================
  // UTILITY FUNCTIONS
  // ============================================

  /// สร้างเลขที่บิลอัตโนมัติ
  static Future<String> _generateInvoiceNumber() async {
    final now = DateTime.now();
    final prefix = 'INV${now.year}${now.month.toString().padLeft(2, '0')}';

    final lastInvoice = await _supabase
        .from('invoices')
        .select('invoice_number')
        .like('invoice_number', '$prefix%')
        .order('invoice_number', ascending: false)
        .limit(1)
        .maybeSingle();

    int nextNumber = 1;
    if (lastInvoice != null) {
      final lastNum = lastInvoice['invoice_number'].toString();
      final numPart = lastNum.substring(prefix.length);
      nextNumber = (int.tryParse(numPart) ?? 0) + 1;
    }

    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }

  /// ดึงสถิติใบแจ้งหนี้
  static Future<Map<String, dynamic>> getInvoiceStats({
    String? branchId,
    int? month,
    int? year,
  }) async {
    try {
      var query = _supabase.from('invoices').select('invoice_status');

      if (branchId != null) {
        query = _supabase.from('invoices').select('''
          invoice_status,
          rooms!inner(branch_id)
        ''').eq('rooms.branch_id', branchId);
      }

      if (month != null) {
        query = query.eq('invoice_month', month);
      }

      if (year != null) {
        query = query.eq('invoice_year', year);
      }

      final result = await query;

      final total = result.length;
      final pending =
          result.where((r) => r['invoice_status'] == 'pending').length;
      final partial =
          result.where((r) => r['invoice_status'] == 'partial').length;
      final paid = result.where((r) => r['invoice_status'] == 'paid').length;
      final overdue =
          result.where((r) => r['invoice_status'] == 'overdue').length;
      final cancelled =
          result.where((r) => r['invoice_status'] == 'cancelled').length;

      // คำนวณยอดเงิน
      final invoices = await _supabase
          .from('invoices')
          .select('total_amount, paid_amount, invoice_status');

      double totalRevenue = 0;
      double collectedAmount = 0;
      double pendingAmount = 0;

      for (var invoice in invoices) {
        final total = invoice['total_amount'] ?? 0.0;
        final paid = invoice['paid_amount'] ?? 0.0;

        totalRevenue += total;
        collectedAmount += paid;

        if (invoice['invoice_status'] != 'paid' &&
            invoice['invoice_status'] != 'cancelled') {
          pendingAmount += (total - paid);
        }
      }

      return {
        'total': total,
        'pending': pending,
        'partial': partial,
        'paid': paid,
        'overdue': overdue,
        'cancelled': cancelled,
        'total_revenue': totalRevenue,
        'collected_amount': collectedAmount,
        'pending_amount': pendingAmount,
      };
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสถิติ: $e');
    }
  }

  /// ตรวจสอบและอัปเดตสถานะค้างชำระ
  static Future<void> updateOverdueInvoices() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      await _supabase
          .from('invoices')
          .update({'invoice_status': 'overdue'})
          .lt('due_date', today)
          .neq('invoice_status', 'paid')
          .neq('invoice_status', 'cancelled');
    } catch (e) {
      print('Error updating overdue invoices: $e');
    }
  }

  /// คำนวณค่าปรับล่าช้า
  static double calculateLateFee({
    required DateTime dueDate,
    required double totalAmount,
    String lateFeeType = 'fixed',
    double lateFeeAmount = 0,
    int startDay = 1,
    double? maxAmount,
  }) {
    final today = DateTime.now();
    final daysLate = today.difference(dueDate).inDays;

    if (daysLate < startDay) {
      return 0;
    }

    double calculatedFee = 0;

    switch (lateFeeType) {
      case 'fixed':
        calculatedFee = lateFeeAmount;
        break;
      case 'percentage':
        calculatedFee = totalAmount * (lateFeeAmount / 100);
        break;
      case 'daily':
        calculatedFee = lateFeeAmount * daysLate;
        break;
    }

    if (maxAmount != null && calculatedFee > maxAmount) {
      calculatedFee = maxAmount;
    }

    return calculatedFee;
  }

  /// ส่งการแจ้งเตือนใบแจ้งหนี้ (สำหรับอนาคต - ต่อกับระบบแจ้งเตือน)
  static Future<Map<String, dynamic>> sendInvoiceNotification(
      String invoiceId) async {
    try {
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลใบแจ้งหนี้'};
      }

      // TODO: ส่ง SMS, Email, หรือ Line Notify
      // ตัวอย่าง: await sendSMS(invoice['tenant_phone'], message);

      return {
        'success': true,
        'message': 'ส่งการแจ้งเตือนสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการส่งการแจ้งเตือน: $e',
      };
    }
  }

  /// ดึงรายการใบแจ้งหนี้ที่ใกล้ครบกำหนด
  static Future<List<Map<String, dynamic>>> getUpcomingDueInvoices({
    int daysBeforeDue = 3,
    String? branchId,
  }) async {
    try {
      final targetDate = DateTime.now()
          .add(Duration(days: daysBeforeDue))
          .toIso8601String()
          .split('T')[0];

      var query = _supabase
          .from('invoices')
          .select('''
        *,
        rooms!inner(room_id, room_number, branch_id,
          branches!inner(branch_name)),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone)
      ''')
          .lte('due_date', targetDate)
          .or('invoice_status.eq.pending,invoice_status.eq.partial');

      if (branchId != null) {
        query = query.eq('rooms.branch_id', branchId);
      }

      final result = await query.order('due_date', ascending: true);

      return List<Map<String, dynamic>>.from(result).map((invoice) {
        return {
          ...invoice,
          'tenant_name': invoice['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': invoice['tenants']?['tenant_phone'] ?? '-',
          'room_number': invoice['rooms']?['room_number'] ?? '-',
          'branch_name': invoice['rooms']?['branches']?['branch_name'] ?? '-',
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    }
  }

  /// ดึงรายการใบแจ้งหนี้ที่ค้างชำระ
  static Future<List<Map<String, dynamic>>> getOverdueInvoices({
    String? branchId,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      var query = _supabase
          .from('invoices')
          .select('''
        *,
        rooms!inner(room_id, room_number, branch_id,
          branches!inner(branch_name)),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone)
      ''')
          .lt('due_date', today)
          .or('invoice_status.eq.pending,invoice_status.eq.partial,invoice_status.eq.overdue');

      if (branchId != null) {
        query = query.eq('rooms.branch_id', branchId);
      }

      final result = await query.order('due_date', ascending: true);

      return List<Map<String, dynamic>>.from(result).map((invoice) {
        final dueDate = DateTime.parse(invoice['due_date']);
        final daysOverdue = DateTime.now().difference(dueDate).inDays;

        return {
          ...invoice,
          'tenant_name': invoice['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': invoice['tenants']?['tenant_phone'] ?? '-',
          'room_number': invoice['rooms']?['room_number'] ?? '-',
          'branch_name': invoice['rooms']?['branches']?['branch_name'] ?? '-',
          'days_overdue': daysOverdue,
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    }
  }

  /// ออกบิลหลายห้องพร้อมกัน (Bulk Invoice Generation)
  static Future<Map<String, dynamic>> generateBulkInvoices({
    required List<String> readingIds,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageInvoices,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการออกบิล'};
      }

      List<Map<String, dynamic>> successList = [];
      List<Map<String, dynamic>> failedList = [];

      for (String readingId in readingIds) {
        try {
          final result = await generateInvoiceFromReading(readingId);
          if (result['success']) {
            successList.add({
              'reading_id': readingId,
              'invoice_id': result['invoice_id'],
              'invoice_number': result['invoice_number'],
            });
          } else {
            failedList.add({
              'reading_id': readingId,
              'error': result['message'],
            });
          }
        } catch (e) {
          failedList.add({
            'reading_id': readingId,
            'error': e.toString(),
          });
        }
      }

      return {
        'success': true,
        'total': readingIds.length,
        'success_count': successList.length,
        'failed_count': failedList.length,
        'success_list': successList,
        'failed_list': failedList,
        'message':
            'ออกบิลสำเร็จ ${successList.length} ใบ จากทั้งหมด ${readingIds.length} ใบ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.toString()}',
      };
    }
  }

  /// สร้างรายงานรายได้รายเดือน
  static Future<Map<String, dynamic>> getMonthlyRevenueReport({
    required int month,
    required int year,
    String? branchId,
  }) async {
    try {
      var query = _supabase.from('invoices').select('''
        invoice_id,
        invoice_number,
        total_amount,
        paid_amount,
        invoice_status,
        rental_amount,
        utilities_amount,
        other_charges,
        discount_amount,
        late_fee_amount,
        issue_date,
        due_date,
        paid_date,
        rooms!inner(room_number, branch_id,
          branches!inner(branch_name)),
        tenants!inner(tenant_fullname)
      ''').eq('invoice_month', month).eq('invoice_year', year);

      if (branchId != null) {
        query = query.eq('rooms.branch_id', branchId);
      }

      final result = await query;

      double totalRevenue = 0;
      double totalRental = 0;
      double totalUtilities = 0;
      double totalOtherCharges = 0;
      double totalDiscount = 0;
      double totalLateFee = 0;
      double totalCollected = 0;
      double totalPending = 0;

      int totalInvoices = result.length;
      int paidInvoices = 0;
      int pendingInvoices = 0;
      int overdueInvoices = 0;

      for (var invoice in result) {
        final total = invoice['total_amount'] ?? 0.0;
        final paid = invoice['paid_amount'] ?? 0.0;
        final status = invoice['invoice_status'];

        totalRevenue += total;
        totalRental += invoice['rental_amount'] ?? 0.0;
        totalUtilities += invoice['utilities_amount'] ?? 0.0;
        totalOtherCharges += invoice['other_charges'] ?? 0.0;
        totalDiscount += invoice['discount_amount'] ?? 0.0;
        totalLateFee += invoice['late_fee_amount'] ?? 0.0;
        totalCollected += paid;

        if (status == 'paid') {
          paidInvoices++;
        } else if (status == 'overdue') {
          overdueInvoices++;
          totalPending += (total - paid);
        } else if (status == 'pending' || status == 'partial') {
          pendingInvoices++;
          totalPending += (total - paid);
        }
      }

      final collectionRate = totalRevenue > 0
          ? (totalCollected / totalRevenue * 100).toStringAsFixed(2)
          : '0.00';

      return {
        'success': true,
        'month': month,
        'year': year,
        'branch_id': branchId,
        'summary': {
          'total_invoices': totalInvoices,
          'paid_invoices': paidInvoices,
          'pending_invoices': pendingInvoices,
          'overdue_invoices': overdueInvoices,
          'total_revenue': totalRevenue,
          'total_rental': totalRental,
          'total_utilities': totalUtilities,
          'total_other_charges': totalOtherCharges,
          'total_discount': totalDiscount,
          'total_late_fee': totalLateFee,
          'total_collected': totalCollected,
          'total_pending': totalPending,
          'collection_rate': collectionRate,
        },
        'invoices': result,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการสร้างรายงาน: $e',
      };
    }
  }

  /// เพิ่มค่าใช้จ่ายอื่นๆ ลงในใบแจ้งหนี้
  static Future<Map<String, dynamic>> addOtherCharge({
    required String invoiceId,
    required String chargeName,
    required double chargeAmount,
    String? chargeDesc,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // เพิ่มค่าใช้จ่าย
      await _supabase.from('invoice_other_charges').insert({
        'invoice_id': invoiceId,
        'charge_name': chargeName,
        'charge_amount': chargeAmount,
        'charge_desc': chargeDesc,
      });

      // อัปเดตยอดรวมในบิล
      final invoice = await getInvoiceById(invoiceId);
      if (invoice != null) {
        final newOtherCharges =
            (invoice['other_charges'] ?? 0.0) + chargeAmount;
        final newSubtotal = invoice['rental_amount'] +
            invoice['utilities_amount'] +
            newOtherCharges;
        final newTotal = newSubtotal -
            (invoice['discount_amount'] ?? 0.0) +
            (invoice['late_fee_amount'] ?? 0.0);

        await _supabase.from('invoices').update({
          'other_charges': newOtherCharges,
          'subtotal': newSubtotal,
          'total_amount': newTotal,
        }).eq('invoice_id', invoiceId);
      }

      return {
        'success': true,
        'message': 'เพิ่มค่าใช้จ่ายสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  /// ลบค่าใช้จ่ายอื่นๆ
  static Future<Map<String, dynamic>> removeOtherCharge(String chargeId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // ดึงข้อมูลค่าใช้จ่าย
      final charge = await _supabase
          .from('invoice_other_charges')
          .select('*')
          .eq('id', chargeId)
          .single();

      final invoiceId = charge['invoice_id'];
      final chargeAmount = charge['charge_amount'] ?? 0.0;

      // ลบค่าใช้จ่าย
      await _supabase.from('invoice_other_charges').delete().eq('id', chargeId);

      // อัปเดตยอดรวมในบิล
      final invoice = await getInvoiceById(invoiceId);
      if (invoice != null) {
        final newOtherCharges =
            (invoice['other_charges'] ?? 0.0) - chargeAmount;
        final newSubtotal = invoice['rental_amount'] +
            invoice['utilities_amount'] +
            newOtherCharges;
        final newTotal = newSubtotal -
            (invoice['discount_amount'] ?? 0.0) +
            (invoice['late_fee_amount'] ?? 0.0);

        await _supabase.from('invoices').update({
          'other_charges': newOtherCharges,
          'subtotal': newSubtotal,
          'total_amount': newTotal,
        }).eq('invoice_id', invoiceId);
      }

      return {
        'success': true,
        'message': 'ลบค่าใช้จ่ายสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  /// ใช้ส่วนลดกับใบแจ้งหนี้
  static Future<Map<String, dynamic>> applyDiscount({
    required String invoiceId,
    required String discountType,
    required double discountAmount,
    String? discountReason,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลใบแจ้งหนี้'};
      }

      if (invoice['invoice_status'] == 'paid') {
        return {
          'success': false,
          'message': 'ไม่สามารถใช้ส่วนลดกับบิลที่ชำระแล้ว'
        };
      }

      final subtotal = invoice['subtotal'] ?? 0.0;
      final newTotal =
          subtotal - discountAmount + (invoice['late_fee_amount'] ?? 0.0);

      if (newTotal < 0) {
        return {
          'success': false,
          'message': 'ยอดส่วนลดมากกว่ายอดรวม',
        };
      }

      await _supabase.from('invoices').update({
        'discount_type': discountType,
        'discount_amount': discountAmount,
        'discount_reason': discountReason,
        'total_amount': newTotal,
      }).eq('invoice_id', invoiceId);

      return {
        'success': true,
        'message': 'ใช้ส่วนลดสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  /// Export ข้อมูลใบแจ้งหนี้เป็น CSV
  static Future<String> exportInvoicesToCSV({
    String? branchId,
    int? month,
    int? year,
  }) async {
    try {
      final invoices = await getAllInvoices(
        branchId: branchId,
        invoiceMonth: month,
        invoiceYear: year,
        limit: 10000, // ดึงทั้งหมด
      );

      final csv = StringBuffer();

      // Header
      csv.writeln(
          'เลขที่บิล,เดือน,ปี,ห้อง,ผู้เช่า,ค่าเช่า,ค่าน้ำ-ไฟ,ค่าใช้จ่ายอื่น,ส่วนลด,ค่าปรับ,ยอดรวม,ชำระแล้ว,คงเหลือ,สถานะ,วันครบกำหนด');

      // Data
      for (var invoice in invoices) {
        final remaining =
            (invoice['total_amount'] ?? 0.0) - (invoice['paid_amount'] ?? 0.0);

        csv.writeln(
            '${invoice['invoice_number']},${invoice['invoice_month']},${invoice['invoice_year']},${invoice['room_number']},${invoice['tenant_name']},${invoice['rental_amount']},${invoice['utilities_amount']},${invoice['other_charges']},${invoice['discount_amount']},${invoice['late_fee_amount']},${invoice['total_amount']},${invoice['paid_amount']},$remaining,${invoice['invoice_status']},${invoice['due_date']}');
      }

      return csv.toString();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการ Export: $e');
    }
  }
}

// ============================================
// HELPER CLASS สำหรับข้อมูลสรุป
// ============================================

class InvoiceSummary {
  final int totalInvoices;
  final int pendingInvoices;
  final int partialInvoices;
  final int paidInvoices;
  final int overdueInvoices;
  final int cancelledInvoices;
  final double totalRevenue;
  final double collectedAmount;
  final double pendingAmount;
  final String collectionRate;

  InvoiceSummary({
    required this.totalInvoices,
    required this.pendingInvoices,
    required this.partialInvoices,
    required this.paidInvoices,
    required this.overdueInvoices,
    required this.cancelledInvoices,
    required this.totalRevenue,
    required this.collectedAmount,
    required this.pendingAmount,
    required this.collectionRate,
  });

  factory InvoiceSummary.fromMap(Map<String, dynamic> map) {
    return InvoiceSummary(
      totalInvoices: map['total'] ?? 0,
      pendingInvoices: map['pending'] ?? 0,
      partialInvoices: map['partial'] ?? 0,
      paidInvoices: map['paid'] ?? 0,
      overdueInvoices: map['overdue'] ?? 0,
      cancelledInvoices: map['cancelled'] ?? 0,
      totalRevenue: map['total_revenue']?.toDouble() ?? 0.0,
      collectedAmount: map['collected_amount']?.toDouble() ?? 0.0,
      pendingAmount: map['pending_amount']?.toDouble() ?? 0.0,
      collectionRate: '${map['collection_rate'] ?? 0}%',
    );
  }
}
