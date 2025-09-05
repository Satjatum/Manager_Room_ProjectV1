import 'package:flutter/material.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenantListDetailUi extends StatefulWidget {
  final String? tenantId; // เพิ่มบรรทัดนี้
  final Map<String, dynamic>? tenant; // เปลี่ยนเป็น optional
  final VoidCallback? onTenantUpdated;

  const TenantListDetailUi({
    Key? key,
    this.tenantId, // เพิ่มบรรทัดนี้
    this.tenant, // เปลี่ยนเป็น optional
    this.onTenantUpdated,
  }) : super(key: key);

  @override
  State<TenantListDetailUi> createState() => _TenantListDetailUiState();
}

class _TenantListDetailUiState extends State<TenantListDetailUi> {
  final supabase = Supabase.instance.client;
  late Map<String, dynamic> _tenant;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.tenant != null) {
      _tenant = Map<String, dynamic>.from(widget.tenant!);
    } else if (widget.tenantId != null) {
      _refreshTenantData();
    }
  }

  Future<void> _refreshTenantData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase.from('tenants').select('''
            tenant_id, tenant_full_name, tenant_phone, tenant_card,
            tenant_code, tenant_in, tenant_out, tenant_status, 
            has_account, room_number, last_access_at, contact_status,
            created_at, updated_at,
            rooms!inner(room_name, room_rate, room_deposit, room_cate),
            branches!inner(branch_name)
          ''').eq('tenant_id', widget.tenantId!).single();

      setState(() {
        _tenant = response;
      });
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTenantStatus(String newStatus) async {
    try {
      await supabase.from('tenants').update({
        'tenant_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', _tenant['tenant_id']);

      // อัปเดตสถานะห้องด้วย
      if (newStatus == 'checkout' || newStatus == 'terminated') {
        await supabase.from('rooms').update({
          'room_status': 'available',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('room_id', _tenant['room_id']);
      }

      _showSuccessSnackBar('อัปเดตสถานะสำเร็จ');
      await _refreshTenantData();
      widget.onTenantUpdated?.call();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการอัปเดตสถานะ: $e');
    }
  }

  Future<void> _updateContactStatus(String newContactStatus) async {
    try {
      await supabase.from('tenants').update({
        'contact_status': newContactStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', _tenant['tenant_id']);

      _showSuccessSnackBar('อัปเดตสถานะการติดต่อสำเร็จ');
      await _refreshTenantData();
      widget.onTenantUpdated?.call();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการอัปเดตสถานะการติดต่อ: $e');
    }
  }

  Future<void> _deleteTenant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบ'),
        content: Text(
            'คุณต้องการลบข้อมูลผู้เช่า "${_tenant['tenant_full_name']}" ใช่หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase
            .from('tenants')
            .delete()
            .eq('tenant_id', _tenant['tenant_id']);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ลบข้อมูลผู้เช่าสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('เกิดข้อผิดพลาดในการลบข้อมูล: $e');
        }
      }
    }
  }

  bool _canManageTenant() {
    final currentUser = AuthService.getCurrentUser();
    if (currentUser?.isSuperAdmin ?? false) return true;
    if (currentUser?.isAdmin ?? false) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManageTenant();
    final room = _tenant['rooms'];
    final branch = _tenant['branches'];
    final tenantIn = DateTime.parse(_tenant['tenant_in']);
    final tenantOut = DateTime.parse(_tenant['tenant_out']);
    final isExpiringSoon = tenantOut.difference(DateTime.now()).inDays <= 30;
    final hasCode = _tenant['tenant_code'] != null &&
        _tenant['tenant_code'].toString().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('รายละเอียดผู้เช่า'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (canManage)
            PopupMenuButton<String>(
              // onSelected: (value) async {
              //   switch (value) {
              //     case 'edit':
              //       await _navigateToEdit();
              //       break;
              //     case 'code':
              //       if (hasCode) _navigateToCode();
              //       break;
              //     case 'refresh':
              //       await _refreshTenantData();
              //       break;
              //     case 'delete':
              //       await _deleteTenant();
              //       break;
              //   }
              // },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('แก้ไขข้อมูล'),
                    ],
                  ),
                ),
                if (hasCode)
                  PopupMenuItem(
                    value: 'code',
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('แสดงรหัส QR'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('รีเฟรชข้อมูล'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outlined, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('ลบข้อมูล', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _refreshTenantData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    _buildProfileHeaderCard(),

                    SizedBox(height: 20),

                    // Quick Actions Card
                    _buildQuickActionsCard(),

                    SizedBox(height: 20),

                    // Personal Information Card
                    _buildPersonalInfoCard(),

                    SizedBox(height: 20),

                    // Room Information Card
                    _buildRoomInfoCard(),

                    SizedBox(height: 20),

                    // Contract Information Card
                    _buildContractInfoCard(),

                    SizedBox(height: 20),

                    // Account & Access Card
                    _buildAccountInfoCard(),

                    SizedBox(height: 20),

                    // System Information Card
                    _buildSystemInfoCard(),

                    SizedBox(height: 100), // Space for FAB
                  ],
                ),
              ),
            ),
      // floatingActionButton: canManage
      //     ? FloatingActionButton.extended(
      //         onPressed: _navigateToEdit,
      //         backgroundColor: AppColors.primary,
      //         foregroundColor: Colors.white,
      //         icon: Icon(Icons.edit),
      //         label: Text('แก้ไขข้อมูล'),
      //       )
      //     : null,
    );
  }

  Widget _buildProfileHeaderCard() {
    final room = _tenant['rooms'];
    final hasCode = _tenant['tenant_code'] != null &&
        _tenant['tenant_code'].toString().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar และข้อมูลหลัก
          Row(
            children: [
              _avatarFromName(_tenant['tenant_full_name']),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tenant['tenant_full_name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text(
                          _tenant['tenant_phone'],
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.home_outlined,
                            color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'ห้อง ${_tenant['room_number']} - ${room['room_name']}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasCode)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    // onTap: _navigateToCode,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.qr_code_2, color: Colors.white, size: 32),
                          SizedBox(height: 4),
                          Text(
                            'QR Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 20),

          // Status badges
          Row(
            children: [
              _buildStatusBadge(_tenant['tenant_status'], forHeader: true),
              SizedBox(width: 12),
              if (_tenant['contact_status'] != null)
                _buildContactStatusBadge(_tenant['contact_status'],
                    forHeader: true),
              Spacer(),
              // Price display
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '฿${_formatCurrency(room['room_rate']?.toDouble() ?? 0)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ต่อเดือน',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    final canManage = _canManageTenant();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'การดำเนินการด่วน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.swap_horiz_outlined,
                    label: 'เปลี่ยนสถานะ',
                    color: Colors.blue,
                    onTap: canManage ? _showStatusUpdateDialog : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.phone_outlined,
                    label: 'สถานะติดต่อ',
                    color: Colors.green,
                    onTap: canManage ? _showContactStatusDialog : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    final hasCode = _tenant['tenant_code'] != null &&
        _tenant['tenant_code'].toString().isNotEmpty;

    return _buildInfoCard(
      title: 'ข้อมูลส่วนตัว',
      icon: Icons.person_outline,
      children: [
        _buildInfoRow('ชื่อ-นามสกุล', _tenant['tenant_full_name']),
        _buildInfoRow('เบอร์โทรศัพท์', _tenant['tenant_phone']),
        _buildInfoRow('บัตรประชาชน/Passport', _tenant['tenant_card']),
        if (hasCode) _buildInfoRow('รหัสผู้เช่า', _tenant['tenant_code']),
      ],
    );
  }

  Widget _buildRoomInfoCard() {
    final room = _tenant['rooms'];
    final branch = _tenant['branches'];

    return _buildInfoCard(
      title: 'ข้อมูลที่พัก',
      icon: Icons.home_outlined,
      children: [
        _buildInfoRow('สาขา', branch['branch_name']),
        _buildInfoRow('หมายเลขห้อง', _tenant['room_number']),
        _buildInfoRow('ชื่อห้อง', room['room_name']),
        _buildInfoRow('ประเภทห้อง', room['room_cate']),
        _buildInfoRow('ค่าเช่ารายเดือน',
            '฿${_formatCurrency(room['room_rate']?.toDouble() ?? 0)}'),
        _buildInfoRow('เงินมัดจำ',
            '฿${_formatCurrency(room['room_deposit']?.toDouble() ?? 0)}'),
      ],
    );
  }

  Widget _buildContractInfoCard() {
    final tenantIn = DateTime.parse(_tenant['tenant_in']);
    final tenantOut = DateTime.parse(_tenant['tenant_out']);
    final duration = tenantOut.difference(tenantIn).inDays;
    final remaining = tenantOut.difference(DateTime.now()).inDays;

    return _buildInfoCard(
      title: 'ข้อมูลสัญญา',
      icon: Icons.description_outlined,
      children: [
        _buildInfoRow('วันที่เข้าพัก', _formatDate(tenantIn)),
        _buildInfoRow('วันที่สิ้นสุด', _formatDate(tenantOut)),
        _buildInfoRow('ระยะเวลาสัญญา', '$duration วัน'),
        _buildInfoRow('เวลาคงเหลือ', _getRemainingDays(tenantOut)),
        _buildInfoRow('สถานะสัญญา', _getStatusText(_tenant['tenant_status'])),
        _buildInfoRow(
            'สถานะการติดต่อ', _getContactStatusText(_tenant['contact_status'])),
      ],
    );
  }

  Widget _buildAccountInfoCard() {
    return _buildInfoCard(
      title: 'ข้อมูลบัญชีและการเข้าใช้งาน',
      icon: Icons.account_circle_outlined,
      children: [
        _buildInfoRow(
            'มีบัญชีผู้ใช้', _tenant['has_account'] == true ? 'มี' : 'ไม่มี'),
        if (_tenant['last_access_at'] != null)
          _buildInfoRow('เข้าใช้งานล่าสุด',
              _formatDateTime(DateTime.parse(_tenant['last_access_at'])))
        else
          _buildInfoRow('เข้าใช้งานล่าสุด', 'ไม่เคยเข้าใช้งาน'),
      ],
    );
  }

  Widget _buildSystemInfoCard() {
    return _buildInfoCard(
      title: 'ข้อมูลระบบ',
      icon: Icons.settings_outlined,
      children: [
        _buildInfoRow('วันที่สร้างข้อมูล',
            _formatDateTime(DateTime.parse(_tenant['created_at']))),
        _buildInfoRow('อัปเดตล่าสุด',
            _formatDateTime(DateTime.parse(_tenant['updated_at']))),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool forHeader = false}) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'เข้าพักแล้ว';
        icon = Icons.check_circle_outlined;
        break;
      case 'suspended':
        color = Colors.orange;
        label = 'ระงับชั่วคราว';
        icon = Icons.pause_circle_outlined;
        break;
      case 'checkout':
        color = Colors.red;
        label = 'ออกจากห้อง';
        icon = Icons.exit_to_app_outlined;
        break;
      case 'terminated':
        color = Colors.grey;
        label = 'ยกเลิกสัญญา';
        icon = Icons.cancel_outlined;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: forHeader ? 16 : 12, vertical: forHeader ? 8 : 6),
      decoration: BoxDecoration(
        color:
            forHeader ? Colors.white.withOpacity(0.2) : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(forHeader ? 20 : 16),
        border: Border.all(
          color: forHeader
              ? Colors.white.withOpacity(0.5)
              : color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: forHeader ? 18 : 14,
              color: forHeader ? Colors.white : color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: forHeader ? 14 : 12,
              color: forHeader ? Colors.white : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactStatusBadge(String contactStatus,
      {bool forHeader = false}) {
    Color color;
    String label;
    IconData icon;

    switch (contactStatus) {
      case 'reachable':
        color = Colors.green;
        label = 'ติดต่อได้';
        icon = Icons.phone_enabled_outlined;
        break;
      case 'unreachable':
        color = Colors.red;
        label = 'ติดต่อไม่ได้';
        icon = Icons.phone_disabled_outlined;
        break;
      case 'pending':
        color = Colors.orange;
        label = 'รอติดต่อ';
        icon = Icons.schedule_outlined;
        break;
      default:
        return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: forHeader ? 16 : 12, vertical: forHeader ? 8 : 6),
      decoration: BoxDecoration(
        color:
            forHeader ? Colors.white.withOpacity(0.2) : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(forHeader ? 20 : 16),
        border: Border.all(
          color: forHeader
              ? Colors.white.withOpacity(0.5)
              : color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: forHeader ? 18 : 14,
              color: forHeader ? Colors.white : color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: forHeader ? 14 : 12,
              color: forHeader ? Colors.white : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFromName(String name) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e[0])
            .join()
            .toUpperCase();

    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.white.withOpacity(0.2),
      child: CircleAvatar(
        radius: 36,
        backgroundColor: Colors.white,
        child: Text(
          initials,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
    );
  }

  // Future<void> _navigateToEdit() async {
  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => EditTenantUi(
  //         tenant: _tenant,
  //         onTenantUpdated: () {
  //           _refreshTenantData();
  //           widget.onTenantUpdated?.call();
  //         },
  //       ),
  //     ),
  //   );

  //   if (result == true) {
  //     await _refreshTenantData();
  //   }
  // }

  // void _navigateToCode() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => TenantCodeUi(
  //         tenant: _tenant,
  //       ),
  //     ),
  //   );
  // }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('เปลี่ยนสถานะผู้เช่า'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ผู้เช่า: ${_tenant['tenant_full_name']}'),
            Text('ห้อง: ${_tenant['room_number']}'),
            SizedBox(height: 16),
            Text('เลือกสถานะใหม่:',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          if (_tenant['tenant_status'] != 'active')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateTenantStatus('active');
              },
              child: Text('เข้าพักแล้ว', style: TextStyle(color: Colors.green)),
            ),
          if (_tenant['tenant_status'] != 'suspended')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateTenantStatus('suspended');
              },
              child:
                  Text('ระงับชั่วคราว', style: TextStyle(color: Colors.orange)),
            ),
          if (_tenant['tenant_status'] != 'checkout')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateTenantStatus('checkout');
              },
              child: Text('ออกจากห้อง', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  void _showContactStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('เปลี่ยนสถานะการติดต่อ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ผู้เช่า: ${_tenant['tenant_full_name']}'),
            Text('เบอร์: ${_tenant['tenant_phone']}'),
            SizedBox(height: 16),
            Text('เลือกสถานะการติดต่อ:',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateContactStatus('reachable');
            },
            child: Text('ติดต่อได้', style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateContactStatus('unreachable');
            },
            child: Text('ติดต่อไม่ได้', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateContactStatus('pending');
            },
            child: Text('รอติดต่อ', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
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

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'เข้าพักแล้ว';
      case 'suspended':
        return 'ระงับชั่วคราว';
      case 'checkout':
        return 'ออกจากห้อง';
      case 'terminated':
        return 'ยกเลิกสัญญา';
      default:
        return status;
    }
  }

  String _getContactStatusText(String? contactStatus) {
    if (contactStatus == null) return 'ไม่ระบุ';
    switch (contactStatus) {
      case 'reachable':
        return 'ติดต่อได้';
      case 'unreachable':
        return 'ติดต่อไม่ได้';
      case 'pending':
        return 'รอติดต่อ';
      default:
        return contactStatus;
    }
  }

  String _getRemainingDays(DateTime tenantOut) {
    final remaining = tenantOut.difference(DateTime.now()).inDays;
    if (remaining > 0) {
      return '$remaining วัน';
    } else if (remaining == 0) {
      return 'หมดสัญญาวันนี้';
    } else {
      return 'หมดสัญญาแล้ว ${remaining.abs()} วัน';
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}
