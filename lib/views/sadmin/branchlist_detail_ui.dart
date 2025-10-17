import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/roomlist_ui.dart';
import 'package:manager_room_project/views/sadmin/tenantlist_ui.dart';
import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../services/branch_service.dart';
import '../../services/branch_manager_service.dart';
import '../../widgets/colors.dart';
import 'branch_edit_ui.dart';

class BranchListDetail extends StatefulWidget {
  final String branchId;

  const BranchListDetail({
    Key? key,
    required this.branchId,
  }) : super(key: key);

  @override
  State<BranchListDetail> createState() => _BranchListDetailState();
}

class _BranchListDetailState extends State<BranchListDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _branchManagers = [];
  Map<String, dynamic>? _branchData;
  Map<String, dynamic> _branchStats = {};
  bool _isLoadingManagers = false;
  bool _isLoading = true;
  UserModel? _currentUser;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    _loadBranchDetails();
  }

  Future<void> _loadBranchManagers() async {
    setState(() => _isLoadingManagers = true);
    try {
      final managers =
          await BranchManagerService.getBranchManagers(widget.branchId);
      if (mounted) {
        setState(() {
          _branchManagers = managers;
          _isLoadingManagers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingManagers = false);
      }
      print('Error loading managers: $e');
    }
  }

  Future<void> _loadBranchDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final branchData = await BranchService.getBranchById(widget.branchId);
      final stats = await BranchService.getBranchStatistics(widget.branchId);
      await _loadBranchManagers(); // เพิ่มบรรทัดนี้

      if (mounted) {
        setState(() {
          _branchData = branchData;
          _branchStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBranchStatus() async {
    if (_isAnonymous || _branchData == null) return;

    final currentStatus = _branchData!['is_active'] ?? false;
    final branchName = _branchData!['branch_name'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              currentStatus ? Icons.visibility_off : Icons.visibility,
              color: currentStatus ? Colors.orange : Colors.green,
            ),
            SizedBox(width: 12),
            Text(currentStatus ? 'ปิดใช้งานสาขา' : 'เปิดใช้งานสาขา'),
          ],
        ),
        content: Text(
          'คุณต้องการ${currentStatus ? 'ปิด' : 'เปิด'}ใช้งานสาขา "$branchName" ใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(currentStatus ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await BranchService.toggleBranchStatus(widget.branchId);

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
              ),
            );
            await _loadBranchDetails();
          } else {
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteBranch() async {
    if (_isAnonymous || _branchData == null) return;

    final branchName = _branchData!['branch_name'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('ยืนยันการลบสาขา'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คุณต้องการลบสาขา "$branchName" ใช่หรือไม่?'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'การลบจะไม่สามารถกู้คืนได้',
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('ลบสาขา'),
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
            child: CircularProgressIndicator(),
          ),
        );

        final result = await BranchService.deleteBranch(widget.branchId);

        if (mounted) Navigator.pop(context);

        if (mounted) {
          if (result['success']) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(bool isActive) {
    return isActive ? Colors.green : Colors.orange;
  }

  String _getStatusText(bool isActive) {
    return isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน';
  }

  bool get _canManage {
    if (_isAnonymous) return false;
    // SuperAdmin can manage all branches
    if (_currentUser?.userRole == UserRole.superAdmin) return true;
    // Admin can manage only branches they are assigned to (as branch manager)
    if (_currentUser?.userRole == UserRole.admin) {
      final uid = _currentUser!.userId;
      return _branchManagers.any((m) {
        final directId = m['user_id'];
        final nested = m['users'] as Map<String, dynamic>?;
        final nestedId = nested?['user_id'];
        return directId == uid || nestedId == uid;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('รายละเอียดสาขา'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_branchData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('รายละเอียดสาขา'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('ไม่พบข้อมูลสาขา'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('กลับ'),
              ),
            ],
          ),
        ),
      );
    }

    final isActive = _branchData!['is_active'] ?? false;
    final statusColor = _getStatusColor(isActive);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeaderImage(),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // Branch Info Header
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _branchData!['branch_name'] ?? 'ไม่มีชื่อ',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: statusColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _getStatusText(isActive),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primary,
              tabs: [
                Tab(icon: Icon(Icons.info), text: 'ข้อมูลสาขา'),
                Tab(icon: Icon(Icons.analytics), text: 'สถิติ'),
                Tab(icon: Icon(Icons.settings), text: 'จัดการ'),
              ],
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(),
                  _buildStatsTab(),
                  _buildManageTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderImage() {
    final hasImage = _branchData!['branch_image'] != null &&
        _branchData!['branch_image'].toString().isNotEmpty;

    if (hasImage) {
      return Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            child: Image.network(
              _branchData!['branch_image'],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultHeader(),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return _buildDefaultHeader();
  }

  Widget _buildDefaultHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business,
                size: 80, color: Colors.white.withOpacity(0.7)),
            SizedBox(height: 16),
            Text(
              'ไม่มีรูปภาพสาขา',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return RefreshIndicator(
      onRefresh: _loadBranchDetails,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              'ข้อมูลพื้นฐาน',
              Icons.info_outline,
              [
                _buildInfoRow(
                    'ชื่อสาขา', _branchData!['branch_name'] ?? 'ไม่ระบุ'),
                _buildInfoRow(
                    'รหัสสาขา', _branchData!['branch_code'] ?? 'ไม่ระบุ'),
                _buildInfoRow(
                    'ที่อยู่', _branchData!['branch_address'] ?? 'ไม่ระบุ'),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoCard(
              'ข้อมูลผู้ดูแล',
              Icons.people_outline,
              [
                if (_isLoadingManagers)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  )
                else if (_branchManagers.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'ยังไม่มีผู้ดูแลสาขา',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                else
                  ..._branchManagers.map((manager) {
                    final userData = manager['users'] as Map<String, dynamic>;
                    final isPrimary = manager['is_primary'] == true;
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? Colors.blue.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPrimary
                              ? Colors.blue.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isPrimary
                                  ? Colors.blue.shade200
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: isPrimary
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData['user_name'] ?? 'ไม่มีชื่อ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  userData['user_email'] ?? 'ไม่มีอีเมล',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPrimary)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'ผู้ดูแลหลัก',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
            if (_branchData!['branch_desc'] != null &&
                _branchData!['branch_desc'].toString().isNotEmpty) ...[
              SizedBox(height: 16),
              _buildInfoCard(
                'รายละเอียดเพิ่มเติม',
                Icons.description_outlined,
                [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _branchData!['branch_desc'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadBranchDetails,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'ห้องทั้งหมด',
                    _branchStats['total_rooms']?.toString() ?? '0',
                    Icons.hotel,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'ห้องที่มีผู้เช่า',
                    _branchStats['occupied_rooms']?.toString() ?? '0',
                    Icons.people,
                    Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'ห้องว่าง',
                    _branchStats['available_rooms']?.toString() ?? '0',
                    Icons.hotel_outlined,
                    Colors.orange,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'ห้องซ่อมบำรุง',
                    _branchStats['maintenance_rooms']?.toString() ?? '0',
                    Icons.build,
                    Colors.amber,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'อัตราการเข้าพัก',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildOccupancyChart(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageTab() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ดูห้องพักในสาขา
          _buildManageCard(
            icon: Icons.hotel,
            title: 'ดูห้องพักในสาขา',
            subtitle: 'ดูรายการห้องพักทั้งหมดในสาขานี้',
            color: Colors.blue,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoomListUI(
                    branchId: widget.branchId,
                    branchName: _branchData!['branch_name'] ?? '',
                  ),
                ),
              );
              if (result == true) {
                await _loadBranchDetails();
              }
            },
          ),
          SizedBox(height: 12),

          // ดูผู้เช่าในสาขา
          _buildManageCard(
            icon: Icons.person_outline,
            title: 'ดูผู้เช่าในสาขา',
            subtitle: 'ดูรายชื่อผู้เช่าทั้งหมดในสาขานี้',
            color: Colors.green,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TenantListUI(
                    branchId: widget.branchId,
                    branchName: _branchData!['branch_name'] ?? '',
                  ),
                ),
              );
              if (result == true) {
                await _loadBranchDetails();
              }
            },
          ),
          SizedBox(height: 12),

          if (_canManage) ...[
            // แก้ไขข้อมูลสาขา
            _buildManageCard(
              icon: Icons.edit,
              title: 'แก้ไขข้อมูลสาขา',
              subtitle: 'แก้ไขข้อมูลและรายละเอียดสาขา',
              color: Colors.yellow,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BranchEditPage(
                      branchId: widget.branchId,
                    ),
                  ),
                );
                if (result == true) {
                  await _loadBranchDetails();
                }
              },
            ),
            SizedBox(height: 12),

            // เปิด/ปิดใช้งานสาขา
            _buildManageCard(
              icon: isActive ? Icons.visibility_off : Icons.visibility,
              title: isActive ? 'ปิดใช้งานสาขา' : 'เปิดใช้งานสาขา',
              subtitle: isActive
                  ? 'ปิดการแสดงผลสาขานี้ในระบบ'
                  : 'เปิดการแสดงผลสาขานี้ในระบบ',
              color: isActive ? Colors.orange : Colors.green,
              onTap: _toggleBranchStatus,
            ),
            SizedBox(height: 12),

            // ลบสาขา (SuperAdmin only)
            if (_currentUser?.userRole == UserRole.superAdmin)
              _buildManageCard(
                icon: Icons.delete_forever,
                title: 'ลบสาขา',
                subtitle: 'ลบสาขานี้ออกจากระบบถาวร',
                color: Colors.red,
                onTap: _deleteBranch,
              ),
          ] else if (_isAnonymous) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'เข้าสู่ระบบเพื่อเข้าถึงเมนูจัดการ',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
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
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Text(': ', style: TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupancyChart() {
    final totalRooms = _branchStats['total_rooms'] ?? 0;
    final occupiedRooms = _branchStats['occupied_rooms'] ?? 0;
    final occupancyRate = totalRooms > 0 ? (occupiedRooms / totalRooms) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('อัตราการเข้าพัก',
                style: TextStyle(fontWeight: FontWeight.w500)),
            Text('${(occupancyRate * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: occupancyRate,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              occupancyRate > 0.8
                  ? Colors.green
                  : occupancyRate > 0.5
                      ? Colors.orange
                      : Colors.red,
            ),
            minHeight: 8,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('มีผู้เช่า', style: TextStyle(fontSize: 12)),
                  Text('$occupiedRooms',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('ห้องว่าง', style: TextStyle(fontSize: 12)),
                  Text('${totalRooms - occupiedRooms}',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManageCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  bool get isActive => _branchData?['is_active'] ?? false;
}
