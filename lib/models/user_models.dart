import 'dart:convert';

enum UserRole {
  superAdmin,
  admin,
  user,
  tenant,
}

enum UserPermission {
  full, // superadmin
  manage, // admin
  limited, // user
  view, // tenant
}

// Server-side permission system - permissions will be managed on server
// These are just reference enums for client-side display
enum DetailedPermission {
  // All permissions for superadmin
  all,

  // Admin permissions
  manageRooms,
  manageTenants,
  manageContracts,
  viewReports,
  manageIssues,
  manageBranches,
  manageUsers,
  manageMeterReadings, // เพิ่มใหม่สำหรับบันทึกค่ามิเตอร์
  manageUtilityRates, // เพิ่มใหม่สำหรับอัตราค่าสาธารณูปโภค
  manageInvoices, // เพิ่มใหม่สำหรับจัดการใบแจ้งหนี้

  // User permissions
  viewRooms,
  viewTenants,
  viewContracts,
  viewMeterReadings, // เพิ่มใหม่สำหรับดูค่ามิเตอร์
  createMeterReadings, // เพิ่มใหม่สำหรับสร้างค่ามิเตอร์

  // Tenant permissions
  viewOwnData,
  createIssues,
  viewInvoices,
  makePayments,
  viewOwnMeterReadings, // เพิ่มใหม่สำหรับผู้เช่าดูค่ามิเตอร์ของตัวเอง

  // Additional specific permissions
  viewFinancials,
  managePayments,
  systemSettings,
}

class UserModel {
  final String userId;
  final String userName;
  final String userEmail;
  final UserRole userRole;
  final UserPermission userPermission;
  final List<DetailedPermission> detailedPermissions;
  final DateTime? lastLogin;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional info for display
  final String? branchId;
  final String? branchName;
  final String? tenantId;
  final String? tenantFullName;
  final String? tenantPhone;
  final String? tenantProfile;

  UserModel({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.userPermission,
    required this.detailedPermissions,
    this.lastLogin,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.branchId,
    this.branchName,
    this.tenantId,
    this.tenantFullName,
    this.tenantPhone,
    this.tenantProfile,
  });

  // Create UserModel from server response
  // Server should handle permission validation
  factory UserModel.fromDatabase(Map<String, dynamic> data) {
    final roleStr = data['role'] as String;
    final role = _parseRole(roleStr);
    final permission = _getPermissionFromRole(role);

    // Server should provide validated permissions
    final detailedPermissions = _parseDetailedPermissions(data['permissions']);

    // Extract tenant info if available
    String? tenantId;
    String? tenantFullName;
    String? tenantPhone;
    String? tenantProfile;

    if (data['tenant_info'] != null) {
      final tenantInfo = data['tenant_info'] as Map<String, dynamic>;
      tenantId = tenantInfo['tenant_id'];
      tenantFullName = tenantInfo['tenant_fullname'];
      tenantPhone = tenantInfo['tenant_phone'];
      tenantProfile = tenantInfo['tenant_profile'];
    }

    return UserModel(
      userId: data['user_id'],
      userName: data['user_name'],
      userEmail: data['user_email'],
      userRole: role,
      userPermission: permission,
      detailedPermissions: detailedPermissions,
      lastLogin: data['last_login'] != null
          ? DateTime.parse(data['last_login'])
          : null,
      isActive: data['is_active'] ?? false,
      createdBy: data['created_by'],
      createdAt: DateTime.parse(data['created_at']),
      updatedAt: DateTime.parse(data['updated_at']),
      branchId: data['branch_id'],
      branchName: data['branch_name'],
      tenantId: tenantId,
      tenantFullName: tenantFullName,
      tenantPhone: tenantPhone,
      tenantProfile: tenantProfile,
    );
  }

