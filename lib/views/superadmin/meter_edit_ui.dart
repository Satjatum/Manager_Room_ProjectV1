import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:manager_room_project/widgets/navbar.dart';
import '../../services/meter_service.dart';
import '../../services/auth_service.dart';
import '../../services/image_service.dart';
import '../../models/user_models.dart';
import '../../widgets/colors.dart';
import 'dart:io';
import 'dart:typed_data';

class MeterReadingEditPage extends StatefulWidget {
  final String readingId;

  const MeterReadingEditPage({
    Key? key,
    required this.readingId,
  }) : super(key: key);

  @override
  State<MeterReadingEditPage> createState() => _MeterReadingEditPageState();
}

class _MeterReadingEditPageState extends State<MeterReadingEditPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final _waterCurrentController = TextEditingController();
  final _electricCurrentController = TextEditingController();
  final _notesController = TextEditingController();

  // Data
  Map<String, dynamic>? _reading;
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();

  // Images - Support both mobile and web
  File? _newWaterImage;
  File? _newElectricImage;
  Uint8List? _newWaterImageBytes;
  Uint8List? _newElectricImageBytes;
  String? _newWaterImageName;
  String? _newElectricImageName;
  String? _existingWaterImageUrl;
  String? _existingElectricImageUrl;
  bool _removeWaterImage = false;
  bool _removeElectricImage = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _waterCurrentController.dispose();
    _electricCurrentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _currentUser = await AuthService.getCurrentUser();
      _reading =
          await MeterReadingService.getMeterReadingById(widget.readingId);

      if (_reading != null) {
        // Fill form data
        final waterReading = _reading!['water_current_reading'];
        final electricReading = _reading!['electric_current_reading'];

        _waterCurrentController.text =
            waterReading != null ? waterReading.toString() : '';
        _electricCurrentController.text =
            electricReading != null ? electricReading.toString() : '';
        _notesController.text = _reading!['reading_notes']?.toString() ?? '';

        // Parse date safely
        if (_reading!['reading_date'] != null) {
          try {
            _selectedDate =
                DateTime.parse(_reading!['reading_date'].toString());
          } catch (e) {
            print('Error parsing date: $e');
            _selectedDate = DateTime.now();
          }
        }

        // Get image URLs
        _existingWaterImageUrl = _reading!['water_meter_image']?.toString();
        _existingElectricImageUrl =
            _reading!['electric_meter_image']?.toString();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('th'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickImage(String type) async {
    try {
      if (kIsWeb) {
        await _pickImageForWeb(type);
      } else {
        await _pickImageForMobile(type);
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
  }

  Future<void> _pickImageForWeb(String type) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      final name = image.name;

      if (await _validateImageBytesForWeb(bytes, name)) {
        setState(() {
          if (type == 'water') {
            _newWaterImageBytes = bytes;
            _newWaterImageName = name;
            _newWaterImage = null;
            _removeWaterImage = false;
          } else {
            _newElectricImageBytes = bytes;
            _newElectricImageName = name;
            _newElectricImage = null;
            _removeElectricImage = false;
          }
        });
      }
    }
  }

  Future<void> _pickImageForMobile(String type) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'เลือกรูปภาพ${type == 'water' ? 'มิเตอร์น้ำ' : 'มิเตอร์ไฟ'}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(context, ImageSource.camera),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 40, color: AppTheme.primary),
                              const SizedBox(height: 8),
                              const Text('ถ่ายรูป',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            Navigator.pop(context, ImageSource.gallery),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.photo_library,
                                  size: 40, color: AppTheme.primary),
                              const SizedBox(height: 8),
                              const Text('แกลเลอรี่',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('ยกเลิก',
                        style: TextStyle(color: Colors.grey[600])),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final file = File(image.path);
      if (await _validateImageFile(file)) {
        setState(() {
          if (type == 'water') {
            _newWaterImage = file;
            _newWaterImageBytes = null;
            _newWaterImageName = null;
            _removeWaterImage = false;
          } else {
            _newElectricImage = file;
            _newElectricImageBytes = null;
            _newElectricImageName = null;
            _removeElectricImage = false;
          }
        });
      }
    }
  }

  Future<bool> _validateImageBytesForWeb(
      Uint8List bytes, String fileName) async {
    try {
      if (bytes.length > 5 * 1024 * 1024) {
        _showErrorSnackBar('ขนาดไฟล์เกิน 5MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า');
        return false;
      }

      if (bytes.isEmpty) {
        _showErrorSnackBar('ไฟล์เสียหายหรือมีขนาด 0 bytes');
        return false;
      }

      final extension = fileName.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        _showErrorSnackBar('รองรับเฉพาะไฟล์ JPG, JPEG, PNG, WebP เท่านั้น');
        return false;
      }

      return true;
    } catch (e) {
      _showErrorSnackBar('ไม่สามารถตรวจสอบไฟล์ได้: $e');
      return false;
    }
  }

  Future<bool> _validateImageFile(File file) async {
    try {
      if (!await file.exists()) {
        _showErrorSnackBar('ไฟล์ไม่พบหรือถูกลบ');
        return false;
      }

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        _showErrorSnackBar('ขนาดไฟล์เกิน 5MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า');
        return false;
      }

      if (fileSize == 0) {
        _showErrorSnackBar('ไฟล์เสียหายหรือมีขนาด 0 bytes');
        return false;
      }

      final extension = file.path.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        _showErrorSnackBar('รองรับเฉพาะไฟล์ JPG, JPEG, PNG, WebP เท่านั้น');
        return false;
      }

      return true;
    } catch (e) {
      _showErrorSnackBar('ไม่สามารถตรวจสอบไฟล์ได้: $e');
      return false;
    }
  }

  void _removeImage(String type) {
    setState(() {
      if (type == 'water') {
        _newWaterImage = null;
        _newWaterImageBytes = null;
        _newWaterImageName = null;
        _removeWaterImage = true;
      } else {
        _newElectricImage = null;
        _newElectricImageBytes = null;
        _newElectricImageName = null;
        _removeElectricImage = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ลบรูปภาพแล้ว'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('กรุณากรอกข้อมูลให้ครบถ้วน');
      return;
    }

    final currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) {
      _showErrorSnackBar('กรุณาเข้าสู่ระบบใหม่');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? waterImageUrl = _existingWaterImageUrl;
      String? electricImageUrl = _existingElectricImageUrl;

      // อัปโหลดรูปน้ำ (ถ้ามี)
      if (_newWaterImage != null || _newWaterImageBytes != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 16),
                const Text('กำลังอัปโหลดรูปภาพมิเตอร์น้ำ...'),
              ],
            ),
          ),
        );

        try {
          dynamic uploadResult;
          final roomNumber = _reading!['room_number']?.toString() ?? 'unknown';
          final readingMonth =
              _reading!['reading_month'] ?? DateTime.now().month;
          final readingYear = _reading!['reading_year'] ?? DateTime.now().year;

          final monthStr = readingMonth.toString().padLeft(2, '0');
          final yearStr = readingYear.toString();
          final contextInfo = 'room_${roomNumber}_${monthStr}_${yearStr}';

          if (kIsWeb && _newWaterImageBytes != null) {
            uploadResult = await ImageService.uploadImageFromBytes(
              _newWaterImageBytes!,
              _newWaterImageName ?? 'water_meter.jpg',
              'meter-images',
              folder: '$yearStr/$monthStr',
              prefix: 'water_meter',
              context: contextInfo,
            );
          } else if (!kIsWeb && _newWaterImage != null) {
            uploadResult = await ImageService.uploadImage(
              _newWaterImage!,
              'meter-images',
              folder: '$yearStr/$monthStr',
              prefix: 'water_meter',
              context: contextInfo,
            );
          }

          if (mounted) Navigator.of(context).pop();

          if (uploadResult != null && uploadResult['success']) {
            waterImageUrl = uploadResult['url'];
          } else {
            throw Exception(
                uploadResult?['message'] ?? 'ไม่สามารถอัปโหลดรูปมิเตอร์น้ำได้');
          }
        } catch (e) {
          if (mounted) Navigator.of(context).pop();
          throw e;
        }
      } else if (_removeWaterImage) {
        waterImageUrl = null;
      }

      // อัปโหลดรูปไฟ (ถ้ามี)
      if (_newElectricImage != null || _newElectricImageBytes != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 16),
                const Text('กำลังอัปโหลดรูปภาพมิเตอร์ไฟ...'),
              ],
            ),
          ),
        );

        try {
          dynamic uploadResult;
          final roomNumber = _reading!['room_number']?.toString() ?? 'unknown';
          final readingMonth =
              _reading!['reading_month'] ?? DateTime.now().month;
          final readingYear = _reading!['reading_year'] ?? DateTime.now().year;

          final monthStr = readingMonth.toString().padLeft(2, '0');
          final yearStr = readingYear.toString();
          final contextInfo = 'room_${roomNumber}_${monthStr}_${yearStr}';

          if (kIsWeb && _newElectricImageBytes != null) {
            uploadResult = await ImageService.uploadImageFromBytes(
              _newElectricImageBytes!,
              _newElectricImageName ?? 'electric_meter.jpg',
              'meter-images',
              folder: '$yearStr/$monthStr',
              prefix: 'electric_meter',
              context: contextInfo,
            );
          } else if (!kIsWeb && _newElectricImage != null) {
            uploadResult = await ImageService.uploadImage(
              _newElectricImage!,
              'meter-images',
              folder: '$yearStr/$monthStr',
              prefix: 'electric_meter',
              context: contextInfo,
            );
          }

          if (mounted) Navigator.of(context).pop();

          if (uploadResult != null && uploadResult['success']) {
            electricImageUrl = uploadResult['url'];
          } else {
            throw Exception(
                uploadResult?['message'] ?? 'ไม่สามารถอัปโหลดรูปมิเตอร์ไฟได้');
          }
        } catch (e) {
          if (mounted) Navigator.of(context).pop();
          throw e;
        }
      } else if (_removeElectricImage) {
        electricImageUrl = null;
      }

      // Prepare update data
      Map<String, dynamic> updateData = {
        'water_current_reading': _waterCurrentController.text.trim().isEmpty
            ? null
            : double.tryParse(_waterCurrentController.text.trim()),
        'electric_current_reading':
            _electricCurrentController.text.trim().isEmpty
                ? null
                : double.tryParse(_electricCurrentController.text.trim()),
        'reading_date': _selectedDate.toIso8601String().split('T')[0],
        'reading_notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'water_meter_image': waterImageUrl,
        'electric_meter_image': electricImageUrl,
      };

      // Update meter reading
      final result = await MeterReadingService.updateMeterReading(
        widget.readingId,
        updateData,
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          Text(result['message'] ?? 'อัปเดตค่ามิเตอร์สำเร็จ')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          _showErrorSnackBar(result['message']?.toString() ?? 'เกิดข้อผิดพลาด');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขค่ามิเตอร์'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'กำลังโหลดข้อมูล...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : _reading == null
              ? _buildErrorState()
              : _buildEditForm(),
      bottomNavigationBar:
          _reading != null && _reading!['reading_status'] == 'draft'
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: _buildSaveButton(),
                )
              : const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ไม่พบข้อมูลค่ามิเตอร์',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('กลับ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final readingStatus = _reading!['reading_status']?.toString() ?? '';

    if (readingStatus != 'draft') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  size: 64,
                  color: Colors.orange[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'ไม่สามารถแก้ไขได้',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'สามารถแก้ไขได้เฉพาะค่ามิเตอร์ที่มีสถานะ "ร่าง" เท่านั้น',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(readingStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(readingStatus)),
                ),
                child: Text(
                  'สถานะปัจจุบัน: ${_getStatusText(readingStatus)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _getStatusColor(readingStatus),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('กลับ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderInfo(),
            const SizedBox(height: 20),
            _buildDateSection(),
            const SizedBox(height: 20),
            _buildMeterReadingSection(),
            const SizedBox(height: 20),
            _buildImageSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'ข้อมูลการบันทึก',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 16),
            _buildInfoRow(
                'เลขที่บันทึก', _reading!['reading_number']?.toString() ?? '-'),
            _buildInfoRow('สาขา', _reading!['branch_name']?.toString() ?? '-'),
            _buildInfoRow('ห้อง', _reading!['room_number']?.toString() ?? '-'),
            _buildInfoRow(
                'ผู้เช่า', _reading!['tenant_name']?.toString() ?? '-'),
            _buildInfoRow(
              'เดือน/ปี',
              '${_getMonthName(_reading!['reading_month'] ?? 1)} ${_reading!['reading_year'] ?? DateTime.now().year}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'วันที่บันทึก',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeterReadingSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.electrical_services, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'บันทึกค่ามิเตอร์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildMeterInput(
              'มิเตอร์น้ำ',
              Icons.water_drop,
              Colors.blue,
              _reading!['water_previous_reading'],
              _waterCurrentController,
            ),
            const SizedBox(height: 24),
            _buildMeterInput(
              'มิเตอร์ไฟ',
              Icons.electric_bolt,
              Colors.orange,
              _reading!['electric_previous_reading'],
              _electricCurrentController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeterInput(
    String title,
    IconData icon,
    Color color,
    dynamic previousReading,
    TextEditingController controller,
  ) {
    final previous = _parseDouble(previousReading);
    final current = double.tryParse(controller.text.trim()) ?? 0.0;
    final usage = current - previous;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ค่าก่อนหน้า (แสดงอย่างเดียว)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'ค่าก่อนหน้า: ${_formatNumber(previousReading)}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ค่าปัจจุบัน
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'ค่าปัจจุบัน *',
            prefixIcon: Icon(icon, color: color),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: (value) => setState(() {}),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'กรุณากรอกค่าปัจจุบัน';
            }
            final currentValue = double.tryParse(value.trim());
            if (currentValue == null) {
              return 'กรุณากรอกตัวเลขที่ถูกต้อง';
            }
            if (currentValue < previous) {
              return 'ค่าปัจจุบันต้องมากกว่าหรือเท่ากับค่าก่อนหน้า';
            }
            return null;
          },
        ),

        const SizedBox(height: 12),

        // แสดงการใช้งาน
        if (controller.text.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  'การใช้งาน: ${usage >= 0 ? usage.toStringAsFixed(2) : '0.00'} หน่วย',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'รูปภาพมิเตอร์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildImagePicker('water', 'มิเตอร์น้ำ', Colors.blue),
            const SizedBox(height: 16),
            _buildImagePicker('electric', 'มิเตอร์ไฟ', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(String type, String label, Color color) {
    final hasNewImage = (type == 'water' &&
            (_newWaterImage != null || _newWaterImageBytes != null)) ||
        (type == 'electric' &&
            (_newElectricImage != null || _newElectricImageBytes != null));
    final hasExistingImage = (type == 'water' &&
            _existingWaterImageUrl != null &&
            !_removeWaterImage) ||
        (type == 'electric' &&
            _existingElectricImageUrl != null &&
            !_removeElectricImage);
    final hasImage = hasNewImage || hasExistingImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasImage ? color : Colors.grey.shade300,
              width: hasImage ? 2 : 1,
            ),
            color: hasImage ? color.withOpacity(0.05) : Colors.grey.shade50,
          ),
          child: hasImage
              ? Stack(
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildImagePreview(type),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeImage(type),
                          tooltip: 'ลบรูปภาพ',
                        ),
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: () => _pickImage(type),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        kIsWeb ? Icons.upload_file : Icons.camera_alt,
                        size: 48,
                        color: color,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        kIsWeb ? 'เลือกไฟล์รูปภาพ' : 'ถ่ายรูป$label',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kIsWeb
                            ? 'แตะเพื่อเลือกไฟล์จากคอมพิวเตอร์'
                            : 'แตะเพื่อเลือกจากแกลเลอรี่หรือถ่ายรูปใหม่',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'รองรับ JPG, PNG, WebP (สูงสุด 5MB)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (hasImage) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(type),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('เปลี่ยนรูปภาพ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview(String type) {
    if (type == 'water') {
      if (kIsWeb && _newWaterImageBytes != null) {
        return Image.memory(
          _newWaterImageBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (!kIsWeb && _newWaterImage != null) {
        return Image.file(
          _newWaterImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (_existingWaterImageUrl != null && !_removeWaterImage) {
        return Image.network(
          _existingWaterImageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'ไม่สามารถโหลดรูปภาพได้',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } else {
      if (kIsWeb && _newElectricImageBytes != null) {
        return Image.memory(
          _newElectricImageBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (!kIsWeb && _newElectricImage != null) {
        return Image.file(
          _newElectricImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (_existingElectricImageUrl != null && !_removeElectricImage) {
        return Image.network(
          _existingElectricImageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'ไม่สามารถโหลดรูปภาพได้',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    }

    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          size: 48,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_alt, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'หมายเหตุ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'หมายเหตุเพิ่มเติม (ถ้ามี)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xff10B981), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveChanges,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save, color: Colors.white),
        label: Text(
          _isSaving ? 'กำลังบันทึก...' : 'บันทึกการแก้ไข',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSaving ? Colors.grey : AppTheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: _isSaving ? 0 : 2,
        ),
      ),
    );
  }

  // Helper methods
  String _getMonthName(int month) {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    if (month < 1 || month > 12) return '-';
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0.00';
    final numValue = _parseDouble(value);
    return numValue.toStringAsFixed(2);
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'confirmed':
        return Colors.green;
      case 'billed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'ร่าง';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'billed':
        return 'ออกบิลแล้ว';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }
}
