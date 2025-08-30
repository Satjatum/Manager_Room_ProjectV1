import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

final supabase = Supabase.instance.client;

class AddRoomScreen extends StatefulWidget {
  final String? branchId;
  final String? branchName;

  const AddRoomScreen({
    Key? key,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form Controllers
  final _roomNumberController = TextEditingController();
  final _roomNameController = TextEditingController();
  final _roomRateController = TextEditingController();
  final _roomDepositController = TextEditingController();
  final _roomSizeController = TextEditingController();
  final _roomDescriptionController = TextEditingController();

  // Form Values
  String? _selectedBranchId;
  String? _selectedBranchName;
  String _selectedCategory = 'standard';
  String _selectedType = 'single';
  String _selectedStatus = 'available';
  int _maxOccupants = 1;
  List<String> _selectedFacilities = [];
  List<Uint8List> _selectedImages = [];
  List<String> _imageBase64List = [];

  // Data Lists
  List<Map<String, dynamic>> _branches = [];
  final List<Map<String, dynamic>> _categories = [
    {'value': 'economy', 'label': 'ประหยัด', 'icon': Icons.home},
    {'value': 'standard', 'label': 'มาตรฐาน', 'icon': Icons.home_outlined},
    {'value': 'deluxe', 'label': 'ดีลักซ์', 'icon': Icons.home_work},
    {'value': 'premium', 'label': 'พรีเมี่ยม', 'icon': Icons.apartment},
    {'value': 'vip', 'label': 'วีไอพี', 'icon': Icons.villa},
  ];

  final List<Map<String, dynamic>> _roomTypes = [
    {'value': 'single', 'label': 'เดี่ยว', 'icon': Icons.single_bed},
    {'value': 'twin', 'label': 'แฝด', 'icon': Icons.bed},
    {'value': 'double', 'label': 'คู่', 'icon': Icons.king_bed},
    {'value': 'family', 'label': 'ครอบครัว', 'icon': Icons.family_restroom},
    {'value': 'studio', 'label': 'สตูดิโอ', 'icon': Icons.apartment},
    {'value': 'suite', 'label': 'สวีท', 'icon': Icons.villa},
  ];

  final List<Map<String, dynamic>> _facilities = [
    {
      'value': 'เครื่องปรับอากาศ',
      'label': 'เครื่องปรับอากาศ',
      'icon': Icons.ac_unit
    },
    {'value': 'Wi-Fi', 'label': 'Wi-Fi', 'icon': Icons.wifi},
    {'value': 'โทรทัศน์', 'label': 'โทรทัศน์', 'icon': Icons.tv},
    {'value': 'ตู้เย็น', 'label': 'ตู้เย็น', 'icon': Icons.kitchen},
    {
      'value': 'เครื่องทำน้ำอุ่น',
      'label': 'เครื่องทำน้ำอุ่น',
      'icon': Icons.hot_tub
    },
    {'value': 'ตู้เสื้อผ้า', 'label': 'ตู้เสื้อผ้า', 'icon': Icons.checkroom},
    {'value': 'โต๊ะทำงาน', 'label': 'โต๊ะทำงาน', 'icon': Icons.desk},
    {'value': 'ระเบียง', 'label': 'ระเบียง', 'icon': Icons.balcony},
    {'value': 'ที่จอดรถ', 'label': 'ที่จอดรถ', 'icon': Icons.local_parking},
    {
      'value': 'เครื่องซักผ้า',
      'label': 'เครื่องซักผ้า',
      'icon': Icons.local_laundry_service
    },
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    _selectedBranchName = widget.branchName;
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
            .select('branch_id, branch_name')
            .eq('branch_status', 'active')
            .order('branch_name');
      } else if (currentUser?.isAdmin ?? false) {
        // Admin เห็นเฉพาะสาขาตัวเอง
        response = await supabase
            .from('branches')
            .select('branch_id, branch_name')
            .eq('owner_id', currentUser!.userId)
            .eq('branch_status', 'active')
            .order('branch_name');
      } else {
        // User อื่นๆ เห็นเฉพาะสาขาที่สังกัด
        if (currentUser?.branchId != null) {
          response = await supabase
              .from('branches')
              .select('branch_id, branch_name')
              .eq('branch_id', currentUser!.branchId!)
              .eq('branch_status', 'active');
        } else {
          response = [];
        }
      }

      setState(() {
        _branches = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading branches: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage();

      if (images != null && images.isNotEmpty) {
        List<Uint8List> imageBytesList = [];
        List<String> base64List = [];

        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          imageBytesList.add(bytes);
          base64List.add(base64String);
        }

        setState(() {
          _selectedImages = imageBytesList;
          _imageBase64List = base64List;
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเลือกรูปภาพ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageBase64List.removeAt(index);
    });
  }

  Future<void> _submitRoom() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกสาขา')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ตรวจสอบว่าหมายเลขห้องซ้ำหรือไม่
      final existingRoom = await supabase
          .from('rooms')
          .select('room_id')
          .eq('branch_id', _selectedBranchId!)
          .eq('room_number', _roomNumberController.text.trim())
          .maybeSingle();

      if (existingRoom != null) {
        throw Exception(
            'หมายเลขห้อง ${_roomNumberController.text} มีอยู่แล้วในสาขานี้');
      }

      // เตรียมข้อมูลสำหรับบันทึก
      final roomData = {
        'branch_id': _selectedBranchId,
        'branch_name': _selectedBranchName ?? '',
        'room_number': _roomNumberController.text.trim(),
        'room_name': _roomNameController.text.trim(),
        'room_cate': _selectedCategory,
        'room_type': _selectedType,
        'room_rate': double.parse(_roomRateController.text.trim()),
        'room_deposit': double.parse(_roomDepositController.text.trim()),
        'room_max': _maxOccupants,
        'room_size': _roomSizeController.text.isNotEmpty
            ? double.parse(_roomSizeController.text.trim())
            : null,
        'room_fac': _selectedFacilities,
        'room_status': _selectedStatus,
        'room_images':
            _imageBase64List.isNotEmpty ? jsonEncode(_imageBase64List) : null,
        'room_des': _roomDescriptionController.text.trim().isNotEmpty
            ? _roomDescriptionController.text.trim()
            : null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // บันทึกลง Supabase
      await supabase.from('rooms').insert(roomData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เพิ่มห้อง ${_roomNameController.text} สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // ส่งค่ากลับไปว่าเพิ่มสำเร็จ
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มห้องพัก'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _submitRoom,
              child: const Text(
                'บันทึก',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text('กำลังบันทึกข้อมูล...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Branch Selection
                    _buildSectionTitle('สาขา', Icons.business),
                    _buildBranchSelector(),

                    const SizedBox(height: 24),

                    // Basic Info
                    _buildSectionTitle('ข้อมูลพื้นฐาน', Icons.info),
                    _buildBasicInfoFields(),

                    const SizedBox(height: 24),

                    // Category & Type
                    _buildSectionTitle('ประเภทห้อง', Icons.category),
                    _buildCategorySelector(),
                    const SizedBox(height: 16),
                    _buildTypeSelector(),

                    const SizedBox(height: 24),

                    // Pricing
                    _buildSectionTitle('ราคา', Icons.monetization_on),
                    _buildPricingFields(),

                    const SizedBox(height: 24),

                    // Room Details
                    _buildSectionTitle('รายละเอียดห้อง', Icons.home),
                    _buildRoomDetailsFields(),

                    const SizedBox(height: 24),

                    // Facilities
                    _buildSectionTitle('สิ่งอำนวยความสะดวก', Icons.star),
                    _buildFacilitiesSelector(),

                    const SizedBox(height: 24),

                    // Images
                    _buildSectionTitle('รูปภาพห้อง', Icons.image),
                    _buildImageSelector(),

                    const SizedBox(height: 24),

                    // Description
                    _buildSectionTitle('คำอธิบาย', Icons.description),
                    _buildDescriptionField(),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'เพิ่มห้องพัก',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_branches.isEmpty)
              Text(
                'กำลังโหลดข้อมูลสาขา...',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedBranchId,
                decoration: const InputDecoration(
                  labelText: 'เลือกสาขา',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                items: _branches.map((branch) {
                  return DropdownMenuItem<String>(
                    value: branch['branch_id'],
                    child: Text(branch['branch_name']),
                  );
                }).toList(),
                onChanged: widget.branchId != null
                    ? null
                    : (value) {
                        setState(() {
                          _selectedBranchId = value;
                          _selectedBranchName = _branches.firstWhere(
                              (b) => b['branch_id'] == value)['branch_name'];
                        });
                      },
                validator: (value) => value == null ? 'กรุณาเลือกสาขา' : null,
              ),
            if (_selectedBranchName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'สาขาที่เลือก: $_selectedBranchName',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoFields() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _roomNumberController,
                    decoration: const InputDecoration(
                      labelText: 'หมายเลขห้อง',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณาใส่หมายเลขห้อง';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _roomNameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อห้อง',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.home),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณาใส่ชื่อห้อง';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'สถานะห้อง',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
              ),
              items: const [
                DropdownMenuItem(value: 'available', child: Text('ว่าง')),
                DropdownMenuItem(value: 'occupied', child: Text('มีผู้เช่า')),
                DropdownMenuItem(
                    value: 'maintenance', child: Text('ซ่อมบำรุง')),
                DropdownMenuItem(value: 'reserved', child: Text('จอง')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('หมวดหมู่ห้อง',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category['value'];
                return FilterChip(
                  avatar: Icon(
                    category['icon'],
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  label: Text(
                    category['label'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category['value'];
                    });
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.grey[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ประเภทห้อง',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roomTypes.map((type) {
                final isSelected = _selectedType == type['value'];
                return FilterChip(
                  avatar: Icon(
                    type['icon'],
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  label: Text(
                    type['label'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = type['value'];
                      // อัปเดต max occupants ตาม type
                      switch (type['value']) {
                        case 'single':
                          _maxOccupants = 1;
                          break;
                        case 'twin':
                        case 'double':
                          _maxOccupants = 2;
                          break;
                        case 'family':
                          _maxOccupants = 4;
                          break;
                        case 'studio':
                          _maxOccupants = 2;
                          break;
                        case 'suite':
                          _maxOccupants = 4;
                          break;
                      }
                    });
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.grey[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingFields() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _roomRateController,
                    decoration: const InputDecoration(
                      labelText: 'ค่าเช่ารายเดือน',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on),
                      suffixText: 'บาท',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณาใส่ค่าเช่า';
                      }
                      if (double.tryParse(value) == null ||
                          double.parse(value) <= 0) {
                        return 'กรุณาใส่ค่าเช่าที่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _roomDepositController,
                    decoration: const InputDecoration(
                      labelText: 'เงินมัดจำ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                      suffixText: 'บาท',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณาใส่เงินมัดจำ';
                      }
                      if (double.tryParse(value) == null ||
                          double.parse(value) < 0) {
                        return 'กรุณาใส่เงินมัดจำที่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomDetailsFields() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _roomSizeController,
                    decoration: const InputDecoration(
                      labelText: 'ขนาดห้อง (ไม่บังคับ)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.square_foot),
                      suffixText: 'ตร.ม.',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _maxOccupants.toString(),
                    decoration: const InputDecoration(
                      labelText: 'จำนวนผู้เข้าพักสูงสุด',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people),
                      suffixText: 'คน',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _maxOccupants = int.tryParse(value) ?? 1;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณาใส่จำนวนผู้เข้าพัก';
                      }
                      final num = int.tryParse(value);
                      if (num == null || num <= 0) {
                        return 'กรุณาใส่จำนวนที่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เลือกสิ่งอำนวยความสะดวก',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _facilities.map((facility) {
                final isSelected =
                    _selectedFacilities.contains(facility['value']);
                return FilterChip(
                  avatar: Icon(
                    facility['icon'],
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  label: Text(
                    facility['label'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedFacilities.add(facility['value']);
                      } else {
                        _selectedFacilities.remove(facility['value']);
                      }
                    });
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.grey[100],
                );
              }).toList(),
            ),
            if (_selectedFacilities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'เลือกแล้ว ${_selectedFacilities.length} รายการ',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('รูปภาพห้อง (ไม่บังคับ)',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('เลือกรูป'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedImages.isNotEmpty)
              Container(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedImages[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 32, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'ยังไม่ได้เลือกรูปภาพ',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _roomDescriptionController,
          decoration: const InputDecoration(
            labelText: 'คำอธิบายเพิ่มเติม (ไม่บังคับ)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
            hintText: 'เช่น ห้องมีวิวสวน, ใกล้ลิฟต์, ชั้น 2...',
          ),
          maxLines: 3,
          maxLength: 500,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _roomNameController.dispose();
    _roomRateController.dispose();
    _roomDepositController.dispose();
    _roomSizeController.dispose();
    _roomDescriptionController.dispose();
    super.dispose();
  }
}
