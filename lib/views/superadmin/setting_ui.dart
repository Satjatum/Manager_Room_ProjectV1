import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/logout_service.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:manager_room_project/widget/appcolors.dart';

class SettingUi extends StatefulWidget {
  const SettingUi({super.key});

  @override
  _SettingUiState createState() => _SettingUiState();
}

class _SettingUiState extends State<SettingUi> with LogoutMixin {
  final supabase = Supabase.instance.client;

  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'Thai';
  bool _isLoading = true;
  bool _isUpdating = false;

  // Controllers for editing
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _tenantProfile;
  Map<String, dynamic>? _branchProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      // โหลดข้อมูลพื้นฐาน user
      final userResponse = await supabase
          .from('users')
          .select('*')
          .eq('user_id', currentUser.userId)
          .single();

      setState(() {
        _userProfile = userResponse;
        _usernameController.text = userResponse['username'] ?? '';
        _emailController.text = userResponse['user_email'] ?? '';
      });

      // ถ้าเป็น tenant ให้โหลดข้อมูล tenant เพิ่ม
      if (currentUser.isTenant && currentUser.tenantId != null) {
        final tenantResponse = await supabase.from('tenants').select('''
              *, rooms!inner(room_name, room_number, room_rate, room_deposit),
              branches!inner(branch_name, branch_address, branch_phone)
            ''').eq('tenant_id', currentUser.tenantId!).single();

        setState(() {
          _tenantProfile = tenantResponse;
          _phoneController.text = tenantResponse['tenant_phone'] ?? '';
        });
      }

