import 'package:flutter/material.dart';
import 'package:manager_room_project/views/superadmin/addtenant_ui.dart';
import 'package:manager_room_project/views/superadmin/tenantcode_ui.dart';
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

  Future<void> _createUserAccountWithNavigation(
      Map<String, dynamic> tenant) async {
    try {
      // Show enhanced loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'กำลังสร้างบัญชีผู้ใช้...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Create user account logic here
      await supabase.from('tenants').update({
        'has_account': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenant['tenant_id']);

      Navigator.pop(context); // Close loading dialog
      _showSuccessSnackBar('สร้างบัญชีผู้ใช้สำเร็จ');
      _loadTenants();
      Future.delayed(Duration(milliseconds: 800), () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TenantCodeManagerScreen(),
          ),
        );
      });
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorSnackBar('เกิดข้อผิดพลาดในการสร้างบัญชี: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.getCurrentUser();
    final canAdd =
        (currentUser?.isSuperAdmin ?? false) || (currentUser?.isAdmin ?? false);
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TenantListDetailUi(
                tenantId: tenant['tenant_id'],
                onTenantUpdated: _loadTenants,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Header Section ----------
                Row(
                  children: [
                    // Compact Avatar
                    Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            AppColors.primary.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          tenant['tenant_full_name'][0].toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name and basic info - Flexible to prevent overflow
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant['tenant_full_name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined,
                                  size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  tenant['tenant_phone'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Compact Status Badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildCompactStatusBadge(
                          hasAccount ? 'บัญชี' : 'ไม่มีบัญชี',
                          hasAccount ? Colors.blue : Colors.grey,
                          hasAccount
                              ? Icons.account_circle
                              : Icons.account_circle_outlined,
                        ),
                        const SizedBox(height: 4),
                        _buildCompactStatusBadge(
                          hasCode ? 'รหัส' : 'ไม่มีรหัส',
                          hasCode ? Colors.green : Colors.orange,
                          hasCode ? Icons.qr_code : Icons.qr_code_scanner,
                        ),
                      ],
                    ),

                    const SizedBox(width: 8),

                    // Popup Menu Button - Compact
                    PopupMenuButton<String>(
                      icon: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      tooltip: 'ตัวเลือก',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TenantListDetailUi(
                                  tenantId: tenant['tenant_id'],
                                  onTenantUpdated: _loadTenants,
                                ),
                              ),
                            );
                            break;
                          case 'create_account':
                            _showCreateAccountDialog(tenant);
                            break;
                          case 'delete_account':
                            _showDeleteAccountDialog(tenant);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit,
                                  size: 16, color: Colors.blue[600]),
                              SizedBox(width: 8),
                              Text('แก้ไข', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'create_account',
                          enabled: tenant['has_account'] != true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_add,
                                size: 16,
                                color: tenant['has_account'] == true
                                    ? Colors.grey[400]
                                    : Colors.green[600],
                              ),
                              SizedBox(width: 8),
                              Text(
                                'สร้างบัญชี',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: tenant['has_account'] == true
                                      ? Colors.grey[400]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete_account',
                          enabled: tenant['has_account'] == true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_remove,
                                size: 16,
                                color: tenant['has_account'] == true
                                    ? Colors.red[600]
                                    : Colors.grey[400],
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ลบบัญชี',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: tenant['has_account'] == true
                                      ? Colors.red[600]
                                      : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ---------- Room Info Section - Compact ----------
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Room info - takes most space
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.home,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ห้อง ${tenant['room_number']}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        room['room_name'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.payments,
                                    size: 14, color: Colors.green[600]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${room['room_rate']} บาท/เดือน',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // QR Code section - compact
                      if (hasCode) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_2,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(height: 2),
                              Text(
                                tenant['tenant_code'],
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ---------- Compact Date and Status Row ----------
                Row(
                  children: [
                    // Contract dates - compact
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCompactDateCard(
                              icon: Icons.login,
                              label: 'เข้าพัก',
                              date: _formatCompactDate(tenantIn),
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCompactDateCard(
                              icon: Icons.logout,
                              label: 'สิ้นสุด',
                              date: _formatCompactDate(tenantOut),
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ---------- Status Badges Row - if needed ----------
                if (status != null ||
                    contactStatus != null ||
                    (isExpiringSoon && status == 'active')) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (status != null) _buildSimpleStatusBadge(status),
                      if (contactStatus != null)
                        _buildSimpleContactStatusBadge(contactStatus),
                      if (isExpiringSoon && status == 'active')
                        _buildSimpleWarningBadge(),
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

// Compact helper methods
  Widget _buildCompactStatusBadge(String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDateCard({
    required IconData icon,
    required String label,
    required String date,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            date,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'เข้าพัก';
        break;
      case 'suspended':
        color = Colors.orange;
        label = 'ระงับ';
        break;
      case 'checkout':
        color = Colors.red;
        label = 'ออก';
        break;
      case 'terminated':
        color = Colors.grey;
        label = 'ยกเลิก';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSimpleContactStatusBadge(String contactStatus) {
    Color color;
    String label;

    switch (contactStatus) {
      case 'reachable':
        color = Colors.green;
        label = 'ติดต่อได้';
        break;
      case 'unreachable':
        color = Colors.red;
        label = 'ติดต่อไม่ได้';
        break;
      case 'pending':
        color = Colors.orange;
        label = 'รอติดต่อ';
        break;
      default:
        return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSimpleWarningBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        'ใกล้หมดสัญญา',
        style: TextStyle(
          fontSize: 10,
          color: Colors.orange[700],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

// Compact date formatter
  String _formatCompactDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year.toString().substring(2)}';
  }

// Enhanced Dialog Methods
  void _showCreateAccountDialog(Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person_add_rounded, color: Colors.green[600]),
            ),
            SizedBox(width: 12),
            Text(
              'สร้างบัญชีผู้ใช้',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ผู้เช่า: ${tenant['tenant_full_name']}',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('เบอร์โทร: ${tenant['tenant_phone']}',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.blue[600], size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ระบบจะสร้างบัญชีผู้ใช้ให้กับผู้เช่าท่านนี้เพื่อเข้าใช้งานแอปพลิเคชัน',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createUserAccountWithNavigation(tenant);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'สร้างบัญชี',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_rounded, color: Colors.red[600]),
            ),
            SizedBox(width: 12),
            Text(
              'ลบบัญชีผู้ใช้',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ผู้เช่า: ${tenant['tenant_full_name']}',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('เบอร์โทร: ${tenant['tenant_phone']}',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red[600], size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'การลบบัญชีผู้ใช้จะทำให้ผู้เช่าไม่สามารถเข้าใช้งานแอปพลิเคชันได้ คุณต้องการดำเนินการต่อหรือไม่?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUserAccount(tenant);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'ลบบัญชี',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUserAccount(Map<String, dynamic> tenant) async {
    try {
      // Show enhanced loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red[600]!),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'กำลังลบบัญชีผู้ใช้...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Delete user account logic here
      await supabase.from('tenants').update({
        'has_account': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenant['tenant_id']);

      Navigator.pop(context); // Close loading dialog
      _showSuccessSnackBar('ลบบัญชีผู้ใช้สำเร็จ');
      _loadTenants();
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorSnackBar('เกิดข้อผิดพลาดในการลบบัญชี: $e');
    }
  }

// Enhanced SnackBar methods
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.error_rounded, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 4),
      ),
    );
  }

// =================== Helpers ===================

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
