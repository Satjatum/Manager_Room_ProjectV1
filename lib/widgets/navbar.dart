import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:manager_room_project/views/admin/admindash_ui.dart';
import 'package:manager_room_project/views/superadmin/branchlist_ui.dart';
import 'package:manager_room_project/views/superadmin/issuelist_ui.dart';
import 'package:manager_room_project/views/superadmin/roomlist_ui.dart';
import 'package:manager_room_project/views/superadmin/tenantlist_ui.dart';
import 'package:manager_room_project/views/tenant/tenantdash_ui.dart';
import 'package:manager_room_project/widgets/colors.dart';
import '../middleware/auth_middleware.dart';
import '../models/user_models.dart';
import '../views/login_ui.dart';
import '../views/setting_ui.dart';
import '../views/superadmin/superadmindash_ui.dart';

class AppBottomNav extends StatefulWidget {
  final int currentIndex;

  const AppBottomNav({Key? key, this.currentIndex = 0}) : super(key: key);

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  UserModel? _currentUser;
  bool _isLoading = true;
  List<NavItem> _navigationItems = [];
  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthMiddleware.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _setupNavigationByRole(user);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupNavigationByRole(UserModel? user) {
    if (user == null) {
      _navigationItems = [];
      _pages = [];
      return;
    }

    switch (user.userRole) {
      case UserRole.superAdmin:
        _setupSuperAdminNavigation();
        break;
      case UserRole.admin:
        _setupAdminNavigation();
        break;
      case UserRole.user:
        _setupUserNavigation();
        break;
      case UserRole.tenant:
        _setupTenantNavigation();
        break;
    }
  }

  void _setupSuperAdminNavigation() {
    _navigationItems = [
      NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'แดชบอร์ด',
      ),
      NavItem(
        icon: Icons.business_outlined,
        activeIcon: Icons.business,
        label: 'สาขา',
      ),
      NavItem(
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics,
        label: 'ปัญหา',
      ),
      NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'ตั้งค่า',
      ),
    ];

    _pages = [
      const SuperadmindashUi(), // Dashboard
      const BranchlistUi(), // Branches - ใส่ page ที่ถูกต้องตรงนี้
      const IssuesListScreen(), // Reports - ใส่ page ที่ถูกต้องตรงนี้
      const SettingUi(), // Settings
    ];
  }

  void _setupAdminNavigation() {
    _navigationItems = [
      NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'แดชบอร์ด',
      ),
      NavItem(
        icon: Icons.business_outlined,
        activeIcon: Icons.business,
        label: 'สาขา',
      ),
      NavItem(
        icon: Icons.hotel_outlined,
        activeIcon: Icons.hotel,
        label: 'ห้องพัก',
      ),
      NavItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'ผู้เช่า',
      ),
      NavItem(
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics,
        label: 'ปัญหา',
      ),
      NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'ตั้งค่า',
      ),
    ];

    _pages = [
      const AdmindashUi(),
      const BranchlistUi(),
      const RoomListUI(),
      const TenantListUI(),
      const IssuesListScreen(),
      const SettingUi(),
    ];
  }

  void _setupUserNavigation() {
    _navigationItems = [
      NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'แดชบอร์ด',
      ),
      NavItem(
        icon: Icons.hotel_outlined,
        activeIcon: Icons.hotel,
        label: 'ห้องพัก',
      ),
      NavItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'ผู้เช่า',
      ),
      NavItem(
        icon: Icons.report_problem_outlined,
        activeIcon: Icons.report_problem,
        label: 'ปัญหา',
      ),
      NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'ตั้งค่า',
      ),
    ];

    _pages = [];
  }

  void _setupTenantNavigation() {
    _navigationItems = [
      NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'หน้าแรก',
      ),
      // NavItem(
      //   icon: Icons.receipt_long_outlined,
      //   activeIcon: Icons.receipt_long,
      //   label: 'บิล',
      // ),
      // NavItem(
      //   icon: Icons.payment_outlined,
      //   activeIcon: Icons.payment,
      //   label: 'ชำระเงิน',
      // ),
      NavItem(
        icon: Icons.report_problem_outlined,
        activeIcon: Icons.report_problem,
        label: 'แจ้งปัญหา',
      ),
      NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'โปรไฟล์',
      ),
    ];

    _pages = [
      const TenantdashUi(),
      const IssuesListScreen(),
      const SettingUi(),
    ];
  }

  void _onItemTapped(BuildContext context, int index) {
    // ตรวจสอบ authentication แบบ synchronous ก่อน
    if (_currentUser == null) {
      _navigateToLogin(context);
      return;
    }

    // Navigation ทันทีโดยไม่รอ
    if (index < _pages.length && index < _navigationItems.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => _pages[index]),
      );
    }
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginUi()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
        ),
      );
    }

    if (_navigationItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = widget.currentIndex == index;

              return Expanded(
                child: _buildNavItem(item, isSelected, index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(NavItem item, bool isSelected, int index) {
    return InkWell(
      onTap: () => _onItemTapped(context, index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? AppTheme.primary : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : Colors.grey[600],
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavItem({required this.icon, required this.activeIcon, required this.label});
}
