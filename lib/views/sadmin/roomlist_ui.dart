import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/amenities_ui.dart';
import 'package:manager_room_project/views/sadmin/room_add_ui.dart';
import 'package:manager_room_project/views/sadmin/room_edit_ui.dart';
import 'package:manager_room_project/views/sadmin/roomcate_ui.dart';
import 'package:manager_room_project/views/sadmin/roomlist_detail_ui.dart';
import 'package:manager_room_project/views/sadmin/roomtype_ui.dart';
// เพิ่ม import หน้าจัดการข้อมูลพื้นฐาน

import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../services/room_service.dart';
import '../../widgets/colors.dart';

class RoomListUI extends StatefulWidget {
  final String? branchId;
  final String? branchName;

  const RoomListUI({
    Key? key,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<RoomListUI> createState() => _RoomListUIState();
}

class _RoomListUIState extends State<RoomListUI> {
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _filteredRooms = [];
  List<Map<String, dynamic>> _branches = [];
  Map<String, List<Map<String, dynamic>>> _roomAmenities = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _selectedRoomStatusFilter = 'all';
  String? _selectedBranchId;
  UserModel? _currentUser;
  bool _isAnonymous = false;
  bool _canAddRoom = false;
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
      await _refreshAddPermission();
    } catch (e) {
      setState(() {
        _currentUser = null;
        _isAnonymous = true;
      });
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await RoomService.getBranchesForRoomFilter();
      if (mounted) {
        setState(() {
          _branches = branches;
        });
      }
    } catch (e) {
      print('Error loading branches: $e');
    }
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> rooms;

      if (_isAnonymous) {
        rooms = await RoomService.getActiveRooms(branchId: _selectedBranchId);
      } else if (_currentUser!.userRole == UserRole.superAdmin) {
        rooms = await RoomService.getAllRooms(
          branchId: _selectedBranchId,
          isActive:
              _selectedStatus == 'all' ? null : _selectedStatus == 'active',
        );
      } else {
        rooms = await RoomService.getRoomsByUser(branchId: _selectedBranchId);
      }

      Map<String, List<Map<String, dynamic>>> amenitiesMap = {};
      for (var room in rooms) {
        try {
          final amenities = await RoomService.getRoomAmenities(room['room_id']);
          amenitiesMap[room['room_id']] = amenities;
        } catch (e) {
          print('Error loading amenities for room ${room['room_id']}: $e');
          amenitiesMap[room['room_id']] = [];
        }
      }

      if (mounted) {
        setState(() {
          _rooms = rooms;
          _filteredRooms = _rooms;
          _roomAmenities = amenitiesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _rooms = [];
          _filteredRooms = [];
          _roomAmenities = {};
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ลองใหม่',
              textColor: Colors.white,
              onPressed: _loadRooms,
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
    _filterRooms();
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status ?? 'all';
    });
    _loadRooms();
  }

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId;
    });
    _refreshAddPermission();
    _loadRooms();
  }

  void _onRoomStatusFilterChanged(String? status) {
    setState(() {
      _selectedRoomStatusFilter = status ?? 'all';
    });
    _filterRooms();
  }

  void _filterRooms() {
    if (!mounted) return;
    setState(() {
      _filteredRooms = _rooms.where((room) {
        final searchTerm = _searchQuery.toLowerCase();
        final matchesSearch = (room['room_number'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (room['branch_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (room['room_type_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (room['room_category_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            ('เลขที่').toString().toLowerCase().contains(searchTerm);

        final matchesStatus = _selectedRoomStatusFilter == 'all' ||
            (room['room_status'] ?? 'unknown') == _selectedRoomStatusFilter;

        return matchesSearch && matchesStatus;
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

    if (_selectedRoomStatusFilter != 'all') {
      filters.add('สถานะ: ${_getStatusText(_selectedRoomStatusFilter)}');
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
            SizedBox(width: 8),
            Text('ต้องเข้าสู่ระบบ'),
          ],
        ),
        content: Text('คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถ$actionได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to login page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันแสดงเมนูจัดการข้อมูลพื้นฐาน
  void _showMasterDataMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'จัดการข้อมูลพื้นฐาน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Divider(height: 1),
            _buildMasterDataMenuItem(
              icon: Icons.category_outlined,
              title: 'จัดการประเภทห้อง',
              subtitle: 'ห้องพัดลม, ห้องแอร์, Studio',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomTypesUI(),
                  ),
                ).then((_) => _loadRooms());
              },
            ),
            Divider(height: 1),
            _buildMasterDataMenuItem(
              icon: Icons.grid_view_outlined,
              title: 'จัดการหมวดหมู่ห้อง',
              subtitle: 'ห้องเดี่ยว, ห้องคู่, ห้องครอบครัว',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomCategoriesUI(),
                  ),
                ).then((_) => _loadRooms());
              },
            ),
            Divider(height: 1),
            _buildMasterDataMenuItem(
              icon: Icons.stars_outlined,
              title: 'จัดการสิ่งอำนวยความสะดวก',
              subtitle: 'แอร์, WiFi, ตู้เสื้อผ้า, ที่จอดรถ',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AmenitiesUI(),
                  ),
                ).then((_) => _loadRooms());
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterDataMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Future<void> _toggleRoomStatus(
      String roomId, String roomNumber, String currentStatus) async {
    if (_isAnonymous) {
      _showLoginPrompt('เปลี่ยนสถานะห้อง');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('เปลี่ยนสถานะห้อง $roomNumber'),
        content: Text('คุณต้องการเปลี่ยนสถานะห้องนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('ยืนยัน'),
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

        final result = await RoomService.toggleRoomStatus(roomId);

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            await _loadRooms();
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
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteRoom(String roomId, String roomNumber) async {
    if (_isAnonymous) {
      _showLoginPrompt('ลบห้อง');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.warning_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'ยืนยันการลบห้องถาวร',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'คุณต้องการลบห้อง "$roomNumber" ออกจากระบบถาวรใช่หรือไม่?',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'การลบถาวรจะทำให้ข้อมูลห้องหายไปจากระบบทั้งหมด และไม่สามารถกู้คืนได้อีก',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
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
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text('ลบถาวร'),
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

        final result = await RoomService.deleteRoom(roomId);

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            await _loadRooms();
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
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
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

  String _getStatusText(String status) {
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle;
      case 'occupied':
        return Icons.person;
      case 'maintenance':
        return Icons.build;
      case 'reserved':
        return Icons.event;
      default:
        return Icons.help;
    }
  }

  IconData _getAmenityIcon(String? iconName) {
    if (iconName == null) return Icons.star;

    switch (iconName) {
      case 'ac_unit':
        return Icons.ac_unit;
      case 'air':
        return Icons.air;
      case 'bed':
        return Icons.bed;
      case 'door_sliding':
        return Icons.door_sliding;
      case 'desk':
        return Icons.desk;
      case 'water_heater':
      case 'water_drop':
        return Icons.water_drop;
      case 'wifi':
        return Icons.wifi;
      case 'local_parking':
        return Icons.local_parking;
      case 'videocam':
        return Icons.videocam;
      case 'credit_card':
        return Icons.credit_card;
      default:
        return Icons.star;
    }
  }

  bool get _canManage =>
      !_isAnonymous &&
      (_currentUser?.userRole == UserRole.superAdmin ||
          _currentUser?.userRole == UserRole.admin);

  Future<void> _refreshAddPermission() async {
    if (!mounted) return;
    bool allowed = false;
    if (!_isAnonymous) {
      if (_currentUser?.userRole == UserRole.superAdmin) {
        allowed = true;
      } else if (_currentUser?.userRole == UserRole.admin &&
          _selectedBranchId != null &&
          _selectedBranchId!.isNotEmpty) {
        allowed = await RoomService.isUserManagerOfBranch(
            _currentUser!.userId, _selectedBranchId!);
      }
    }
    if (mounted) {
      setState(() {
        _canAddRoom = allowed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการห้องพัก'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ปุ่มจัดการข้อมูลพื้นฐาน (แสดงเฉพาะ superadmin)
          if (!_isAnonymous && _currentUser?.userRole == UserRole.superAdmin)
            IconButton(
              icon: Icon(Icons.settings_outlined),
              onPressed: _showMasterDataMenu,
              tooltip: 'จัดการข้อมูลพื้นฐาน',
            ),
          // รวม Filter ทั้งหมดในปุ่มเดียว
          PopupMenuButton<String>(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedStatus != 'all' ||
                    _selectedRoomStatusFilter != 'all')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 8,
                        height: 8,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'กรองข้อมูล',
            itemBuilder: (context) => [
              // Header - สถานะใช้งาน
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
                PopupMenuDivider(),
              ],

              // Header - สถานะห้อง
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'สถานะห้องพัก',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 14,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'room_status:all',
                child: Row(
                  children: [
                    Icon(
                      _selectedRoomStatusFilter == 'all'
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
                value: 'room_status:available',
                child: Row(
                  children: [
                    Icon(
                      _selectedRoomStatusFilter == 'available'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        const Text('ห้องว่าง'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'room_status:occupied',
                child: Row(
                  children: [
                    Icon(
                      _selectedRoomStatusFilter == 'occupied'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.blue),
                        SizedBox(width: 4),
                        const Text('มีผู้เช่า'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'room_status:maintenance',
                child: Row(
                  children: [
                    Icon(
                      _selectedRoomStatusFilter == 'maintenance'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(Icons.build, size: 14, color: Colors.orange),
                        SizedBox(width: 4),
                        const Text('ซ่อมบำรุง'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'room_status:reserved',
                child: Row(
                  children: [
                    Icon(
                      _selectedRoomStatusFilter == 'reserved'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(Icons.event, size: 14, color: Colors.purple),
                        SizedBox(width: 4),
                        const Text('จอง'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'room_status:unknown',
                child: Row(
                  children: [
                    Icon(
                      _selectedRoomStatusFilter == 'unknown'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(Icons.help, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        const Text('ไม่ทราบ'),
                      ],
                    ),
                  ],
                ),
              ),

              // ปุ่มล้าง Filter
              if (_selectedStatus != 'all' ||
                  _selectedRoomStatusFilter != 'all') ...[
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'ล้างตัวกรองทั้งหมด',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            onSelected: (value) {
              if (value == 'clear_all') {
                setState(() {
                  _selectedStatus = 'all';
                  _selectedRoomStatusFilter = 'all';
                });
                if (!_isAnonymous) {
                  _loadRooms();
                } else {
                  _filterRooms();
                }
              } else if (value.startsWith('active_status:')) {
                final status = value.split(':')[1];
                _onStatusChanged(status);
              } else if (value.startsWith('room_status:')) {
                final status = value.split(':')[1];
                _onRoomStatusFilterChanged(status);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาห้องพัก',
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
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_branches.isNotEmpty && widget.branchId == null) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedBranchId ?? 'all',
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('ทุกสาขา'),
                        ),
                        ..._branches.map((branch) {
                          return DropdownMenuItem<String>(
                            value: branch['branch_id'] as String,
                            child: Text(branch['branch_name'] ?? ''),
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
                    _selectedRoomStatusFilter != 'all' ||
                    _searchQuery.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list_alt,
                            size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getActiveFiltersText(),
                            style: TextStyle(
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
                              _selectedRoomStatusFilter = 'all';
                              _searchQuery = '';
                              _searchController.clear();
                            });
                            _loadRooms();
                          },
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
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
                        SizedBox(height: 16),
                        Text('กำลังโหลดข้อมูล...'),
                      ],
                    ),
                  )
                : _filteredRooms.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadRooms,
                        color: AppTheme.primary,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredRooms.length,
                          itemBuilder: (context, index) {
                            final room = _filteredRooms[index];
                            return _buildRoomCard(room, _canManage);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _canAddRoom
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomAddUI(
                      branchId: _selectedBranchId,
                      branchName: _selectedBranchId != null
                          ? _branches.firstWhere(
                              (b) => b['branch_id'] == _selectedBranchId,
                              orElse: () => {},
                            )['branch_name']
                          : null,
                    ),
                  ),
                );

                if (result == true) {
                  await _loadRooms();
                }
              },
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'ไม่พบห้องที่ค้นหา' : 'ยังไม่มีห้องพัก',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'ลองเปลี่ยนคำค้นหา หรือกรองสถานะ'
                : _canAddRoom
                    ? 'เริ่มต้นโดยการเพิ่มห้องพักแรก'
                    : 'ไม่มีห้องพักในสาขานี้',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          if (_searchQuery.isEmpty && _canAddRoom)
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomAddUI(
                        branchId: _selectedBranchId,
                        branchName: _selectedBranchId != null
                            ? _branches.firstWhere(
                                (b) => b['branch_id'] == _selectedBranchId,
                                orElse: () => {},
                              )['branch_name']
                            : null,
                      ),
                    ),
                  );

                  if (result == true) {
                    await _loadRooms();
                  }
                },
                icon: Icon(Icons.add),
                label: Text('เพิ่มห้องใหม่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, bool canManage) {
    final isActive = room['is_active'] ?? false;
    final status = room['room_status'] ?? 'available';
    final statusColor = _getStatusColor(status);
    final roomId = room['room_id'];
    final amenities = _roomAmenities[roomId] ?? [];

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RoomDetailUI(
                roomId: room['room_id'],
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.hotel,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${room['room_category_name']} เลขที่ ${room['room_number'] ?? 'ไม่ระบุ'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (room['branch_name'] != null)
                          Text(
                            room['branch_name'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // สถานะห้อง
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(status),
                            size: 14, color: statusColor),
                        SizedBox(width: 4),
                        Text(
                          _getStatusText(status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 5),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
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
                          size: 14,
                          color: isActive ? Colors.green : Colors.orange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              Row(
                children: [
                  // Room Type
                  if (room['room_type_name'] != null) ...[
                    SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.category,
                      room['room_type_name'],
                      Colors.blue,
                    ),
                  ],
                ],
              ),

              SizedBox(height: 12),

              // Room Info (Size & Price)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (room['room_size'] != null) ...[
                        Icon(Icons.aspect_ratio,
                            size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          '${room['room_size']} ตร.ม.',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                        SizedBox(width: 16),
                      ],
                      Icon(Icons.payments, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        '${room['room_price'] ?? 0} บาท/เดือน',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.security, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        'ค่ามัดจำ: ${room['room_deposit'] ?? 0} บาท',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Room Description
              if (room['room_desc'] != null &&
                  room['room_desc'].toString().trim().isNotEmpty) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.description,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          room['room_desc'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Amenities Section
              if (amenities.isNotEmpty) ...[
                SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars, size: 14, color: Colors.amber[700]),
                        SizedBox(width: 4),
                        Text(
                          'สิ่งอำนวยความสะดวก',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: amenities.take(5).map((amenity) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue[200]!,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getAmenityIcon(amenity['amenities_icon']),
                                size: 12,
                                color: Colors.blue[700],
                              ),
                              SizedBox(width: 4),
                              Text(
                                amenity['amenities_name'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    if (amenities.length > 5)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '+${amenities.length - 5} เพิ่มเติม',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              // Action Buttons
              if (canManage) ...[
                Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoomDetailUI(
                                roomId: room['room_id'],
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.visibility, size: 16),
                        label: Text('ดู'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RoomEditUI(roomId: room['room_id']),
                            ),
                          );
                          if (result == true) {
                            _loadRooms();
                          }
                        },
                        icon: Icon(Icons.edit, size: 16),
                        label: Text('แก้ไข'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'toggle':
                            _toggleRoomStatus(
                              room['room_id'],
                              room['room_number'] ?? '',
                              status,
                            );
                            break;
                          case 'delete':
                            if (_currentUser?.userRole == UserRole.superAdmin) {
                              _deleteRoom(
                                room['room_id'],
                                room['room_number'] ?? '',
                              );
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                isActive
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 16,
                                color: isActive ? Colors.orange : Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text(isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
                            ],
                          ),
                        ),
                        if (_currentUser?.userRole == UserRole.superAdmin)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_forever,
                                    size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'ลบถาวร',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                      ],
                      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ] else if (_isAnonymous)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomDetailUI(
                              roomId: room['room_id'],
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('ดูรายละเอียด'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary),
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
