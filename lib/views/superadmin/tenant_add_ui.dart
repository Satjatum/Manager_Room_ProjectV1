import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/tenant_service.dart';
import '../../services/room_service.dart';
import '../../services/branch_service.dart';
import '../../services/image_service.dart';
import '../../services/user_service.dart';
import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../widgets/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenantAddUI extends StatefulWidget {
  final String? branchId;
  final String? branchName;

  const TenantAddUI({
    Key? key,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<TenantAddUI> createState() => _TenantAddUIState();
}

class _TenantAddUIState extends State<TenantAddUI>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Tab Controller
  late TabController _tabController;
  int _currentTabIndex = 0;

  // Tenant form controllers
  final _tenantIdCardController = TextEditingController();
  final _tenantFullNameController = TextEditingController();
  final _tenantPhoneController = TextEditingController();

  // User account controllers
  final _userNameController = TextEditingController();
  final _userEmailController = TextEditingController();
  final _userPasswordController = TextEditingController();

  // Contract controllers
  final _contractNumController = TextEditingController();
  final _contractPriceController = TextEditingController();
  final _contractDepositController = TextEditingController();
  final _contractNotesController = TextEditingController();

  String? _selectedGender;
  String? _selectedBranchId;
  String? _selectedRoomId;
  DateTime? _contractStartDate;
  DateTime? _contractEndDate;
  int _paymentDay = 1;
  bool _contractPaid = false;
  bool _isActive = true;
  bool _createUserAccount = true;
  bool _isLoading = false;
  bool _isLoadingData = false;
  bool _isCheckingAuth = true;
  bool _showPassword = false;

  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _availableRooms = [];

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // Contract document
  String? _documentPath;
  String? _documentName;
  Uint8List? _documentBytes;

  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });

    _generateContractNumber();

    if (widget.branchId != null) {
      _selectedBranchId = widget.branchId;
    }

    _initializePageData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tenantIdCardController.dispose();
    _tenantFullNameController.dispose();
    _tenantPhoneController.dispose();
    _userNameController.dispose();
    _userEmailController.dispose();
    _userPasswordController.dispose();
    _contractNumController.dispose();
    _contractPriceController.dispose();
    _contractDepositController.dispose();
    _contractNotesController.dispose();
    super.dispose();
  }

  void _generateContractNumber() {
    final now = DateTime.now();
    final random = Random();
    final randomNum = random.nextInt(9999).toString().padLeft(4, '0');
    _contractNumController.text =
        'CT${now.year}${now.month.toString().padLeft(2, '0')}$randomNum';
  }

  Future<void> _initializePageData() async {
    await _loadCurrentUser();
    if (_currentUser != null) {
      await _loadDropdownData();

      if (widget.branchId != null) {
        await _loadAvailableRooms(widget.branchId!);
      }
    }
    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
      });
    }
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
      if (mounted) {
        setState(() {
          _currentUser = null;
        });
      }
    }
  }

  Future<void> _loadDropdownData() async {
    if (_currentUser == null) return;

    setState(() => _isLoadingData = true);

    try {
      final branches = await BranchService.getBranchesByUser();

      if (mounted) {
        setState(() {
          _branches = branches;
          _isLoadingData = false;
        });

        if (_selectedBranchId != null) {
          await _loadAvailableRooms(_selectedBranchId!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        _showErrorSnackBar('ไม่สามารถโหลดข้อมูลได้: $e');
      }
    }
  }

  Future<void> _loadAvailableRooms(String branchId) async {
    try {
      final rooms = await RoomService.getAllRooms(
        branchId: branchId,
        roomStatus: 'available',
        isActive: true,
      );

      if (mounted) {
        setState(() {
          _availableRooms = rooms;
          _selectedRoomId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('ไม่สามารถโหลดข้อมูลห้องได้: $e');
      }
    }
  }

  // เลือกไฟล์เอกสารสัญญา
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _documentPath = file.path ?? '';
          _documentName = file.name;
          _documentBytes = file.bytes;
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกไฟล์: $e');
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
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
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _validateImageBytesForWeb(
      Uint8List bytes, String fileName) async {
    try {
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          _showErrorSnackBar(
              'ขนาดไฟล์เกิน 5MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า');
        }
        return false;
      }

      final extension = fileName.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          _showErrorSnackBar('รองรับเฉพาะไฟล์ JPG, JPEG, PNG, WebP เท่านั้น');
        }
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _validateImageFile(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          _showErrorSnackBar(
              'ขนาดไฟล์เกิน 5MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า');
        }
        return false;
      }

      final extension = file.path.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          _showErrorSnackBar('รองรับเฉพาะไฟล์ JPG, JPEG, PNG, WebP เท่านั้น');
        }
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'T';

    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else {
      return words[0][0].toUpperCase();
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_contractStartDate ?? DateTime.now())
          : (_contractEndDate ?? DateTime.now().add(const Duration(days: 365))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: Localizations.localeOf(context),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _contractStartDate = picked;
          if (_contractEndDate == null) {
            _contractEndDate = picked.add(const Duration(days: 365));
          }
        } else {
          _contractEndDate = picked;
        }
      });
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Validation ก่อนบันทึก
  bool _validateCurrentTab() {
    if (_currentTabIndex == 0) {
      // Tab ข้อมูลผู้เช่า
      if (_tenantIdCardController.text.trim().isEmpty) {
        _showErrorSnackBar('กรุณากรอกเลขบัตรประชาชน');
        return false;
      }
      if (_tenantFullNameController.text.trim().isEmpty) {
        _showErrorSnackBar('กรุณากรอกชื่อ-นามสกุล');
        return false;
      }
      if (_tenantPhoneController.text.trim().isEmpty) {
        _showErrorSnackBar('กรุณากรอกเบอร์โทรศัพท์');
        return false;
      }
      if (_selectedBranchId == null) {
        _showErrorSnackBar('กรุณาเลือกสาขา');
        return false;
      }
    } else if (_currentTabIndex == 1) {
      // Tab บัญชีผู้ใช้
      if (_createUserAccount) {
        if (_userNameController.text.trim().isEmpty) {
          _showErrorSnackBar('กรุณากรอกชื่อผู้ใช้');
          return false;
        }
        if (_userEmailController.text.trim().isEmpty) {
          _showErrorSnackBar('กรุณากรอกอีเมล');
          return false;
        }
        if (_userPasswordController.text.trim().isEmpty) {
          _showErrorSnackBar('กรุณากรอกรหัสผ่าน');
          return false;
        }
      }
    } else if (_currentTabIndex == 2) {
      // Tab สัญญาเช่า
      if (_selectedRoomId == null) {
        _showErrorSnackBar('กรุณาเลือกห้องเช่า');
        return false;
      }
      if (_contractStartDate == null || _contractEndDate == null) {
        _showErrorSnackBar('กรุณาระบุวันที่เริ่มต้นและสิ้นสุดสัญญา');
        return false;
      }
      if (_contractEndDate!.isBefore(_contractStartDate!)) {
        _showErrorSnackBar('วันที่สิ้นสุดสัญญาต้องมาหลังวันที่เริ่มต้น');
        return false;
      }
      if (_contractPriceController.text.trim().isEmpty) {
        _showErrorSnackBar('กรุณากรอกค่าเช่า');
        return false;
      }
      if (_contractDepositController.text.trim().isEmpty) {
        _showErrorSnackBar('กรุณากรอกค่าประกัน');
        return false;
      }
    }

    return true;
  }

  void _nextTab() {
    if (_validateCurrentTab()) {
      if (_currentTabIndex < 2) {
        _tabController.animateTo(_currentTabIndex + 1);
      }
    }
  }

  void _previousTab() {
    if (_currentTabIndex > 0) {
      _tabController.animateTo(_currentTabIndex - 1);
    }
  }

  Future<void> _saveTenant() async {
    if (_currentUser == null) {
      _showErrorSnackBar('กรุณาเข้าสู่ระบบก่อนเพิ่มผู้เช่า');
      Navigator.of(context).pop();
      return;
    }

    // Validate all tabs
    for (int i = 0; i <= 2; i++) {
      setState(() => _currentTabIndex = i);
      _tabController.animateTo(i);
      if (!_validateCurrentTab()) {
        return;
      }
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      String? userId;

      // Upload profile image if selected
      if (_selectedImage != null || _selectedImageBytes != null) {
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

        dynamic uploadResult;
        if (kIsWeb && _selectedImageBytes != null) {
          uploadResult = await ImageService.uploadImageFromBytes(
            _selectedImageBytes!,
            _selectedImageName ?? 'tenant_profile.jpg',
            'tenant-images',
            folder: 'profiles',
          );
        } else if (!kIsWeb && _selectedImage != null) {
          uploadResult = await ImageService.uploadImage(
            _selectedImage!,
            'tenant-images',
            folder: 'profiles',
          );
        }

        if (mounted) Navigator.of(context).pop();

        if (uploadResult != null && uploadResult['success']) {
          imageUrl = uploadResult['url'];
        } else {
          throw Exception(
              uploadResult?['message'] ?? 'ไม่สามารถอัปโหลดรูปภาพได้');
        }
      }

      // Create user account if requested
      if (_createUserAccount) {
        final userResult = await UserService.createUser({
          'user_name': _userNameController.text.trim(),
          'user_email': _userEmailController.text.trim(),
          'user_pass': _userPasswordController.text,
          'role': 'tenant',
          'permissions': [
            'view_own_data',
            'create_issues',
            'view_invoices',
            'make_payments',
          ],
          'is_active': true,
        });

        if (!userResult['success']) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showErrorSnackBar(
                'ไม่สามารถสร้างบัญชีผู้ใช้ได้: ${userResult['message']}');
          }
          return;
        }

        userId = userResult['data']['user_id'];
      }

      // Create tenant
      final tenantData = {
        'branch_id': _selectedBranchId,
        'tenant_idcard': _tenantIdCardController.text.trim(),
        'tenant_fullname': _tenantFullNameController.text.trim(),
        'tenant_phone': _tenantPhoneController.text.trim(),
        'gender': _selectedGender,
        'tenant_profile': imageUrl,
        'is_active': _isActive,
        'user_id': userId,
      };

      final tenantResult = await TenantService.createTenant(tenantData);

      if (!tenantResult['success']) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar(tenantResult['message']);
        }
        return;
      }

      final tenantId = tenantResult['data']['tenant_id'];

      // Create rental contract
      final contractData = {
        'contract_num': _contractNumController.text.trim(),
        'room_id': _selectedRoomId,
        'tenant_id': tenantId,
        'start_date': _contractStartDate!.toIso8601String().split('T')[0],
        'end_date': _contractEndDate!.toIso8601String().split('T')[0],
        'contract_price':
            double.tryParse(_contractPriceController.text.trim()) ?? 0,
        'contract_deposit':
            double.tryParse(_contractDepositController.text.trim()) ?? 0,
        'contract_paid': _contractPaid,
        'payment_day': _paymentDay,
        'contract_status': 'active',
        'contract_note': _contractNotesController.text.trim().isEmpty
            ? null
            : _contractNotesController.text.trim(),
      };

      // Insert contract directly to database
      await _supabase
          .from('rental_contracts')
          .insert(contractData)
          .select()
          .single();

      // Update room status to occupied
      await _supabase
          .from('rooms')
          .update({'room_status': 'occupied'}).eq('room_id', _selectedRoomId!);

      if (mounted) {
        setState(() => _isLoading = false);

        _showSuccessSnackBar(
          'สร้างผู้เช่าและสัญญาเช่าสำเร็จ'
          '${_createUserAccount ? ' พร้อมบัญชีผู้ใช้' : ''}',
        );

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('เพิ่มผู้เช่าใหม่'),
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
          title: const Text('เพิ่มผู้เช่าใหม่'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'กรุณาเข้าสู่ระบบ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถเพิ่มผู้เช่าได้',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เพิ่มผู้เช่าใหม่'),
            if (widget.branchName != null)
              Text(
                widget.branchName!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'ข้อมูลผู้เช่า', icon: Icon(Icons.person)),
            Tab(text: 'บัญชีผู้ใช้', icon: Icon(Icons.account_circle)),
            Tab(text: 'สัญญาเช่า', icon: Icon(Icons.description)),
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
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildTenantInfoTab(),
                        _buildUserAccountTab(),
                        _buildContractTab(),
                      ],
                    ),
                  ),
                  _buildNavigationButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildTenantInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileImageSection(),
          const SizedBox(height: 24),
          _buildTenantInfoSection(),
          const SizedBox(height: 24),
          _buildStatusSection(),
        ],
      ),
    );
  }

  Widget _buildUserAccountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUserAccountSection(),
        ],
      ),
    );
  }

  Widget _buildContractTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRoomSelectionSection(),
          const SizedBox(height: 24),
          _buildContractSection(),
          const SizedBox(height: 24),
          _buildContractDocumentSection(),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    final hasImage = _selectedImage != null || _selectedImageBytes != null;
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
            const SizedBox(height: 16),

            // สาขา
            DropdownButtonFormField<String>(
              value: _selectedBranchId,
              decoration: InputDecoration(
                labelText: 'สาขา *',
                prefixIcon: const Icon(Icons.business),
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
              items: _branches.map((branch) {
                return DropdownMenuItem<String>(
                  value: branch['branch_id'],
                  child: Text(branch['branch_name'] ?? ''),
                );
              }).toList(),
              onChanged: (value) async {
                setState(() {
                  _selectedBranchId = value;
                  _selectedRoomId = null;
                  _availableRooms = [];
                });

                if (value != null) {
                  await _loadAvailableRooms(value);
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาเลือกสาขา';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAccountSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'บัญชีผู้ใช้',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _createUserAccount,
                  onChanged: (value) {
                    setState(() {
                      _createUserAccount = value;
                      if (!value) {
                        _userNameController.clear();
                        _userEmailController.clear();
                        _userPasswordController.clear();
                      }
                    });
                  },
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _createUserAccount
                  ? 'สร้างบัญชีเพื่อให้ผู้เช่าสามารถเข้าสู่ระบบได้'
                  : 'ไม่สร้างบัญชีผู้ใช้ (เฉพาะข้อมูลผู้เช่า)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            if (_createUserAccount) ...[
              const SizedBox(height: 16),

              // ชื่อผู้ใช้
              TextFormField(
                controller: _userNameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อผู้ใช้ *',
                  hintText: 'ใช้สำหรับเข้าสู่ระบบ',
                  prefixIcon: const Icon(Icons.person_outline),
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
                validator: _createUserAccount
                    ? (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกชื่อผู้ใช้';
                        }
                        if (value.length < 4) {
                          return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 4 ตัวอักษร';
                        }
                        return null;
                      }
                    : null,
              ),
              const SizedBox(height: 16),

              // อีเมล
              TextFormField(
                controller: _userEmailController,
                decoration: InputDecoration(
                  labelText: 'อีเมล *',
                  hintText: 'example@email.com',
                  prefixIcon: const Icon(Icons.email),
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
                keyboardType: TextInputType.emailAddress,
                validator: _createUserAccount
                    ? (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกอีเมล';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'รูปแบบอีเมลไม่ถูกต้อง';
                        }
                        return null;
                      }
                    : null,
              ),
              const SizedBox(height: 16),

              // รหัสผ่าน
              TextFormField(
                controller: _userPasswordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน *',
                  hintText: 'อย่างน้อย 6 ตัวอักษร',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
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
                obscureText: !_showPassword,
                validator: _createUserAccount
                    ? (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกรหัสผ่าน';
                        }
                        if (value.length < 6) {
                          return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                        }
                        return null;
                      }
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSelectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'เลือกห้องเช่า',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedBranchId == null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'กรุณาเลือกสาขาก่อนเพื่อดูห้องว่าง',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_selectedBranchId != null) ...[
              DropdownButtonFormField<String>(
                value: _selectedRoomId,
                decoration: InputDecoration(
                  labelText: 'ห้องพัก *',
                  prefixIcon: const Icon(Icons.hotel),
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
                items: _availableRooms.map((room) {
                  return DropdownMenuItem<String>(
                    value: room['room_id'],
                    child: Row(
                      children: [
                        Text(
                            '${room['room_category_name'] ?? 'ห้อง'} เลขที่ ${room['room_number']}'),
                        const SizedBox(width: 8),
                        Text(
                          '฿${room['room_price']?.toStringAsFixed(0) ?? '0'}',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRoomId = value;
                    if (value != null) {
                      final selectedRoom = _availableRooms.firstWhere(
                        (room) => room['room_id'] == value,
                        orElse: () => {},
                      );
                      if (selectedRoom.isNotEmpty) {
                        _contractPriceController.text =
                            selectedRoom['room_price']?.toString() ?? '';
                        _contractDepositController.text =
                            selectedRoom['room_deposit']?.toString() ?? '';
                      }
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณาเลือกห้องพัก';
                  }
                  return null;
                },
              ),
              if (_availableRooms.isEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ไม่มีห้องว่างในสาขานี้',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContractSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'รายละเอียดสัญญา',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // เลขที่สัญญา
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _contractNumController,
                    decoration: InputDecoration(
                      labelText: 'เลขที่สัญญา *',
                      prefixIcon: const Icon(Icons.assignment),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xff10B981), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณากรอกเลขที่สัญญา';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _generateContractNumber,
                  icon: Icon(Icons.refresh, color: AppTheme.primary),
                  tooltip: 'สร้างเลขที่สัญญาใหม่',
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

  Widget _buildContractDocumentSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'เอกสารสัญญา',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // อัปโหลดเอกสาร
            OutlinedButton.icon(
              onPressed: _pickDocument,
              icon: Icon(Icons.upload_file),
              label: Text(
                  _documentName ?? 'อัปโหลดเอกสารสัญญา (PDF, DOC, รูปภาพ)'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_documentName != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _documentName!,
                        style: TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _documentPath = null;
                          _documentName = null;
                          _documentBytes = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentTabIndex > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousTab,
                icon: const Icon(Icons.arrow_back),
                label: const Text('ย้อนกลับ'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_currentTabIndex > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentTabIndex > 0 ? 1 : 1,
            child: ElevatedButton.icon(
              onPressed: _currentTabIndex < 2 ? _nextTab : _saveTenant,
              icon: Icon(
                _currentTabIndex < 2 ? Icons.arrow_forward : Icons.save,
                color: Colors.white,
              ),
              label: Text(
                _currentTabIndex < 2 ? 'ถัดไป' : 'บันทึกข้อมูล',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
