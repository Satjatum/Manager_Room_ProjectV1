import 'package:flutter/material.dart';
import 'package:manager_room_project/views/superadmin/tenant_add_ui.dart';
import 'package:manager_room_project/views/superadmin/tenant_edit_ui.dart';
import 'package:manager_room_project/views/superadmin/tenantlist_detail_ui.dart';
import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../services/tenant_service.dart';
import '../../widgets/colors.dart';

class TenantListUI extends StatefulWidget {
  final String? branchId;
  final String? branchName;

  const TenantListUI({
    Key? key,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<TenantListUI> createState() => _TenantListUIState();
}

class _TenantListUIState extends State<TenantListUI> {
  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _filteredTenants = [];
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String? _selectedBranchId;
  UserModel? _currentUser;
  bool _isAnonymous = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthMiddleware.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isAnonymous = user == null;
      });
    } catch (e) {
      setState(() {
        _currentUser = null;
        _isAnonymous = true;
      });
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    if (_isAnonymous) {
      _loadTenants();
      return;
    }

    try {
      final branches = await TenantService.getBranchesForTenantFilter();
      if (mounted) {
        setState(() {
          _branches = branches;
        });
      }
    } catch (e) {
      print('Error loading branches: $e');
    }
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> tenants;

      if (_isAnonymous) {
        tenants = [];
      } else if (_currentUser!.userRole == UserRole.superAdmin ||
          _currentUser!.userRole == UserRole.admin) {
        tenants = await TenantService.getAllTenants(
          branchId: _selectedBranchId,
          isActive:
              _selectedStatus == 'all' ? null : _selectedStatus == 'active',
        );
      } else {
        tenants =
            await TenantService.getTenantsByUser(branchId: _selectedBranchId);
      }

      if (mounted) {
        setState(() {
          _tenants = tenants;
          _filteredTenants = _tenants;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _tenants = [];
          _filteredTenants = [];
        });
        print('เกิดข้อผิดพลาดในการโหลดข้อมูล ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ลองใหม่',
              textColor: Colors.white,
              onPressed: _loadTenants,
            ),
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterTenants();
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status ?? 'all';
    });
    _loadTenants();
  }

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId;
    });
    _loadTenants();
  }

  void _filterTenants() {
    if (!mounted) return;
    setState(() {
      _filteredTenants = _tenants.where((tenant) {
        final searchTerm = _searchQuery.toLowerCase();
        final matchesSearch = (tenant['tenant_fullname'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (tenant['tenant_idcard'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (tenant['tenant_phone'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm);

        return matchesSearch;
      }).toList();
    });
  }

  String _getActiveFiltersText() {
    List<String> filters = [];

    if (_selectedBranchId != null) {
      final branch = _branches.firstWhere(
        (b) => b['branch_id'] == _selectedBranchId,
        orElse: () => {},
      );
      if (branch.isNotEmpty) {
        filters.add('สาขา: ${branch['branch_name']}');
      }
    }

    if (_selectedStatus != 'all') {
      filters.add(_selectedStatus == 'active' ? 'เปิดใช้งาน' : 'ปิดใช้งาน');
    }

    if (_searchQuery.isNotEmpty) {
      filters.add('ค้นหา: "$_searchQuery"');
    }

    return filters.isEmpty ? 'แสดงทั้งหมด' : filters.join(' • ');
  }

  void _showLoginPrompt(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.login, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('ต้องเข้าสู่ระบบ'),
          ],
        ),
        content: Text('คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถ$actionได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTenantStatus(
      String tenantId, String tenantName, bool currentStatus) async {
    if (_isAnonymous) {
      _showLoginPrompt('เปลี่ยนสถานะผู้เช่า');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('เปลี่ยนสถานะผู้เช่า $tenantName'),
        content: Text(currentStatus
            ? 'คุณต้องการปิดใช้งานผู้เช่านี้ใช่หรือไม่?'
            : 'คุณต้องการเปิดใช้งานผู้เช่านี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );

        final result = await TenantService.toggleTenantStatus(tenantId);

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            await _loadTenants();
          } else {
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddTenant() async {
    if (_isAnonymous) {
      _showLoginPrompt('เพิ่มผู้เช่า');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenantAddUI(
          branchId: widget.branchId,
          branchName: widget.branchName,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadTenants();
    }
  }

  bool get _canManage =>
      !_isAnonymous &&
      (_currentUser?.userRole == UserRole.superAdmin ||
          _currentUser?.userRole == UserRole.admin ||
          _currentUser?.hasAnyPermission([
                DetailedPermission.all,
                DetailedPermission.manageTenants,
              ]) ==
              true);

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการผู้เช่า'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedStatus != 'all')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 8, height: 8),
                    ),
                  ),
              ],
            ),
            tooltip: 'กรองข้อมูล',
            itemBuilder: (context) => [
              if (!_isAnonymous) ...[
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'สถานะการใช้งาน',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'active_status:all',
                  child: Row(
                    children: [
                      Icon(
                        _selectedStatus == 'all'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('ทั้งหมด'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'active_status:active',
                  child: Row(
                    children: [
                      Icon(
                        _selectedStatus == 'active'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      const Text('เปิดใช้งาน'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'active_status:inactive',
                  child: Row(
                    children: [
                      Icon(
                        _selectedStatus == 'inactive'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      const Text('ปิดใช้งาน'),
                    ],
                  ),
                ),
                if (_selectedStatus != 'all') ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'ล้างตัวกรองทั้งหมด',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
            onSelected: (value) {
              if (value == 'clear_all') {
                setState(() {
                  _selectedStatus = 'all';
                });
                _loadTenants();
              } else if (value.startsWith('active_status:')) {
                final status = value.split(':')[1];
                _onStatusChanged(status);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTenants,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาผู้เช่า (ชื่อ, เบอร์โทร, บัตรประชาชน)',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[700]),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                if (_branches.isNotEmpty && widget.branchId == null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedBranchId ?? 'all',
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('ทุกสาขา'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'null',
                          child: Text('ยังไม่ระบุสาขา'),
                        ),
                        ..._branches.map((branch) {
                          return DropdownMenuItem<String>(
                            value: branch['branch_id'] as String,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    branch['branch_name'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // แสดงจำนวนผู้ดูแล (ถ้ามี)
                                if (branch['manager_count'] != null &&
                                    branch['manager_count'] > 0)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.people,
                                          size: 10,
                                          color: Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${branch['manager_count']}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        _onBranchChanged(value == 'all' ? null : value);
                      },
                    ),
                  ),
                ],
                if (_selectedBranchId != null ||
                    _selectedStatus != 'all' ||
                    _searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list_alt,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getActiveFiltersText(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedBranchId = widget.branchId;
                              _selectedStatus = 'all';
                              _searchQuery = '';
                              _searchController.clear();
                            });
                            _loadTenants();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        const SizedBox(height: 16),
                        const Text('กำลังโหลดข้อมูล...'),
                      ],
                    ),
                  )
                : _filteredTenants.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadTenants,
                        color: AppTheme.primary,
                        child:
                            isWideScreen ? _buildGridView() : _buildListView(),
                      ),
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddTenant,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('เพิ่มผู้เช่า'),
              tooltip: 'เพิ่มผู้เช่าใหม่',
            )
          : null,
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTenants.length,
      itemBuilder: (context, index) {
        final tenant = _filteredTenants[index];
        return _buildTenantCard(tenant, _canManage);
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 280,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredTenants.length,
      itemBuilder: (context, index) {
        final tenant = _filteredTenants[index];
        return _buildTenantCard(tenant, _canManage);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _isAnonymous
                ? 'กรุณาเข้าสู่ระบบเพื่อดูข้อมูลผู้เช่า'
                : _searchQuery.isNotEmpty
                    ? 'ไม่พบผู้เช่าที่ค้นหา'
                    : 'ยังไม่มีผู้เช่า',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'ลองเปลี่ยนคำค้นหา หรือกรองสถานะ'
                : _isAnonymous
                    ? ''
                    : 'เริ่มต้นโดยการเพิ่มผู้เช่าใหม่',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          if (_searchQuery.isEmpty && _canManage)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: _navigateToAddTenant,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มผู้เช่า'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant, bool canManage) {
    final isActive = tenant['is_active'] ?? false;
    final gender = tenant['gender'];
    final profileImageUrl = tenant['tenant_profile'];
    final tenantId = tenant['tenant_id'];
    final branchName = tenant['branch_name'] ?? 'ไม่ระบุสาขา';
    final hasBranch = tenant['branch_id'] != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 380;
    final profileSize = compact ? 48.0 : 56.0;

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TenantDetailUI(tenantId: tenantId),
            ),
          );

          if (result == true && mounted) {
            await _loadTenants();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row - Profile + Name + Status + Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileImage(
                    profileImageUrl: profileImageUrl,
                    gender: gender,
                    tenantName: tenant['tenant_fullname'] ?? '',
                  ),
                  SizedBox(width: compact ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tenant['tenant_fullname'] ?? 'ไม่ระบุ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.badge,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tenant['tenant_idcard'] ?? 'ไม่ระบุ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
                  SizedBox(width: compact ? 4 : 8),
                  // Actions menu
                  _buildActionsMenu(tenant, canManage, isActive),
                  SizedBox(width: compact ? 6 : 8),
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.cancel,
                          size: 12,
                          color: isActive ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'เปิด' : 'ปิด',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Phone Number
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tenant['tenant_phone'] ?? 'ไม่ระบุ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Branch Information
              Row(
                children: [
                  Icon(
                    Icons.business,
                    size: 14,
                    color: hasBranch ? Colors.grey[600] : Colors.orange[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            branchName,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasBranch
                                  ? Colors.grey[600]
                                  : Colors.orange[600],
                              fontStyle: hasBranch
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Manager count badge
                        if (hasBranch &&
                            tenant['branch_manager_count'] != null &&
                            tenant['branch_manager_count'] > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 8,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${tenant['branch_manager_count']}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Action Buttons moved to PopupMenu (header)
              // Keep card clean – no inline buttons below
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsMenu(
      Map<String, dynamic> tenant, bool canManage, bool isActive) {
    final tenantId = tenant['tenant_id'];
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[700]),
      tooltip: 'การทำงาน',
      onSelected: (value) async {
        switch (value) {
          case 'view':
            if (_isAnonymous) {
              _showLoginPrompt('ดูรายละเอียด');
              return;
            }
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TenantDetailUI(tenantId: tenantId),
              ),
            );
            if (result == true && mounted) {
              await _loadTenants();
            }
            break;
          case 'edit':
            if (_isAnonymous) {
              _showLoginPrompt('แก้ไข');
              return;
            }
            if (!canManage) return;
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TenantEditUI(
                  tenantId: tenantId,
                  tenantData: tenant,
                ),
              ),
            );
            if (result == true && mounted) {
              await _loadTenants();
            }
            break;
          case 'toggle':
            if (_isAnonymous) {
              _showLoginPrompt(isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน');
              return;
            }
            if (!canManage) return;
            _toggleTenantStatus(
              tenant['tenant_id'],
              tenant['tenant_fullname'] ?? '',
              isActive,
            );
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: const [
              Icon(Icons.visibility, size: 18),
              SizedBox(width: 8),
              Text('ดูรายละเอียด'),
            ],
          ),
        ),
        if (canManage)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: const [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('แก้ไข'),
              ],
            ),
          ),
        if (canManage)
          PopupMenuItem(
            value: 'toggle',
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: isActive ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProfileImage({
    required String? profileImageUrl,
    required String? gender,
    required String tenantName,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final size = screenWidth < 380 ? 48.0 : 56.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.primary.withOpacity(0.1),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: profileImageUrl != null && profileImageUrl.isNotEmpty
            ? Image.network(
                profileImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildProfileFallback(tenantName);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  );
                },
              )
            : _buildProfileFallback(tenantName),
      ),
    );
  }

  Widget _buildProfileFallback(String tenantName) {
    return Container(
      color: AppTheme.primary.withOpacity(0.1),
      child: Center(
        child: Text(
          _getInitials(tenantName),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'T';

    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else {
      return words[0][0].toUpperCase();
    }
  }
}
