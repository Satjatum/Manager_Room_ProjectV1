import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:manager_room_project/views/superadmin/roomdetail_ui.dart';
import 'package:manager_room_project/views/superadmin/addtenant_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/views/superadmin/editbranch_ui.dart';
import 'package:manager_room_project/views/superadmin/addroom_ui.dart';

class BranchDetailScreen extends StatefulWidget {
  final Map<String, dynamic> branch;

  const BranchDetailScreen({
    Key? key,
    required this.branch,
  }) : super(key: key);

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

final supabase = Supabase.instance.client;

class _BranchDetailScreenState extends State<BranchDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic> _branchData = {};
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _filteredRooms = [];

  bool _isLoading = false;
  bool _isLoadingRooms = false;
  String _searchQuery = '';
  String _selectedRoomStatus = 'all';
  String _selectedRoomCategory = 'all';

  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // สถิติสาขา
  Map<String, dynamic> _branchStats = {
    'total_rooms': 0,
    'occupied_rooms': 0,
    'available_rooms': 0,
    'maintenance_rooms': 0,
    'total_tenants': 0,
    'monthly_revenue': 0.0,
    'pending_payments': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _branchData = Map<String, dynamic>.from(widget.branch);
    _loadBranchDetails();
    _loadBranchStats();
    _loadRoomData();
  }

  Future<void> _loadBranchDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('branches')
          .select('*')
          .eq('branch_id', _branchData['branch_id'])
          .single();

      // โหลดข้อมูล owner แยกต่างหาก
      if (response['owner_id'] != null) {
        try {
          final ownerResponse = await supabase
              .from('users')
              .select('username, user_email, user_profile')
              .eq('user_id', response['owner_id'])
              .single();

          response['owner_name'] =
              ownerResponse['username'] ?? response['owner_name'] ?? 'ไม่ระบุ';
          response['owner_email'] = ownerResponse['user_email'] ?? '';
          response['owner_profile'] = ownerResponse['user_profile'];
        } catch (e) {
          response['owner_name'] = response['owner_name'] ?? 'ไม่ระบุ';
          response['owner_email'] = '';
        }
      } else {
        response['owner_name'] = response['owner_name'] ?? 'ไม่ระบุ';
        response['owner_email'] = '';
      }

