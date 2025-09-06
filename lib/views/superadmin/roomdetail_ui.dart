import 'package:flutter/material.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/views/superadmin/editroom_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

final supabase = Supabase.instance.client;

class RoomdetailUi extends StatefulWidget {
  final Map<String, dynamic> room;

  const RoomdetailUi({
    Key? key,
    required this.room,
  }) : super(key: key);

  @override
  State<RoomdetailUi> createState() => _RoomdetailUiState();
}

class _RoomdetailUiState extends State<RoomdetailUi> {
  Map<String, dynamic> _roomData = {};
  bool _isLoading = false;
  PageController _imageController = PageController();
  int _currentImageIndex = 0;
  List<String> _imageList = [];

  // ข้อมูล master data
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _statuses = [];
  List<Map<String, dynamic>> _facilities = [];

  @override
  void initState() {
    super.initState();
    _roomData = Map<String, dynamic>.from(widget.room);
    _loadImages();
    _loadRoomDetails();
    _loadMasterData();
  }

  void _loadImages() {
    if (_roomData['room_images'] != null &&
        _roomData['room_images'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(_roomData['room_images']);
        if (decoded is List) {
          _imageList = decoded.cast<String>();
        }
      } catch (e) {
        print('Error decoding room images: $e');
      }
    }
  }

  Future<void> _loadRoomDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('rooms')
          .select('*')
          .eq('room_id', _roomData['room_id'])
          .single();

      setState(() {
        _roomData = response;
        _loadImages();
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

  Future<void> _loadMasterData() async {
    try {
      final results = await Future.wait([
        supabase
            .from('room_categories')
            .select('*')
            .eq('is_active', true)
            .order('display_order'),
        supabase
            .from('room_types')
            .select('*')
            .eq('is_active', true)
            .order('display_order'),
        supabase
            .from('room_status_types')
            .select('*')
            .eq('is_active', true)
            .order('display_order'),
        supabase
            .from('room_facilities')
            .select('*')
            .eq('is_active', true)
            .order('display_order'),
      ]);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(results[0]);
        _types = List<Map<String, dynamic>>.from(results[1]);
        _statuses = List<Map<String, dynamic>>.from(results[2]);
        _facilities = List<Map<String, dynamic>>.from(results[3]);
      });
    } catch (e) {
      print('Error loading master data: $e');
    }
  }

