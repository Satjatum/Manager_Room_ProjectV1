import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/model/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddBranchScreen extends StatefulWidget {
  const AddBranchScreen({Key? key}) : super(key: key);

  @override
  State<AddBranchScreen> createState() => _AddBranchScreenState();
}

final supabase = Supabase.instance.client;

class _AddBranchScreenState extends State<AddBranchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _branchAddressController = TextEditingController();
  final _branchPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedOwnerId;
  String? _selectedOwnerName;
  String? _branchImageBase64;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isLoadingOwners = false;
  List<UserModel> _adminUsers = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAdminUsers();
  }

  Future<void> _loadAdminUsers() async {
    setState(() {
      _isLoadingOwners = true;
    });

    try {
      final users = await AuthService.getAllUsers();
      setState(() {
        _adminUsers = users
            .where((user) =>
                user.userRole == UserRole.admin ||
                user.userRole == UserRole.superAdmin)
            .toList();
      });
    } catch (e) {
      print('Error loading admin users: $e');
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
        // Read file as bytes - this works on both web and mobile
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);

        setState(() {
          _imageBytes = bytes;
          _branchImageBase64 = base64String;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('เลือกรูปภาพสำเร็จ'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Handle lost data for mobile platforms only (not available on web)
      if (!kIsWeb && !kDebugMode) {
        try {
          final lost = await _picker.retrieveLostData();
          if (!lost.isEmpty && lost.file != null) {
            final bytes = await lost.file!.readAsBytes();
            final base64String = base64Encode(bytes);

            setState(() {
              _imageBytes = bytes;
              _branchImageBase64 = base64String;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.restore, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('กู้คืนรูปภาพสำเร็จ'),
                    ],
                  ),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            return;
          }
        } catch (lostError) {
          print('Error retrieving lost data: $lostError');
          // Continue to show cancellation message
        }
      }

      // User cancelled or no image selected
      print('Image selection cancelled by user');
    } catch (e) {
      print('Error in image picker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child:
                      Text('เกิดข้อผิดพลาดในการเลือกรูปภาพ: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
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

  Future<void> _saveBranch() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedOwnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('กรุณาเลือกเจ้าของสาขา'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Insert branch data - use the base64 string directly instead of calling AuthService.fileToBase64
      final response = await supabase.from('branches').insert({
        'branch_name': _branchNameController.text.trim(),
        'branch_address': _branchAddressController.text.trim(),
        'branch_phone': _branchPhoneController.text.trim(),
        'owner_id': _selectedOwnerId,
        'owner_name': _selectedOwnerName,
        'branch_status': 'active',
        'branch_image': _branchImageBase64, // Use the base64 string directly
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('เพิ่มสาขาสำเร็จ'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // ส่งค่า true กลับไปเพื่อ refresh
      }
    } catch (e) {
      print('Error saving branch: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'ลองใหม่',
              textColor: Colors.white,
              onPressed: _saveBranch,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'เพิ่มสาขาใหม่',
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
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // รูปภาพสาขา
              _buildImageSection(),
              SizedBox(height: 24),

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
              SizedBox(height: 16),

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
              SizedBox(height: 16),

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
              SizedBox(height: 16),

              // เจ้าของสาขา
              _buildOwnerSection(),
              SizedBox(height: 16),

              // รายละเอียดเพิ่มเติม
              _buildTextFormField(
                controller: _descriptionController,
                label: 'รายละเอียดเพิ่มเติม',
                icon: Icons.description,
                maxLines: 4,
                required: false,
              ),
              SizedBox(height: 32),

              // ปุ่มบันทึก
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveBranch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? Row(
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
                            Text('กำลังบันทึก...',
                                style: TextStyle(fontSize: 16)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text(
                              'บันทึกสาขา',
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
        SizedBox(height: 8),
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
                          SizedBox(width: 8),
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
                      border: Border.all(
                        color: Colors.grey[300]!,
                        style: BorderStyle.solid,
                      ),
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
                        SizedBox(height: 12),
                        Text(
                          'แตะเพื่อเลือกรูปภาพ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
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
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: EdgeInsets.all(12),
              child: Icon(icon, color: AppColors.primary, size: 20),
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
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
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
        SizedBox(height: 8),
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
              items: _adminUsers.map((user) {
                return DropdownMenuItem<String>(
                  value: user.userId,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: 2),
                        Text(
                          '(${user.userRole.toString().split('.').last})',
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
                  _selectedOwnerName = _adminUsers
                      .firstWhere((user) => user.userId == value)
                      .displayName;
                });
              },
              validator: (value) {
                if (value == null) {
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

  @override
  void dispose() {
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchPhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