  // Helper methods
  static UserRole _parseRole(String roleStr) {
    switch (roleStr) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'user':
        return UserRole.user;
      case 'tenant':
        return UserRole.tenant;
      default:
        return UserRole.user;
    }
  }

  static UserPermission _getPermissionFromRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return UserPermission.full;
      case UserRole.admin:
        return UserPermission.manage;
      case UserRole.user:
        return UserPermission.limited;
      case UserRole.tenant:
        return UserPermission.view;
    }
  }

  // Parse permissions from server response
  static List<DetailedPermission> _parseDetailedPermissions(
      dynamic permissionsData) {
    final List<DetailedPermission> permissions = [];

    if (permissionsData == null) return permissions;

    List<dynamic> permissionsList;
    if (permissionsData is String) {
      try {
        final decoded = json.decode(permissionsData);
        permissionsList = decoded is List ? decoded : [];
      } catch (e) {
        return permissions;
      }
    } else if (permissionsData is List) {
      permissionsList = permissionsData;
    } else {
      return permissions;
    }

    // Map server permission strings to enum values
    for (final permission in permissionsList) {
      final permissionStr = permission.toString();
      switch (permissionStr) {
        case 'all':
          permissions.add(DetailedPermission.all);
          break;
        case 'manage_rooms':
          permissions.add(DetailedPermission.manageRooms);
          break;
        case 'manage_tenants':
          permissions.add(DetailedPermission.manageTenants);
          break;
        case 'manage_contracts':
          permissions.add(DetailedPermission.manageContracts);
          break;
        case 'view_reports':
          permissions.add(DetailedPermission.viewReports);
          break;
        case 'manage_issues':
          permissions.add(DetailedPermission.manageIssues);
          break;
        case 'manage_branches':
          permissions.add(DetailedPermission.manageBranches);
          break;
        case 'manage_users':
          permissions.add(DetailedPermission.manageUsers);
          break;
        case 'manage_meter_readings': // เพิ่มใหม่
          permissions.add(DetailedPermission.manageMeterReadings);
          break;
        case 'manage_utility_rates': // เพิ่มใหม่
          permissions.add(DetailedPermission.manageUtilityRates);
          break;
        case 'manage_invoices': // เพิ่มใหม่
          permissions.add(DetailedPermission.manageInvoices);
          break;
        case 'view_rooms':
          permissions.add(DetailedPermission.viewRooms);
          break;
        case 'view_tenants':
          permissions.add(DetailedPermission.viewTenants);
          break;
        case 'view_contracts':
          permissions.add(DetailedPermission.viewContracts);
          break;
        case 'view_meter_readings': // เพิ่มใหม่
          permissions.add(DetailedPermission.viewMeterReadings);
          break;
        case 'create_meter_readings': // เพิ่มใหม่
          permissions.add(DetailedPermission.createMeterReadings);
          break;
        case 'view_own_data':
          permissions.add(DetailedPermission.viewOwnData);
          break;
        case 'create_issues':
          permissions.add(DetailedPermission.createIssues);
          break;
        case 'view_invoices':
          permissions.add(DetailedPermission.viewInvoices);
          break;
        case 'make_payments':
          permissions.add(DetailedPermission.makePayments);
          break;
        case 'view_own_meter_readings': // เพิ่มใหม่
          permissions.add(DetailedPermission.viewOwnMeterReadings);
          break;
        case 'view_financials':
          permissions.add(DetailedPermission.viewFinancials);
          break;
        case 'manage_payments':
          permissions.add(DetailedPermission.managePayments);
          break;
        case 'system_settings':
          permissions.add(DetailedPermission.systemSettings);
          break;
      }
    }

    return permissions;
  }

  // Client-side permission checking (should also be validated on server)
  bool hasPermission(DetailedPermission permission) {
    if (detailedPermissions.contains(DetailedPermission.all)) {
      return true;
    }
    return detailedPermissions.contains(permission);
  }

  bool hasAnyPermission(List<DetailedPermission> permissions) {
    if (detailedPermissions.contains(DetailedPermission.all)) {
      return true;
    }
    return permissions
        .any((permission) => detailedPermissions.contains(permission));
  }

  bool canManage() {
    return userRole == UserRole.superAdmin ||
        userRole == UserRole.admin ||
        hasPermission(DetailedPermission.all);
  }

  bool canViewReports() {
    return hasAnyPermission([
      DetailedPermission.all,
      DetailedPermission.viewReports,
      DetailedPermission.viewFinancials,
    ]);
  }

  // เพิ่มฟังก์ชันตรวจสอบสิทธิ์สำหรับระบบมิเตอร์
  bool canManageMeterReadings() {
    return hasAnyPermission([
      DetailedPermission.all,
      DetailedPermission.manageMeterReadings,
    ]);
  }

  bool canCreateMeterReadings() {
    return hasAnyPermission([
      DetailedPermission.all,
      DetailedPermission.manageMeterReadings,
      DetailedPermission.createMeterReadings,
    ]);
  }

  bool canViewMeterReadings() {
    return hasAnyPermission([
      DetailedPermission.all,
      DetailedPermission.manageMeterReadings,
      DetailedPermission.viewMeterReadings,
      DetailedPermission.createMeterReadings,
      DetailedPermission.viewOwnMeterReadings,
    ]);
  }

  bool canManageUtilityRates() {
    return hasAnyPermission([
      DetailedPermission.all,
      DetailedPermission.manageUtilityRates,
    ]);
  }

  bool canManageInvoices() {
    return hasAnyPermission([
      DetailedPermission.all,
      DetailedPermission.manageInvoices,
    ]);
  }

  // Display helpers
  String get displayName {
    if (userRole == UserRole.tenant && tenantFullName != null) {
      return tenantFullName!;
    }
    return userName;
  }

  String get roleDisplayName {
    switch (userRole) {
      case UserRole.superAdmin:
        return 'ผู้ดูแลระบบหลัก';
      case UserRole.admin:
        return 'ผู้ดูแลระบบ';
      case UserRole.user:
        return 'ผู้ใช้งาน';
      case UserRole.tenant:
        return 'ผู้เช่า';
    }
  }

  String get permissionDisplayName {
    switch (userPermission) {
      case UserPermission.full:
        return 'เข้าถึงได้ทั้งหมด';
      case UserPermission.manage:
        return 'จัดการข้อมูล';
      case UserPermission.limited:
        return 'เข้าถึงจำกัด';
      case UserPermission.view:
        return 'ดูข้อมูลเท่านั้น';
    }
  }

  String get lastLoginDisplay {
    if (lastLogin == null) return 'ไม่เคยเข้าสู่ระบบ';

    final now = DateTime.now();
    final difference = now.difference(lastLogin!);

    if (difference.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else {
      return '${lastLogin!.day}/${lastLogin!.month}/${lastLogin!.year}';
    }
  }

  List<String> get detailedPermissionStrings {
    return detailedPermissions.map((permission) {
      switch (permission) {
        case DetailedPermission.all:
          return 'ทั้งหมด';
        case DetailedPermission.manageRooms:
          return 'จัดการห้องพัก';
        case DetailedPermission.manageTenants:
          return 'จัดการผู้เช่า';
        case DetailedPermission.manageContracts:
          return 'จัดการสัญญา';
        case DetailedPermission.viewReports:
          return 'ดูรายงาน';
        case DetailedPermission.manageIssues:
          return 'จัดการปัญหา';
        case DetailedPermission.manageBranches:
          return 'จัดการสาขา';
        case DetailedPermission.manageUsers:
          return 'จัดการผู้ใช้';
        case DetailedPermission.manageMeterReadings: // เพิ่มใหม่
          return 'จัดการค่ามิเตอร์';
        case DetailedPermission.manageUtilityRates: // เพิ่มใหม่
          return 'จัดการอัตราค่าสาธารณูปโภค';
        case DetailedPermission.manageInvoices: // เพิ่มใหม่
          return 'จัดการใบแจ้งหนี้';
        case DetailedPermission.viewRooms:
          return 'ดูข้อมูลห้องพัก';
        case DetailedPermission.viewTenants:
          return 'ดูข้อมูลผู้เช่า';
        case DetailedPermission.viewContracts:
          return 'ดูข้อมูลสัญญา';
        case DetailedPermission.viewMeterReadings: // เพิ่มใหม่
          return 'ดูข้อมูลค่ามิเตอร์';
        case DetailedPermission.createMeterReadings: // เพิ่มใหม่
          return 'สร้างค่ามิเตอร์';
        case DetailedPermission.viewOwnData:
          return 'ดูข้อมูลส่วนตัว';
        case DetailedPermission.createIssues:
          return 'แจ้งปัญหา';
        case DetailedPermission.viewInvoices:
          return 'ดูใบแจ้งหนี้';
        case DetailedPermission.makePayments:
          return 'ชำระเงิน';
        case DetailedPermission.viewOwnMeterReadings: // เพิ่มใหม่
          return 'ดูค่ามิเตอร์ส่วนตัว';
        case DetailedPermission.viewFinancials:
          return 'ดูข้อมูลการเงิน';
        case DetailedPermission.managePayments:
          return 'จัดการการชำระเงิน';
        case DetailedPermission.systemSettings:
          return 'ตั้งค่าระบบ';
      }
    }).toList();
  }

  @override
  String toString() {
    return 'UserModel(userId: $userId, userName: $userName, userRole: $userRole, lastLogin: $lastLogin)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  UserModel copyWith({
    String? userId,
    String? userName,
    String? userEmail,
    UserRole? userRole,
    UserPermission? userPermission,
    List<DetailedPermission>? detailedPermissions,
    DateTime? lastLogin,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? branchId,
    String? branchName,
    String? tenantId,
    String? tenantFullName,
    String? tenantPhone,
    String? tenantProfile,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
      userPermission: userPermission ?? this.userPermission,
      detailedPermissions: detailedPermissions ?? this.detailedPermissions,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      tenantId: tenantId ?? this.tenantId,
      tenantFullName: tenantFullName ?? this.tenantFullName,
      tenantPhone: tenantPhone ?? this.tenantPhone,
      tenantProfile: tenantProfile ?? this.tenantProfile,
    );
  }
}