  Future<void> _changeRoomStatus(String newStatusId) async {
    try {
      final statusCode = _getStatusCodeById(newStatusId);

      await supabase.from('rooms').update({
        'status_id': newStatusId,
        'room_status': statusCode,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('room_id', _roomData['room_id']);

      setState(() {
        _roomData['status_id'] = newStatusId;
        _roomData['room_status'] = statusCode;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัพเดทสถานะห้องสำเร็จ'),
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

  String? _getStatusCodeById(String statusId) {
    try {
      final status = _statuses.firstWhere((s) => s['status_id'] == statusId);
      return status['status_code'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _editRoom() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRoomUi(
          roomId: _roomData['room_id'],
        ),
      ),
    );

    if (result == true) {
      await _loadRoomDetails();
      await _loadMasterData();
    }
  }

  Future<void> _deleteRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบ'),
        content: Text(
            'คุณต้องการลบห้อง "${_roomData['room_name'] ?? _roomData['room_number']}" ใช่หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้'),
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
            .from('rooms')
            .delete()
            .eq('room_id', _roomData['room_id']);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ลบห้องสำเร็จ'),
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

  // Helper methods สำหรับการแสดงผลข้อมูลจากตารางใหม่
  String _getCategoryName() {
    if (_roomData['category_id'] != null) {
      try {
        final category = _categories.firstWhere(
            (cat) => cat['category_id'] == _roomData['category_id']);
        return category['category_name'] ?? 'ไม่ระบุ';
      } catch (e) {
        return 'ไม่พบข้อมูล';
      }
    }
    return 'ไม่ระบุ';
  }

  String _getTypeName() {
    if (_roomData['type_id'] != null) {
      try {
        final type =
            _types.firstWhere((t) => t['type_id'] == _roomData['type_id']);
        return type['type_name'] ?? 'ไม่ระบุ';
      } catch (e) {
        return 'ไม่พบข้อมูล';
      }
    }
    return 'ไม่ระบุ';
  }

  String _getStatusName() {
    if (_roomData['status_id'] != null) {
      try {
        final status = _statuses
            .firstWhere((s) => s['status_id'] == _roomData['status_id']);
        return status['status_name'] ?? 'ไม่ระบุ';
      } catch (e) {
        return 'ไม่พบข้อมูล';
      }
    }
    return 'ไม่ระบุ';
  }

  Color _getStatusColor() {
    if (_roomData['status_id'] != null) {
      try {
        final status = _statuses
            .firstWhere((s) => s['status_id'] == _roomData['status_id']);
        if (status['status_color'] != null) {
          return Color(
              int.parse(status['status_color'].replaceFirst('#', '0xFF')));
        }
      } catch (e) {
        return Colors.grey;
      }
    }
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (_roomData['status_id'] != null) {
      try {
        final status = _statuses
            .firstWhere((s) => s['status_id'] == _roomData['status_id']);
        if (status['status_icon'] != null) {
          return _getIconFromString(status['status_icon']);
        }
      } catch (e) {
        return Icons.help;
      }
    }
    return Icons.help;
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'check_circle':
        return Icons.check_circle;
      case 'people':
      case 'person':
        return Icons.people;
      case 'build':
        return Icons.build;
      case 'book':
      case 'bookmark':
        return Icons.bookmark;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'construction':
        return Icons.construction;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'wifi':
        return Icons.wifi;
      case 'tv':
        return Icons.tv;
      case 'kitchen':
        return Icons.kitchen;
      case 'hot_tub':
        return Icons.hot_tub;
      case 'checkroom':
        return Icons.checkroom;
      case 'desk':
        return Icons.desk;
      case 'balcony':
        return Icons.balcony;
      case 'local_parking':
        return Icons.local_parking;
      case 'local_laundry_service':
        return Icons.local_laundry_service;
      case 'microwave':
        return Icons.microwave;
      case 'chair':
        return Icons.chair;
      case 'lock':
        return Icons.lock;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'pool':
        return Icons.pool;
      default:
        return Icons.help;
    }
  }

  String _getFacilityLabel(String facility) {
    try {
      final facilityData = _facilities.firstWhere((f) =>
          f['facility_code'] == facility || f['facility_name'] == facility);
      return facilityData['facility_name'] ?? facility;
    } catch (e) {
      return facility;
    }
  }

  IconData _getFacilityIcon(String facility) {
    try {
      final facilityData = _facilities.firstWhere((f) =>
          f['facility_code'] == facility || f['facility_name'] == facility);
      if (facilityData['facility_icon'] != null) {
        return _getIconFromString(facilityData['facility_icon']);
      }
    } catch (e) {
      // Return default icon if not found
    }
    return Icons.star;
  }

  bool _canManageRoom() {
    final currentUser = AuthService.getCurrentUser();
    if (currentUser?.isSuperAdmin ?? false) return true;

    if (currentUser?.isAdmin ?? false) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManageRoom();

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
                          await _editRoom();
                          break;
                        case 'change_status':
                          _showStatusChangeDialog();
                          break;
                        case 'delete':
                          await _deleteRoom();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
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
                        value: 'change_status',
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz,
                                size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('เปลี่ยนสถานะ'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
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
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeaderImages(),
              ),
            ),
          ];
        },
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room Header
                    _buildRoomHeader(),

                    SizedBox(height: 24),

                    // Basic Info
                    _buildInfoCard(
                      'ข้อมูลพื้นฐาน',
                      Icons.info_outline,
                      [
                        _buildInfoRow('หมายเลขห้อง',
                            _roomData['room_number'] ?? 'ไม่ระบุ'),
                        _buildInfoRow(
                            'ชื่อห้อง', _roomData['room_name'] ?? 'ไม่ระบุ'),
                        _buildInfoRow(
                            'สาขา', _roomData['branch_name'] ?? 'ไม่ระบุ'),
                        _buildInfoRow('หมวดหมู่', _getCategoryName()),
                        _buildInfoRow('ประเภท', _getTypeName()),
                        if (_roomData['room_size'] != null)
                          _buildInfoRow(
                              'ขนาด', '${_roomData['room_size']} ตร.ม.'),
                        _buildInfoRow('จำนวนผู้เข้าพักสูงสุด',
                            '${_roomData['room_max'] ?? 1} คน'),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Pricing
                    _buildInfoCard(
                      'ราคาและค่าใช้จ่าย',
                      Icons.monetization_on,
                      [
                        _buildInfoRow('ค่าเช่ารายเดือน',
                            '฿${_formatCurrency(_roomData['room_rate']?.toDouble() ?? 0)}'),
                        _buildInfoRow('เงินมัดจำ',
                            '฿${_formatCurrency(_roomData['room_deposit']?.toDouble() ?? 0)}'),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Facilities
                    if (_roomData['room_fac'] != null &&
                        (_roomData['room_fac'] as List).isNotEmpty)
                      _buildFacilitiesCard(),

                    SizedBox(height: 16),

                    // Description
                    if (_roomData['room_des'] != null &&
                        _roomData['room_des'].toString().isNotEmpty)
                      _buildInfoCard(
                        'คำอธิบาย',
                        Icons.description_outlined,
                        [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _roomData['room_des'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),

                    SizedBox(height: 16),

                    // System Info
                    _buildInfoCard(
                      'ข้อมูลระบบ',
                      Icons.timeline,
                      [
                        _buildInfoRow('วันที่สร้าง',
                            _formatDateTime(_roomData['created_at'])),
                        _buildInfoRow('อัพเดทล่าสุด',
                            _formatDateTime(_roomData['updated_at'])),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Action Buttons
                    if (canManage) _buildActionButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderImages() {
    if (_imageList.isEmpty) {
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
              Icon(Icons.hotel, size: 80, color: Colors.white.withOpacity(0.7)),
              SizedBox(height: 16),
              Text(
                'ไม่มีรูปภาพห้อง',
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

    return Stack(
      children: [
        PageView.builder(
          controller: _imageController,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemCount: _imageList.length,
          itemBuilder: (context, index) {
            return Image.memory(
              base64Decode(_imageList[index]),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image,
                            size: 50, color: Colors.grey[500]),
                        SizedBox(height: 8),
                        Text('ไม่สามารถโหลดรูปภาพได้'),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        // Image indicator
        if (_imageList.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _imageList.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == entry.key
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }).toList(),
            ),
          ),
        // Gradient overlay
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

  Widget _buildRoomHeader() {
    final statusColor = _getStatusColor();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _roomData['room_number'] ?? '',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusIcon(), size: 16, color: statusColor),
                      SizedBox(width: 6),
                      Text(
                        _getStatusName(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              _roomData['room_name'] ?? 'ไม่มีชื่อ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_getCategoryName()} • ${_getTypeName()}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '฿${_formatCurrency(_roomData['room_rate']?.toDouble() ?? 0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'ต่อเดือน',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                SizedBox(width: 8),
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
      padding: EdgeInsets.symmetric(vertical: 4),
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
              ),
            ),
          ),
          Text(': '),
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

  Widget _buildFacilitiesCard() {
    final facilities = _roomData['room_fac'] as List;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'สิ่งอำนวยความสะดวก',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: facilities.length,
              itemBuilder: (context, index) {
                final facility = facilities[index];
                return Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getFacilityIcon(facility),
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getFacilityLabel(facility),
                          style: TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _editRoom,
            // icon: Icon(Icons.edit),
            label: Text('แก้ไขข้อมูลห้อง'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _deleteRoom,
            // icon: Icon(Icons.delete),
            label: Text('ลบห้อง'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  void _showStatusChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('เปลี่ยนสถานะห้อง'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _statuses.length,
            itemBuilder: (context, index) {
              final status = _statuses[index];
              final isCurrentStatus =
                  _roomData['status_id'] == status['status_id'];

              Color statusColor;
              try {
                statusColor = Color(int.parse(
                    status['status_color'].replaceFirst('#', '0xFF')));
              } catch (e) {
                statusColor = Colors.grey;
              }

              return ListTile(
                leading: Icon(
                  _getIconFromString(status['status_icon'] ?? 'help'),
                  color: statusColor,
                ),
                title: Text(status['status_name'] ?? ''),
                subtitle: status['status_description'] != null
                    ? Text(status['status_description'])
                    : null,
                trailing: isCurrentStatus
                    ? Icon(Icons.check, color: Colors.green)
                    : null,
                enabled: !isCurrentStatus,
                onTap: isCurrentStatus
                    ? null
                    : () {
                        Navigator.pop(context);
                        _changeRoomStatus(status['status_id']);
                      },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
        ],
      ),
    );
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

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }
}
