import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({Key? key}) : super(key: key);

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'maintenance';
  String _selectedPriority = 'normal';
  List<File> _selectedImages = [];
  List<String> _imageBase64List = [];

  bool _isSubmitting = false;
  Map<String, dynamic>? _tenantData;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadTenantData();
  }

  Future<void> _loadTenantData() async {
    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser?.tenantId == null) {
        throw Exception('ไม่พบข้อมูลผู้เช่า');
      }

      final tenantResponse = await supabase.from('tenants').select('''
            *, rooms!inner(room_number, room_name),
            branches!inner(branch_name)
          ''').eq('tenant_id', currentUser!.tenantId!).single();

      setState(() {
        _tenantData = tenantResponse;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();

      if (images.length > 5) {
        _showErrorSnackBar('สามารถแนบรูปภาพได้สูงสุด 5 รูป');
        return;
      }

      List<File> imageFiles = [];
      List<String> base64Images = [];

      for (XFile xFile in images) {
        final file = File(xFile.path);
        final bytes = await file.readAsBytes();

        // ตรวจสอบขนาดไฟล์ (จำกัดที่ 2MB ต่อรูป)
        if (bytes.length > 2 * 1024 * 1024) {
          _showErrorSnackBar('รูปภาพต้องมีขนาดไม่เกิน 2MB ต่อรูป');
          continue;
        }

        imageFiles.add(file);
        base64Images.add(base64Encode(bytes));
      }

      setState(() {
        _selectedImages = imageFiles;
        _imageBase64List = base64Images;
      });
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
      _imageBase64List.removeAt(index);
    });
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();

      // เตรียมข้อมูลรูปภาพ
      String? imagesData;
      if (_imageBase64List.isNotEmpty) {
        imagesData = jsonEncode(_imageBase64List);
      }

      // บันทึกปัญหาลงฐานข้อมูล
      final issueData = {
        'branch_id': _tenantData!['branch_id'],
        'room_id': _tenantData!['room_id'],
        'tenant_id': _tenantData!['tenant_id'],
        'issue_title': _titleController.text.trim(),
        'issue_description': _descriptionController.text.trim(),
        'issue_category': _selectedCategory,
        'issue_priority': _selectedPriority,
        'issue_status': 'reported',
        'issue_images': imagesData,
        'reported_by': currentUser!.userId,
        'reported_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response =
          await supabase.from('issues').insert(issueData).select().single();

      // สร้าง update record แรก
      await supabase.from('issue_updates').insert({
        'issue_id': response['issue_id'],
        'updated_by': currentUser.userId,
        'update_type': 'status_change',
        'new_status': 'reported',
        'update_message': 'รายงานปัญหาเริ่มต้น',
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSuccessSnackBar(
          'รายงานปัญหาสำเร็จ! หมายเลข: ${response['issue_id'].toString().substring(0, 8)}');

      // กลับไปหน้าก่อนหน้า
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการรายงานปัญหา: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('รายงานปัญหา'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('รายงานปัญหา'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ข้อมูลห้อง
              _buildRoomInfoCard(),
              SizedBox(height: 20),

              // หัวข้อปัญหา
              Text(
                'หัวข้อปัญหา',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'เช่น ก๊อกน้ำรั่ว, ไฟไม่ติด, แอร์เสีย',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'กรุณากรอกหัวข้อปัญหา';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // รายละเอียดปัญหา
              Text(
                'รายละเอียดปัญหา',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'อธิบายรายละเอียดปัญหา อาการ และสิ่งที่ต้องการให้แก้ไข',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'กรุณากรอกรายละเอียดปัญหา';
                  }
                  if (value!.trim().length < 10) {
                    return 'รายละเอียดต้องมีอย่างน้อย 10 ตัวอักษร';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // ประเภทปัญหา
              Text(
                'ประเภทปัญหา',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'plumbing',
                      child: Row(
                        children: [
                          Icon(Icons.plumbing, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('ปัญหาน้ำ/ประปา'),
                        ],
                      )),
                  DropdownMenuItem(
                      value: 'electrical',
                      child: Row(
                        children: [
                          Icon(Icons.electrical_services,
                              color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('ปัญหาไฟฟ้า'),
                        ],
                      )),
                  DropdownMenuItem(
                      value: 'cleaning',
                      child: Row(
                        children: [
                          Icon(Icons.cleaning_services,
                              color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('ความสะอาด'),
                        ],
                      )),
                  DropdownMenuItem(
                      value: 'maintenance',
                      child: Row(
                        children: [
                          Icon(Icons.build, color: Colors.brown, size: 20),
                          SizedBox(width: 8),
                          Text('ซ่อมบำรุง'),
                        ],
                      )),
                  DropdownMenuItem(
                      value: 'security',
                      child: Row(
                        children: [
                          Icon(Icons.security, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('ความปลอดภัย'),
                        ],
                      )),
                  DropdownMenuItem(
                      value: 'other',
                      child: Row(
                        children: [
                          Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                          SizedBox(width: 8),
                          Text('อื่นๆ'),
                        ],
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),

              SizedBox(height: 16),

              // ระดับความเร่งด่วน
              Text(
                'ระดับความเร่งด่วน',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('ต่ำ', style: TextStyle(fontSize: 14)),
                      subtitle:
                          Text('ไม่เร่งด่วน', style: TextStyle(fontSize: 12)),
                      value: 'low',
                      groupValue: _selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                      dense: true,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('ปกติ', style: TextStyle(fontSize: 14)),
                      subtitle:
                          Text('ควรแก้ไข', style: TextStyle(fontSize: 12)),
                      value: 'normal',
                      groupValue: _selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                      dense: true,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('สูง', style: TextStyle(fontSize: 14)),
                      subtitle:
                          Text('เร่งด่วน', style: TextStyle(fontSize: 12)),
                      value: 'high',
                      groupValue: _selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                      dense: true,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('ด่วนมาก', style: TextStyle(fontSize: 14)),
                      subtitle:
                          Text('แก้ไขทันที', style: TextStyle(fontSize: 12)),
                      value: 'urgent',
                      groupValue: _selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                      dense: true,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // แนบรูปภาพ
              Text(
                'แนบรูปภาพ (ไม่บังคับ)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: _pickImages,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo,
                          size: 40, color: Colors.grey[600]),
                      SizedBox(height: 8),
                      Text(
                        'แตะเพื่อเลือกรูปภาพ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        'สูงสุด 5 รูป, ขนาดไม่เกิน 2MB ต่อรูป',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),

              if (_selectedImages.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'รูปภาพที่เลือก (${_selectedImages.length})',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
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
                ),
              ],

              SizedBox(height: 32),

              // ปุ่มส่งรายงาน
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitIssue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
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
                            Text('กำลังส่งรายงาน...'),
                          ],
                        )
                      : Text(
                          'ส่งรายงานปัญหา',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลการรายงาน',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ผู้รายงาน: ${_tenantData!['tenant_full_name']}'),
                      Text(
                          'ห้อง: ${_tenantData!['room_number']} - ${_tenantData!['rooms']['room_name']}'),
                      Text('สาขา: ${_tenantData!['branches']['branch_name']}'),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateTime.now().toString().substring(0, 16),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
