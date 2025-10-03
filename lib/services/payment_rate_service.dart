import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentSettingsService {
  static final _supabase = Supabase.instance.client;

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// ดึงการตั้งค่าการชำระเงินของสาขา
  static Future<Map<String, dynamic>?> getPaymentSettings(
      String branchId) async {
    try {
      final response = await _supabase
          .from('payment_settings')
          .select()
          .eq('branch_id', branchId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('ไม่สามารถดึงข้อมูลการตั้งค่าการชำระเงินได้: $e');
    }
  }

  /// ดึงการตั้งค่าที่ใช้งานอยู่ของสาขา
  static Future<Map<String, dynamic>?> getActivePaymentSettings(
      String branchId) async {
    try {
      final response = await _supabase
          .from('payment_settings')
          .select()
          .eq('branch_id', branchId)
          .eq('is_active', true)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('ไม่สามารถดึงข้อมูลการตั้งค่าการชำระเงินได้: $e');
    }
  }

  // ============================================
  // CREATE/UPDATE OPERATION (UPSERT)
  // ============================================

  /// บันทึกหรืออัปเดตการตั้งค่าการชำระเงิน
  static Future<Map<String, dynamic>> savePaymentSettings({
    required String branchId,
    required bool enableLateFee,
    String? lateFeeType,
    double? lateFeeAmount,
    int? lateFeeStartDay,
    double? lateFeeMaxAmount,
    required bool enableDiscount,
    double? earlyPaymentDiscount,
    int? earlyPaymentDays,
    String? settingDesc,
    bool isActive = true,
    String? createdBy,
  }) async {
    try {
      // Validation สำหรับค่าปรับ
      if (enableLateFee) {
        if (lateFeeType == null ||
            !['fixed', 'percentage', 'daily'].contains(lateFeeType)) {
          throw Exception('กรุณาเลือกประเภทค่าปรับ');
        }

        if (lateFeeAmount == null || lateFeeAmount <= 0) {
          throw Exception('กรุณากรอกจำนวนค่าปรับที่มากกว่า 0');
        }

        if (lateFeeStartDay == null ||
            lateFeeStartDay < 1 ||
            lateFeeStartDay > 31) {
          throw Exception('วันเริ่มคิดค่าปรับต้องอยู่ระหว่าง 1-31');
        }

        if (lateFeeType == 'percentage' && lateFeeAmount > 100) {
          throw Exception('เปอร์เซ็นต์ค่าปรับต้องไม่เกิน 100%');
        }
      }

      // Validation สำหรับส่วนลด
      if (enableDiscount) {
        if (earlyPaymentDiscount == null || earlyPaymentDiscount <= 0) {
          throw Exception('กรุณากรอกเปอร์เซ็นต์ส่วนลดที่มากกว่า 0');
        }

        if (earlyPaymentDiscount > 100) {
          throw Exception('เปอร์เซ็นต์ส่วนลดต้องไม่เกิน 100%');
        }

        if (earlyPaymentDays == null || earlyPaymentDays <= 0) {
          throw Exception('กรุณากรอกจำนวนวันก่อนกำหนดที่มากกว่า 0');
        }
      }

      final data = {
        'branch_id': branchId,
        'enable_late_fee': enableLateFee,
        'late_fee_type': enableLateFee ? lateFeeType : null,
        'late_fee_amount': enableLateFee ? lateFeeAmount : 0,
        'late_fee_start_day': enableLateFee ? lateFeeStartDay : 1,
        'late_fee_max_amount': enableLateFee ? lateFeeMaxAmount : null,
        'enable_discount': enableDiscount,
        'early_payment_discount': enableDiscount ? earlyPaymentDiscount : 0,
        'early_payment_days': enableDiscount ? earlyPaymentDays : 0,
        'setting_desc': settingDesc?.trim(),
        'is_active': isActive,
        'created_by': createdBy,
      };

      final response = await _supabase
          .from('payment_settings')
          .upsert(data, onConflict: 'branch_id')
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('ไม่สามารถบันทึกการตั้งค่าการชำระเงินได้: $e');
    }
  }

  // ============================================
  // DELETE OPERATION
  // ============================================

  /// ลบการตั้งค่าการชำระเงิน
  static Future<void> deletePaymentSettings(String branchId) async {
    try {
      await _supabase
          .from('payment_settings')
          .delete()
          .eq('branch_id', branchId);
    } catch (e) {
      throw Exception('ไม่สามารถลบการตั้งค่าการชำระเงินได้: $e');
    }
  }

  /// เปิด/ปิดการใช้งานการตั้งค่า
  static Future<void> togglePaymentSettingsStatus(
      String branchId, bool isActive) async {
    try {
      await _supabase
          .from('payment_settings')
          .update({'is_active': isActive}).eq('branch_id', branchId);
    } catch (e) {
      throw Exception('ไม่สามารถเปลี่ยนสถานะการตั้งค่าได้: $e');
    }
  }

  // ============================================
  // CALCULATION FUNCTIONS
  // ============================================

  /// คำนวณค่าปรับชำระล่าช้า
  static Future<double> calculateLateFee({
    required String invoiceId,
    DateTime? paymentDate,
  }) async {
    try {
      final date = paymentDate ?? DateTime.now();
      final response = await _supabase.rpc(
        'calculate_late_fee',
        params: {
          'p_invoice_id': invoiceId,
          'p_payment_date': date.toIso8601String().split('T')[0],
        },
      );

      return (response ?? 0).toDouble();
    } catch (e) {
      throw Exception('ไม่สามารถคำนวณค่าปรับได้: $e');
    }
  }

  /// คำนวณส่วนลดชำระก่อนกำหนด
  static Future<double> calculateEarlyDiscount({
    required String invoiceId,
    DateTime? paymentDate,
  }) async {
    try {
      final date = paymentDate ?? DateTime.now();
      final response = await _supabase.rpc(
        'calculate_early_discount',
        params: {
          'p_invoice_id': invoiceId,
          'p_payment_date': date.toIso8601String().split('T')[0],
        },
      );

      return (response ?? 0).toDouble();
    } catch (e) {
      throw Exception('ไม่สามารถคำนวณส่วนลดได้: $e');
    }
  }

  /// คำนวณค่าปรับแบบ Manual (ไม่ต้องเรียก Database Function)
  static double calculateLateFeeManual({
    required Map<String, dynamic> settings,
    required DateTime dueDate,
    required double subtotal,
    DateTime? paymentDate,
  }) {
    final date = paymentDate ?? DateTime.now();

    // ตรวจสอบว่าเปิดใช้งานค่าปรับหรือไม่
    if (settings['enable_late_fee'] != true) {
      return 0;
    }

    // คำนวณจำนวนวันที่เกินกำหนด
    final daysLate = date.difference(dueDate).inDays;
    final startDay = settings['late_fee_start_day'] ?? 1;

    // ถ้ายังไม่เกินกำหนดหรือยังไม่ถึงวันเริ่มคิดค่าปรับ
    if (daysLate < startDay) {
      return 0;
    }

    final lateFeeType = settings['late_fee_type'] ?? 'fixed';
    final lateFeeAmount = (settings['late_fee_amount'] ?? 0).toDouble();
    final maxAmount = settings['late_fee_max_amount'] != null
        ? (settings['late_fee_max_amount'] as num).toDouble()
        : null;

    double lateFee = 0;

    switch (lateFeeType) {
      case 'fixed':
        lateFee = lateFeeAmount;
        break;

      case 'percentage':
        lateFee = subtotal * (lateFeeAmount / 100);
        break;

      case 'daily':
        final chargeDays = daysLate - startDay + 1;
        lateFee = lateFeeAmount * chargeDays;
        break;
    }

    // จำกัดค่าปรับสูงสุด (ถ้ามีการกำหนด)
    if (maxAmount != null && lateFee > maxAmount) {
      lateFee = maxAmount;
    }

    return lateFee;
  }

  /// คำนวณส่วนลดแบบ Manual
  static double calculateEarlyDiscountManual({
    required Map<String, dynamic> settings,
    required DateTime dueDate,
    required double subtotal,
    DateTime? paymentDate,
  }) {
    final date = paymentDate ?? DateTime.now();

    // ตรวจสอบว่าเปิดใช้งานส่วนลดหรือไม่
    if (settings['enable_discount'] != true) {
      return 0;
    }

    // คำนวณจำนวนวันก่อนกำหนด
    final daysEarly = dueDate.difference(date).inDays;
    final requiredDays = settings['early_payment_days'] ?? 0;

    // ถ้าชำระไม่เร็วพอ
    if (daysEarly < requiredDays) {
      return 0;
    }

    final discountPercent =
        (settings['early_payment_discount'] ?? 0).toDouble();
    return subtotal * (discountPercent / 100);
  }

  // ============================================
  // UTILITY FUNCTIONS
  // ============================================

  /// ตรวจสอบว่าสาขามีการตั้งค่าหรือยัง
  static Future<bool> hasPaymentSettings(String branchId) async {
    try {
      final response = await _supabase
          .from('payment_settings')
          .select('setting_id')
          .eq('branch_id', branchId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// สร้างตัวอย่างการคำนวณ
  static Map<String, String> generateExample({
    required bool enableLateFee,
    String? lateFeeType,
    double? lateFeeAmount,
    int? lateFeeStartDay,
    required bool enableDiscount,
    double? earlyPaymentDiscount,
    int? earlyPaymentDays,
  }) {
    Map<String, String> examples = {};

    // ตัวอย่างค่าปรับ
    if (enableLateFee && lateFeeAmount != null && lateFeeStartDay != null) {
      final sampleRental = 5000.0;
      String lateFeeExample = '';

      switch (lateFeeType) {
        case 'fixed':
          lateFeeExample =
              'หากชำระล่าช้าเกิน $lateFeeStartDay วัน\nจะเพิ่มค่าปรับ ${lateFeeAmount.toStringAsFixed(0)} บาท';
          break;

        case 'percentage':
          final fee = sampleRental * (lateFeeAmount / 100);
          lateFeeExample =
              'หากค่าเช่า ${sampleRental.toStringAsFixed(0)} บาท และล่าช้าเกิน $lateFeeStartDay วัน\n'
              'จะเพิ่มค่าปรับ $lateFeeAmount% = ${fee.toStringAsFixed(0)} บาท';
          break;

        case 'daily':
          final sampleDays = 5;
          final chargeDays = sampleDays - lateFeeStartDay + 1;
          final fee = lateFeeAmount * chargeDays;
          lateFeeExample =
              'ค่าปรับ ${lateFeeAmount.toStringAsFixed(0)} บาท/วัน หลังเกิน $lateFeeStartDay วัน\n'
              'ตัวอย่าง: ล่าช้า $sampleDays วัน = ${fee.toStringAsFixed(0)} บาท';
          break;
      }

      examples['late_fee'] = lateFeeExample;
    }

    // ตัวอย่างส่วนลด
    if (enableDiscount &&
        earlyPaymentDiscount != null &&
        earlyPaymentDays != null) {
      final sampleRental = 5000.0;
      final discount = sampleRental * (earlyPaymentDiscount / 100);
      final finalAmount = sampleRental - discount;

      examples['discount'] =
          'หากค่าเช่า ${sampleRental.toStringAsFixed(0)} บาท และชำระก่อนกำหนด $earlyPaymentDays วัน\n'
          'จะได้ส่วนลด $earlyPaymentDiscount% = ${discount.toStringAsFixed(0)} บาท\n'
          'ชำระเพียง ${finalAmount.toStringAsFixed(0)} บาท';
    }

    return examples;
  }

  /// รับสถิติการตั้งค่า
  static Future<Map<String, dynamic>> getPaymentSettingsStats() async {
    try {
      final response = await _supabase.from('payment_settings').select();

      final List<Map<String, dynamic>> settings =
          List<Map<String, dynamic>>.from(response);

      final totalSettings = settings.length;
      final activeSettings =
          settings.where((s) => s['is_active'] == true).length;
      final withLateFee =
          settings.where((s) => s['enable_late_fee'] == true).length;
      final withDiscount =
          settings.where((s) => s['enable_discount'] == true).length;

      return {
        'total': totalSettings,
        'active': activeSettings,
        'inactive': totalSettings - activeSettings,
        'with_late_fee': withLateFee,
        'with_discount': withDiscount,
      };
    } catch (e) {
      throw Exception('ไม่สามารถดึงสถิติการตั้งค่าได้: $e');
    }
  }

  /// ตรวจสอบว่าควรคิดค่าปรับหรือไม่
  static bool shouldApplyLateFee({
    required Map<String, dynamic> settings,
    required DateTime dueDate,
    DateTime? currentDate,
  }) {
    if (settings['enable_late_fee'] != true) return false;

    final date = currentDate ?? DateTime.now();
    final daysLate = date.difference(dueDate).inDays;
    final startDay = settings['late_fee_start_day'] ?? 1;

    return daysLate >= startDay;
  }

  /// ตรวจสอบว่าควรให้ส่วนลดหรือไม่
  static bool shouldApplyDiscount({
    required Map<String, dynamic> settings,
    required DateTime dueDate,
    DateTime? paymentDate,
  }) {
    if (settings['enable_discount'] != true) return false;

    final date = paymentDate ?? DateTime.now();
    final daysEarly = dueDate.difference(date).inDays;
    final requiredDays = settings['early_payment_days'] ?? 0;

    return daysEarly >= requiredDays;
  }
}