      // ถ้าเป็น admin หรือ user ที่มี branch_id ให้โหลดข้อมูล branch
      if (currentUser.branchId != null) {
        final branchResponse = await supabase
            .from('branches')
            .select('*')
            .eq('branch_id', currentUser.branchId!)
            .single();

        setState(() {
          _branchProfile = branchResponse;
        });
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();

      // อัปเดตข้อมูล users table
      await supabase.from('users').update({
        'username': _usernameController.text.trim(),
        'user_email': _emailController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', currentUser!.userId);

      // ถ้าเป็น tenant ให้อัปเดตเบอร์โทรใน tenants table
      if (currentUser.isTenant && currentUser.tenantId != null) {
        await supabase.from('tenants').update({
          'tenant_phone': _phoneController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('tenant_id', currentUser.tenantId!);
      }

      _showSuccessSnackBar('อัปเดตข้อมูลสำเร็จ');
      await _loadUserProfile(); // โหลดข้อมูลใหม่
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการอัปเดต: $e');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showErrorSnackBar('กรุณากรอกข้อมูลให้ครบถ้วน');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('รหัสผ่านใหม่และยืนยันรหัสผ่านไม่ตรงกัน');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showErrorSnackBar('รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();

      // อัปเดตรหัสผ่าน (ควรเข้ารหัสก่อนในระบบจริง)
      await supabase.from('users').update({
        'user_pass': _newPasswordController.text,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', currentUser!.userId);

      _showSuccessSnackBar('เปลี่ยนรหัสผ่านสำเร็จ');

      // ล้างฟิลด์
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการเปลี่ยนรหัสผ่าน: $e');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.getCurrentUser();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('การตั้งค่า'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('การตั้งค่า'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (_isUpdating)
            Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Section
              _buildUserProfileCard(currentUser),

              const SizedBox(height: 20),

              // Role-specific Information
              if (currentUser?.isTenant == true && _tenantProfile != null) ...[
                _buildTenantInformation(),
                const SizedBox(height: 20),
              ],

              if ((currentUser?.isAdmin == true ||
                      currentUser?.isUser == true) &&
                  _branchProfile != null) ...[
                _buildBranchInformation(),
                const SizedBox(height: 20),
              ],

              // Account Settings
              _buildSectionTitle('การตั้งค่าบัญชี'),
              _buildAccountSettingsCard(),

              const SizedBox(height: 20),

              // App Settings
              _buildSectionTitle('การตั้งค่าแอพพลิเคชั่น'),
              _buildAppSettingsCard(),

              const SizedBox(height: 20),

              // System Settings (เฉพาะ SuperAdmin และ Admin)
              if (currentUser?.isSuperAdmin == true ||
                  currentUser?.isAdmin == true) ...[
                _buildSectionTitle('ระบบ'),
                _buildSystemSettingsCard(),
                const SizedBox(height: 20),
              ],

              // Support & Info
              _buildSectionTitle('ความช่วยเหลือ'),
              _buildSupportCard(),

              const SizedBox(height: 30),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: performLogout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'ออกจากระบบ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 5),
    );
  }

  Widget _buildUserProfileCard(currentUser) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (_userProfile?['username']
                            ?.substring(0, 1)
                            .toUpperCase()) ??
                        'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userProfile?['username'] ?? 'ผู้ใช้',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userProfile?['user_email'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getRoleText(_userProfile?['user_role'] ?? ''),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (_userProfile?['user_status'] != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                        _userProfile!['user_status'])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getStatusText(_userProfile!['user_status']),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getStatusColor(
                                      _userProfile!['user_status']),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditProfileDialog(),
                  icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                ),
              ],
            ),

            // แสดงข้อมูลเพิ่มเติมตาม role
            if (currentUser?.isTenant == true && _tenantProfile != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.home, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ห้อง ${_tenantProfile!['room_number']} - ${_tenantProfile!['rooms']['room_name']}',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _tenantProfile!['branches']['branch_name'],
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if ((currentUser?.isAdmin == true || currentUser?.isUser == true) &&
                _branchProfile != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _branchProfile!['branch_name'],
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            currentUser?.isAdmin == true
                                ? 'เจ้าของสาขา'
                                : 'พนักงาน',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTenantInformation() {
    if (_tenantProfile == null) return SizedBox.shrink();

    final room = _tenantProfile!['rooms'];
    final branch = _tenantProfile!['branches'];
    final tenantIn = DateTime.parse(_tenantProfile!['tenant_in']);
    final tenantOut = DateTime.parse(_tenantProfile!['tenant_out']);
    final daysLeft = tenantOut.difference(DateTime.now()).inDays;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลการเช่า',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow(
                'รหัสผู้เช่า', _tenantProfile!['tenant_code'] ?? 'ยังไม่มี'),
            _buildInfoRow('ค่าเช่า', '${room['room_rate']} บาท/เดือน'),
            _buildInfoRow('เงินมัดจำ', '${room['room_deposit']} บาท'),
            _buildInfoRow('วันที่เข้าพัก',
                '${tenantIn.day}/${tenantIn.month}/${tenantIn.year}'),
            _buildInfoRow('วันที่สิ้นสุด',
                '${tenantOut.day}/${tenantOut.month}/${tenantOut.year}'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: daysLeft <= 30
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                daysLeft <= 0
                    ? 'สัญญาหมดอายุแล้ว'
                    : daysLeft <= 30
                        ? 'เหลืออีก $daysLeft วัน'
                        : 'คงเหลือ $daysLeft วัน',
                style: TextStyle(
                  color:
                      daysLeft <= 30 ? Colors.orange[700] : Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchInformation() {
    if (_branchProfile == null) return SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลสาขา',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow('ชื่อสาขา', _branchProfile!['branch_name']),
            _buildInfoRow('ที่อยู่', _branchProfile!['branch_address']),
            _buildInfoRow('เบอร์โทร', _branchProfile!['branch_phone']),
            _buildInfoRow('เจ้าของสาขา', _branchProfile!['owner_name']),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSettingsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.person,
            title: 'แก้ไขโปรไฟล์',
            subtitle: 'เปลี่ยนแปลงข้อมูลส่วนตัว',
            onTap: () => _showEditProfileDialog(),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.lock,
            title: 'เปลี่ยนรหัสผ่าน',
            subtitle: 'อัพเดทรหัสผ่านเพื่อความปลอดภัย',
            onTap: () => _showChangePasswordDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildSwitchItem(
            icon: Icons.notifications,
            title: 'การแจ้งเตือน',
            subtitle: 'รับการแจ้งเตือนต่างๆ',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          _buildDivider(),
          _buildSwitchItem(
            icon: Icons.dark_mode,
            title: 'โหมดมืด',
            subtitle: 'เปลี่ยนธีมเป็นโหมดมืด',
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
              });
              _showComingSoonSnackBar('โหมดมืด');
            },
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.language,
            title: 'ภาษา',
            subtitle: _selectedLanguage,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showLanguageDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSettingsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.backup,
            title: 'สำรองข้อมูล',
            subtitle: 'สำรองข้อมูลของคุณ',
            onTap: () => _showComingSoonDialog('สำรองข้อมูล'),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.sync,
            title: 'ซิงค์ข้อมูล',
            subtitle: 'ซิงค์ข้อมูลกับเซิร์ฟเวอร์',
            onTap: () => _showSyncDialog(),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.storage,
            title: 'การจัดการพื้นที่เก็บข้อมูล',
            subtitle: 'จัดการแคชและไฟล์ชั่วคราว',
            onTap: () => _showStorageDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.help,
            title: 'คำถามที่พบบ่อย',
            subtitle: 'คำตอบสำหรับคำถามทั่วไป',
            onTap: () => _showComingSoonDialog('คำถามที่พบบ่อย'),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.contact_support,
            title: 'ติดต่อสนับสนุน',
            subtitle: 'ติดต่อทีมสนับสนุน',
            onTap: () => _showContactDialog(),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.info,
            title: 'เกี่ยวกับแอพ',
            subtitle: 'เวอร์ชั่นและข้อมูลแอพ',
            onTap: () => _showAboutDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey[300],
      indent: 16,
      endIndent: 16,
    );
  }

  // Dialog Methods
  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขโปรไฟล์'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อผู้ใช้',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (AuthService.getCurrentUser()?.isTenant == true) ...[
                SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'เบอร์โทรศัพท์',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: _isUpdating
                ? null
                : () async {
                    Navigator.pop(context);
                    await _updateProfile();
                  },
            child: _isUpdating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เปลี่ยนรหัสผ่าน'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านปัจจุบัน',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านใหม่',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'ยืนยันรหัสผ่านใหม่',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: _isUpdating
                ? null
                : () async {
                    Navigator.pop(context);
                    await _changePassword();
                  },
            child: _isUpdating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('เปลี่ยนรหัสผ่าน'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เลือกภาษา'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('ไทย'),
              value: 'Thai',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'English',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                Navigator.pop(context);
                _showComingSoonSnackBar('ภาษาอังกฤษ');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ซิงค์ข้อมูล'),
        content: const Text('ต้องการซิงค์ข้อมูลกับเซิร์ฟเวอร์หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSyncingDialog();
            },
            child: const Text('ซิงค์'),
          ),
        ],
      ),
    );
  }

