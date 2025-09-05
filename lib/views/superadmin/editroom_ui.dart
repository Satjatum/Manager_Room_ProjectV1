import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

final supabase = Supabase.instance.client;

class EditRoomUi extends StatefulWidget {
  final String roomId;

  const EditRoomUi({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  State<EditRoomUi> createState() => _EditRoomUiState();
}

class _EditRoomUiState extends State<EditRoomUi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;

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
  String? _selectedCategoryId;
  String? _selectedTypeId;
  String? _selectedStatusId;
  int _maxOccupants = 1;
  List<String> _selectedFacilities = [];
  List<Uint8List> _selectedImages = [];
  List<String> _imageBase64List = [];

  // Current room data
  Map<String, dynamic>? _currentRoom;

  // Data Lists from Database
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _roomTypes = [];
  List<Map<String, dynamic>> _facilities = [];
  List<Map<String, dynamic>> _statusTypes = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      await Future.wait([
        _loadRoomData(),
        _loadBranches(),
        _loadCategories(),
        _loadRoomTypes(),
        _loadFacilities(),
        _loadStatusTypes(),
      ]);

      // Set form values from current room data
      if (_currentRoom != null) {
        _populateFormFields();
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadRoomData() async {
    try {
      final response = await supabase
          .from('rooms')
          .select('*')
          .eq('room_id', widget.roomId)
          .single();

      setState(() {
        _currentRoom = response;
      });
    } catch (e) {
      print('Error loading room data: $e');
      throw Exception('ไม่พบข้อมูลห้อง');
    }
  }

  void _populateFormFields() {
    if (_currentRoom == null) return;

    _roomNumberController.text = _currentRoom!['room_number'] ?? '';
    _roomNameController.text = _currentRoom!['room_name'] ?? '';
    _roomRateController.text = _currentRoom!['room_rate']?.toString() ?? '';
    _roomDepositController.text =
        _currentRoom!['room_deposit']?.toString() ?? '';
    _roomSizeController.text = _currentRoom!['room_size']?.toString() ?? '';
    _roomDescriptionController.text = _currentRoom!['room_des'] ?? '';

    _selectedBranchId = _currentRoom!['branch_id'];
    _selectedBranchName = _currentRoom!['branch_name'];
    _selectedCategoryId = _currentRoom!['category_id'];
    _selectedTypeId = _currentRoom!['type_id'];
    _selectedStatusId = _currentRoom!['status_id'];
    _maxOccupants = _currentRoom!['room_max'] ?? 1;

    // Load facilities
    if (_currentRoom!['room_fac'] != null) {
      _selectedFacilities = List<String>.from(_currentRoom!['room_fac']);
    }

    // Load images
    if (_currentRoom!['room_images'] != null) {
      try {
        final imagesList = jsonDecode(_currentRoom!['room_images']);
        if (imagesList is List) {
          _imageBase64List = List<String>.from(imagesList);
          // Convert base64 to Uint8List for display
          _selectedImages = _imageBase64List.map((base64String) {
            return base64Decode(base64String);
          }).toList();
        }
      } catch (e) {
        print('Error parsing images: $e');
      }
    }
  }

  Future<void> _loadBranches() async {
    try {
      final currentUser = AuthService.getCurrentUser();
      late List<dynamic> response;

      if (currentUser?.isSuperAdmin ?? false) {
        response = await supabase
            .from('branches')
            .select('branch_id, branch_name')
            .eq('branch_status', 'active')
            .order('branch_name');
      } else if (currentUser?.isAdmin ?? false) {
        response = await supabase
            .from('branches')
            .select('branch_id, branch_name')
            .eq('owner_id', currentUser!.userId)
            .eq('branch_status', 'active')
            .order('branch_name');
      } else {
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

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('room_categories')
          .select('*')
          .eq('is_active', true)
          .order('display_order');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadRoomTypes() async {
    try {
      final response = await supabase
          .from('room_types')
          .select('*')
          .eq('is_active', true)
          .order('display_order');

      setState(() {
        _roomTypes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading room types: $e');
    }
  }

  Future<void> _loadFacilities() async {
    try {
      final response = await supabase
          .from('room_facilities')
          .select('*')
          .eq('is_active', true)
          .order('display_order');

      setState(() {
        _facilities = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading facilities: $e');
    }
  }

  Future<void> _loadStatusTypes() async {
    try {
      final response = await supabase
          .from('room_status_types')
          .select('*')
          .eq('is_active', true)
          .order('display_order');

      setState(() {
        _statusTypes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading status types: $e');
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

  Future<void> _updateRoom() async {
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
      // ตรวจสอบว่าหมายเลขห้องซ้ำหรือไม่ (ยกเว้นห้องปัจจุบัน)
      final existingRoom = await supabase
          .from('rooms')
          .select('room_id')
          .eq('branch_id', _selectedBranchId!)
          .eq('room_number', _roomNumberController.text.trim())
          .neq('room_id', widget.roomId)
          .maybeSingle();

      if (existingRoom != null) {
        throw Exception(
            'หมายเลขห้อง ${_roomNumberController.text} มีอยู่แล้วในสาขานี้');
      }

      final roomData = {
        'branch_id': _selectedBranchId,
        'branch_name': _selectedBranchName ?? '',
        'room_number': _roomNumberController.text.trim(),
        'room_name': _roomNameController.text.trim(),
        'room_rate': double.parse(_roomRateController.text.trim()),
        'room_deposit': double.parse(_roomDepositController.text.trim()),
        'room_max': _maxOccupants,
        'room_size': _roomSizeController.text.isNotEmpty
            ? double.parse(_roomSizeController.text.trim())
            : null,
        'room_fac': _selectedFacilities,
        'room_images':
            _imageBase64List.isNotEmpty ? jsonEncode(_imageBase64List) : null,
        'room_des': _roomDescriptionController.text.trim().isNotEmpty
            ? _roomDescriptionController.text.trim()
            : null,
        'category_id': _selectedCategoryId,
        'type_id': _selectedTypeId,
        'status_id': _selectedStatusId,
        'room_cate': _categories.firstWhere(
          (cat) => cat['category_id'] == _selectedCategoryId,
          orElse: () => {'category_code': 'standard'},
        )['category_code'],
        'room_type': _roomTypes.firstWhere(
          (type) => type['type_id'] == _selectedTypeId,
          orElse: () => {'type_code': 'single'},
        )['type_code'],
        'room_status': _statusTypes.firstWhere(
          (status) => status['status_id'] == _selectedStatusId,
          orElse: () => {'status_code': 'available'},
        )['status_code'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase
          .from('rooms')
          .update(roomData)
          .eq('room_id', widget.roomId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปเดตห้อง ${_roomNameController.text} สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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

  Future<void> _deleteRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบห้อง ${_roomNameController.text} หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await supabase.from('rooms').delete().eq('room_id', widget.roomId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ลบห้อง ${_roomNameController.text} สำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาดในการลบห้อง: ${e.toString()}'),
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
  }

  IconData _getIconFromString(String? iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'home_outlined':
        return Icons.home_outlined;
      case 'home_work':
        return Icons.home_work;
      case 'apartment':
        return Icons.apartment;
      case 'villa':
        return Icons.villa;
      case 'single_bed':
        return Icons.single_bed;
      case 'bed':
        return Icons.bed;
      case 'king_bed':
        return Icons.king_bed;
      case 'family_restroom':
        return Icons.family_restroom;
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
      case 'check_circle':
        return Icons.check_circle;
      case 'people':
        return Icons.people;
      case 'build':
        return Icons.build;
      case 'bookmark':
        return Icons.bookmark;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'construction':
        return Icons.construction;
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
        return Icons.help_outline;
    }
  }

  Color _getColorFromString(String? colorString) {
    if (colorString == null) return AppColors.primary;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลห้อง'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text('กำลังโหลดข้อมูล...'),
                ],
              ),
            )
          : _isLoading
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
                        // รูปภาพห้อง
                        _buildImageSection(),

                        const SizedBox(height: 24),

                        // หมายเลขห้อง
                        _buildRoomNumberField(),

                        const SizedBox(height: 16),

                        // ชื่อห้อง
                        _buildRoomNameField(),

                        const SizedBox(height: 16),

                        // ค่าเช่า
                        _buildRentField(),

                        const SizedBox(height: 16),

                        // เงินมัดจำ
                        _buildDepositField(),

                        const SizedBox(height: 16),

                        // จำนวนที่พัก
                        _buildOccupantsField(),

                        const SizedBox(height: 16),

                        // ขนาดห้อง
                        _buildRoomSizeField(),

                        const SizedBox(height: 24),

                        // หมวดหมู่และประเภทห้อง
                        _buildCategoryTypeSection(),

                        const SizedBox(height: 24),

                        // สิ่งอำนวยความสะดวก
                        _buildFacilitiesSection(),

                        const SizedBox(height: 24),

                        // สถานะห้อง
                        _buildStatusSection(),

                        const SizedBox(height: 24),

                        // คำอธิบาย
                        _buildDescriptionField(),

                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading || _isLoadingData
                                ? null
                                : _updateRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('แก้ไขห้อง',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading || _isLoadingData
                                ? null
                                : _deleteRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('ลบห้อง',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'รูปภาพห้อง',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _selectedImages.isNotEmpty
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _selectedImages[0],
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.white, size: 20),
                              onPressed: _pickImages,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.white, size: 20),
                              onPressed: () => _removeImage(0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: _pickImages,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey[300]!, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'เพิ่มรูปภาพห้อง',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            children: required
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.primary),
              suffixText: suffix,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomNumberField() {
    return _buildFormField(
      label: 'หมายเลขห้อง',
      controller: _roomNumberController,
      icon: Icons.numbers,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'กรุณาใส่หมายเลขห้อง';
        }
        return null;
      },
    );
  }

  Widget _buildRoomNameField() {
    return _buildFormField(
      label: 'ชื่อห้อง (ถ้ามี)',
      controller: _roomNameController,
      icon: Icons.home,
      required: false,
    );
  }

  Widget _buildRentField() {
    return _buildFormField(
      label: 'ค่าเช่า',
      controller: _roomRateController,
      icon: Icons.monetization_on,
      suffix: 'บาท/เดือน',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'กรุณาใส่ค่าเช่า';
        }
        if (double.tryParse(value) == null || double.parse(value) <= 0) {
          return 'กรุณาใส่ค่าเช่าที่ถูกต้อง';
        }
        return null;
      },
    );
  }

  Widget _buildDepositField() {
    return _buildFormField(
      label: 'เงินมัดจำ',
      controller: _roomDepositController,
      icon: Icons.account_balance_wallet,
      suffix: 'บาท',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'กรุณาใส่เงินมัดจำ';
        }
        if (double.tryParse(value) == null || double.parse(value) < 0) {
          return 'กรุณาใส่เงินมัดจำที่ถูกต้อง';
        }
        return null;
      },
    );
  }

  Widget _buildOccupantsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            text: 'จำนวนที่พัก',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            children: [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextFormField(
            initialValue: _maxOccupants.toString(),
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
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.people, color: AppColors.primary),
              suffixText: 'คน',
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomSizeField() {
    return _buildFormField(
      label: 'ขนาดห้อง (ตร.ม.)',
      controller: _roomSizeController,
      icon: Icons.square_foot,
      suffix: 'ตร.ม.',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      required: false,
    );
  }

  Widget _buildCategoryTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'หมวดหมู่และประเภทห้อง',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (_categories.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((category) {
              final isSelected = _selectedCategoryId == category['category_id'];
              return FilterChip(
                avatar: Icon(
                  _getIconFromString(category['category_icon']),
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                label: Text(
                  category['category_name'] ?? '',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategoryId = category['category_id'];
                  });
                },
                selectedColor: _getColorFromString(category['category_color']),
                backgroundColor: Colors.grey[100],
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        if (_roomTypes.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _roomTypes.map((type) {
              final isSelected = _selectedTypeId == type['type_id'];
              return FilterChip(
                avatar: Icon(
                  _getIconFromString(type['type_icon']),
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                label: Text(
                  type['type_name'] ?? '',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedTypeId = type['type_id'];
                    _maxOccupants = type['default_max_occupants'] ?? 1;
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: Colors.grey[100],
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildFacilitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สิ่งอำนวยความสะดวก',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (_facilities.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _facilities.map((facility) {
              final facilityCode = facility['facility_code'] ?? '';
              final isSelected = _selectedFacilities.contains(facilityCode);
              return FilterChip(
                avatar: Icon(
                  _getIconFromString(facility['facility_icon']),
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                label: Text(
                  facility['facility_name'] ?? '',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFacilities.add(facilityCode);
                    } else {
                      _selectedFacilities.remove(facilityCode);
                    }
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: Colors.grey[100],
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สถานะห้อง',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedStatusId,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.info, color: AppColors.primary),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: _statusTypes.map((status) {
              return DropdownMenuItem<String>(
                value: status['status_id'],
                child: Row(
                  children: [
                    Icon(
                      _getIconFromString(status['status_icon']),
                      color: _getColorFromString(status['status_color']),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(status['status_name'] ?? ''),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatusId = value;
              });
            },
            validator: (value) => value == null ? 'กรุณาเลือกสถานะห้อง' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'คำอธิบายเพิ่มเติม',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextFormField(
            controller: _roomDescriptionController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(Icons.description, color: AppColors.primary),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: 'เช่น ห้องมีวิวสวน, ใกล้ลิฟต์, ชั้น 2...',
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ),
      ],
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
