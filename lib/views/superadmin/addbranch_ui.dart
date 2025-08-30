import 'package:flutter/material.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/model/user_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AddBranchScreen extends StatefulWidget {
  const AddBranchScreen({Key? key}) : super(key: key);

  @override
  State<AddBranchScreen> createState() => _AddBranchScreenState();
}

class _AddBranchScreenState extends State<AddBranchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _branchAddressController = TextEditingController();
  final _branchPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedOwnerId;
  String? _selectedOwnerName;
  File? _branchImage;
  bool _isLoading = false;
  List<UserModel> _adminUsers = [];

  @override
  void initState() {
    super.initState();
    _loadAdminUsers();
  }

  Future<void> _loadAdminUsers() async {
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
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _branchImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveBranch() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedOwnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณาเลือกเจ้าของสาขา')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert image to base64 if selected
      String? imageBase64;
      if (_branchImage != null) {
        imageBase64 = await AuthService.fileToBase64(_branchImage!);
      }

      // Insert branch data (สมมติว่ามี BranchService)
      final response = await supabase.from('branches').insert({
        'branch_name': _branchNameController.text.trim(),
        'branch_address': _branchAddressController.text.trim(),
        'branch_phone': _branchPhoneController.text.trim(),
        'owner_id': _selectedOwnerId,
        'owner_name': _selectedOwnerName,
        'branch_status': 'active',
        'branch_image': imageBase64,
        'description': _descriptionController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เพิ่มสาขาสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // ส่งค่า true กลับไปเพื่อ refresh
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
      appBar: AppBar(
        title: Text('เพิ่มสาขาใหม่'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveBranch,
            child: Text(
              'บันทึก',
              style: TextStyle(color: Colors.white),
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
              // Branch Image
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _branchImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _branchImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  size: 40, color: Colors.grey[600]),
                              SizedBox(height: 8),
                              Text('เพิ่มรูปภาพ',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Branch Name
              TextFormField(
                controller: _branchNameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อสาขา *',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อสาขา';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Branch Address
              TextFormField(
                controller: _branchAddressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'ที่อยู่สาขา *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกที่อยู่สาขา';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Branch Phone
              TextFormField(
                controller: _branchPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'เบอร์โทรสาขา *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกเบอร์โทรสาขา';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Owner Selection
              DropdownButtonFormField<String>(
                value: _selectedOwnerId,
                decoration: InputDecoration(
                  labelText: 'เจ้าของสาขา *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: _adminUsers.map((user) {
                  return DropdownMenuItem<String>(
                    value: user.userId,
                    child: Text(
                        '${user.displayName} (${user.userRole.toString().split('.').last})'),
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
              ),

              SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'รายละเอียดเพิ่มเติม',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),

              SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveBranch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'บันทึกสาขา',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  @override
  void dispose() {
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchPhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
