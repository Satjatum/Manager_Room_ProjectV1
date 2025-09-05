import 'package:flutter/material.dart';
import 'package:manager_room_project/views/superadmin/addtenant_ui.dart';
import 'package:manager_room_project/views/superadmin/tenantlistdetail_ui.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';

class TenantlistUi extends StatefulWidget {
  final String? preSelectedBranchId;

  const TenantlistUi({
    Key? key,
    this.preSelectedBranchId,
  }) : super(key: key);

  @override
  State<TenantlistUi> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantlistUi> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _filteredTenants = [];

  bool _isLoading = false;
  String? _selectedBranchId;
  String _selectedStatusFilter = 'all';
  String _selectedContactStatusFilter = 'all';
  String _searchQuery = '';

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.preSelectedBranchId;
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final currentUser = AuthService.getCurrentUser();
      late List<dynamic> response;

      if (currentUser?.isSuperAdmin ?? false) {
        // Super Admin เห็นทุกสาขา
        response = await supabase
            .from('branches')
            .select('branch_id, branch_name, branch_status')
            .eq('branch_status', 'active')
            .order('branch_name');
      } else if (currentUser?.isAdmin ?? false) {
        // Admin เห็นเฉพาะสาขาตัวเอง
        response = await supabase
            .from('branches')
            .select('branch_id, branch_name, branch_status')
            .eq('owner_id', currentUser!.userId)
            .eq('branch_status', 'active')
            .order('branch_name');
      } else {
        // User เห็นเฉพาะสาขาที่ตนเองสังกัด
        if (currentUser?.branchId != null) {
          response = await supabase
              .from('branches')
              .select('branch_id, branch_name, branch_status')
              .eq('branch_id', currentUser!.branchId!)
              .eq('branch_status', 'active');
        } else {
          response = [];
        }
      }

      setState(() {
        _branches = List<Map<String, dynamic>>.from(response);
        if (_selectedBranchId == null && _branches.isNotEmpty) {
          _selectedBranchId = _branches.first['branch_id'];
        }
      });

