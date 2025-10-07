import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../services/meter_service.dart';
import '../../services/branch_service.dart';
import '../../services/image_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_models.dart';
import '../../widgets/colors.dart';

class MeterReadingFormPage extends StatefulWidget {
  final String? readingId; // null = create, not null = edit

  const MeterReadingFormPage({Key? key, this.readingId}) : super(key: key);

  @override
  State<MeterReadingFormPage> createState() => _MeterReadingFormPageState();
}

class _MeterReadingFormPageState extends State<MeterReadingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _waterCurrentController = TextEditingController();
  final _electricCurrentController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingActiveRooms = false;
  bool _isCheckingAuth = true;

  // ข้อมูลฟอร์ม
  String? _selectedBranchId;
  String? _selectedRoomId;
  String? _selectedTenantId;
  String? _selectedContractId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  DateTime _selectedDate = DateTime.now();

  // ข้อมูลอ้างอิง
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _activeRooms = [];
  Map<String, dynamic>? _lastReading;
  Map<String, dynamic>? _existingReading; // สำหรับ edit mode
  UserModel? _currentUser;

  // รูปภาพ - รองรับทั้ง Web และ Mobile
  File? _waterMeterImage;
  File? _electricMeterImage;
  Uint8List? _waterMeterImageBytes;
  Uint8List? _electricMeterImageBytes;
  String? _waterMeterImageName;
  String? _electricMeterImageName;
  String? _waterMeterImageUrl;
  String? _electricMeterImageUrl;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _waterCurrentController.dispose();
    _electricCurrentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // โหลดข้อมูลเริ่มต้น
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      await _loadCurrentUser();
      if (_currentUser != null) {
        await _loadBranches();

        // ถ้าเป็น edit mode
        if (widget.readingId != null) {
          await _loadExistingReading();
        }
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      print('Error loading current user: $e');
      if (mounted) {
        setState(() {
          _currentUser = null;
        });
      }
    }
  }

  // โหลดสาขา
  Future<void> _loadBranches() async {
    try {
      final branches = await BranchService.getBranchesByUser();
      setState(() => _branches = branches);

      // ถ้ามีสาขาเดียว ให้เลือกอัตโนมัติ
      if (branches.length == 1) {
        _selectedBranchId = branches.first['branch_id'];
        await _loadActiveRooms();
      }
    } catch (e) {
      debugPrint('Error loading branches: $e');
    }
  }

  // โหลดข้อมูลที่มีอยู่ (edit mode)
  Future<void> _loadExistingReading() async {
    try {
      final reading =
          await MeterReadingService.getMeterReadingById(widget.readingId!);
      if (reading != null) {
        setState(() {
          _existingReading = reading;
          _selectedBranchId = reading['rooms']['branch_id'];
          _selectedRoomId = reading['room_id'];
          _selectedTenantId = reading['tenant_id'];
          _selectedContractId = reading['contract_id'];
          _selectedMonth = reading['reading_month'];
          _selectedYear = reading['reading_year'];
          _selectedDate = DateTime.parse(reading['reading_date']);

          _waterCurrentController.text =
              reading['water_current_reading']?.toString() ?? '';
          _electricCurrentController.text =
              reading['electric_current_reading']?.toString() ?? '';
          _notesController.text = reading['reading_notes'] ?? '';

          _waterMeterImageUrl = reading['water_meter_image'];
          _electricMeterImageUrl = reading['electric_meter_image'];
        });

        await _loadActiveRooms();
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูลค่ามิเตอร์: $e');
    }
  }

  // โหลดห้องที่มีสัญญา active
  Future<void> _loadActiveRooms() async {
    if (_selectedBranchId == null) return;

    setState(() => _isLoadingActiveRooms = true);

    try {
      final rooms = await MeterReadingService.getActiveRoomsForMeterReading(
        branchId: _selectedBranchId,
      );
      setState(() => _activeRooms = rooms);
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดห้องที่ใช้งาน: $e');
    } finally {
      setState(() => _isLoadingActiveRooms = false);
    }
  }

  Future<void> _loadLastReading() async {
    if (_selectedRoomId == null) return;

    try {
      final lastReading =
          await MeterReadingService.getLastMeterReading(_selectedRoomId!);
      setState(() => _lastReading = lastReading);
    } catch (e) {
      debugPrint('Error loading last reading: $e');
    }
  }

  // เลือกรูปภาพ - รองรับทั้ง Web และ Mobile
  Future<void> _pickImage(String meterType) async {
    try {
      if (kIsWeb) {
        await _pickImageForWeb(meterType);
      } else {
        await _pickImageForMobile(meterType);
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
  }

  Future<void> _pickImageForWeb(String meterType) async {
    final XFile? image = await _imagePicker.pickImage(
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
          if (meterType == 'water') {
            _waterMeterImageBytes = bytes;
            _waterMeterImageName = name;
            _waterMeterImage = null;
            _waterMeterImageUrl = null; // ล้าง URL เดิม
          } else {
            _electricMeterImageBytes = bytes;
            _electricMeterImageName = name;
            _electricMeterImage = null;
            _electricMeterImageUrl = null; // ล้าง URL เดิม
          }
        });
      }
    }
  }

  Future<void> _pickImageForMobile(String meterType) async {
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
                  'เลือกรูปภาพ${meterType == 'water' ? 'มิเตอร์น้ำ' : 'มิเตอร์ไฟ'}',
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

    final XFile? image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final file = File(image.path);
      if (await _validateImageFile(file)) {
        setState(() {
          if (meterType == 'water') {
            _waterMeterImage = file;
            _waterMeterImageBytes = null;
            _waterMeterImageName = null;
            _waterMeterImageUrl = null; // ล้าง URL เดิม
          } else {
            _electricMeterImage = file;
            _electricMeterImageBytes = null;
            _electricMeterImageName = null;
            _electricMeterImageUrl = null; // ล้าง URL เดิม
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

  // ลบรูปภาพ
  void _removeImage(String meterType) {
    setState(() {
      if (meterType == 'water') {
        _waterMeterImage = null;
        _waterMeterImageBytes = null;
        _waterMeterImageName = null;
        _waterMeterImageUrl = null;
      } else {
        _electricMeterImage = null;
        _electricMeterImageBytes = null;
        _electricMeterImageName = null;
        _electricMeterImageUrl = null;
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

  // บันทึกข้อมูล
  // บันทึกข้อมูล - ส่วนที่แก้ไขเฉพาะ _saveReading() method
  Future<void> _saveReading() async {
    if (_currentUser == null) {
      _showErrorSnackBar('กรุณาเข้าสู่ระบบก่อนเพิ่มข้อมูล');
      Navigator.of(context).pop();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? waterImageUrl = _waterMeterImageUrl;
      String? electricImageUrl = _electricMeterImageUrl;

      // อัปโหลดรูปน้ำ
      if (_waterMeterImage != null || _waterMeterImageBytes != null) {
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

          // สร้าง contextInfo สำหรับชื่อไฟล์ (เปลี่ยนชื่อเพื่อไม่ conflict)
          final roomNumber = _activeRooms.firstWhere(
              (room) => room['room_id'] == _selectedRoomId)['room_number'];
          final contextInfo =
              'room_${roomNumber}_${_selectedMonth.toString().padLeft(2, '0')}_${_selectedYear}';

          if (kIsWeb && _waterMeterImageBytes != null) {
            uploadResult = await ImageService.uploadImageFromBytes(
              _waterMeterImageBytes!,
              _waterMeterImageName ?? 'water_meter.jpg',
              'meter-images',
              folder:
                  '$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}',
              prefix: 'water_meter',
              context: contextInfo,
            );
          } else if (!kIsWeb && _waterMeterImage != null) {
            uploadResult = await ImageService.uploadImage(
              _waterMeterImage!,
              'meter-images',
              folder:
                  '$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}',
              prefix: 'water_meter',
              context: contextInfo,
            );
          }

          if (mounted) Navigator.of(context).pop();

          if (uploadResult != null && uploadResult['success']) {
            waterImageUrl = uploadResult['url'];

            // แสดงข้อความถ้ามีการเปลี่ยนชื่อไฟล์
            if (uploadResult['renamed'] == true) {
              debugPrint(
                  'Water meter image renamed to: ${uploadResult['fileName']}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'รูปมิเตอร์น้ำถูกเปลี่ยนชื่อเป็น: ${uploadResult['fileName']}'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            throw Exception(
                uploadResult?['message'] ?? 'ไม่สามารถอัปโหลดรูปมิเตอร์น้ำได้');
          }
        } catch (e) {
          if (mounted) Navigator.of(context).pop();
          throw e;
        }
      }

      // อัปโหลดรูปไฟ
      if (_electricMeterImage != null || _electricMeterImageBytes != null) {
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

          // สร้าง contextInfo สำหรับชื่อไฟล์ (เปลี่ยนชื่อเพื่อไม่ conflict)
          final roomNumber = _activeRooms.firstWhere(
              (room) => room['room_id'] == _selectedRoomId)['room_number'];
          final contextInfo =
              'room_${roomNumber}_${_selectedMonth.toString().padLeft(2, '0')}_${_selectedYear}';

          if (kIsWeb && _electricMeterImageBytes != null) {
            uploadResult = await ImageService.uploadImageFromBytes(
              _electricMeterImageBytes!,
              _electricMeterImageName ?? 'electric_meter.jpg',
              'meter-images',
              folder:
                  '$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}',
              prefix: 'electric_meter',
              context: contextInfo,
            );
          } else if (!kIsWeb && _electricMeterImage != null) {
            uploadResult = await ImageService.uploadImage(
              _electricMeterImage!,
              'meter-images',
              folder:
                  '$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}',
              prefix: 'electric_meter',
              context: contextInfo,
            );
          }

          if (mounted) Navigator.of(context).pop();

          if (uploadResult != null && uploadResult['success']) {
            electricImageUrl = uploadResult['url'];

            // แสดงข้อความถ้ามีการเปลี่ยนชื่อไฟล์
            if (uploadResult['renamed'] == true) {
              debugPrint(
                  'Electric meter image renamed to: ${uploadResult['fileName']}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'รูปมิเตอร์ไฟถูกเปลี่ยนชื่อเป็น: ${uploadResult['fileName']}'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            throw Exception(
                uploadResult?['message'] ?? 'ไม่สามารถอัปโหลดรูปมิเตอร์ไฟได้');
          }
        } catch (e) {
          if (mounted) Navigator.of(context).pop();
          throw e;
        }
      }

      // เตรียมข้อมูลสำหรับบันทึก
      final readingData = {
        'room_id': _selectedRoomId,
        'tenant_id': _selectedTenantId,
        'contract_id': _selectedContractId,
        'reading_month': _selectedMonth,
        'reading_year': _selectedYear,
        'reading_date': _selectedDate.toIso8601String().split('T')[0],
        'water_current_reading':
            double.tryParse(_waterCurrentController.text) ?? 0.0,
        'electric_current_reading':
            double.tryParse(_electricCurrentController.text) ?? 0.0,
        'water_meter_image': waterImageUrl,
        'electric_meter_image': electricImageUrl,
        'reading_notes': _notesController.text.trim(),
      };

      Map<String, dynamic> result;

      if (widget.readingId != null) {
        // อัปเดต
        result = await MeterReadingService.updateMeterReading(
            widget.readingId!, readingData);
      } else {
        // สร้างใหม่
        result = await MeterReadingService.createMeterReading(readingData);
      }

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result['message'])),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );

          Navigator.of(context).pop(true);
        }
      } else {
        _showErrorSnackBar(result['message']);
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // แสดง SnackBar ข้อผิดพลาด
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.readingId != null
              ? 'แก้ไขค่ามิเตอร์'
              : 'บันทึกค่ามิเตอร์'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text('กำลังตรวจสอบสิทธิ์...'),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.readingId != null
              ? 'แก้ไขค่ามิเตอร์'
              : 'บันทึกค่ามิเตอร์'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'กรุณาเข้าสู่ระบบ',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถบันทึกค่ามิเตอร์ได้',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('กลับ'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.readingId != null ? 'แก้ไขค่ามิเตอร์' : 'บันทึกค่ามิเตอร์'),
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
                  const Text('กำลังโหลดข้อมูล...'),
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
                    // ข้อมูลพื้นฐาน
                    _buildBasicInfoSection(),

                    const SizedBox(height: 24),

                    // ค่าก่อนหน้า (ถ้ามี)
                    if (_lastReading != null) _buildPreviousReadingSection(),

                    const SizedBox(height: 24),

                    // บันทึกค่ามิเตอร์
                    _buildMeterReadingSection(),

                    const SizedBox(height: 24),

                    // รูปภาพมิเตอร์
                    _buildImageSection(),

                    const SizedBox(height: 24),

                    // หมายเหตุ
                    _buildNotesSection(),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
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
      ),
    );
  }

  // Widget builders (ใช้ code เดิม)
  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ข้อมูลพื้นฐาน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBranchDropdown(),
            const SizedBox(height: 16),
            _buildRoomDropdown(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMonthDropdown()),
                const SizedBox(width: 16),
                Expanded(child: _buildYearDropdown()),
              ],
            ),
            const SizedBox(height: 16),
            _buildDatePicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBranchId,
      decoration: InputDecoration(
        labelText: 'สาขา *',
        prefixIcon: const Icon(Icons.business),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: _branches
          .map((branch) => DropdownMenuItem<String>(
                value: branch['branch_id'],
                child: Text(branch['branch_name']),
              ))
          .toList(),
      validator: (value) => value == null ? 'กรุณาเลือกสาขา' : null,
      onChanged: (value) {
        setState(() {
          _selectedBranchId = value;
          _selectedRoomId = null;
          _selectedTenantId = null;
          _selectedContractId = null;
          _activeRooms.clear();
          _lastReading = null;
        });
        if (value != null) _loadActiveRooms();
      },
    );
  }

  Widget _buildRoomDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRoomId,
      decoration: InputDecoration(
        labelText: 'ห้อง *',
        prefixIcon: const Icon(Icons.room),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        suffixIcon: _isLoadingActiveRooms
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      isExpanded: true,
      isDense: false,
      menuMaxHeight: 300,
      items: _activeRooms
          .map((room) => DropdownMenuItem<String>(
                value: room['room_id'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ห้อง ${room['room_number']}'),
                    Text(
                      '${room['tenant_name']} (${room['tenant_phone']})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ))
          .toList(),
      validator: (value) => value == null ? 'กรุณาเลือกห้อง' : null,
      onChanged: (value) {
        if (value != null) {
          final selectedRoom =
              _activeRooms.firstWhere((room) => room['room_id'] == value);
          setState(() {
            _selectedRoomId = value;
            _selectedTenantId = selectedRoom['tenant_id'];
            _selectedContractId = selectedRoom['contract_id'];
          });
          _loadLastReading();
        }
      },
    );
  }

  Widget _buildMonthDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedMonth,
      decoration: InputDecoration(
        labelText: 'เดือน *',
        prefixIcon: const Icon(Icons.calendar_month),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: List.generate(
          12,
          (index) => DropdownMenuItem(
                value: index + 1,
                child: Text(_getMonthName(index + 1)),
              )),
      onChanged: (value) {
        setState(() => _selectedMonth = value!);
      },
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedYear,
      decoration: InputDecoration(
        labelText: 'ปี *',
        prefixIcon: const Icon(Icons.calendar_today),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: List.generate(5, (index) {
        final year = DateTime.now().year - 2 + index;
        return DropdownMenuItem(
          value: year,
          child: Text('$year'),
        );
      }),
      onChanged: (value) {
        setState(() => _selectedYear = value!);
      },
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.date_range, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'วันที่บันทึก',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousReadingSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ค่าก่อนหน้า',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'มิเตอร์น้ำ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_lastReading!['water_current_reading']?.toStringAsFixed(2) ?? '0.00'} หน่วย',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'มิเตอร์ไฟ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_lastReading!['electric_current_reading']?.toStringAsFixed(2) ?? '0.00'} หน่วย',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
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

  Widget _buildMeterReadingSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.electrical_services, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'มิเตอร์ปัจจุบัน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                _buildMeterReadingInput(
                    'น้ำ', _waterCurrentController, Colors.blue),
                const SizedBox(height: 16),
                _buildMeterReadingInput(
                    'ไฟ', _electricCurrentController, Colors.orange),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMeterReadingInput(
      String type, TextEditingController controller, Color color) {
    final isWater = type == 'น้ำ';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'มิเตอร์$type',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'ค่าปัจจุบัน *',
            suffixText: 'หน่วย',
            prefixIcon: Icon(
              isWater ? Icons.water_drop : Icons.flash_on,
              color: color,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
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
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกค่า$type';
            }
            final currentValue = double.tryParse(value);
            if (currentValue == null) {
              return 'กรุณากรอกตัวเลขที่ถูกต้อง';
            }
            if (currentValue < 0) {
              return 'ค่ามิเตอร์ต้องเป็นตัวเลขบวก';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'รูปภาพมิเตอร์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                if (kIsWeb)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'WEB',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                _buildImagePicker('water', 'มิเตอร์น้ำ', Colors.blue),
                const SizedBox(height: 16),
                _buildImagePicker('electric', 'มิเตอร์ไฟ', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(String meterType, String label, Color color) {
    final isWater = meterType == 'water';
    final imageFile = isWater ? _waterMeterImage : _electricMeterImage;
    final imageBytes =
        isWater ? _waterMeterImageBytes : _electricMeterImageBytes;
    final imageName = isWater ? _waterMeterImageName : _electricMeterImageName;
    final imageUrl = isWater ? _waterMeterImageUrl : _electricMeterImageUrl;

    final hasImage =
        imageFile != null || imageBytes != null || imageUrl != null;

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
                        child: _buildImagePreview(meterType),
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
                          onPressed: () => _removeImage(meterType),
                          tooltip: 'ลบรูปภาพ',
                        ),
                      ),
                    ),
                    if (imageName != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            imageName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                )
              : InkWell(
                  onTap: () => _pickImage(meterType),
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
                  onPressed: () => _pickImage(meterType),
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

  Widget _buildImagePreview(String meterType) {
    final isWater = meterType == 'water';
    final imageFile = isWater ? _waterMeterImage : _electricMeterImage;
    final imageBytes =
        isWater ? _waterMeterImageBytes : _electricMeterImageBytes;
    final imageUrl = isWater ? _waterMeterImageUrl : _electricMeterImageUrl;

    if (kIsWeb && imageBytes != null) {
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (!kIsWeb && imageFile != null) {
      return Image.file(
        imageFile,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
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
        },
      );
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'หมายเหตุ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'หมายเหตุ (ถ้ามี)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
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
                alignLabelWithHint: true,
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
    final canSave =
        !_isSaving && _selectedRoomId != null && !_isLoadingActiveRooms;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: canSave ? _saveReading : null,
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
          _isSaving
              ? 'กำลังบันทึก...'
              : (widget.readingId != null
                  ? 'อัปเดตค่ามิเตอร์'
                  : 'บันทึกค่ามิเตอร์'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canSave ? AppTheme.primary : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: canSave ? 2 : 0,
        ),
      ),
    );
  }

  // Utility functions
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
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
