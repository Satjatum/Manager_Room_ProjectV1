import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'invoice_service.dart';

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

  // ======================
  // ADMIN: Slip Review APIs
  // ======================

  // List payment slips with joins for admin review
  static Future<List<Map<String, dynamic>>> listPaymentSlips({
    String status = 'pending',
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
    String? search, // invoice_number or tenant name/phone
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      // If branchId is provided, prefetch room_ids for that branch to avoid deep 2-level filters
      List<String>? allowedRoomIds;
      if (branchId != null && branchId.isNotEmpty) {
        final roomRows = await _supabase
            .from('rooms')
            .select('room_id')
            .eq('branch_id', branchId);
        final ids = List<Map<String, dynamic>>.from(roomRows)
            .map((r) => r['room_id'])
            .where((id) => id != null)
            .map<String>((id) => id.toString())
            .where((id) => id.isNotEmpty)
            .toList();
        if (ids.isEmpty) {
          return [];
        }
        allowedRoomIds = ids;
      }

      var query = _supabase
          .from('payment_slips')
          .select('''
            *,
            invoices!inner(*,
              rooms!inner(room_id, room_number, branch_id,
                branches!inner(branch_name, branch_code)
              ),
              tenants!inner(tenant_id, tenant_fullname, tenant_phone)
            )
          ''');

      if (status.isNotEmpty && status != 'all') {
        query = query.eq('slip_status', status);
      }
      // Use IN filter on invoices.room_id to avoid unsupported deep two-level filters
      if (allowedRoomIds != null) {
        query = query.inFilter('invoices.room_id', allowedRoomIds);
      }
      if (startDate != null) {
        query = query.gte('payment_date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('payment_date', endDate.toIso8601String());
      }
      if (search != null && search.isNotEmpty) {
        // Avoid deep 2-level filters here; filter invoice_number on server,
        // and apply tenant name/phone filtering client-side after fetch
        query = query.ilike('invoices.invoice_number', '%$search%');
      }

      final res = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      var list = List<Map<String, dynamic>>.from(res).map((row) {
        final inv = row['invoices'] ?? {};
        final room = inv['rooms'] ?? {};
        final br = room['branches'] ?? {};
        final tenant = inv['tenants'] ?? {};
        return {
          ...row,
          'invoice_number': inv['invoice_number'],
          'invoice_total': inv['total_amount'],
          'invoice_paid': inv['paid_amount'],
          'room_number': room['room_number'],
          'branch_id': room['branch_id'],
          'branch_name': br['branch_name'],
          'tenant_name': tenant['tenant_fullname'],
          'tenant_phone': tenant['tenant_phone'],
        };
      }).toList();

      // Client-side search across tenant fields to avoid deep filter errors
      if (search != null && search.isNotEmpty) {
        final s = search.toLowerCase();
        list = list.where((row) {
          final invNum = (row['invoice_number'] ?? '').toString().toLowerCase();
          final name = (row['tenant_name'] ?? '').toString().toLowerCase();
          final phone = (row['tenant_phone'] ?? '').toString().toLowerCase();
          return invNum.contains(s) || name.contains(s) || phone.contains(s);
        }).toList();
      }

      return list;
    } catch (e) {
      throw Exception('โหลดรายการสลิปไม่สำเร็จ: $e');
    }
  }

  static Future<Map<String, dynamic>?> getSlipById(String slipId) async {
    try {
      final res = await _supabase.from('payment_slips').select('''
            *,
            invoices!inner(*,
              rooms!inner(room_id, room_number, branch_id,
                branches!inner(branch_name, branch_code)
              ),
              tenants!inner(tenant_id, tenant_fullname, tenant_phone)
            )
          ''').eq('slip_id', slipId).maybeSingle();
      return res;
    } catch (e) {
      throw Exception('ไม่พบสลิป: $e');
    }
  }

  static Future<String> _generatePaymentNumber() async {
    final now = DateTime.now();
    final prefix = 'PAY${now.year}${now.month.toString().padLeft(2, '0')}';
    final last = await _supabase
        .from('payments')
        .select('payment_number')
        .like('payment_number', '$prefix%')
        .order('payment_number', ascending: false)
        .limit(1)
        .maybeSingle();
    int next = 1;
    if (last != null) {
      final s = (last['payment_number'] ?? '').toString();
      final n = int.tryParse(s.substring(prefix.length)) ?? 0;
      next = n + 1;
    }
    return '$prefix${next.toString().padLeft(4, '0')}';
  }

  // Approve and create payment, update invoice, mark slip verified
  static Future<Map<String, dynamic>> verifySlip({
    required String slipId,
    required double approvedAmount,
    String paymentMethod = 'transfer',
    String? adminNotes,
  }) async {
    try {
      if (approvedAmount <= 0) {
        return {'success': false, 'message': 'จำนวนเงินต้องมากกว่า 0'};
      }

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      final slip = await getSlipById(slipId);
      if (slip == null) {
        return {'success': false, 'message': 'ไม่พบสลิป'};
      }
      if (slip['slip_status'] != 'pending') {
        return {'success': false, 'message': 'สลิปนี้ถูกตรวจสอบแล้ว'};
      }

      final invoiceId = slip['invoice_id'] as String;
      final tenantId = slip['tenant_id'] as String;

      // Create payment record
      final paymentNumber = await _generatePaymentNumber();
      final payment = await _supabase
          .from('payments')
          .insert({
            'payment_number': paymentNumber,
            'invoice_id': invoiceId,
            'tenant_id': tenantId,
            'payment_date': DateTime.now().toIso8601String(),
            'payment_amount': approvedAmount,
            'payment_method': paymentMethod,
            'reference_number': slip['slip_number'],
            'payment_slip_image': slip['slip_image'],
            'payment_status': 'verified',
            'verified_by': currentUser.userId,
            'verified_date': DateTime.now().toIso8601String(),
            'payment_notes': adminNotes,
            'created_by': currentUser.userId,
            'slip_id': slipId,
          })
          .select()
          .single();

      // Mark slip as verified and link payment
      await _supabase.from('payment_slips').update({
        'slip_status': 'verified',
        'verified_by': currentUser.userId,
        'verified_at': DateTime.now().toIso8601String(),
        'admin_notes': adminNotes,
        'payment_id': payment['payment_id'],
      }).eq('slip_id', slipId);

      // Update invoice paid amount/status
      final invUpdate = await InvoiceService.updateInvoicePaymentStatus(
          invoiceId, approvedAmount);
      if (invUpdate['success'] != true) {
        // Not fatal, but include message
      }

      // Add verification history
      await _supabase.from('slip_verification_history').insert({
        'slip_id': slipId,
        'action': 'verify',
        'action_by': currentUser.userId,
        'previous_status': 'pending',
        'new_status': 'verified',
        'notes': adminNotes,
      });

      return {
        'success': true,
        'message': 'อนุมัติสลิปและบันทึกการชำระเงินเรียบร้อย',
        'payment': payment,
      };
    } on PostgrestException catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถอนุมัติสลิปได้: $e'};
    }
  }

  static Future<Map<String, dynamic>> rejectSlip({
    required String slipId,
    required String reason,
  }) async {
    try {
      if (reason.trim().isEmpty) {
        return {'success': false, 'message': 'กรุณาระบุเหตุผลในการปฏิเสธ'};
      }

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      final slip = await getSlipById(slipId);
      if (slip == null) {
        return {'success': false, 'message': 'ไม่พบสลิป'};
      }
      if (slip['slip_status'] != 'pending') {
        return {
          'success': false,
          'message': 'สลิปนี้ถูกตรวจสอบแล้ว ไม่สามารถปฏิเสธได้'
        };
      }

      await _supabase.from('payment_slips').update({
        'slip_status': 'rejected',
        'rejection_reason': reason,
        'verified_by': currentUser.userId,
        'verified_at': DateTime.now().toIso8601String(),
      }).eq('slip_id', slipId);

      await _supabase.from('slip_verification_history').insert({
        'slip_id': slipId,
        'action': 'reject',
        'action_by': currentUser.userId,
        'previous_status': 'pending',
        'new_status': 'rejected',
        'notes': reason,
      });

      return {'success': true, 'message': 'ปฏิเสธสลิปเรียบร้อย'};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถปฏิเสธสลิปได้: $e'};
    }
  }
}
