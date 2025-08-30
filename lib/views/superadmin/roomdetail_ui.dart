import 'package:flutter/material.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

final supabase = Supabase.instance.client;

class RoomDetailScreen extends StatefulWidget {
  final Map<String, dynamic> room;

  const RoomDetailScreen({
    Key? key,
    required this.room,
  }) : super(key: key);

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  Map<String, dynamic> _roomData = {};
  bool _isLoading = false;
  PageController _imageController = PageController();
  int _currentImageIndex = 0;
  List<String> _imageList = [];

  @override
  void initState() {
    super.initState();
    _roomData = Map<String, dynamic>.from(widget.room);
    _loadImages();
    _loadRoomDetails();
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
        _loadImages(); // โหลดรูปใหม่
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

  Future<void> _changeRoomStatus(String newStatus) async {
    try {
      await supabase.from('rooms').update({
        'room_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('room_id', _roomData['room_id']);

      setState(() {
        _roomData['room_status'] = newStatus;
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

  Future<void> _deleteRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบ'),
        content: Text(
            'คุณต้องการลบห้อง "${_roomData['room_name']}" ใช่หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้'),
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
        return Icons.book;
      default:
        return Icons.help;
    }
  }

  String _getCategoryText(String category) {
    switch (category) {
      case 'economy':
        return 'Economy';
      case 'standard':
        return 'Standard';
      case 'deluxe':
        return 'Deluxe';
      case 'premium':
        return 'Premium';
      case 'vip':
        return 'VIP';
      default:
        return 'ไม่ทราบ';
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'single':
        return 'Single';
      case 'twin':
        return 'Twin';
      case 'double':
        return 'Double';
      case 'family':
        return 'Family';
      case 'studio':
        return 'Studio';
      case 'suite':
        return 'Suite';
      default:
        return 'ไม่ทราบ';
    }
  }

  String _getFacilityLabel(String facility) {
    switch (facility) {
      case 'air_conditioner':
        return 'เครื่องปรับอากาศ';
      case 'wifi':
        return 'Wi-Fi';
      case 'tv':
        return 'โทรทัศน์';
      case 'refrigerator':
        return 'ตู้เย็น';
      case 'water_heater':
        return 'เครื่องทำน้ำอุ่น';
      case 'wardrobe':
        return 'ตู้เสื้อผ้า';
      case 'desk':
        return 'โต๊ะทำงาน';
      case 'balcony':
        return 'ระเบียง';
      case 'parking':
        return 'ที่จอดรถ';
      case 'washing_machine':
        return 'เครื่องซักผ้า';
      default:
        return facility;
    }
  }

  IconData _getFacilityIcon(String facility) {
    switch (facility) {
      case 'air_conditioner':
        return Icons.ac_unit;
      case 'wifi':
        return Icons.wifi;
      case 'tv':
        return Icons.tv;
      case 'refrigerator':
        return Icons.kitchen;
      case 'water_heater':
        return Icons.hot_tub;
      case 'wardrobe':
        return Icons.checkroom;
      case 'desk':
        return Icons.desk;
      case 'balcony':
        return Icons.balcony;
      case 'parking':
        return Icons.local_parking;
      case 'washing_machine':
        return Icons.local_laundry_service;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.getCurrentUser();
    final canManage =
        currentUser?.isSuperAdmin ?? currentUser?.isAdmin ?? false;
    final status = _roomData['room_status'] ?? 'available';
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ฟีเจอร์แก้ไขกำลังพัฒนา')),
                          );
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
        body: SingleChildScrollView(
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
                  _buildInfoRow(
                      'หมายเลขห้อง', _roomData['room_number'] ?? 'ไม่ระบุ'),
                  _buildInfoRow(
                      'ชื่อห้อง', _roomData['room_name'] ?? 'ไม่ระบุ'),
                  _buildInfoRow('สาขา', _roomData['branch_name'] ?? 'ไม่ระบุ'),
                  _buildInfoRow('หมวดหมู่',
                      _getCategoryText(_roomData['room_cate'] ?? 'standard')),
                  _buildInfoRow('ประเภท',
                      _getTypeText(_roomData['room_type'] ?? 'single')),
                  if (_roomData['room_size'] != null)
                    _buildInfoRow('ขนาด', '${_roomData['room_size']} ตร.ม.'),
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
                  _buildInfoRow(
                      'วันที่สร้าง', _formatDateTime(_roomData['created_at'])),
                  _buildInfoRow(
                      'อัพเดทล่าสุด', _formatDateTime(_roomData['updated_at'])),
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
    final status = _roomData['room_status'] ?? 'available';
    final statusColor = _getStatusColor(status);

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
                      Icon(_getStatusIcon(status),
                          size: 16, color: statusColor),
                      SizedBox(width: 6),
                      Text(
                        _getStatusText(status),
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
                  '${_getCategoryText(_roomData['room_cate'] ?? 'standard')} • ${_getTypeText(_roomData['room_type'] ?? 'single')}',
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
            onPressed: _showStatusChangeDialog,
            icon: Icon(Icons.swap_horiz),
            label: Text('เปลี่ยนสถานะห้อง'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ฟีเจอร์แก้ไขกำลังพัฒนา')),
              );
            },
            icon: Icon(Icons.edit),
            label: Text('แก้ไขข้อมูลห้อง'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _deleteRoom,
            icon: Icon(Icons.delete),
            label: Text('ลบห้อง'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption(
                'available', 'ว่าง', Icons.check_circle, Colors.green),
            _buildStatusOption(
                'occupied', 'มีผู้เช่า', Icons.person, Colors.blue),
            _buildStatusOption(
                'maintenance', 'ซ่อมบำรุง', Icons.build, Colors.orange),
            _buildStatusOption('reserved', 'จอง', Icons.book, Colors.purple),
          ],
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

  Widget _buildStatusOption(
      String status, String label, IconData icon, Color color) {
    final isCurrentStatus = _roomData['room_status'] == status;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: isCurrentStatus ? Icon(Icons.check, color: Colors.green) : null,
      enabled: !isCurrentStatus,
      onTap: isCurrentStatus
          ? null
          : () {
              Navigator.pop(context);
              _changeRoomStatus(status);
            },
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
