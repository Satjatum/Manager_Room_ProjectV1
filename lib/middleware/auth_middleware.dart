import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../services/auth_service.dart';

class AuthMiddleware {
  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    return await AuthService.isAuthenticated();
  }

  // Get current user
  static Future<UserModel?> getCurrentUser() async {
    return await AuthService.getCurrentUser();
  }

  // Basic role checking (server should also validate)
  static Future<bool> hasRole(UserRole requiredRole) async {
    final user = await getCurrentUser();
    if (user == null) return false;

    return user.userRole == requiredRole ||
        _hasHigherRole(user.userRole, requiredRole);
  }

  // Check if user has any of the required roles
  static Future<bool> hasAnyRole(List<UserRole> requiredRoles) async {
    final user = await getCurrentUser();
    if (user == null) return false;

    for (final role in requiredRoles) {
      if (user.userRole == role || _hasHigherRole(user.userRole, role)) {
        return true;
      }
    }
    return false;
  }

  // Basic permission checking (server validation is more important)
  static Future<bool> hasPermission(DetailedPermission permission) async {
    final user = await getCurrentUser();
    if (user == null) return false;

    return user.hasPermission(permission);
  }

  // Check if user has any of the required permissions
  static Future<bool> hasAnyPermission(
      List<DetailedPermission> permissions) async {
    final user = await getCurrentUser();
    if (user == null) return false;

    return user.hasAnyPermission(permissions);
  }

  // Helper method to check role hierarchy
  static bool _hasHigherRole(UserRole userRole, UserRole requiredRole) {
    const roleHierarchy = {
      UserRole.superAdmin: 4,
      UserRole.admin: 3,
      UserRole.user: 2,
      UserRole.tenant: 1,
    };

    return (roleHierarchy[userRole] ?? 0) >= (roleHierarchy[requiredRole] ?? 0);
  }
}

// Simple widget wrapper for role-based access control
class AuthWrapper extends StatelessWidget {
  final Widget child;
  final Widget fallback;
  final List<UserRole>? requiredRoles;
  final UserRole? requiredRole;
  final List<DetailedPermission>? requiredPermissions;
  final DetailedPermission? requiredPermission;

  const AuthWrapper({
    Key? key,
    required this.child,
    required this.fallback,
    this.requiredRoles,
    this.requiredRole,
    this.requiredPermissions,
    this.requiredPermission,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasAccess = snapshot.data ?? false;
        return hasAccess ? child : fallback;
      },
    );
  }

  Future<bool> _checkAccess() async {
    if (!await AuthMiddleware.isAuthenticated()) {
      return false;
    }

    // Check role-based access
    if (requiredRoles != null) {
      return await AuthMiddleware.hasAnyRole(requiredRoles!);
    }

    if (requiredRole != null) {
      return await AuthMiddleware.hasRole(requiredRole!);
    }

    // Check permission-based access
    if (requiredPermissions != null) {
      return await AuthMiddleware.hasAnyPermission(requiredPermissions!);
    }

    if (requiredPermission != null) {
      return await AuthMiddleware.hasPermission(requiredPermission!);
    }

    return true;
  }
}

// Simple permission-based widget wrapper
class PermissionWrapper extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final List<DetailedPermission> requiredPermissions;
  final bool
      requireAll; // If true, requires ALL permissions; if false, requires ANY

  const PermissionWrapper({
    Key? key,
    required this.child,
    this.fallback,
    required this.requiredPermissions,
    this.requireAll = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkPermissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final hasPermission = snapshot.data ?? false;
        if (hasPermission) {
          return child;
        } else {
          return fallback ?? const SizedBox.shrink();
        }
      },
    );
  }

  Future<bool> _checkPermissions() async {
    final user = await AuthMiddleware.getCurrentUser();
    if (user == null) return false;

    if (requireAll) {
      // Check if user has ALL required permissions
      return requiredPermissions
          .every((permission) => user.hasPermission(permission));
    } else {
      // Check if user has ANY of the required permissions
      return user.hasAnyPermission(requiredPermissions);
    }
  }
}
