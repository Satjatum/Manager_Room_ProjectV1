import 'package:flutter/material.dart';
import '../../services/room_service.dart';
import '../../widgets/colors.dart';

class AmenitiesUI extends StatefulWidget {
  const AmenitiesUI({Key? key}) : super(key: key);

  @override
  State<AmenitiesUI> createState() => _AmenitiesUIState();
}

class _AmenitiesUIState extends State<AmenitiesUI> {
  List<Map<String, dynamic>> _amenities = [];
  List<Map<String, dynamic>> _filteredAmenities = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // รายการไอคอนที่สามารถเลือกได้
  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'ac_unit', 'icon': Icons.ac_unit, 'label': 'แอร์'},
    {'name': 'air', 'icon': Icons.air, 'label': 'พัดลม'},
    {'name': 'bed', 'icon': Icons.bed, 'label': 'เตียง'},
    {
      'name': 'door_sliding',
      'icon': Icons.door_sliding,
      'label': 'ตู้เสื้อผ้า'
    },
    {'name': 'desk', 'icon': Icons.desk, 'label': 'โต๊ะทำงาน'},
    {
      'name': 'water_drop',
      'icon': Icons.water_drop,
      'label': 'เครื่องทำน้ำอุ่น'
    },
    {'name': 'wifi', 'icon': Icons.wifi, 'label': 'WiFi'},
    {'name': 'local_parking', 'icon': Icons.local_parking, 'label': 'ที่จอดรถ'},
    {'name': 'videocam', 'icon': Icons.videocam, 'label': 'กล้องวงจรปิด'},
    {'name': 'credit_card', 'icon': Icons.credit_card, 'label': 'คีย์การ์ด'},
    {'name': 'tv', 'icon': Icons.tv, 'label': 'ทีวี'},
    {'name': 'kitchen', 'icon': Icons.kitchen, 'label': 'ครัว'},
    {'name': 'shower', 'icon': Icons.shower, 'label': 'ฝักบัว'},
    {'name': 'balcony', 'icon': Icons.balcony, 'label': 'ระเบียง'},
    {'name': 'elevator', 'icon': Icons.elevator, 'label': 'ลิฟต์'},
    {'name': 'security', 'icon': Icons.security, 'label': 'รักษาความปลอดภัย'},
    {
      'name': 'local_laundry',
      'icon': Icons.local_laundry_service,
      'label': 'เครื่องซักผ้า'
    },
    {'name': 'microwave', 'icon': Icons.microwave, 'label': 'ไมโครเวฟ'},
    {'name': 'chair', 'icon': Icons.chair, 'label': 'เก้าอี้'},
    {'name': 'lightbulb', 'icon': Icons.lightbulb, 'label': 'ไฟส่องสว่าง'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAmenities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAmenities() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final amenities = await RoomService.getAmenities();
      if (mounted) {
        setState(() {
          _amenities = amenities;
          _filteredAmenities = amenities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredAmenities = _amenities.where((amenity) {
        final name = (amenity['amenities_name'] ?? '').toString().toLowerCase();
        final desc = (amenity['amenities_desc'] ?? '').toString().toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || desc.contains(searchLower);
      }).toList();
    });
  }

  IconData _getIconData(String? iconName) {
    if (iconName == null) return Icons.star;
    final icon = _iconOptions.firstWhere(
      (opt) => opt['name'] == iconName,
      orElse: () => {'icon': Icons.star},
    );
    return icon['icon'] as IconData;
  }

  Future<void> _showIconPicker(
      TextEditingController controller, String currentIcon) async {
    final selectedIcon = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('เลือกไอคอน'),
        content: Container(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _iconOptions.length,
            itemBuilder: (context, index) {
              final option = _iconOptions[index];
              final isSelected = option['name'] == currentIcon;
              return InkWell(
                onTap: () => Navigator.pop(context, option['name']),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.2)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option['icon'] as IconData,
                        size: 32,
                        color: isSelected ? AppTheme.primary : Colors.grey[700],
                      ),
                      SizedBox(height: 4),
                      Text(
                        option['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              isSelected ? AppTheme.primary : Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
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

    if (selectedIcon != null) {
      controller.text = selectedIcon;
    }
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? amenity}) async {
    final isEdit = amenity != null;
    final nameController = TextEditingController(
      text: isEdit ? amenity['amenities_name'] : '',
    );
    final descController = TextEditingController(
      text: isEdit ? amenity['amenities_desc'] : '',
    );
    final iconController = TextEditingController(
      text: isEdit ? (amenity['amenities_icon'] ?? 'star') : 'star',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit : Icons.add_circle_outline,
                color: AppTheme.primary,
              ),
              SizedBox(width: 8),
              Text(isEdit
                  ? 'แก้ไขสิ่งอำนวยความสะดวก'
                  : 'เพิ่มสิ่งอำนวยความสะดวก'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    await _showIconPicker(
                      iconController,
                      iconController.text,
                    );
                    setDialogState(() {});
                  },
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getIconData(iconController.text),
                          size: 48,
                          color: AppTheme.primary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'แตะเพื่อเลือกไอคอน',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อสิ่งอำนวยความสะดวก *',
                    hintText: 'เช่น แอร์, WiFi',
                    prefixIcon: Icon(Icons.stars),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  autofocus: !isEdit,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'คำอธิบาย',
                    hintText: 'รายละเอียดเพิ่มเติม',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('กรุณากรอกชื่อสิ่งอำนวยความสะดวก'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );

        final data = {
          'amenities_name': nameController.text.trim(),
          'amenities_desc': descController.text.trim(),
          'amenities_icon': iconController.text,
        };

        Map<String, dynamic> response;
        if (isEdit) {
          response = await RoomService.updateAmenity(
            amenity['amenities_id'],
            data,
          );
        } else {
          response = await RoomService.createAmenity(data);
        }

        if (mounted) Navigator.pop(context);

        if (mounted) {
          if (response['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message']),
                backgroundColor: Colors.green,
              ),
            );
            await _loadAmenities();
          } else {
            throw Exception(response['message']);
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

  Future<void> _deleteAmenity(Map<String, dynamic> amenity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('ยืนยันการลบ'),
          ],
        ),
        content: Text(
          'คุณต้องการลบสิ่งอำนวยความสะดวก "${amenity['amenities_name']}" ใช่หรือไม่?\n\nหากมีห้องที่ใช้สิ่งอำนวยความสะดวกนี้อยู่ จะไม่สามารถลบได้',
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
            child: Text('ลบ'),
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

        final result = await RoomService.deleteAmenity(
          amenity['amenities_id'],
        );

        if (mounted) Navigator.pop(context);

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
              ),
            );
            await _loadAmenities();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการสิ่งอำนวยความสะดวก'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAmenities,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ค้นหาสิ่งอำนวยความสะดวก',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _filteredAmenities.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.stars_outlined,
                                size: 80, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'ไม่พบสิ่งอำนวยความสะดวกที่ค้นหา'
                                  : 'ยังไม่มีสิ่งอำนวยความสะดวก',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showAddEditDialog(),
                              icon: Icon(Icons.add),
                              label: Text('เพิ่มสิ่งอำนวยความสะดวกแรก'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: _filteredAmenities.length,
                        itemBuilder: (context, index) {
                          final amenity = _filteredAmenities[index];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showAddEditDialog(amenity: amenity),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getIconData(amenity['amenities_icon']),
                                        color: Colors.orange,
                                        size: 40,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      amenity['amenities_name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (amenity['amenities_desc'] != null &&
                                        amenity['amenities_desc']
                                            .toString()
                                            .isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        amenity['amenities_desc'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit,
                                              size: 18, color: Colors.blue),
                                          onPressed: () => _showAddEditDialog(
                                              amenity: amenity),
                                          tooltip: 'แก้ไข',
                                          padding: EdgeInsets.all(4),
                                          constraints: BoxConstraints(),
                                        ),
                                        SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                          onPressed: () =>
                                              _deleteAmenity(amenity),
                                          tooltip: 'ลบ',
                                          padding: EdgeInsets.all(4),
                                          constraints: BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primary,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'เพิ่มสิ่งอำนวยความสะดวก',
      ),
    );
  }
}
