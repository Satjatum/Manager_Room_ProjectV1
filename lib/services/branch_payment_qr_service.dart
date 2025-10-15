import 'package:supabase_flutter/supabase_flutter.dart';

class BranchPaymentQrService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getByBranch(String branchId) async {
    try {
      final res = await _supabase
          .from('branch_payment_qr')
          .select('*')
          .eq('branch_id', branchId)
          .order('is_primary', ascending: false)
          .order('display_order', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      throw Exception('โหลดบัญชี/QR ไม่ได้: $e');
    }
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    try {
      final res =
          await _supabase.from('branch_payment_qr').insert(data).select().single();
      return {'success': true, 'data': res};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> update(
      String qrId, Map<String, dynamic> data) async {
    try {
      final res = await _supabase
          .from('branch_payment_qr')
          .update(data)
          .eq('qr_id', qrId)
          .select()
          .single();
      return {'success': true, 'data': res};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> toggleActive(String qrId, bool active) async {
    return update(qrId, {'is_active': active});
  }

  static Future<Map<String, dynamic>> setPrimary(
      {required String qrId, required String branchId}) async {
    try {
      // Unset all primaries in this branch
      await _supabase
          .from('branch_payment_qr')
          .update({'is_primary': false})
          .eq('branch_id', branchId);

      // Set selected as primary
      await _supabase
          .from('branch_payment_qr')
          .update({'is_primary': true})
          .eq('qr_id', qrId);

      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> delete(String qrId) async {
    try {
      await _supabase.from('branch_payment_qr').delete().eq('qr_id', qrId);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
