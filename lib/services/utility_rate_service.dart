import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

class UtilityRatesService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// ดึงรายการอัตราค่าบริการทั้งหมดตามสาขา
  static Future<List<Map<String, dynamic>>> getUtilityRates({
    required String branchId,
    bool? isActive,
  }) async {
    try {
      var query =
          _supabase.from('utility_rates').select().eq('branch_id', branchId);

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      // ต้องเรียก method ที่ return Future ก่อน await
      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('ไม่สามารถดึงข้อมูลอัตราค่าบริการได้: $e');
    }
  }

  /// ดึงอัตราค่าบริการเฉพาะตาม ID
  static Future<Map<String, dynamic>?> getUtilityRateById(String rateId) async {
    try {
      final response = await _supabase
          .from('utility_rates')
          .select()
          .eq('rate_id', rateId)
          .single();

      return response;
    } catch (e) {
      throw Exception('ไม่สามารถดึงข้อมูลอัตราค่าบริการได้: $e');
    }
  }

  /// ดึงอัตราค่าบริการที่ใช้งานอยู่สำหรับห้อง (สำหรับออกบิล)
  static Future<List<Map<String, dynamic>>> getActiveRatesForBranch(
      String branchId) async {
    try {
      final response = await _supabase
          .from('utility_rates')
          .select()
          .eq('branch_id', branchId)
          .eq('is_active', true)
          .order('rate_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('ไม่สามารถดึงข้อมูลอัตราค่าบริการที่ใช้งานได้: $e');
    }
  }

  /// ดึงอัตราค่าบริการแบบมิเตอร์ (สำหรับบันทึกค่ามิเตอร์)
  static Future<List<Map<String, dynamic>>> getMeteredRates(
      String branchId) async {
    try {
      final response = await _supabase
          .from('utility_rates')
          .select()
          .eq('branch_id', branchId)
          .eq('is_metered', true)
          .eq('is_active', true)
          .order('rate_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('ไม่สามารถดึงข้อมูลอัตราค่าบริการแบบมิเตอร์ได้: $e');
    }
  }

  // ============================================
  // CREATE OPERATION
  // ============================================

  /// สร้างอัตราค่าบริการใหม่
  static Future<Map<String, dynamic>> createUtilityRate(
      {required String branchId,
      required String rateName,
      required double ratePrice,
      required String rateUnit,
      required bool isMetered,
      required bool isFixed,
      double fixedAmount = 0,
      double additionalCharge = 0,
      String? rateDesc,
      bool isActive = true,
      String? createdBy}) async {
    try {
      // Validation
      if (rateName.trim().isEmpty) {
        throw Exception('กรุณากรอกชื่อค่าบริการ');
      }

      if (isMetered && ratePrice <= 0) {
        throw Exception('กรุณากรอกราคาต่อหน่วยที่มากกว่า 0');
      }

      if (isFixed && fixedAmount <= 0) {
        throw Exception('กรุณากรอกจำนวนเงินคงที่ที่มากกว่า 0');
      }

      final data = {
        'branch_id': branchId,
        'rate_name': rateName.trim(),
        'rate_price': ratePrice,
        'rate_unit': rateUnit.trim(),
        'is_metered': isMetered,
        'is_fixed': isFixed,
        'fixed_amount': fixedAmount,
        'additional_charge': additionalCharge,
        'rate_desc': rateDesc?.trim(),
        'is_active': isActive,
        'created_by': createdBy
      };

      final response =
          await _supabase.from('utility_rates').insert(data).select().single();

      return response;
    } catch (e) {
      throw Exception('ไม่สามารถสร้างอัตราค่าบริการได้: $e');
    }
  }

  // ============================================
  // UPDATE OPERATION
  // ============================================

  /// อัปเดตอัตราค่าบริการ
  static Future<Map<String, dynamic>> updateUtilityRate({
    required String rateId,
    String? rateName,
    double? ratePrice,
    String? rateUnit,
    bool? isMetered,
    bool? isFixed,
    double? fixedAmount,
    double? additionalCharge,
    String? rateDesc,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (rateName != null && rateName.trim().isNotEmpty) {
        updates['rate_name'] = rateName.trim();
      }
      if (ratePrice != null) updates['rate_price'] = ratePrice;
      if (rateUnit != null) updates['rate_unit'] = rateUnit.trim();
      if (isMetered != null) updates['is_metered'] = isMetered;
      if (isFixed != null) updates['is_fixed'] = isFixed;
      if (fixedAmount != null) updates['fixed_amount'] = fixedAmount;
      if (additionalCharge != null) {
        updates['additional_charge'] = additionalCharge;
      }
      if (rateDesc != null) updates['rate_desc'] = rateDesc.trim();
      if (isActive != null) updates['is_active'] = isActive;

      if (updates.isEmpty) {
        throw Exception('ไม่มีข้อมูลที่ต้องการอัปเดต');
      }

      final response = await _supabase
          .from('utility_rates')
          .update(updates)
          .eq('rate_id', rateId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('ไม่สามารถอัปเดตอัตราค่าบริการได้: $e');
    }
  }

  /// เปิด/ปิดการใช้งานอัตราค่าบริการ
  static Future<void> toggleUtilityRateStatus(
      String rateId, bool isActive) async {
    try {
      await _supabase
          .from('utility_rates')
          .update({'is_active': isActive}).eq('rate_id', rateId);
    } catch (e) {
      throw Exception('ไม่สามารถเปลี่ยนสถานะอัตราค่าบริการได้: $e');
    }
  }

  // ============================================
  // DELETE OPERATION
  // ============================================

  /// ลบอัตราค่าบริการ
  static Future<void> deleteUtilityRate(String rateId) async {
    try {
      // ตรวจสอบว่ามีการใช้งานอยู่หรือไม่
      final usageCheck = await _supabase
          .from('meter_readings')
          .select('reading_id')
          .eq('rate_id', rateId)
          .limit(1);

      if (usageCheck.isNotEmpty) {
        throw Exception(
            'ไม่สามารถลบอัตราค่าบริการนี้ได้ เนื่องจากมีการใช้งานในบันทึกค่ามิเตอร์แล้ว');
      }

      await _supabase.from('utility_rates').delete().eq('rate_id', rateId);
    } catch (e) {
      throw Exception('ไม่สามารถลบอัตราค่าบริการได้: $e');
    }
  }

  // ============================================
  // UTILITY FUNCTIONS
  // ============================================

  /// คำนวณค่าใช้จ่ายจากการใช้งาน
  static double calculateUtilityCost({
    required Map<String, dynamic> rate,
    double usageAmount = 0,
  }) {
    final bool isMetered = rate['is_metered'] ?? false;
    final bool isFixed = rate['is_fixed'] ?? false;
    final double ratePrice = (rate['rate_price'] ?? 0).toDouble();
    final double fixedAmount = (rate['fixed_amount'] ?? 0).toDouble();
    final double additionalCharge = (rate['additional_charge'] ?? 0).toDouble();

    double total = 0;

    // คำนวณค่าตามมิเตอร์
    if (isMetered) {
      total += ratePrice * usageAmount;
    }

    // เพิ่มค่าคงที่
    if (isFixed) {
      total += fixedAmount;
    }

    // เพิ่มค่าใช้จ่ายเพิ่มเติม
    total += additionalCharge;

    return total;
  }

  /// ตรวจสอบว่ามีอัตราค่าบริการชื่อซ้ำหรือไม่
  static Future<bool> isRateNameExists({
    required String branchId,
    required String rateName,
    String? excludeRateId,
  }) async {
    try {
      var query = _supabase
          .from('utility_rates')
          .select('rate_id')
          .eq('branch_id', branchId)
          .ilike('rate_name', rateName.trim());

      if (excludeRateId != null) {
        query = query.neq('rate_id', excludeRateId);
      }

      final response = await query.limit(1);
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// รับสถิติการใช้งานอัตราค่าบริการ
  static Future<Map<String, dynamic>> getUtilityRateStats(
      String branchId) async {
    try {
      final rates = await getUtilityRates(branchId: branchId);
      final activeRates = rates.where((r) => r['is_active'] == true).length;
      final meteredRates = rates.where((r) => r['is_metered'] == true).length;
      final fixedRates = rates.where((r) => r['is_fixed'] == true).length;

      return {
        'total': rates.length,
        'active': activeRates,
        'inactive': rates.length - activeRates,
        'metered': meteredRates,
        'fixed': fixedRates,
      };
    } catch (e) {
      throw Exception('ไม่สามารถดึงสถิติอัตราค่าบริการได้: $e');
    }
  }
}
