import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class PaymentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Load active payment QR/accounts of a branch for tenant display
  static Future<List<Map<String, dynamic>>> getBranchQRCodes(
      String branchId) async {
    try {
      final result = await _supabase
          .from('branch_payment_qr')
          .select('*')
          .eq('branch_id', branchId)
          .eq('is_active', true)
          .order('is_primary', ascending: false)
          .order('display_order', ascending: true)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('ไม่สามารถโหลดข้อมูลช่องทางชำระเงินของสาขาได้: $e');
    }
  }

  // Submit payment slip for verification (no invoice status change here)
  static Future<Map<String, dynamic>> submitPaymentSlip({
    required String invoiceId,
    required String tenantId,
    String? qrId, // optional selected branch account/QR
    required double paidAmount,
    required DateTime paymentDateTime,
    required String slipImageUrl,
    String? slipNumber,
    String? transferFromBank,
    String? transferFromAccount,
    String? transferToAccount,
    String? tenantNotes,
  }) async {
    try {
      // Basic validations
      if (paidAmount <= 0) {
        return {
          'success': false,
          'message': 'จำนวนเงินต้องมากกว่า 0',
        };
      }

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // Insert payment_slips as pending
      final data = {
        'invoice_id': invoiceId,
        'tenant_id': tenantId,
        'qr_id': qrId,
        'slip_image': slipImageUrl,
        'slip_number': slipNumber,
        'paid_amount': paidAmount,
        'payment_date': paymentDateTime.toIso8601String(),
        'payment_time':
            '${paymentDateTime.hour.toString().padLeft(2, '0')}:${paymentDateTime.minute.toString().padLeft(2, '0')}:00',
        'transfer_from_bank': transferFromBank,
        'transfer_from_account': transferFromAccount,
        'transfer_to_account': transferToAccount,
        'tenant_notes': tenantNotes,
        'slip_status': 'pending',
        'slip_type': 'manual',
      };

      final result =
          await _supabase.from('payment_slips').insert(data).select().single();

      return {
        'success': true,
        'message': 'ส่งสลิปเรียบร้อย รอผู้ดูแลตรวจสอบ',
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
        'message': 'ไม่สามารถส่งสลิปได้: $e',
      };
    }
  }
}