      setState(() {
        _branchData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดรายละเอียด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadBranchStats() async {
    try {
      // โหลดสถิติห้อง จาก rooms table
      final roomsResponse = await supabase
          .from('rooms')
          .select('room_status')
          .eq('branch_id', _branchData['branch_id']);

      // โหลดสถิติผู้เช่า จาก tenants table
      final tenantsResponse = await supabase
          .from('tenants')
          .select('tenant_id, tenant_status')
          .eq('branch_id', _branchData['branch_id'])
          .eq('tenant_status', 'active');

      // โหลดสถิติการชำระเงิน จาก bills table (เดือนนี้)
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final paymentsResponse = await supabase
          .from('bills')
          .select('bill_amount, payment_status')
          .eq('branch_id', _branchData['branch_id'])
          .gte('created_at', firstDayOfMonth.toIso8601String());

      // คำนวดสถิติ
      final totalRooms = roomsResponse.length;
      final occupiedRooms = roomsResponse
          .where((room) => room['room_status'] == 'occupied')
          .length;
      final availableRooms = roomsResponse
          .where((room) => room['room_status'] == 'available')
          .length;
      final maintenanceRooms = roomsResponse
          .where((room) => room['room_status'] == 'maintenance')
          .length;

      final totalTenants = tenantsResponse.length;

      double monthlyRevenue = 0.0;
      int pendingPayments = 0;

      for (var payment in paymentsResponse) {
        if (payment['payment_status'] == 'paid') {
          monthlyRevenue += (payment['bill_amount'] ?? 0.0).toDouble();
        } else if (payment['payment_status'] == 'pending') {
          pendingPayments++;
        }
      }

      setState(() {
        _branchStats = {
          'total_rooms': totalRooms,
          'occupied_rooms': occupiedRooms,
          'available_rooms': availableRooms,
          'maintenance_rooms': maintenanceRooms,
          'total_tenants': totalTenants,
          'monthly_revenue': monthlyRevenue,
          'pending_payments': pendingPayments,
        };
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() {
        _branchStats = {
          'total_rooms': 0,
          'occupied_rooms': 0,
          'available_rooms': 0,
          'maintenance_rooms': 0,
          'total_tenants': 0,
          'monthly_revenue': 0.0,
          'pending_payments': 0,
        };
      });
    }
  }

  Future<void> _loadRoomData() async {
    setState(() {
      _isLoadingRooms = true;
    });

    try {
      // โหลดห้องทั้งหมดของสาขา
      final roomsResponse = await supabase
          .from('rooms')
          .select('*')
          .eq('branch_id', _branchData['branch_id'])
          .order('room_number');

      setState(() {
        _rooms = List<Map<String, dynamic>>.from(roomsResponse);
        _filteredRooms = _rooms;
      });

      _filterRooms();
    } catch (e) {
      print('Error loading rooms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลห้อง: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingRooms = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterRooms();
  }

  void _onStatusFilterChanged(String? status) {
    setState(() {
      _selectedRoomStatus = status ?? 'all';
    });
    _filterRooms();
  }

  void _onCategoryFilterChanged(String? category) {
    setState(() {
      _selectedRoomCategory = category ?? 'all';
    });
    _filterRooms();
  }

  void _filterRooms() {
    setState(() {
      _filteredRooms = _rooms.where((room) {
        final searchTerm = _searchQuery.toLowerCase();
        final matchesSearch = (room['room_number'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (room['room_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm);

        final matchesStatus = _selectedRoomStatus == 'all' ||
            room['room_status'] == _selectedRoomStatus;

        final matchesCategory = _selectedRoomCategory == 'all' ||
            room['room_cate'] == _selectedRoomCategory;

        return matchesSearch && matchesStatus && matchesCategory;
      }).toList();
    });
  }

  Future<void> _updateBranchImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);

        await supabase.from('branches').update({
          'branch_image': base64String,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('branch_id', _branchData['branch_id']);

        setState(() {
          _branchData['branch_image'] = base64String;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('อัพเดทรูปภาพสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการอัพเดทรูปภาพ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBranchStatus() async {
    final currentStatus = _branchData['branch_status'] ?? 'active';
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';

    try {
      await supabase.from('branches').update({
        'branch_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('branch_id', _branchData['branch_id']);

      setState(() {
        _branchData['branch_status'] = newStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัพเดทสถานะสาขาสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBranch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'คุณต้องการลบสาขา "${_branchData['branch_name']}" ใช่หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้ และจะส่งผลกระทบต่อข้อมูลที่เกี่ยวข้องทั้งหมด'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase
            .from('branches')
            .delete()
            .eq('branch_id', _branchData['branch_id']);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ลบสาขาสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleRoomStatus(String roomId, String currentStatus) async {
    String newStatus;
    switch (currentStatus) {
      case 'available':
        newStatus = 'maintenance';
        break;
      case 'maintenance':
        newStatus = 'available';
        break;
      case 'occupied':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถเปลี่ยนสถานะห้องที่มีผู้เช่าอยู่ได้'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      default:
        newStatus = 'available';
    }

    try {
      await supabase.from('rooms').update({
        'room_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('room_id', roomId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัพเดทสถานะห้องสำเร็จ'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _loadRoomData();
      await _loadBranchStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoom(String roomId, String roomNumber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
          'คุณต้องการลบห้อง "$roomNumber" ใช่หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('rooms').delete().eq('room_id', roomId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ลบห้องสำเร็จ'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        await _loadRoomData();
        await _loadBranchStats();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // ฟังก์ชันเพิ่มผู้เช่าใหม่
  Future<void> _addTenant() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTenantScreen(
          preSelectedBranchId: _branchData['branch_id'],
        ),
      ),
    );

    if (result == true) {
      // รีเฟรชข้อมูลหลังเพิ่มผู้เช่าสำเร็จ
      await _loadBranchStats();
      await _loadRoomData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เพิ่มผู้เช่าสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.getCurrentUser();
    final canManage = currentUser?.isSuperAdmin ??
        (currentUser?.isAdmin ??
            false && currentUser?.userId == _branchData['owner_id']);
    final status = _branchData['branch_status'] ?? 'active';
    final statusColor = _getStatusColor(status);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 300,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                if (canManage)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditBranchScreen(branch: _branchData),
                            ),
                          );
                          if (result == true) {
                            await _loadBranchDetails();
                          }
                          break;
                        case 'toggle_status':
                          await _toggleBranchStatus();
                          break;
                        case 'delete':
                          await _deleteBranch();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('แก้ไข'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Row(
                          children: [
                            Icon(
                              status == 'active'
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 20,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(status == 'active'
                                ? 'ปิดใช้งาน'
                                : 'เปิดใช้งาน'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('ลบสาขา', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
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
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _branchData['branch_name'] ?? 'ไม่มีชื่อ',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                _getStatusText(status),
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
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.info), text: 'รายละเอียด'),
                Tab(icon: Icon(Icons.analytics), text: 'สถิติ'),
                Tab(icon: Icon(Icons.hotel), text: 'จัดการห้อง'),
              ],
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(),
                  _buildStatsTab(),
                  _buildRoomManagementTab(canManage),
                ],
              ),
            ),
          ],
        ),
      ),
      // FloatingActionButton แบบ Dynamic
      floatingActionButton: canManage ? _buildFloatingActionButton() : null,
    );
  }

  // FloatingActionButton แบบ Dynamic ตาม Tab ที่เลือก
  Widget _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 2: // Tab จัดการห้อง
        return FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddRoomUI(
                  branchId: _branchData['branch_id'],
                  branchName: _branchData['branch_name'],
                ),
              ),
            );
            if (result == true) {
              await _loadRoomData();
              await _loadBranchStats();
            }
          },
          backgroundColor: AppColors.primary,
          heroTag: "addRoom",
          child: const Icon(Icons.add, color: Colors.white),
        );
      case 1: // Tab สถิติ - เพิ่มผู้เช่า
        return FloatingActionButton.extended(
          onPressed: _addTenant,
          backgroundColor: Colors.green,
          heroTag: "addTenant",
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text(
            'เพิ่มผู้เช่า',
            style: TextStyle(color: Colors.white),
          ),
        );
      default: // Tab รายละเอียด - เพิ่มผู้เช่า
        return FloatingActionButton.extended(
          onPressed: _addTenant,
          backgroundColor: Colors.green,
          heroTag: "addTenantDefault",
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text(
            'เพิ่มผู้เช่า',
            style: TextStyle(color: Colors.white),
          ),
        );
    }
  }

  Widget _buildHeaderImage() {
    final hasImage = _branchData['branch_image'] != null &&
        _branchData['branch_image'].toString().isNotEmpty;

    if (hasImage) {
      return Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            child: Image.memory(
              base64Decode(_branchData['branch_image']),
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
    } else {
      return _buildDefaultHeader();
    }
  }

  Widget _buildDefaultHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business,
                size: 80, color: Colors.white.withOpacity(0.7)),
            const SizedBox(height: 16),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'ข้อมูลพื้นฐาน',
            Icons.info_outline,
            [
              _buildInfoRow(
                  'ชื่อสาขา', _branchData['branch_name'] ?? 'ไม่ระบุ'),
              _buildInfoRow('รหัสสาขา', _branchData['branch_id'] ?? 'ไม่ระบุ'),
              _buildInfoRow(
                  'ที่อยู่', _branchData['branch_address'] ?? 'ไม่ระบุ'),
              _buildInfoRow(
                  'เบอร์โทร', _branchData['branch_phone'] ?? 'ไม่ระบุ'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'ข้อมูลเจ้าของ',
            Icons.person_outline,
            [
              _buildInfoRow(
                  'ชื่อเจ้าของ', _branchData['owner_name'] ?? 'ไม่ระบุ'),
              _buildInfoRow(
                  'อีเมลเจ้าของ', _branchData['owner_email'] ?? 'ไม่ระบุ'),
            ],
          ),
          if (_branchData['description'] != null &&
              _branchData['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoCard(
              'รายละเอียดเพิ่มเติม',
              Icons.description_outlined,
              [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _branchData['description'],
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
          const SizedBox(height: 16),
          _buildInfoCard(
            'ข้อมูลระบบ',
            Icons.timeline,
            [
              _buildInfoRow(
                  'วันที่สร้าง', _formatDateTime(_branchData['created_at'])),
              _buildInfoRow(
                  'อัพเดทล่าสุด', _formatDateTime(_branchData['updated_at'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ห้องพัก
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'ห้องทั้งหมด',
                  _branchStats['total_rooms'].toString(),
                  Icons.hotel,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'ห้องที่มีผู้เช่า',
                  _branchStats['occupied_rooms'].toString(),
                  Icons.people,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'ห้องว่าง',
                  _branchStats['available_rooms'].toString(),
                  Icons.hotel_outlined,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'ผู้เช่าทั้งหมด',
                  _branchStats['total_tenants'].toString(),
                  Icons.group,
                  Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // รายได้
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'รายได้เดือนนี้',
                  '฿${_formatNumber(_branchStats['monthly_revenue'])}',
                  Icons.monetization_on,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'ชำระเงินค้างชำระ',
                  _branchStats['pending_payments'].toString(),
                  Icons.payment,
                  Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Occupancy Rate Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'อัตราการเข้าพัก',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildOccupancyChart(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomManagementTab(bool canManage) {
    return Column(
      children: [
        // ส่วนค้นหาและกรอง
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                  hintText: 'ค้นหาห้อง',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
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
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRoomStatus,
                      decoration: const InputDecoration(
                        labelText: 'สถานะ',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        DropdownMenuItem(
                            value: 'available', child: Text('ว่าง')),
                        DropdownMenuItem(
                            value: 'occupied', child: Text('มีผู้เช่า')),
                        DropdownMenuItem(
                            value: 'maintenance', child: Text('ซ่อมบำรุง')),
                      ],
                      onChanged: _onStatusFilterChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRoomCategory,
                      decoration: const InputDecoration(
                        labelText: 'ประเภท',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        DropdownMenuItem(
                            value: 'economy', child: Text('ประหยัด')),
                        DropdownMenuItem(
                            value: 'standard', child: Text('มาตรฐาน')),
                        DropdownMenuItem(
                            value: 'deluxe', child: Text('ดีลักซ์')),
                        DropdownMenuItem(
                            value: 'premium', child: Text('พรีเมี่ยม')),
                        DropdownMenuItem(value: 'vip', child: Text('วีไอพี')),
                      ],
                      onChanged: _onCategoryFilterChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // รายการห้อง
        Expanded(
          child: _isLoadingRooms
              ? const Center(child: CircularProgressIndicator())
              : _filteredRooms.isEmpty
                  ? _buildEmptyRoomsState(canManage)
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadRoomData();
                        await _loadBranchStats();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRooms.length,
                        itemBuilder: (context, index) {
                          final room = _filteredRooms[index];
                          return _buildRoomCard(room, canManage);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupancyChart() {
    final totalRooms = _branchStats['total_rooms'];
    final occupiedRooms = _branchStats['occupied_rooms'];
    final occupancyRate = totalRooms > 0 ? (occupiedRooms / totalRooms) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('อัตราการเข้าพัก'),
            Text('${(occupancyRate * 100).toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: occupancyRate,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            occupancyRate > 0.8
                ? Colors.green
                : occupancyRate > 0.5
                    ? Colors.orange
                    : Colors.red,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('มีผู้เช่า', style: TextStyle(fontSize: 12)),
                  Text('$occupiedRooms',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 4),
                  const Text('ห้องว่าง', style: TextStyle(fontSize: 12)),
                  Text('${totalRooms - occupiedRooms}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyRoomsState(bool canAdd) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'ไม่พบห้องที่ค้นหา'
                : 'ยังไม่มีห้องในสาขานี้',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'ลองเปลี่ยนคำค้นหาหรือกรองข้อมูล'
                : 'เริ่มต้นโดยการเพิ่มห้องแรก',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          if (_searchQuery.isEmpty && canAdd) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddRoomUI(
                      branchId: _branchData['branch_id'],
                      branchName: _branchData['branch_name'],
                    ),
                  ),
                );
                if (result == true) {
                  await _loadRoomData();
                  await _loadBranchStats();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มห้องใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, bool canManage) {
    final status = room['room_status'] ?? 'available';
    final statusColor = _getRoomStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ห้อง ${room['room_number']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        room['room_name'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getRoomStatusText(status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoomdetailUi(room: room),
                            ),
                          );
                          if (result == true) {
                            await _loadRoomData();
                            await _loadBranchStats();
                          }
                          break;
                        case 'toggle_status':
                          await _toggleRoomStatus(room['room_id'], status);
                          break;
                        case 'delete':
                          await _deleteRoom(
                              room['room_id'], room['room_number']);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('แก้ไข'),
                          ],
                        ),
                      ),
                      if (status != 'occupied')
                        PopupMenuItem(
                          value: 'toggle_status',
                          child: Row(
                            children: [
                              Icon(
                                status == 'available'
                                    ? Icons.build
                                    : Icons.check,
                                size: 20,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(status == 'available'
                                  ? 'ปิดซ่อมบำรุง'
                                  : 'เปิดใช้งาน'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('ลบห้อง', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'ประเภท: ${_getRoomCategoryText(room['room_cate'])}'),
                      Text('ชนิด: ${_getRoomTypeText(room['room_type'])}'),
                      Text('ขนาด: ${room['room_size']} ตร.ม.'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ค่าเช่า: ${room['room_rate']} บาท/เดือน'),
                      Text('เงินมัดจำ: ${room['room_deposit']} บาท'),
                      Text('ผู้พักสูงสุด: ${room['room_max']} คน'),
                    ],
                  ),
                ),
              ],
            ),
            if (room['room_des'] != null &&
                room['room_des'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                room['room_des'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'maintenance':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'เปิดใช้งาน';
      case 'inactive':
        return 'ปิดใช้งาน';
      case 'maintenance':
        return 'ซ่อมบำรุง';
      default:
        return 'ไม่ทราบ';
    }
  }

  Color _getRoomStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'occupied':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'reserved':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRoomStatusText(String status) {
    switch (status) {
      case 'available':
        return 'ว่าง';
      case 'occupied':
        return 'มีผู้เช่า';
      case 'maintenance':
        return 'ซ่อมบำรุง';
      case 'reserved':
        return 'จอง';
      default:
        return 'ไม่ทราบ';
    }
  }

  String _getRoomCategoryText(String category) {
    switch (category) {
      case 'economy':
        return 'ประหยัด';
      case 'standard':
        return 'มาตรฐาน';
      case 'deluxe':
        return 'ดีลักซ์';
      case 'premium':
        return 'พรีเมี่ยม';
      case 'vip':
        return 'วีไอพี';
      default:
        return category;
    }
  }

  String _getRoomTypeText(String type) {
    switch (type) {
      case 'single':
        return 'เดี่ยว';
      case 'twin':
        return 'แฝด';
      case 'double':
        return 'คู่';
      case 'family':
        return 'ครอบครัว';
      case 'studio':
        return 'สตูดิโอ';
      case 'suite':
        return 'สวีท';
      default:
        return type;
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'ไม่ทราบ';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'ไม่ทราบ';
    }
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
