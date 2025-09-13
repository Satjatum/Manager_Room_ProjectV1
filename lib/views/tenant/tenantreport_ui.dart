import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'maintenance';
  String _selectedPriority = 'normal';
  List<File> _selectedImages = [];
  List<Uint8List> _webImageBytes = [];
  List<String> _imageBase64List = [];

  bool _isSubmitting = false;
  Map<String, dynamic>? _tenantData;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));

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

      _animationController?.forward();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final currentCount =
          kIsWeb ? _webImageBytes.length : _selectedImages.length;
      if (currentCount >= 5) {
        _showErrorSnackBar('สามารถแนบรูปภาพได้สูงสุด 5 รูป');
        return;
      }

      if (kIsWeb) {
        await _pickImageWeb();
      } else {
        await _pickImageMobile();
      }
    } catch (e) {
      print('Error in _pickImages: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ');
    }
  }

  Future<void> _pickImageWeb() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;

    input.click();

    await input.onChange.first;

    if (input.files != null && input.files!.isNotEmpty) {
      for (html.File file in input.files!) {
        if (_webImageBytes.length >= 5) {
          _showErrorSnackBar('สามารถแนบรูปภาพได้สูงสุด 5 รูป');
          break;
        }

        if (file.size > 2 * 1024 * 1024) {
          _showErrorSnackBar('รูปภาพต้องมีขนาดไม่เกิน 2MB ต่อรูป');
          continue;
        }

        if (!file.type.startsWith('image/')) {
          _showErrorSnackBar('กรุณาเลือกไฟล์รูปภาพเท่านั้น');
          continue;
        }

        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        await reader.onLoad.first;

        final Uint8List bytes = reader.result as Uint8List;

        setState(() {
          _webImageBytes.add(bytes);
          _imageBase64List.add(base64Encode(bytes));
        });
      }

      if (_webImageBytes.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เพิ่มรูปภาพสำเร็จ (${_webImageBytes.length}/5)'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickImageMobile() async {
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เลือกรูปภาพ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('เลือกจากแกลเลอรี่'),
                onTap: () => Navigator.of(context).pop('gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('ถ่ายรูป'),
                onTap: () => Navigator.of(context).pop('camera'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    XFile? image;

    try {
      if (result == 'gallery') {
        image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );
      } else if (result == 'camera') {
        image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );
      }
    } catch (e) {
      print('Image picker error: $e');
      _showErrorSnackBar('ไม่สามารถเข้าถึงแกลเลอรี่หรือกล้องได้');
      return;
    }

    if (image == null) return;
    await _processSelectedImageMobile(image);
  }

  Future<void> _processSelectedImageMobile(XFile image) async {
    try {
      final file = File(image.path);

      if (!await file.exists()) {
        _showErrorSnackBar('ไม่พบไฟล์รูปภาพ');
        return;
      }

      final bytes = await file.readAsBytes();

      if (bytes.length > 2 * 1024 * 1024) {
        _showErrorSnackBar('รูปภาพต้องมีขนาดไม่เกิน 2MB');
        return;
      }

      setState(() {
        _selectedImages.add(file);
        _imageBase64List.add(base64Encode(bytes));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เพิ่มรูปภาพสำเร็จ (${_selectedImages.length}/5)'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error processing image: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการประมวลผลรูปภาพ');
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      if (kIsWeb) {
        _webImageBytes.removeAt(index);
      } else {
        _selectedImages.removeAt(index);
      }
      _imageBase64List.removeAt(index);
    });
  }

  void _clearAllImages() {
    setState(() {
      if (kIsWeb) {
        _webImageBytes.clear();
      } else {
        _selectedImages.clear();
      }
      _imageBase64List.clear();
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

      String? imagesData;
      if (_imageBase64List.isNotEmpty) {
        imagesData = jsonEncode(_imageBase64List);
      }

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

      await supabase.from('issue_updates').insert({
        'issue_id': response['issue_id'],
        'updated_by': currentUser.userId,
        'update_type': 'status_change',
        'new_status': 'reported',
        'update_message': 'รายงานปัญหาเริ่มต้น',
        'created_at': DateTime.now().toIso8601String(),
      });

      // แสดง Dialog สำเร็จแทนการใช้ SnackBar
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'รายงานปัญหาสำเร็จ!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'หมายเลขรายงาน: ${response['issue_id'].toString().substring(0, 8)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ทีมงานจะดำเนินการตรวจสอบและแก้ไขปัญหาโดยเร็วที่สุด',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // ปิด dialog
                      Navigator.of(context).pop(true); // กลับไปหน้าก่อนหน้า
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('ตกลง'),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Error submitting issue: $e');
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการรายงานปัญหา: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('รายงานปัญหา',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
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
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text('กำลังโหลดข้อมูล...',
                  style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title:
            Text('รายงานปัญหา', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
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
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoomInfoCard(),
                const SizedBox(height: 24),
                _buildSectionCard(
                  title: 'หัวข้อปัญหา',
                  icon: Icons.title,
                  child: TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'เช่น ก๊อกน้ำรั่ว, ไฟไม่ติด, แอร์เสีย',
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
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon:
                          Icon(Icons.text_fields, color: Colors.grey[600]),
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'กรุณากรอกหัวข้อปัญหา';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'รายละเอียดปัญหา',
                  icon: Icons.description,
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'อธิบายรายละเอียดปัญหา อาการ และสิ่งที่ต้องการให้แก้ไข',
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
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
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
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'ประเภทปัญหา',
                  icon: Icons.category,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
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
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'plumbing',
                        child: _buildCategoryItem(
                          Icons.plumbing,
                          'ปัญหาน้ำ/ประปา',
                          Colors.blue,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'electrical',
                        child: _buildCategoryItem(
                          Icons.electrical_services,
                          'ปัญหาไฟฟ้า',
                          Colors.orange,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'cleaning',
                        child: _buildCategoryItem(
                          Icons.cleaning_services,
                          'ความสะอาด',
                          Colors.green,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'maintenance',
                        child: _buildCategoryItem(
                          Icons.build,
                          'ซ่อมบำรุง',
                          Colors.brown,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'security',
                        child: _buildCategoryItem(
                          Icons.security,
                          'ความปลอดภัย',
                          Colors.red,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: _buildCategoryItem(
                          Icons.more_horiz,
                          'อื่นๆ',
                          Colors.grey,
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'ระดับความเร่งด่วน',
                  icon: Icons.priority_high,
                  child: Column(
                    children: [
                      _buildPriorityOption('low', 'ต่ำ', 'ไม่เร่งด่วน',
                          Colors.green, Icons.keyboard_arrow_down),
                      _buildPriorityOption('normal', 'ปกติ', 'ควรแก้ไข',
                          Colors.blue, Icons.remove),
                      _buildPriorityOption('high', 'สูง', 'เร่งด่วน',
                          Colors.orange, Icons.keyboard_arrow_up),
                      _buildPriorityOption('urgent', 'ด่วนมาก', 'แก้ไขทันที',
                          Colors.red, Icons.priority_high),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'แนบรูปภาพ (ไม่บังคับ)',
                  icon: Icons.photo_camera,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: (kIsWeb
                                    ? _webImageBytes.length
                                    : _selectedImages.length) <
                                5
                            ? _pickImages
                            : null,
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: (kIsWeb
                                          ? _webImageBytes.length
                                          : _selectedImages.length) <
                                      5
                                  ? AppColors.primary.withOpacity(0.5)
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: (kIsWeb
                                        ? _webImageBytes.length
                                        : _selectedImages.length) <
                                    5
                                ? AppColors.primary.withOpacity(0.05)
                                : Colors.grey[100],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (kIsWeb
                                              ? _webImageBytes.length
                                              : _selectedImages.length) <
                                          5
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  (kIsWeb
                                              ? _webImageBytes.length
                                              : _selectedImages.length) <
                                          5
                                      ? Icons.add_a_photo
                                      : Icons.check_circle,
                                  size: 24,
                                  color: (kIsWeb
                                              ? _webImageBytes.length
                                              : _selectedImages.length) <
                                          5
                                      ? AppColors.primary
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (kIsWeb
                                            ? _webImageBytes.length
                                            : _selectedImages.length) <
                                        5
                                    ? 'แตะเพื่อเลือกรูปภาพ'
                                    : 'เลือกรูปครบแล้ว (5/5)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: (kIsWeb
                                              ? _webImageBytes.length
                                              : _selectedImages.length) <
                                          5
                                      ? Colors.grey[700]
                                      : Colors.grey[500],
                                ),
                              ),
                              Text(
                                'รูปที่เลือกแล้ว: ${kIsWeb ? _webImageBytes.length : _selectedImages.length}/5',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              if (kIsWeb)
                                Text(
                                  '(รองรับการเลือกหลายรูปพร้อมกัน)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if ((kIsWeb
                          ? _webImageBytes.isNotEmpty
                          : _selectedImages.isNotEmpty)) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'รูปภาพที่เลือก',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _clearAllImages,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('ลบทั้งหมด'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: kIsWeb
                                ? _webImageBytes.length
                                : _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.memory(
                                              _webImageBytes[index],
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  width: 100,
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: const Icon(Icons.error,
                                                      color: Colors.red),
                                                );
                                              },
                                            )
                                          : Image.file(
                                              _selectedImages[index],
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  width: 100,
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: const Icon(Icons.error,
                                                      color: Colors.red),
                                                );
                                              },
                                            ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
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
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kIsWeb ? Colors.blue[50] : Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: kIsWeb
                                    ? Colors.blue[200]!
                                    : Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                kIsWeb ? Icons.web : Icons.smartphone,
                                color: kIsWeb
                                    ? Colors.blue[600]
                                    : Colors.green[600],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  kIsWeb
                                      ? 'เลือกรูปหลายรูปพร้อมกันได้บน Web Browser'
                                      : 'แตะที่รูปภาพด้านบนเพื่อเพิ่มรูปใหม่ (ถ้ายังไม่ครบ 5 รูป)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: kIsWeb
                                        ? Colors.blue[700]
                                        : Colors.green[700],
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
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isSubmitting
                          ? [Colors.grey[400]!, Colors.grey[500]!]
                          : [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8)
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isSubmitting ? Colors.grey : AppColors.primary)
                            .withOpacity(0.3),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitIssue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'กำลังส่งรายงาน...',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'ส่งรายงานปัญหา',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'ข้อมูลการรายงาน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
              Icons.person, 'ผู้รายงาน', _tenantData!['tenant_full_name']),
          _buildInfoRow(Icons.home, 'ห้อง',
              '${_tenantData!['room_number']} - ${_tenantData!['rooms']['room_name']}'),
          _buildInfoRow(
              Icons.business, 'สาขา', _tenantData!['branches']['branch_name']),
          _buildInfoRow(Icons.access_time, 'เวลา',
              DateTime.now().toString().substring(0, 16)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPriorityOption(
      String value, String title, String subtitle, Color color, IconData icon) {
    final isSelected = _selectedPriority == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPriority = value;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.grey[400],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isSelected ? color : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? color.withOpacity(0.8)
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
