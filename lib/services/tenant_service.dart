import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class TenantCodeService {
  static final supabase = Supabase.instance.client;

  /// สร้างรหัสผู้เช่าอัตโนมัติ
  static String generateTenantCode({
    required String branchId,
    required String roomNumber,
    String? customPrefix,
  }) {
    // ใช้ 4 ตัวอักษรแรกของ branch_id + room_number + random 4 digits
    final branchPrefix = branchId.substring(0, 4).toUpperCase();
    final roomCode = roomNumber.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final random = Random().nextInt(9999).toString().padLeft(4, '0');

    return '${customPrefix ?? 'T'}$branchPrefix$roomCode$random';
  }

  /// สร้างรหัสผู้เช่าแบบกำหนดเอง
  static String generateCustomCode({
    String? prefix,
    String? branchCode,
    String? roomCode,
    int? sequenceNumber,
  }) {
    final parts = <String>[];

    if (prefix != null) parts.add(prefix);
    if (branchCode != null) parts.add(branchCode);
    if (roomCode != null) parts.add(roomCode);
    if (sequenceNumber != null) {
      parts.add(sequenceNumber.toString().padLeft(4, '0'));
    } else {
      parts.add(Random().nextInt(9999).toString().padLeft(4, '0'));
    }

    return parts.join('');
  }

  /// ตรวจสอบว่ารหัสผู้เช่าซ้ำหรือไม่
  static Future<bool> isCodeExists(String tenantCode) async {
    try {
      final response = await supabase
          .from('tenants')
          .select('tenant_id')
          .eq('tenant_code', tenantCode)
          .maybeSingle();

      return response != null;
    } catch (e) {
      throw Exception('Error checking tenant code: $e');
    }
  }

  /// สร้างรหัสผู้เช่าที่ไม่ซ้ำ
  static Future<String> generateUniqueCode({
    required String branchId,
    required String roomNumber,
    String? customPrefix,
    int maxAttempts = 10,
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      final code = generateTenantCode(
        branchId: branchId,
        roomNumber: roomNumber,
        customPrefix: customPrefix,
      );

      final exists = await isCodeExists(code);
      if (!exists) {
        return code;
      }
    }

    throw Exception(
        'Cannot generate unique tenant code after $maxAttempts attempts');
  }

  /// สร้างรหัสผู้เช่าแบบเรียงลำดับ
  static Future<String> generateSequentialCode({
    required String branchId,
    String? prefix,
  }) async {
    try {
      // หาเลขลำดับถัดไปของสาขา
      final result = await supabase
          .from('tenants')
          .select('tenant_code')
          .eq('branch_id', branchId)
          .not('tenant_code', 'is', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      int nextSequence = 1;

      if (result != null) {
        final lastCode = result['tenant_code'] as String;
        // พยายามดึงเลขลำดับจากตัวสุดท้าย
        final match = RegExp(r'(\d+)$').firstMatch(lastCode);
        if (match != null) {
          nextSequence = int.parse(match.group(1)!) + 1;
        }
      }

      // สร้างรหัสใหม่
      final branchCode = branchId.substring(0, 4).toUpperCase();
      final finalPrefix = prefix ?? 'T';
      final code =
          '$finalPrefix$branchCode${nextSequence.toString().padLeft(4, '0')}';

      return code;
    } catch (e) {
      throw Exception('Error generating sequential code: $e');
    }
  }

  /// อัพเดทรหัสผู้เช่าในฐานข้อมูล
  static Future<void> updateTenantCode(
      String tenantId, String tenantCode) async {
    try {
      await supabase.from('tenants').update({
        'tenant_code': tenantCode,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenantId);
    } catch (e) {
      throw Exception('Error updating tenant code: $e');
    }
  }

  /// สร้างบัญชีผู้ใช้สำหรับผู้เช่า
  static Future<String?> createTenantAccount({
    required String tenantId,
    required String tenantCode,
    required String tenantName,
    required String tenantPhone,
    String? initialPassword,
  }) async {
    try {
      // สร้าง email และ username
      final email = '${tenantCode.toLowerCase()}@tenant.local';
      final username = tenantCode.toLowerCase();

      // ใช้รหัสผู้เช่าเป็นรหัสผ่านเริ่มต้น หรือรหัสที่กำหนด
      final password = initialPassword ?? tenantCode;

      // TODO: Hash password properly
      final hashedPassword = sha256.convert(utf8.encode(password)).toString();

      // สร้าง user record
      final userResponse = await supabase
          .from('users')
          .insert({
            'user_email': email,
            'username': username,
            'user_pass': hashedPassword,
            'user_role': 'tenant',
            'user_status': 'active',
            'tenant_id': tenantId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('user_id')
          .single();

      final userId = userResponse['user_id'] as String;

      // อัพเดท tenant record
      await supabase.from('tenants').update({
        'user_id': userId,
        'has_account': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenantId);

      return userId;
    } catch (e) {
      throw Exception('Error creating tenant account: $e');
    }
  }
}
