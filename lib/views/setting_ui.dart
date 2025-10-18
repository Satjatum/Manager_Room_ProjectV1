import 'package:flutter/material.dart';
import 'package:manager_room_project/views/payment_setting_ui.dart';
import 'package:manager_room_project/views/utility_setting_ui.dart';
import 'package:manager_room_project/views/payment_qr_management_ui.dart';
import '../widgets/navbar.dart';
import '../services/auth_service.dart';
import '../middleware/auth_middleware.dart';
import '../models/user_models.dart';
import 'login_ui.dart';
import 'sadmin/user_management_ui.dart';

/// Re‑styled Settings UI
/// - คงทุก method / navigation / data เดิม
/// - ปรับเฉพาะ UI: spacing, hierarchy, readability, touch target, สีตามธีม (#10B981)
class SettingUi extends StatefulWidget {
  const SettingUi({Key? key}) : super(key: key);

  @override
  State<SettingUi> createState() => _SettingUiState();
}

class _SettingUiState extends State<SettingUi> {
  UserModel? currentUser;
  bool isLoading = true;
  int activeSessionsCount = 0;
  List<Map<String, dynamic>> loginHistory = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthMiddleware.getCurrentUser();
      final sessionsCount = await AuthService.getActiveSessionsCount();
      final history = await AuthService.getUserLoginHistory(limit: 5);
      if (mounted) {
        setState(() {
          currentUser = user;
          activeSessionsCount = sessionsCount;
          loginHistory = history;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ===== Actions (ไม่แตะ logic) =====
  Future<void> _showLogoutConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ConfirmDialog(
          icon: Icons.logout,
          iconColor: Colors.orange,
          title: 'ออกจากระบบ',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('คุณต้องการออกจากระบบหรือไม่?'),
              const SizedBox(height: 8),
              Text('เซสชันทั้งหมด: $activeSessionsCount',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Text('คุณจะต้องเข้าสู่ระบบใหม่ในครั้งต่อไป',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          cancelText: 'ยกเลิก',
          okText: 'ออกจากระบบ',
          okColor: Colors.orange,
        );
      },
    );
    if (result == true) await _performLogout();
  }

  Future<void> _performLogout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await AuthService.signOut();
      await AuthService.cleanExpiredSessions();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ออกจากระบบเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginUi()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการออกจากระบบ'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _terminateOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'ยกเลิกเซสชันอื่น',
        icon: Icons.logout,
        iconColor: Colors.red,
        body: Text(
          'คุณต้องการยกเลิกเซสชันอื่นทั้งหมดหรือไม่? ($activeSessionsCount เซสชันทั้งหมด)\n\nการกระทำนี้จะทำให้อุปกรณ์อื่นที่เข้าสู่ระบบออกจากระบบใหม่',
        ),
        cancelText: 'ยกเลิก',
        okText: 'ยกเลิกเซสชันอื่น',
        okColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
        final result = await AuthService.terminateOtherSessions();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ));
          if (result['success']) _loadUserData();
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการยกเลิกเซสชัน'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  // ===== Build =====
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1200;
    final isWeb = size.width >= 1200;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ตั้งค่า')),
        body: const Center(child: Text('ไม่สามารถโหลดข้อมูลผู้ใช้ได้')),
        bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่า'),
        backgroundColor: const Color(0xff10B981),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: _buildResponsiveBody(isMobile, isTablet, isWeb),
      bottomNavigationBar:
          isMobile ? const AppBottomNav(currentIndex: 5) : null,
    );
  }

  Widget _buildResponsiveBody(bool isMobile, bool isTablet, bool isWeb) {
    final horizontal = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
          sliver: SliverList.list(children: [
            _UserCard(user: currentUser!, isMobile: isMobile),
            const SizedBox(height: 12),
            if (currentUser!.detailedPermissions.isNotEmpty)
              _PermissionsCard(user: currentUser!, isMobile: isMobile),
            const SizedBox(height: 12),
            _SettingsGroup(
              isMobile: isMobile,
              currentUser: currentUser!,
              onOpenUserManagement: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UserManagementUi()),
              ),
              onOpenUtilityRates: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UtilityRatesManagementUi()),
              ),
              onOpenPaymentSettings: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PaymentSettingsUi()),
              ),
              onOpenPaymentQR: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PaymentQrManagementUi()),
              ),
            ),
            const SizedBox(height: 12),
            _SessionCard(
              isMobile: isMobile,
              activeSessionsCount: activeSessionsCount,
              onRefresh: _loadUserData,
              onTerminateOthers: _terminateOtherSessions,
            ),
            const SizedBox(height: 12),
            if (loginHistory.isNotEmpty)
              _LoginHistoryCard(isMobile: isMobile, loginHistory: loginHistory),
            const SizedBox(height: 16),
            _FullWidthButton(
              label: 'ออกจากระบบ',
              icon: Icons.logout,
              background: Colors.orange,
              foreground: Colors.white,
              onPressed: _showLogoutConfirmation,
            ),
            const SizedBox(height: 10),
            _VersionInfo(),
          ]),
        ),
      ],
    );
  }
}

