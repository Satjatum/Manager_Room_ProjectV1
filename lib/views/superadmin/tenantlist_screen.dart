import 'package:flutter/material.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';

class TenantListScreen extends StatefulWidget {
  final String? preSelectedBranchId;

  const TenantListScreen({
    Key? key,
    this.preSelectedBranchId,
  }) : super(key: key);

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _filteredTenants = [];

  bool _isLoading = false;
  String? _selectedBranchId;
  String _selectedStatusFilter = 'all';
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
            has_account, room_number, last_access_at,
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

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _tenants;

    // กรองตามสถานะ
    if (_selectedStatusFilter != 'all') {
      filtered = filtered
          .where((tenant) => tenant['tenant_status'] == _selectedStatusFilter)
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

  void _showTenantDetails(Map<String, dynamic> tenant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTenantDetailsSheet(tenant),
    );
  }

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
    return Scaffold(
      appBar: AppBar(
        title: Text('รายชื่อผู้เช่า'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTenants,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header พร้อมตัวกรองและค้นหา
          _buildFilterHeader(),

          // สถิติ
          _buildStatisticsRow(),

          // รายการผู้เช่า
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
          Navigator.pushNamed(context, '/add-tenant')
              ?.then((_) => _loadTenants());
        },
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      color: Colors.grey[50],
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // เลือกสาขา
          if (_branches.length > 1) ...[
            Row(
              children: [
                Icon(Icons.business, color: AppColors.primary),
                SizedBox(width: 12),
                Text('สาขา: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBranchId,
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
            SizedBox(height: 12),
          ],

          // ช่องค้นหา
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อ, เบอร์โทร, บัตร, ห้อง หรือรหัสผู้เช่า...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applyFilters();
            },
          ),

          SizedBox(height: 12),

          // ตัวกรองสถานะ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('all', 'ทั้งหมด', Icons.people),
                SizedBox(width: 8),
                _buildStatusChip('active', 'เข้าพักแล้ว', Icons.check_circle),
                SizedBox(width: 8),
                _buildStatusChip(
                    'suspended', 'ระงับชั่วคราว', Icons.pause_circle),
                SizedBox(width: 8),
                _buildStatusChip('checkout', 'ออกจากห้อง', Icons.exit_to_app),
                SizedBox(width: 8),
                _buildStatusChip('terminated', 'ยกเลิกสัญญา', Icons.cancel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String value, String label, IconData icon) {
    final isSelected = _selectedStatusFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16, color: isSelected ? Colors.white : Colors.grey[600]),
          SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedStatusFilter = value;
        });
        _applyFilters();
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontSize: 12,
      ),
    );
  }

  Widget _buildStatisticsRow() {
    final totalTenants = _tenants.length;
    final activeTenants =
        _tenants.where((t) => t['tenant_status'] == 'active').length;
    final suspendedTenants =
        _tenants.where((t) => t['tenant_status'] == 'suspended').length;
    final checkedOutTenants =
        _tenants.where((t) => t['tenant_status'] == 'checkout').length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildStatItem('ทั้งหมด', totalTenants, Colors.blue),
          _buildStatItem('เข้าพัก', activeTenants, Colors.green),
          _buildStatItem('ระงับ', suspendedTenants, Colors.orange),
          _buildStatItem('ออกแล้ว', checkedOutTenants, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
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
            _searchQuery.isNotEmpty || _selectedStatusFilter != 'all'
                ? 'ไม่พบผู้เช่าตามเงื่อนไขที่กำหนด'
                : 'ยังไม่มีผู้เช่าในสาขานี้',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (_searchQuery.isNotEmpty || _selectedStatusFilter != 'all') ...[
            SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedStatusFilter = 'all';
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
    final hasCode = tenant['tenant_code'] != null &&
        tenant['tenant_code'].toString().isNotEmpty;
    final hasAccount = tenant['has_account'] == true;

    final tenantIn = DateTime.parse(tenant['tenant_in']);
    final tenantOut = DateTime.parse(tenant['tenant_out']);
    final isExpiringSoon = tenantOut.difference(DateTime.now()).inDays <= 30;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showTenantDetails(tenant),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant['tenant_full_name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone,
                                size: 14, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text(
                              tenant['tenant_phone'],
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusBadge(status),
                      if (isExpiringSoon && status == 'active') ...[
                        SizedBox(height: 4),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ใกล้หมดสัญญา',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              SizedBox(height: 12),

              // ข้อมูลห้องและรหัส
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.home,
                                size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'ห้อง ${tenant['room_number']} - ${room['room_name']}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${room['room_rate']} บาท/เดือน',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasCode)
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.qr_code,
                                size: 16, color: AppColors.primary),
                            SizedBox(height: 2),
                            Text(
                              tenant['tenant_code'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 12),

              // วันที่เข้าพักและออก
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.login, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          '${tenantIn.day}/${tenantIn.month}/${tenantIn.year}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          '${tenantOut.day}/${tenantOut.month}/${tenantOut.year}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  // ปุ่มเปลี่ยนสถานะ
                  InkWell(
                    onTap: () => _showStatusUpdateDialog(tenant),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.more_vert,
                          size: 16, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),

              // ไอคอนสถานะ
              SizedBox(height: 8),
              Row(
                children: [
                  if (hasAccount) ...[
                    Icon(Icons.account_circle, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text('มีบัญชี',
                        style: TextStyle(fontSize: 11, color: Colors.blue)),
                    SizedBox(width: 12),
                  ],
                  if (tenant['last_access_at'] != null) ...[
                    Icon(Icons.access_time, size: 16, color: Colors.green),
                    SizedBox(width: 4),
                    Text('เข้าใช้งาน',
                        style: TextStyle(fontSize: 11, color: Colors.green)),
                  ],
                ],
              ),
            ],
          ),
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
        icon = Icons.check_circle;
        break;
      case 'suspended':
        color = Colors.orange;
        label = 'ระงับชั่วคราว';
        icon = Icons.pause_circle;
        break;
      case 'checkout':
        color = Colors.red;
        label = 'ออกจากห้อง';
        icon = Icons.exit_to_app;
        break;
      case 'terminated':
        color = Colors.grey;
        label = 'ยกเลิกสัญญา';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
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
                            // TODO: Navigate to edit tenant screen
                          },
                          icon: Icon(Icons.person_outline),
                          label: Text('แก้ไขข้อมูล'),
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