  void _showSyncingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('กำลังซิงค์ข้อมูล...'),
          ],
        ),
      ),
    );

    // Simulate syncing
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      _showSuccessSnackBar('ซิงค์ข้อมูลสำเร็จ');
    });
  }

  void _showStorageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('การจัดการพื้นที่เก็บข้อมูล'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('พื้นที่ที่ใช้: 45.2 MB'),
            SizedBox(height: 8),
            Text('แคช: 12.8 MB'),
            Text('รูปภาพ: 28.7 MB'),
            Text('ข้อมูลอื่นๆ: 3.7 MB'),
            SizedBox(height: 16),
            Text('ต้องการล้างแคชหรือไม่?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackBar('ล้างแคชสำเร็จ');
            },
            child: const Text('ล้างแคช'),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ติดต่อสนับสนุน'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📧 Email: support@dormitory.com'),
            SizedBox(height: 8),
            Text('📞 Phone: 02-xxx-xxxx'),
            SizedBox(height: 8),
            Text('⏰ เวลาทำการ: 9:00-18:00 น.'),
            SizedBox(height: 8),
            Text('💬 Line ID: @dormitory'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เกี่ยวกับแอพ'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dormitory Management System'),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Build: 2024.12.01'),
            SizedBox(height: 16),
            Text('© 2024 Dormitory Management Co., Ltd.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: const Text('ฟีเจอร์นี้กำลังพัฒนา จะเปิดใช้งานในอนาคต'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature กำลังพัฒนา จะเปิดใช้งานในอนาคต'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'ใช้งานได้';
      case 'inactive':
        return 'ไม่ได้ใช้งาน';
      case 'suspended':
        return 'ระงับการใช้งาน';
      default:
        return status;
    }
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return 'ผู้ดูแลระบบสูงสุด';
      case 'admin':
        return 'ผู้ดูแลสาขา';
      case 'user':
        return 'พนักงาน';
      case 'tenant':
        return 'ผู้เช่า';
      default:
        return 'ผู้ใช้';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
