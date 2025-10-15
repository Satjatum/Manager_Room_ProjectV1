import 'package:flutter/material.dart';
import 'package:manager_room_project/views/payment_setting_ui.dart';
import 'package:manager_room_project/views/utility_setting_ui.dart';
import 'package:manager_room_project/views/payment_qr_management_ui.dart';
import '../widgets/navbar.dart';
import '../services/auth_service.dart';
import '../middleware/auth_middleware.dart';
import '../models/user_models.dart';
import 'login_ui.dart';
import '../views/superadmin/user_management_ui.dart';

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
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showLogoutConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.orange),
              SizedBox(width: 8),
              Text('ออกจากระบบ'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('คุณต้องการออกจากระบบหรือไม่?'),
              const SizedBox(height: 8),
              Text(
                'เซสชันทั้งหมด: $activeSessionsCount',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Text(
                'คุณจะต้องเข้าสู่ระบบใหม่ในครั้งต่อไป',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('ออกจากระบบ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _performLogout();
    }
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ออกจากระบบเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginUi()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error during logout: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการออกจากระบบ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _terminateOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกเซสชันอื่น'),
        content: Text(
            'คุณต้องการยกเลิกเซสชันอื่นทั้งหมด? ($activeSessionsCount เซสชันทั้งหมด)\n\n'
            'การกระทำนี้จะทำให้อุปกรณ์อื่นที่เข้าสู่ระบบอยู่ต้องเข้าสู่ระบบใหม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยกเลิกเซสชันอื่น',
                style: TextStyle(color: Colors.white)),
          ),
        ],
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: result['success'] ? Colors.green : Colors.red,
            ),
          );

          if (result['success']) {
            _loadUserData();
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เกิดข้อผิดพลาดในการยกเลิกเซสชัน'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Enhanced User Profile Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              const Color(0xff10B981).withOpacity(0.1),
                          child: Text(
                            currentUser!.displayName
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff10B981),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentUser!.displayName,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser!.userEmail,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xff10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color:
                                    const Color(0xff10B981).withOpacity(0.3)),
                          ),
                          child: Text(
                            currentUser!.roleDisplayName,
                            style: const TextStyle(
                              color: Color(0xff10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            'เข้าสู่ระบบล่าสุด: ${currentUser!.lastLoginDisplay}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // User Permissions Card
            if (currentUser!.detailedPermissions.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Text(
                            'สิทธิ์การใช้งาน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currentUser!.detailedPermissionStrings
                            .take(6)
                            .map((permission) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Text(
                                    permission,
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      if (currentUser!.detailedPermissionStrings.length > 6)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '+${currentUser!.detailedPermissionStrings.length - 6} สิทธิ์เพิ่มเติม',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (currentUser!.userRole == UserRole.superAdmin ||
                currentUser!.canManageUtilityRates() ||
                currentUser!.hasAnyPermission([
                  DetailedPermission.managePayments,
                  DetailedPermission.manageInvoices,
                ]))
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.settings_applications,
                              color: Colors.indigo[600]),
                          const SizedBox(width: 8),
                          Text(
                            'ตั้งค่าระบบ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // User Management (SuperAdmin only)
                    if (currentUser!.userRole == UserRole.superAdmin) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.admin_panel_settings,
                            color: Colors.purple[600]),
                        title: const Text('จัดการผู้ใช้งาน'),
                        subtitle: const Text('เพิ่ม แก้ไข และจัดการผู้ใช้ระบบ'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserManagementUi(),
                            ),
                          );
                        },
                      ),
                    ],
                    // Utility Rates (SuperAdmin or Admin with permission)
                    if (currentUser!.userRole == UserRole.superAdmin ||
                        currentUser!.canManageUtilityRates()) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.bolt, color: Colors.amber),
                        title: const Text('ตั้งค่าอัตราค่าบริการ'),
                        subtitle: const Text('ค่าไฟฟ้า ค่าน้ำ ค่าส่วนกลาง'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const UtilityRatesManagementUi(),
                            ),
                          );
                        },
                      ),
                    ],
                    // Payment Settings (SuperAdmin or Admin with manage payments/invoices)
                    if (currentUser!.userRole == UserRole.superAdmin ||
                        currentUser!.hasAnyPermission([
                          DetailedPermission.managePayments,
                          DetailedPermission.manageInvoices,
                        ])) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.account_balance_wallet,
                            color: Colors.green),
                        title: const Text('ตั้งค่าค่าปรับและส่วนลด'),
                        subtitle:
                            const Text('ค่าปรับชำระล่าช้า ส่วนลดชำระก่อน'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PaymentSettingsUi(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.qr_code_2, color: Colors.teal),
                        title: const Text('ตั้งค่าการชำระเงิน • เพิ่มบัญชี/QR'),
                        subtitle:
                            const Text('เพิ่ม/แก้ไข/ปิดใช้งาน บัญชีธนาคารและ QR ของสาขา'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PaymentQrManagementUi(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Session Management Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.devices, color: Colors.orange[600]),
                    title: const Text('จัดการเซสชัน'),
                    subtitle: Text('เซสชันที่ใช้งานอยู่: $activeSessionsCount'),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadUserData,
                    ),
                  ),
                  if (activeSessionsCount > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _terminateOtherSessions,
                          icon: const Icon(Icons.logout),
                          label: const Text('ยกเลิกเซสชันอื่นทั้งหมด'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[100],
                            foregroundColor: Colors.orange[700],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Recent Login Activity
            if (loginHistory.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history, color: Colors.purple[600]),
                          const SizedBox(width: 8),
                          Text(
                            'ประวัติการเข้าสู่ระบบล่าสุด',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...loginHistory.take(3).map((session) {
                        final createdAt = DateTime.parse(session['created_at']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.computer,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session['user_agent'] ?? 'อุปกรณ์ไม่ทราบ',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '${createdAt.day}/${createdAt.month} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _showLogoutConfirmation,
                icon: const Icon(Icons.logout),
                label: const Text('ออกจากระบบ',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Version Info
            Text(
              'Build: ${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }
}
