import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class UserModel {
  final String userId; // เปลี่ยนจาก id
  final String userEmail; // เปลี่ยนจาก email
  final String username;
  final UserRole userRole; // เปลี่ยนจาก role
  final UserStatus userStatus; // เปลี่ยนจาก status
  final String? branchId; // เพิ่ม
  final String? branchName; // เพิ่ม
  final String? userProfile;
  final List<String> userPermission; // เพิ่ม
  final String? tenantId; // เพิ่ม
  final DateTime? lastLogin; // เพิ่ม
  final String? createdBy; // เพิ่ม
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? tenantCode;

  UserModel({
    required this.userId,
    required this.userEmail,
    required this.username,
    required this.userRole,
    required this.userStatus,
    this.branchId,
    this.branchName,
    this.userProfile,
    this.userPermission = const [],
    this.tenantId,
    this.lastLogin,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.tenantCode,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] ?? '',
      userEmail: json['user_email'] ?? '',
      username: json['username'] ?? '',
      userRole: UserRole.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            json['user_role']?.toLowerCase(),
        orElse: () => UserRole.user,
      ),
      userStatus: UserStatus.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            json['user_status']?.toLowerCase(),
        orElse: () => UserStatus.active,
      ),
      branchId: json['branch_id'],
      branchName: json['branch_name'],
      userProfile: json['user_profile'],
      userPermission: List<String>.from(json['user_permission'] ?? []),
      tenantId: json['tenant_id'],
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      tenantCode: json['tenant_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_email': userEmail,
      'username': username,
      'user_role': userRole.toString().split('.').last,
      'user_status': userStatus.toString().split('.').last,
      'branch_id': branchId,
      'branch_name': branchName,
      'user_profile': userProfile,
      'user_permission': userPermission,
      'tenant_id': tenantId,
      'last_login': lastLogin?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tenant_code': tenantCode,
    };
  }

  // Helper methods
  bool get isSuperAdmin => userRole == UserRole.superAdmin;
  bool get isAdmin => userRole == UserRole.admin;
  bool get isUser => userRole == UserRole.user;
  bool get isTenant => userRole == UserRole.tenant;

  bool hasPermission(String permission) {
    return isSuperAdmin || userPermission.contains(permission);
  }

  bool canAccessBranch(String targetBranchId) {
    return isSuperAdmin || branchId == targetBranchId;
  }

  // สำหรับแสดงชื่อ (ใช้ username แทน userFullName)
  String get displayName => username;
}

enum UserRole {
  superAdmin, // ผู้ดูแลระบบสูงสุด
  admin, // เจ้าของสาขา
  user, // พนักงาน
  tenant // ผู้เช่า
}

enum UserStatus {
  active, // ใช้งานได้ปกติ
  inactive, // ไม่ได้ใช้งาน
  suspended // ถูกระงับ
}
