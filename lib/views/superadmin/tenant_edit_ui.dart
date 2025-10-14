import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../services/tenant_service.dart';
import '../../services/image_service.dart';
import '../../middleware/auth_middleware.dart';
import '../../models/user_models.dart';
import '../../widgets/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenantEditUI extends StatefulWidget {
  final String tenantId;
  final Map<String, dynamic> tenantData;

  const TenantEditUI({
    Key? key,
    required this.tenantId,
    required this.tenantData,
  }) : super(key: key);

  @override
  State<TenantEditUI> createState() => _TenantEditUIState();
}

class _TenantEditUIState extends State<TenantEditUI>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Tab controller
  late TabController _tabController;

  // Tenant form controllers
  final _tenantIdCardController = TextEditingController();
  final _tenantFullNameController = TextEditingController();
  final _tenantPhoneController = TextEditingController();

  // Contract controllers
  final _contractPriceController = TextEditingController();
  final _contractDepositController = TextEditingController();
  final _contractNotesController = TextEditingController();

  String? _selectedGender;
  bool _isActive = true;
  bool _isLoading = false;
  bool _imageChanged = false;
  bool _isLoadingContract = true;

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _currentImageUrl;

  // Contract data
  Map<String, dynamic>? _activeContract;
  DateTime? _contractStartDate;
  DateTime? _contractEndDate;
  int _paymentDay = 1;
  bool _contractPaid = false;

  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
    _loadTenantData();
    _loadActiveContract();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tenantIdCardController.dispose();
    _tenantFullNameController.dispose();
    _tenantPhoneController.dispose();
    _contractPriceController.dispose();
    _contractDepositController.dispose();
    _contractNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthMiddleware.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  void _loadTenantData() {
    _tenantIdCardController.text = widget.tenantData['tenant_idcard'] ?? '';
    _tenantFullNameController.text = widget.tenantData['tenant_fullname'] ?? '';
    _tenantPhoneController.text = widget.tenantData['tenant_phone'] ?? '';
    _selectedGender = widget.tenantData['gender'];
    _isActive = widget.tenantData['is_active'] ?? true;
    _currentImageUrl = widget.tenantData['tenant_profile'];
  }

  Future<void> _loadActiveContract() async {
    setState(() => _isLoadingContract = true);

    try {
      // Query active contract for this tenant
      final result = await _supabase
          .from('rental_contracts')
          .select('''
            *,
            rooms!inner(room_number, room_id, 
              branches!inner(branch_name))
          ''')
          .eq('tenant_id', widget.tenantId)
          .eq('contract_status', 'active')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activeContract = result;
          _isLoadingContract = false;

          if (result != null) {
            _contractPriceController.text =
                result['contract_price']?.toString() ?? '';
            _contractDepositController.text =
                result['contract_deposit']?.toString() ?? '';
            _contractNotesController.text = result['contract_note'] ?? '';
            _contractPaid = result['contract_paid'] ?? false;
            _paymentDay = result['payment_day'] ?? 1;

            if (result['start_date'] != null) {
              _contractStartDate = DateTime.parse(result['start_date']);
            }
            if (result['end_date'] != null) {
              _contractEndDate = DateTime.parse(result['end_date']);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContract = false);
        _showErrorSnackBar('ไม่สามารถโหลดข้อมูลสัญญาได้: $e');
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      if (kIsWeb) {
        await _pickImagesForWeb();
      } else {
        await _pickImagesForMobile();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
      }
    }
  }

  Future<void> _pickImagesForWeb() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
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
          _selectedImageBytes = bytes;
          _selectedImageName = name;
          _imageChanged = true;
        });
      }
    }
  }

  Future<void> _pickImagesForMobile() async {
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
                const Text(
                  'เลือกรูปภาพโปรไฟล์',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageSourceOption(
                        icon: Icons.camera_alt,
                        label: 'ถ่ายรูป',
                        source: ImageSource.camera,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImageSourceOption(
                        icon: Icons.photo_library,
                        label: 'แกลเลอรี่',
                        source: ImageSource.gallery,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'ยกเลิก',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final file = File(image.path);
      if (await _validateImageFile(file)) {
        setState(() {
          _selectedImage = file;
          _imageChanged = true;
        });
      }
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Future<bool> _validateImageBytesForWeb(
      Uint8List bytes, String fileName) async {
    if (bytes.length > 5 * 1024 * 1024) {
      _showErrorSnackBar('ขนาดไฟล์เกิน 5MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า');
      return false;
    }

    final extension = fileName.split('.').last.toLowerCase();
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

    if (!allowedExtensions.contains(extension)) {
      _showErrorSnackBar('รองรับเฉพาะไฟล์ JPG, JPEG, PNG, WebP เท่านั้น');
      return false;
    }

    return true;
  }

  Future<bool> _validateImageFile(File file) async {
    try {
      if (!await file.exists()) return false;

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        _showErrorSnackBar('ขนาดไฟล์เกิน 5MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า');
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
      return false;
    }
  }

  Future<void> _removeImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบรูป'),
        content: const Text('คุณต้องการลบรูปโปรไฟล์หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบรูป'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
        _selectedImageName = null;
        _currentImageUrl = null;
        _imageChanged = true;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_contractStartDate ?? DateTime.now())
          : (_contractEndDate ?? DateTime.now().add(const Duration(days: 365))),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: Localizations.localeOf(context),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _contractStartDate = picked;
        } else {
          _contractEndDate = picked;
        }
      });
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'T';
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return words[0][0].toUpperCase();
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveData() async {
    if (_currentUser == null) {
      _showErrorSnackBar('กรุณาเข้าสู่ระบบก่อนแก้ไขข้อมูล');
      Navigator.of(context).pop();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate contract dates if in contract tab
    if (_tabController.index == 1 && _activeContract != null) {
      if (_contractStartDate == null || _contractEndDate == null) {
        _showErrorSnackBar('กรุณาระบุวันที่เริ่มต้นและสิ้นสุดสัญญา');
        return;
      }

      if (_contractEndDate!.isBefore(_contractStartDate!)) {
        _showErrorSnackBar('วันที่สิ้นสุดสัญญาต้องมาหลังวันที่เริ่มต้น');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;

      // Upload new image if changed (only in tenant tab)
      if (_imageChanged &&
          (_selectedImage != null || _selectedImageBytes != null)) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 16),
                const Text('กำลังอัปโหลดรูปภาพ...'),
              ],
            ),
          ),
        );

        // Delete old image if exists
        if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
          try {
            await ImageService.deleteImage(_currentImageUrl!);
          } catch (e) {
            debugPrint('Error deleting old image: $e');
          }
        }

        dynamic uploadResult;
        if (kIsWeb && _selectedImageBytes != null) {
          uploadResult = await ImageService.uploadImageFromBytes(
            _selectedImageBytes!,
            _selectedImageName ?? 'tenant_profile.jpg',
            'tenant-images',
            folder: 'profiles',
            prefix: 'tenant',
            context: 'profile_${_currentUser!.userId}_${widget.tenantId}',
          );
        } else if (!kIsWeb && _selectedImage != null) {
          uploadResult = await ImageService.uploadImage(
            _selectedImage!,
            'tenant-images',
            folder: 'profiles',
            prefix: 'tenant',
            context: 'profile_${_currentUser!.userId}_${widget.tenantId}',
          );
        }

        if (mounted) Navigator.of(context).pop();

        if (uploadResult != null && uploadResult['success']) {
          imageUrl = uploadResult['url'];
        } else {
          throw Exception(
              uploadResult?['message'] ?? 'ไม่สามารถอัปโหลดรูปภาพได้');
        }
      } else if (_imageChanged && _currentImageUrl != null) {
        // Image was removed
        try {
          await ImageService.deleteImage(_currentImageUrl!);
        } catch (e) {
          debugPrint('Error deleting image: $e');
        }
        imageUrl = null;
      }

      if (_tabController.index == 0) {
        // Save tenant data
        await _saveTenantData(imageUrl);
      } else {
        // Save contract data
        await _saveContractData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  Future<void> _saveTenantData(String? imageUrl) async {
    final tenantData = {
      'tenant_idcard': _tenantIdCardController.text.trim(),
      'tenant_fullname': _tenantFullNameController.text.trim(),
      'tenant_phone': _tenantPhoneController.text.trim(),
      'gender': _selectedGender,
      'tenant_profile': imageUrl,
      'is_active': _isActive,
    };

    final result = await TenantService.updateTenant(
      widget.tenantId,
      tenantData,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success']) {
        _showSuccessSnackBar(result['message']);
        Navigator.of(context).pop(true);
      } else {
        _showErrorSnackBar(result['message']);
      }
    }
  }

  Future<void> _saveContractData() async {
    if (_activeContract == null) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('ไม่พบสัญญาที่ใช้งานอยู่');
      return;
    }

    try {
      final contractData = {
        'start_date': _contractStartDate!.toIso8601String().split('T')[0],
        'end_date': _contractEndDate!.toIso8601String().split('T')[0],
        'contract_price':
            double.tryParse(_contractPriceController.text.trim()) ?? 0,
        'contract_deposit':
            double.tryParse(_contractDepositController.text.trim()) ?? 0,
        'contract_paid': _contractPaid,
        'payment_day': _paymentDay,
        'contract_note': _contractNotesController.text.trim().isEmpty
            ? null
            : _contractNotesController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('rental_contracts')
          .update(contractData)
          .eq('contract_id', _activeContract!['contract_id']);

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessSnackBar('อัปเดตข้อมูลสัญญาสำเร็จ');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('เกิดข้อผิดพลาดในการอัปเดตสัญญา: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลผู้เช่า'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.person),
              text: 'ข้อมูลผู้เช่า',
            ),
            Tab(
              icon: Icon(Icons.description),
              text: 'ข้อมูลสัญญา',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text('กำลังบันทึกข้อมูล...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTenantTab(),
                _buildContractTab(),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSaveButton(),
              ),
            ),
    );
  }

  Widget _buildTenantTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileImageSection(),
            const SizedBox(height: 24),
            _buildTenantInfoSection(),
            const SizedBox(height: 24),
            _buildStatusSection(),
            const SizedBox(height: 80), // Space for bottom button
          ],
        ),
      ),
    );
  }

  Widget _buildContractTab() {
    if (_isLoadingContract) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text('กำลังโหลดข้อมูลสัญญา...'),
          ],
        ),
      );
    }

    if (_activeContract == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'ไม่มีสัญญาที่ใช้งานอยู่',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ผู้เช่ารายนี้ยังไม่มีสัญญาเช่าที่ active',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContractInfoCard(),
          const SizedBox(height: 16),
          _buildContractEditSection(),
          const SizedBox(height: 80), // Space for bottom button
        ],
      ),
    );
  }

  Widget _buildContractInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ข้อมูลสัญญาปัจจุบัน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.assignment,
              label: 'เลขที่สัญญา',
              value: _activeContract!['contract_num'] ?? '-',
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.home,
              label: 'ห้องพัก',
              value: _activeContract!['rooms']?['room_number'] ?? '-',
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.business,
              label: 'สาขา',
              value:
                  _activeContract!['rooms']?['branches']?['branch_name'] ?? '-',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractEditSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'แก้ไขข้อมูลสัญญา',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // วันที่เริ่มสัญญา
            InkWell(
              onTap: () => _selectDate(context, true),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'วันที่เริ่มสัญญา *',
                  prefixIcon: const Icon(Icons.date_range),
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
                ),
                child: Text(
                  _contractStartDate != null
                      ? '${_contractStartDate!.day}/${_contractStartDate!.month}/${_contractStartDate!.year + 543}'
                      : 'เลือกวันที่',
                  style: TextStyle(
                    color: _contractStartDate != null
                        ? Colors.black87
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // วันที่สิ้นสุดสัญญา
            InkWell(
              onTap: () => _selectDate(context, false),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'วันที่สิ้นสุดสัญญา *',
                  prefixIcon: const Icon(Icons.event_busy),
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
                ),
                child: Text(
                  _contractEndDate != null
                      ? '${_contractEndDate!.day}/${_contractEndDate!.month}/${_contractEndDate!.year + 543}'
                      : 'เลือกวันที่',
                  style: TextStyle(
                    color: _contractEndDate != null
                        ? Colors.black87
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ค่าเช่า
            TextFormField(
              controller: _contractPriceController,
              decoration: InputDecoration(
                labelText: 'ค่าเช่า (บาท/เดือน) *',
                prefixIcon: const Icon(Icons.attach_money),
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
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกค่าเช่า';
                }
                if (double.tryParse(value.trim()) == null) {
                  return 'กรุณากรอกตัวเลขเท่านั้น';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ค่าประกัน
            TextFormField(
              controller: _contractDepositController,
              decoration: InputDecoration(
                labelText: 'ค่าประกัน (บาท) *',
                prefixIcon: const Icon(Icons.security),
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
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกค่าประกัน';
                }
                if (double.tryParse(value.trim()) == null) {
                  return 'กรุณากรอกตัวเลขเท่านั้น';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // วันที่ชำระประจำเดือน
            DropdownButtonFormField<int>(
              value: _paymentDay,
              decoration: InputDecoration(
                labelText: 'วันที่ชำระประจำเดือน',
                prefixIcon: const Icon(Icons.calendar_today),
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
              ),
              items: List.generate(31, (index) => index + 1)
                  .map((day) => DropdownMenuItem(
                        value: day,
                        child: Text('วันที่ $day'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _paymentDay = value ?? 1;
                });
              },
            ),
            const SizedBox(height: 16),

            // ชำระค่าประกันแล้ว
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ชำระค่าประกันแล้ว',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Switch(
                    value: _contractPaid,
                    onChanged: (value) {
                      setState(() {
                        _contractPaid = value;
                      });
                    },
                    activeColor: AppTheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // หมายเหตุ
            TextFormField(
              controller: _contractNotesController,
              decoration: InputDecoration(
                labelText: 'หมายเหตุเพิ่มเติม',
                hintText: 'เพิ่มหมายเหตุเกี่ยวกับสัญญาเช่า (ถ้ามี)',
                prefixIcon: const Icon(Icons.note),
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
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImageSection() {
    final hasImage = _selectedImage != null ||
        _selectedImageBytes != null ||
        (_currentImageUrl != null && _currentImageUrl!.isNotEmpty);
    final tenantName = _tenantFullNameController.text.trim();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'รูปภาพโปรไฟล์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade100,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: hasImage
                        ? ClipOval(child: _buildImagePreview())
                        : Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withOpacity(0.1),
                            ),
                            child: Center(
                              child: Text(
                                tenantName.isNotEmpty
                                    ? _getInitials(tenantName)
                                    : 'T',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: Icon(
                            hasImage ? Icons.swap_horiz : Icons.add_a_photo),
                        label: Text(hasImage ? 'เปลี่ยนรูป' : 'เพิ่มรูปภาพ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      if (hasImage) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _removeImage,
                          icon: const Icon(Icons.delete),
                          label: const Text('ลบรูป'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (kIsWeb && _selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return Image.network(
        _currentImageUrl!,
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

  Widget _buildTenantInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ข้อมูลผู้เช่า',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // เลขบัตรประชาชน
            TextFormField(
              controller: _tenantIdCardController,
              decoration: InputDecoration(
                labelText: 'เลขบัตรประชาชน *',
                prefixIcon: const Icon(Icons.credit_card),
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
              ),
              maxLength: 13,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกเลขบัตรประชาชน';
                }
                if (value.length != 13) {
                  return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ชื่อ-นามสกุล
            TextFormField(
              controller: _tenantFullNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อ-นามสกุล *',
                prefixIcon: const Icon(Icons.person),
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
              ),
              onChanged: (value) {
                setState(() {});
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกชื่อ-นามสกุล';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // เบอร์โทรศัพท์
            TextFormField(
              controller: _tenantPhoneController,
              decoration: InputDecoration(
                labelText: 'เบอร์โทรศัพท์ *',
                prefixIcon: const Icon(Icons.phone),
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
              ),
              maxLength: 10,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกเบอร์โทรศัพท์';
                }
                if (value.length != 10) {
                  return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // เพศ
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                labelText: 'เพศ',
                prefixIcon: const Icon(Icons.wc),
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
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('ชาย')),
                DropdownMenuItem(value: 'female', child: Text('หญิง')),
                DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.toggle_on, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'การตั้งค่า',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('เปิดใช้งานผู้เช่า'),
              subtitle: Text(
                _isActive
                    ? 'ผู้เช่าจะปรากฏในระบบและสามารถใช้งานได้'
                    : 'ผู้เช่าจะถูกปิดการใช้งาน',
                style: TextStyle(
                  color: _isActive
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                ),
              ),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
              activeColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveData,
        icon: _isLoading
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
          _isLoading
              ? 'กำลังบันทึก...'
              : _tabController.index == 0
                  ? 'บันทึกข้อมูลผู้เช่า'
                  : 'บันทึกข้อมูลสัญญา',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLoading ? Colors.grey : AppTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: _isLoading ? 0 : 2,
        ),
      ),
    );
  }
}