// ===== Reusable UI pieces (UI only) =====

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(blurRadius: 12, spreadRadius: -2, color: Color(0x11000000)),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill(this.text, {this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xff10B981);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? primary).withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (color ?? primary).withOpacity(.25)),
      ),
      child:
          Text(text, style: TextStyle(color: color ?? primary, fontSize: 12)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.tint});
  final IconData icon;
  final String title;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (tint ?? const Color(0xff10B981)).withOpacity(.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: tint ?? const Color(0xff10B981)),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.isMobile});
  final UserModel user;
  final bool isMobile;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(children: [
            CircleAvatar(
              radius: isMobile ? 36 : 44,
              backgroundColor: const Color(0xff10B981).withOpacity(.1),
              child: Text(
                user.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: isMobile ? 28 : 34,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff10B981),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            )
          ]),
          const SizedBox(height: 10),
          Text(user.displayName,
              style: TextStyle(
                  fontSize: isMobile ? 20 : 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(user.userEmail, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 8),
          _ChipPill(user.roleDisplayName),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text('เข้าสู่ระบบล่าสุด: ${user.lastLoginDisplay}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.user, required this.isMobile});
  final UserModel user;
  final bool isMobile;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(
            icon: Icons.security, title: 'สิทธิการใช้งาน', tint: Colors.teal),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: user.detailedPermissionStrings
              .take(8)
              .map((e) => _ChipPill(e, color: Colors.teal))
              .toList(),
        ),
        if (user.detailedPermissionStrings.length > 8) ...[
          const SizedBox(height: 8),
          Text('+${user.detailedPermissionStrings.length - 8} สิทธิเพิ่มเติม',
              style: TextStyle(
                  color: Colors.grey[600], fontStyle: FontStyle.italic)),
        ]
      ]),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.isMobile,
    required this.currentUser,
    required this.onOpenUserManagement,
    required this.onOpenUtilityRates,
    required this.onOpenPaymentSettings,
    required this.onOpenPaymentQR,
  });
  final bool isMobile;
  final UserModel currentUser;
  final VoidCallback onOpenUserManagement;
  final VoidCallback onOpenUtilityRates;
  final VoidCallback onOpenPaymentSettings;
  final VoidCallback onOpenPaymentQR;

  @override
  Widget build(BuildContext context) {
    final canSeeSettings = !(currentUser.userRole != UserRole.superAdmin &&
        !currentUser.canManageUtilityRates() &&
        !currentUser.hasAnyPermission([
          DetailedPermission.managePayments,
          DetailedPermission.manageInvoices,
        ]));
    if (!canSeeSettings) return const SizedBox.shrink();

    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(
            icon: Icons.settings_applications,
            title: 'ตั้งค่าระบบ',
            tint: Colors.indigo),
        const SizedBox(height: 6),
        const Divider(height: 20),
        if (currentUser.userRole == UserRole.superAdmin)
          _SettingTile(
            icon: Icons.admin_panel_settings,
            title: 'จัดการผู้ใช้งาน',
            subtitle: 'เพิ่ม แก้ไข และจัดการผู้ใช้ระบบ',
            onTap: onOpenUserManagement,
          ),
        if (currentUser.userRole == UserRole.superAdmin ||
            currentUser.canManageUtilityRates())
          _SettingTile(
            icon: Icons.bolt,
            title: 'ตั้งค่าอัตราค่าบริการ',
            subtitle: 'ค่าไฟฟ้า ค่าน้ำ ค่าส่วนกลาง',
            onTap: onOpenUtilityRates,
          ),
        if (currentUser.userRole == UserRole.superAdmin ||
            currentUser.hasAnyPermission([
              DetailedPermission.managePayments,
              DetailedPermission.manageInvoices,
            ])) ...[
          _SettingTile(
            icon: Icons.account_balance_wallet,
            title: 'ตั้งค่าค่าปรับและส่วนลด',
            subtitle: 'ค่าปรับชำระล่าช้า ส่วนลดชำระก่อนเวลา',
            onTap: onOpenPaymentSettings,
          ),
          _SettingTile(
            icon: Icons.qr_code_2,
            title: 'ตั้งค่าการชำระเงิน • เพิ่มบัญชี/QR',
            subtitle: 'เพิ่ม/แก้ไข/ปิดใช้งาน บัญชีธนาคารและ QR ของสาขา',
            onTap: onOpenPaymentQR,
          ),
        ]
      ]),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xff10B981);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black45),
        ]),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.isMobile,
    required this.activeSessionsCount,
    required this.onRefresh,
    required this.onTerminateOthers,
  });
  final bool isMobile;
  final int activeSessionsCount;
  final VoidCallback onRefresh;
  final VoidCallback onTerminateOthers;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(
            icon: Icons.devices, title: 'จัดการเซสชัน', tint: Colors.orange),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text('เซสชันที่ใช้งานอยู่: $activeSessionsCount',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          )
        ]),
        if (activeSessionsCount > 1) ...[
          const SizedBox(height: 8),
          _FullWidthButton(
            label: 'ยกเลิกเซสชันอื่นทั้งหมด',
            icon: Icons.logout,
            background: Colors.orange.shade100,
            foreground: Colors.orange.shade800,
            onPressed: onTerminateOthers,
          ),
        ]
      ]),
    );
  }
}

