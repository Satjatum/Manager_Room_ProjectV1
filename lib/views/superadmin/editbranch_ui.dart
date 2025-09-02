import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';

class EditBranchScreen extends StatefulWidget {
  final Map<String, dynamic> branch;

  const EditBranchScreen({
    Key? key,
    required this.branch,
  }) : super(key: key);

  @override
  State<EditBranchScreen> createState() => _EditBranchScreenState();
}

final supabase = Supabase.instance.client;

class _EditBranchScreenState extends State<EditBranchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _branchAddressController = TextEditingController();
  final _branchPhoneController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedStatus = 'active';
  String? _selectedOwnerId;
  String? _branchImageBase64;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isLoadingOwners = false;
  List<Map<String, dynamic>> _availableOwners = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadAvailableOwners();
  }

  void _initializeData() {
    // ดึงข้อมูลจาก branch ที่ส่งเข้ามา
    _branchNameController.text = widget.branch['branch_name'] ?? '';
    _branchAddressController.text = widget.branch['branch_address'] ?? '';
    _branchPhoneController.text = widget.branch['branch_phone'] ?? '';
    _ownerNameController.text = widget.branch['owner_name'] ?? '';
    _descriptionController.text = widget.branch['description'] ?? '';
    _selectedStatus = widget.branch['branch_status'] ?? 'active';
    _selectedOwnerId = widget.branch['owner_id'];
    _branchImageBase64 = widget.branch['branch_image'];

    // แปลง base64 เป็น bytes สำหรับแสดงภาพ
    if (_branchImageBase64 != null && _branchImageBase64!.isNotEmpty) {
      try {
        _imageBytes = base64Decode(_branchImageBase64!);
      } catch (e) {
        print('Error decoding image: $e');
        _imageBytes = null;
      }
    }
  }

  Future<void> _loadAvailableOwners() async {
    setState(() {
      _isLoadingOwners = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();

      // เฉพาะ Super Admin เท่านั้นที่เห็น dropdown เลือก owner
      if (currentUser?.isSuperAdmin ?? false) {
        final response = await supabase
            .from('users')
            .select('user_id, username, user_email, user_role')
            .inFilter('user_role', ['admin', 'superadmin'])
            .eq('user_status', 'active')
            .order('username');

        setState(() {
          _availableOwners = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error loading owners: $e');
    } finally {
      setState(() {
        _isLoadingOwners = false;
      });
    }
  }

  Future<void> _pickImage() async {
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

        setState(() {
          _imageBytes = bytes;
          _branchImageBase64 = base64String;
        });
      }
    } catch (e) {
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

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _branchImageBase64 = null;
    });
  }

  Future<void> _updateBranch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();

      // สร้าง data object สำหรับอัพเดท
      Map<String, dynamic> updateData = {
        'branch_name': _branchNameController.text.trim(),
        'branch_address': _branchAddressController.text.trim(),
        'branch_phone': _branchPhoneController.text.trim(),
        'branch_status': _selectedStatus,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'branch_image': _branchImageBase64,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // ถ้าเป็น Super Admin ให้อัพเดท owner ได้
      if (currentUser?.isSuperAdmin ?? false) {
        if (_selectedOwnerId != null) {
          updateData['owner_id'] = _selectedOwnerId;
        }
        updateData['owner_name'] = _ownerNameController.text.trim();
      }

      // อัพเดทข้อมูลใน database
      await supabase
          .from('branches')
          .update(updateData)
          .eq('branch_id', widget.branch['branch_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('อัพเดทข้อมูลสาขาสำเร็จ'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // กลับไปหน้าก่อนหน้าพร้อมส่งผลลัพธ์
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการอัพเดท: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
    final currentUser = AuthService.getCurrentUser();
    final isSuperAdmin = currentUser?.isSuperAdmin ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'แก้ไขข้อมูลสาขา',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // รูปภาพสาขา
              _buildImageSection(),
              const SizedBox(height: 24),

              // ชื่อสาขา
              _buildTextFormField(
                controller: _branchNameController,
                label: 'ชื่อสาขา',
                icon: Icons.business,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'กรุณากรอกชื่อสาขา';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ที่อยู่สาขา
              _buildTextFormField(
                controller: _branchAddressController,
                label: 'ที่อยู่สาขา',
                icon: Icons.location_on,
                maxLines: 3,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'กรุณากรอกที่อยู่สาขา';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // เบอร์โทรศัพท์
              _buildTextFormField(
                controller: _branchPhoneController,
                label: 'เบอร์โทรศัพท์',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'กรุณากรอกเบอร์โทรศัพท์';
                  }
                  if (value!.trim().length < 9 || value.trim().length > 10) {
                    return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // เจ้าของสาขา
              if (isSuperAdmin) ...[
                _buildOwnerSection(),
                const SizedBox(height: 16),
              ] else ...[
                _buildTextFormField(
                  controller: _ownerNameController,
                  label: 'เจ้าของสาขา',
                  icon: Icons.person,
                  enabled: false,
                ),
                const SizedBox(height: 16),
              ],

              // สถานะสาขา
              _buildStatusDropdown(),
              const SizedBox(height: 16),

              // รายละเอียดเพิ่มเติม
              _buildTextFormField(
                controller: _descriptionController,
                label: 'รายละเอียดเพิ่มเติม',
                icon: Icons.description,
                maxLines: 4,
                required: false,
              ),
              const SizedBox(height: 32),

              // ปุ่มบันทึก
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateBranch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('กำลังอัพเดท...',
                                style: TextStyle(fontSize: 16)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text(
                              'บันทึกการแก้ไข',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
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
        Text(
          'รูปภาพสาขา',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 2),
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: _imageBytes != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _imageBytes!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildImageButton(
                            icon: Icons.edit,
                            onPressed: _pickImage,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildImageButton(
                            icon: Icons.delete,
                            onPressed: _removeImage,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'แตะเพื่อเลือกรูปภาพ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'รองรับ JPG, PNG',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildImageButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 18),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = true,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            children: required
                ? [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: EdgeInsets.all(12),
              child: Icon(icon,
                  color: enabled ? AppColors.primary : Colors.grey[400],
                  size: 20),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'เจ้าของสาขา',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
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
        if (_isLoadingOwners)
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('กำลังโหลดข้อมูล...'),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            child: DropdownButtonFormField<String>(
              value: _selectedOwnerId,
              decoration: InputDecoration(
                prefixIcon: Container(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.person_outline,
                      color: AppColors.primary, size: 20),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 20), // เพิ่มความสูง
              ),
              hint: Text('เลือกเจ้าของสาขา'),
              isExpanded: true,
              isDense: false, // ให้มีพื้นที่มากขึ้น
              menuMaxHeight: 300, // จำกัดความสูงของ dropdown menu
              items: _availableOwners.map((owner) {
                return DropdownMenuItem<String>(
                  value: owner['user_id'],
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          owner['username'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: 2),
                        Text(
                          '(${owner['user_role']?.toString().split('.').last ?? 'admin'})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedOwnerId = value;
                  // อัพเดท owner name ตาม selection
                  if (value != null) {
                    final selectedOwner = _availableOwners.firstWhere(
                      (owner) => owner['user_id'] == value,
                      orElse: () => {},
                    );
                    _ownerNameController.text = selectedOwner['username'] ?? '';
                  }
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาเลือกเจ้าของสาขา';
                }
                return null;
              },
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'สถานะสาขา',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.flag, color: AppColors.primary, size: 20),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: const [
            DropdownMenuItem(
              value: 'active',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 12),
                  Text('เปิดใช้งาน'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'inactive',
              child: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.orange, size: 20),
                  SizedBox(width: 12),
                  Text('ปิดใช้งาน'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'maintenance',
              child: Row(
                children: [
                  Icon(Icons.build, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Text('ซ่อมบำรุง'),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedStatus = value!;
            });
          },
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
          isExpanded: true,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchPhoneController.dispose();
    _ownerNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
