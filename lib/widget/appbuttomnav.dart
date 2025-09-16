import 'package:flutter/material.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/views/superadmin/billinglist_ui.dart';
import 'package:manager_room_project/views/superadmin/branchlist_ui.dart';
import 'package:manager_room_project/views/superadmin/reportmanagement_ui.dart';
import 'package:manager_room_project/views/superadmin/setting_ui.dart';
import 'package:manager_room_project/views/superadmin/superadmindash_ui.dart';
import 'package:manager_room_project/views/admin/admindash_ui.dart';
import 'package:manager_room_project/views/superadmin/tenantlist_ui.dart';
import 'package:manager_room_project/views/tenant/tenanttracker_ui.dart';
import 'package:manager_room_project/views/user/userdash_ui.dart';
import 'package:manager_room_project/views/tenant/tenantdash_ui.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({
    super.key,
    this.currentIndex = 0,
  });

  void _onItemTapped(BuildContext context, int index) {
    final currentUser = AuthService.getCurrentUser();

    if (currentUser == null) {
      // ถ้าไม่มี user ให้กลับไปหน้า login
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    List<Widget> pages = [];

    // กำหนด pages ตาม role
    if (currentUser.isSuperAdmin) {
      pages = [
        const SuperadmindashUi(), // 0: Dashboard
        const BranchlistUi(), // 1: สาขา
        const TenantlistUi(), // 2: ผู้เช่า
        const IssueManagementScreen(), // 3: แจ้งเตือน
        const BillListScreen(), // 4: ออกบิล
        const SettingUi(), // 5: ตั้งค่า
      ];
    } else if (currentUser.isAdmin) {
      pages = [
        const AdmindashUi(), // 0: Dashboard
        const BranchlistUi(), // 1: สาขา (เฉพาะสาขาตัวเอง)
        const TenantlistUi(), // 2: ผู้เช่า
        const IssueManagementScreen(), // 3: แจ้งเตือน
        const BillListScreen(), // 4: ออกบิล
        const SettingUi(), // 5: ตั้งค่า
      ];
    } else if (currentUser.userRole.toString().contains('user')) {
      pages = [
        const UserdashUi(), // 0: Dashboard
        const BranchlistUi(), // 1: สาขา (อ่านอย่างเดียว)
        const TenantlistUi(), // 2: ผู้เช่า (อ่านอย่างเดียว)
        const IssueManagementScreen(), // 3: แจ้งเตือน
        const SettingUi(), // 4: ตั้งค่า
      ];
    } else if (currentUser.isTenant) {
      pages = [
        const TenantdashUi(), // 0: Dashboard
        const TenantIssuesScreen(), // 1: แจ้งเตือน
        const SettingUi(), // 2: ตั้งค่า
      ];
    } else {
      // Role ไม่ถูกต้อง
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // ตรวจสอบว่า index ที่เลือกอยู่ในช่วงที่ถูกต้องหรือไม่
    if (index >= 0 && index < pages.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => pages[index]),
      );
    }
  }

  List<BottomNavigationBarItem> _getNavigationItems() {
    final currentUser = AuthService.getCurrentUser();

    if (currentUser == null) return [];

    if (currentUser.isSuperAdmin) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'หน้าแรก',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.business),
          label: 'สาขา',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'ผู้เช่า',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mail),
          label: 'แจ้งเตือน',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.document_scanner),
          label: 'ออกบิล',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'ตั้งค่า',
        ),
      ];
    } else if (currentUser.isAdmin) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'หน้าแรก',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.business),
          label: 'สาขา',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'ผู้เช่า',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mail),
          label: 'แจ้งเตือน',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.document_scanner),
          label: 'ออกบิล',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'ตั้งค่า',
        ),
      ];
    } else if (currentUser.userRole.toString().contains('user')) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'หน้าแรก',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.business),
          label: 'สาขา',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'ผู้เช่า',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mail),
          label: 'แจ้งเตือน',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'ตั้งค่า',
        ),
      ];
    } else if (currentUser.isTenant) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'หน้าแรก',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mail),
          label: 'แจ้งเตือน',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'ตั้งค่า',
        ),
      ];
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final navigationItems = _getNavigationItems();

    if (navigationItems.isEmpty) {
      return const SizedBox.shrink(); // ซ่อน BottomNavigationBar ถ้าไม่มี items
    }

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex.clamp(0, navigationItems.length - 1),
      onTap: (index) => _onItemTapped(context, index),
      items: navigationItems,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      elevation: 8,
    );
  }
}

// Helper Widget สำหรับใช้ใน screens ต่างๆ
class ScaffoldWithBottomNav extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  const ScaffoldWithBottomNav({
    super.key,
    required this.body,
    this.currentIndex = 0,
    this.title,
    this.actions,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ??
          (title != null
              ? AppBar(
                  title: Text(title!),
                  actions: actions,
                )
              : null),
      body: body,
      bottomNavigationBar: AppBottomNav(currentIndex: currentIndex),
    );
  }
}