class _LoginHistoryCard extends StatelessWidget {
  const _LoginHistoryCard({required this.isMobile, required this.loginHistory});
  final bool isMobile;
  final List<Map<String, dynamic>> loginHistory;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(
            icon: Icons.history,
            title: 'ประวัติการเข้าสู่ระบบล่าสุด',
            tint: Colors.purple),
        const SizedBox(height: 12),
        ...loginHistory.take(3).map((session) {
          final createdAt = DateTime.parse(session['created_at']);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(children: [
              Icon(Icons.computer,
                  size: isMobile ? 16 : 18, color: Colors.grey[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session['user_agent'] ?? 'อุปกรณ์ไม่ทราบ',
                          style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              fontWeight: FontWeight.w500)),
                      Text(
                        '${createdAt.day}/${createdAt.month}  '
                        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            color: Colors.grey[600]),
                      ),
                    ]),
              )
            ]),
          );
        }).toList(),
      ]),
    );
  }
}

class _FullWidthButton extends StatelessWidget {
  const _FullWidthButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _VersionInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Center(
      child: Text(
        'Build: ${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.body,
    required this.cancelText,
    required this.okText,
    required this.okColor,
  });
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget body;
  final String cancelText;
  final String okText;
  final Color okColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 8),
        Text(title),
      ]),
      content: body,
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText)),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: okColor),
          child: Text(okText, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