      if (_selectedBranchId != null) {
        await _loadTenants();
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
    }
  }

  Future<void> _loadTenants() async {
    if (_selectedBranchId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase.from('tenants').select('''
            tenant_id, tenant_full_name, tenant_phone, tenant_card,
            tenant_code, tenant_in, tenant_out, tenant_status, 
            has_account, room_number, last_access_at, contact_status,
            rooms!inner(room_name, room_rate, room_deposit, room_cate),
            branches!inner(branch_name)
          ''').eq('branch_id', _selectedBranchId!).order('room_number');

      setState(() {
        _tenants = List<Map<String, dynamic>>.from(response);
        _applyFilters();
      });
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้เช่า: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTenantStatus(String tenantId, String newStatus) async {
    try {
      await supabase.from('tenants').update({
        'tenant_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenantId);

      // อัปเดตสถานะห้องด้วย
      if (newStatus == 'checkout' || newStatus == 'terminated') {
        final tenant = _tenants.firstWhere((t) => t['tenant_id'] == tenantId);
        await supabase.from('rooms').update({
          'room_status': 'available',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('room_id', tenant['room_id']);
      }

      _showSuccessSnackBar('อัปเดตสถานะสำเร็จ');
      _loadTenants();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการอัปเดตสถานะ: $e');
    }
  }

  Future<void> _updateContactStatus(
      String tenantId, String newContactStatus) async {
    try {
      await supabase.from('tenants').update({
        'contact_status': newContactStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenantId);

      _showSuccessSnackBar('อัปเดตสถานะการติดต่อสำเร็จ');
      _loadTenants();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการอัปเดตสถานะการติดต่อ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.getCurrentUser();
    final canAdd = currentUser?.isSuperAdmin ?? currentUser?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text('รายชื่อผู้เช่าทั้งหมด'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: 'กรองข้อมูล',
            onSelected: (value) {
              if (value.startsWith('status_')) {
                setState(() {
                  _selectedStatusFilter = value.replaceFirst('status_', '');
                });
              } else if (value.startsWith('contact_')) {
                setState(() {
                  _selectedContactStatusFilter =
                      value.replaceFirst('contact_', '');
                });
              }
              _applyFilters();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'สถานะผู้เช่า',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'status_all',
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive,
                        size: 20, color: Colors.grey[600]),
                    SizedBox(width: 12),
                    Text('ทั้งหมด'),
                    Spacer(),
                    if (_selectedStatusFilter == 'all')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status_active',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20, color: Colors.green),
                    SizedBox(width: 12),
                    Text('เข้าพักแล้ว'),
                    Spacer(),
                    if (_selectedStatusFilter == 'active')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status_suspended',
                child: Row(
                  children: [
                    Icon(Icons.pause_circle, size: 20, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('ระงับชั่วคราว'),
                    Spacer(),
                    if (_selectedStatusFilter == 'suspended')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status_checkout',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('ออกจากห้อง'),
                    Spacer(),
                    if (_selectedStatusFilter == 'checkout')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status_terminated',
                child: Row(
                  children: [
                    Icon(Icons.cancel, size: 20, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('ยกเลิกสัญญา'),
                    Spacer(),
                    if (_selectedStatusFilter == 'terminated')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'สถานะการติดต่อ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'contact_all',
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive,
                        size: 20, color: Colors.grey[600]),
                    SizedBox(width: 12),
                    Text('ทั้งหมด'),
                    Spacer(),
                    if (_selectedContactStatusFilter == 'all')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'contact_reachable',
                child: Row(
                  children: [
                    Icon(Icons.phone_enabled, size: 20, color: Colors.green),
                    SizedBox(width: 12),
                    Text('ติดต่อได้'),
                    Spacer(),
                    if (_selectedContactStatusFilter == 'reachable')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'contact_unreachable',
                child: Row(
                  children: [
                    Icon(Icons.phone_disabled, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('ติดต่อไม่ได้'),
                    Spacer(),
                    if (_selectedContactStatusFilter == 'unreachable')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'contact_pending',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('รอติดต่อ'),
                    Spacer(),
                    if (_selectedContactStatusFilter == 'pending')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTenants,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: [
                _buildSearchHeader(),
              ],
            ),
          ),
          if (_branches.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.business,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBranchId,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.primary,
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        items: _branches.map((branch) {
                          return DropdownMenuItem<String>(
                            value: branch['branch_id'],
                            child: Text(branch['branch_name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBranchId = value;
                          });
                          if (value != null) {
                            _loadTenants();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredTenants.isEmpty
                    ? _buildEmptyState()
                    : _buildTenantsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (canAdd) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTenantScreen(
                  preSelectedBranchId: _selectedBranchId,
                ),
              ),
            ).then((_) => _loadTenants());
          } else {
            _showErrorSnackBar('คุณไม่มีสิทธิ์เพิ่มผู้เช่า');
          }
        },
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildSearchHeader() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'ค้นหาผู้เช่า ',
        hintStyle: TextStyle(
          color: Colors.grey[500],
        ),
        prefixIcon: Icon(
          Icons.search,
          color: Colors.grey[600],
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ||
                    _selectedStatusFilter != 'all' ||
                    _selectedContactStatusFilter != 'all'
                ? 'ไม่พบผู้เช่าตามเงื่อนไขที่กำหนด'
                : 'ยังไม่มีผู้เช่าในสาขานี้',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (_searchQuery.isNotEmpty ||
              _selectedStatusFilter != 'all' ||
              _selectedContactStatusFilter != 'all') ...[
            SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedStatusFilter = 'all';
                  _selectedContactStatusFilter = 'all';
                });
                _applyFilters();
              },
              child: Text('ล้างตัวกรอง'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTenantsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredTenants.length,
      itemBuilder: (context, index) {
        final tenant = _filteredTenants[index];
        return _buildTenantCard(tenant);
      },
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant) {
    final room = tenant['rooms'];
    final status = tenant['tenant_status'];
    final contactStatus = tenant['contact_status'];
    final hasCode = tenant['tenant_code'] != null &&
        tenant['tenant_code'].toString().isNotEmpty;
    final hasAccount = tenant['has_account'] == true;

    final tenantIn = DateTime.parse(tenant['tenant_in']);
    final tenantOut = DateTime.parse(tenant['tenant_out']);
    final isExpiringSoon = tenantOut.difference(DateTime.now()).inDays <= 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TenantListDetailUi(
                tenantId: tenant['tenant_id'], // ส่งเฉพาะ ID
                onTenantUpdated: _loadTenants,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Header Section ----------
                Row(
                  children: [
                    // Enhanced Avatar
                    Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            AppColors.primary.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: _avatarFromName(tenant['tenant_full_name']),
                    ),
                    const SizedBox(width: 16),
                    // Name and basic info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant['tenant_full_name'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                tenant['tenant_phone'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildStatusBadge(status),
                        if (contactStatus != null) ...[
                          const SizedBox(height: 8),
                          _buildContactStatusBadge(contactStatus),
                        ],
                        if (isExpiringSoon && status == 'active') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_outlined,
                                    size: 12, color: Colors.orange[700]),
                                SizedBox(width: 4),
                                Text(
                                  'ใกล้หมดสัญญา',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ---------- Room Info Section ----------
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Room info
                      Expanded(
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
                                  child: Icon(
                                    Icons.home_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ห้อง ${tenant['room_number']}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Text(
                                        room['room_name'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.payments_outlined,
                                    size: 16, color: Colors.green[600]),
                                const SizedBox(width: 8),
                                Text(
                                  '${room['room_rate']} บาท/เดือน',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // QR Code section
                      if (hasCode) ...[
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_2,
                                  size: 24, color: AppColors.primary),
                              const SizedBox(height: 6),
                              Text(
                                tenant['tenant_code'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ---------- Contract Duration Section ----------
                Row(
                  children: [
                    Expanded(
                      child: _buildDateCard(
                        icon: Icons.login_outlined,
                        label: 'เข้าพัก',
                        date: _formatDate(tenantIn),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateCard(
                        icon: Icons.logout_outlined,
                        label: 'สิ้นสุด',
                        date: _formatDate(tenantOut),
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Menu button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showStatusUpdateDialog(tenant),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ---------- Footer Section ----------
                if (hasAccount || tenant['last_access_at'] != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (hasAccount)
                        _buildFeatureBadge(
                          icon: Icons.account_circle_outlined,
                          label: 'มีบัญชี',
                          color: Colors.blue,
                        ),
                      if (tenant['last_access_at'] != null)
                        _buildFeatureBadge(
                          icon: Icons.access_time_outlined,
                          label: 'เข้าใช้งาน',
                          color: Colors.green,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateCard({
    required IconData icon,
    required String label,
    required String date,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
          ),
        ],
      ),
    );
  }

// =================== Helpers ===================

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

    final seed = name.hashCode;
    final hue = (seed % 360).toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.6, 0.7).toColor();

    return CircleAvatar(
      radius: 26,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactStatusBadge(String contactStatus) {
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantDetailsSheet(Map<String, dynamic> tenant) {
    final room = tenant['rooms'];
    final branch = tenant['branches'];
    final tenantIn = DateTime.parse(tenant['tenant_in']);
    final tenantOut = DateTime.parse(tenant['tenant_out']);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'รายละเอียดผู้เช่า',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ข้อมูลส่วนตัว
                  _buildDetailSection(
                    'ข้อมูลส่วนตัว',
                    [
                      _buildDetailRow(
                          'ชื่อ-นามสกุล', tenant['tenant_full_name']),
                      _buildDetailRow('เบอร์โทรศัพท์', tenant['tenant_phone']),
                      _buildDetailRow(
                          'บัตรประชาชน/Passport', tenant['tenant_card']),
                      if (tenant['tenant_code'] != null)
                        _buildDetailRow('รหัสผู้เช่า', tenant['tenant_code']),
                    ],
                  ),

                  SizedBox(height: 20),

                  // ข้อมูลที่พัก
                  _buildDetailSection(
                    'ข้อมูลที่พัก',
                    [
                      _buildDetailRow('สาขา', branch['branch_name']),
                      _buildDetailRow('ห้อง',
                          '${tenant['room_number']} - ${room['room_name']}'),
                      _buildDetailRow(
                          'ค่าเช่า', '${room['room_rate']} บาท/เดือน'),
                      _buildDetailRow(
                          'เงินมัดจำ', '${room['room_deposit']} บาท'),
                      _buildDetailRow('ประเภทห้อง', room['room_cate']),
                    ],
                  ),

                  SizedBox(height: 20),

                  // ข้อมูลสัญญา
                  _buildDetailSection(
                    'ข้อมูลสัญญา',
                    [
                      _buildDetailRow('วันที่เข้าพัก',
                          '${tenantIn.day}/${tenantIn.month}/${tenantIn.year}'),
                      _buildDetailRow('วันที่สิ้นสุด',
                          '${tenantOut.day}/${tenantOut.month}/${tenantOut.year}'),
                      _buildDetailRow(
                          'สถานะ', _getStatusText(tenant['tenant_status'])),
                      _buildDetailRow('สถานะการติดต่อ',
                          _getContactStatusText(tenant['contact_status'])),
                      _buildDetailRow('มีบัญชีผู้ใช้',
                          tenant['has_account'] == true ? 'มี' : 'ไม่มี'),
                      if (tenant['last_access_at'] != null)
                        _buildDetailRow(
                            'เข้าใช้งานล่าสุด',
                            _formatDateTime(
                                DateTime.parse(tenant['last_access_at']))),
                    ],
                  ),

                  SizedBox(height: 30),

                  // ปุ่มดำเนินการ
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showStatusUpdateDialog(tenant);
                          },
                          icon: Icon(Icons.edit),
                          label: Text('เปลี่ยนสถานะ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showContactStatusDialog(tenant);
                          },
                          icon: Icon(Icons.phone),
                          label: Text('สถานะติดต่อ'),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _tenants;

    // กรองตามสถานะ
    if (_selectedStatusFilter != 'all') {
      filtered = filtered
          .where((tenant) => tenant['tenant_status'] == _selectedStatusFilter)
          .toList();
    }

    // กรองตามสถานะการติดต่อ
    if (_selectedContactStatusFilter != 'all') {
      filtered = filtered
          .where((tenant) =>
              tenant['contact_status'] == _selectedContactStatusFilter)
          .toList();
    }

    // กรองตามคำค้นหา
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((tenant) =>
              tenant['tenant_full_name']
                  .toString()
                  .toLowerCase()
                  .contains(query) ||
              tenant['tenant_phone'].toString().toLowerCase().contains(query) ||
              tenant['tenant_card'].toString().toLowerCase().contains(query) ||
              tenant['room_number'].toString().toLowerCase().contains(query) ||
              (tenant['tenant_code']
                      ?.toString()
                      .toLowerCase()
                      .contains(query) ??
                  false))
          .toList();
    }

    setState(() {
      _filteredTenants = filtered;
    });
  }

  // =================== Legacy Dialog Methods (kept for backward compatibility) ===================

  // void _showTenantDetails(Map<String, dynamic> tenant) {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => _buildTenantDetailsSheet(tenant),
  //   );
  // }

  void _showStatusUpdateDialog(Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('เปลี่ยนสถานะผู้เช่า'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ผู้เช่า: ${tenant['tenant_full_name']}'),
            Text('ห้อง: ${tenant['room_number']}'),
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
          if (tenant['tenant_status'] != 'active')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateTenantStatus(tenant['tenant_id'], 'active');
              },
              child: Text('เข้าพักแล้ว', style: TextStyle(color: Colors.green)),
            ),
          if (tenant['tenant_status'] != 'suspended')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateTenantStatus(tenant['tenant_id'], 'suspended');
              },
              child:
                  Text('ระงับชั่วคราว', style: TextStyle(color: Colors.orange)),
            ),
          if (tenant['tenant_status'] != 'checkout')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateTenantStatus(tenant['tenant_id'], 'checkout');
              },
              child: Text('ออกจากห้อง', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  void _showContactStatusDialog(Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('เปลี่ยนสถานะการติดต่อ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ผู้เช่า: ${tenant['tenant_full_name']}'),
            Text('เบอร์: ${tenant['tenant_phone']}'),
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
              _updateContactStatus(tenant['tenant_id'], 'reachable');
            },
            child: Text('ติดต่อได้', style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateContactStatus(tenant['tenant_id'], 'unreachable');
            },
            child: Text('ติดต่อไม่ได้', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateContactStatus(tenant['tenant_id'], 'pending');
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

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
