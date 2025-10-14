import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../services/branch_service.dart';
import '../../services/user_service.dart';
import '../../services/image_service.dart';
import '../../services/branch_manager_service.dart';
import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../widgets/colors.dart';

class BranchEditPage extends StatefulWidget {
  final String branchId;

  const BranchEditPage({
    Key? key,
    required this.branchId,
  }) : super(key: key);

  @override
  State<BranchEditPage> createState() => _BranchEditPageState();
}

class _BranchEditPageState extends State<BranchEditPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _branchCodeController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _branchAddressController = TextEditingController();
  final _branchDescController = TextEditingController();

  late TabController _tabController;
  int _currentTabIndex = 0;

  // Manager-related state
  List<String> _selectedManagerIds = [];
  String? _primaryManagerId;
  List<Map<String, dynamic>> _currentManagers = [];
  List<Map<String, dynamic>> _originalManagers = [];

  String? _currentImageUrl;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _isLoadingManagers = false;
  bool _imageChanged = false;
  bool _isCheckingAuth = true;

  List<Map<String, dynamic>> _adminUsers = [];
  UserModel? _currentUser;
  Map<String, dynamic>? _originalBranchData;

  bool get _isAdminBranchManager {
    if (_currentUser?.userRole != UserRole.admin) return false;
    if (_currentManagers.isEmpty) return false;
    final uid = _currentUser!.userId;
    return _currentManagers.any((m) {
      final directId = m['user_id'];
      final nested = m['users'] as Map<String, dynamic>?;
      final nestedId = nested?['user_id'];
      return directId == uid || nestedId == uid;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _initializePageData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _branchCodeController.dispose();
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchDescController.dispose();
    super.dispose();
  }

  Future<void> _initializePageData() async {
    await _loadCurrentUser();
    if (_currentUser != null) {
      await Future.wait([
        _loadBranchData(),
        _loadAdminUsers(),
        _loadBranchManagers(),
      ]);
    }
    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
        _isLoadingData = false;
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
      print('Error loading current user: $e');
      if (mounted) {
        setState(() {
          _currentUser = null;
        });
      }
    }
  }

  Future<void> _loadBranchData() async {
    try {
      final branch = await BranchService.getBranchById(widget.branchId);

      if (branch != null && mounted) {
        setState(() {
          _originalBranchData = Map.from(branch);
          _branchCodeController.text = branch['branch_code'] ?? '';
          _branchNameController.text = branch['branch_name'] ?? '';
          _branchAddressController.text = branch['branch_address'] ?? '';
          _branchDescController.text = branch['branch_desc'] ?? '';
          _isActive = branch['is_active'] ?? true;
          _currentImageUrl = branch['branch_image'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAdminUsers() async {
    if (_currentUser == null) return;

    // Only load admin users if user is SuperAdmin
    if (_currentUser!.userRole != UserRole.superAdmin) return;

    setState(() => _isLoadingManagers = true);

    try {
      final users = await UserService.getAdminUsers();
      if (mounted) {
        setState(() {
          _adminUsers = users;
          _isLoadingManagers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingManagers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถโหลดรายการผู้ดูแลได้: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadBranchManagers() async {
    try {
      final managers =
          await BranchManagerService.getBranchManagers(widget.branchId);
      if (mounted) {
        setState(() {
          _currentManagers = managers;
          _originalManagers = List.from(managers);

          // Load current selections
          _selectedManagerIds =
              managers.map((m) => m['users']['user_id'] as String).toList();

          // Find primary manager
          final primary = managers.firstWhere(
            (m) => m['is_primary'] == true,
            orElse: () => {},
          );
          if (primary.isNotEmpty) {
            _primaryManagerId = primary['users']['user_id'];
          }
        });
      }
    } catch (e) {
      print('Error loading branch managers: $e');
    }
  }

  // Manager selection methods
  void _toggleManagerSelection(String userId) {
    setState(() {
      if (_selectedManagerIds.contains(userId)) {
        _selectedManagerIds.remove(userId);
        if (_primaryManagerId == userId) {
          // หาคนใหม่เป็น primary ถ้ายังมีคนอยู่
          if (_selectedManagerIds.isNotEmpty) {
            _primaryManagerId = _selectedManagerIds.first;
          } else {
            _primaryManagerId = null;
          }
        }
      } else {
        _selectedManagerIds.add(userId);
        // ถ้าเป็นคนแรก ให้เป็น primary
        if (_selectedManagerIds.length == 1) {
          _primaryManagerId = userId;
        }
      }
    });
  }

  void _setPrimaryManager(String userId) {
    setState(() {
      _primaryManagerId = userId;
    });
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        await _pickImageForWeb();
      } else {
        await _pickImageForMobile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageForWeb() async {
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
          _selectedImage = null;
          _imageChanged = true;
        });
      }
    }
  }

  Future<void> _pickImageForMobile() async {
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
                  'เลือกรูปภาพสาขา',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
          _selectedImageBytes = null;
          _selectedImageName = null;
          _imageChanged = true;
        });
      }
    }
  }

  Future<bool> _validateImageBytesForWeb(
      Uint8List bytes, String fileName) async {
    try {
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ขนาดไฟล์เกิน 5MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไฟล์เสียหายหรือมีขนาด 0 bytes'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final extension = fileName.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('รองรับเฉพาะไฟล์ JPG, JPEG, PNG, WebP เท่านั้น'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถตรวจสอบไฟล์ได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _validateImageFile(File file) async {
    try {
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไฟล์ไม่พบหรือถูกลบ'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ขนาดไฟล์เกิน 5MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      if (fileSize == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไฟล์เสียหายหรือมีขนาด 0 bytes'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final extension = file.path.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('รองรับเฉพาะไฟล์ JPG, JPEG, PNG, WebP เท่านั้น'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถตรวจสอบไฟล์ได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
      _currentImageUrl = null;
      _imageChanged = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ลบรูปภาพแล้ว'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateBranch() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเข้าสู่ระบบก่อนแก้ไขสาขา'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    // Check permissions: allow superadmin/manageBranches OR admin who manages this branch
    final allowedUI = _currentUser!.hasAnyPermission([
          DetailedPermission.all,
          DetailedPermission.manageBranches,
        ]) ||
        _isAdminBranchManager;

    if (!allowedUI) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('คุณไม่มีสิทธิ์ในการแก้ไขสาขา'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      // Switch to info tab if validation fails
      _tabController.animateTo(0);
      return;
    }

    // Validate managers (SuperAdmin only)
    if (_currentUser!.userRole == UserRole.superAdmin) {
      if (_selectedManagerIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเลือกผู้ดูแลอย่างน้อย 1 คน'),
            backgroundColor: Colors.orange,
          ),
        );
        _tabController.animateTo(1);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;

      // Handle image upload/deletion
      if (_imageChanged) {
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
              _selectedImageName ?? 'branch_image.jpg',
              'branch-images',
              folder: 'branches',
            );
          } else if (!kIsWeb && _selectedImage != null) {
            uploadResult = await ImageService.uploadImage(
              _selectedImage!,
              'branch-images',
              folder: 'branches',
            );
          }

          if (mounted) Navigator.of(context).pop();

          if (uploadResult != null && uploadResult['success']) {
            // Delete old image if exists
            if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
              await ImageService.deleteImage(_currentImageUrl!);
            }
            imageUrl = uploadResult['url'];
          } else {
            throw Exception(
                uploadResult?['message'] ?? 'ไม่สามารถอัปโหลดรูปภาพได้');
          }
        } else {
          // Remove image
          if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
            await ImageService.deleteImage(_currentImageUrl!);
          }
          imageUrl = null;
        }
      }

      // Update branch data
      final branchData = {
        'branch_code': _branchCodeController.text.trim(),
        'branch_name': _branchNameController.text.trim(),
        'branch_address': _branchAddressController.text.trim().isEmpty
            ? null
            : _branchAddressController.text.trim(),
        'branch_desc': _branchDescController.text.trim().isEmpty
            ? null
            : _branchDescController.text.trim(),
        'branch_image': imageUrl,
        'is_active': _isActive,
      };

      final result = await BranchService.updateBranch(
        widget.branchId,
        branchData,
      );

      if (!result['success']) {
        throw Exception(result['message']);
      }

      // Update managers if SuperAdmin and changed
      if (_currentUser!.userRole == UserRole.superAdmin) {
        await _updateManagers();
      }

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('อัปเดตสาขาสำเร็จ')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _updateManagers() async {
    // Get original manager IDs
    final originalIds =
        _originalManagers.map((m) => m['users']['user_id'] as String).toSet();
    final newIds = _selectedManagerIds.toSet();

    // Find managers to remove
    final toRemove = originalIds.difference(newIds);
    for (String managerId in toRemove) {
      await BranchManagerService.removeBranchManager(
        branchId: widget.branchId,
        userId: managerId,
      );
    }

    // Find managers to add
    final toAdd = newIds.difference(originalIds);
    for (String managerId in toAdd) {
      await BranchManagerService.addBranchManager(
        branchId: widget.branchId,
        userId: managerId,
        isPrimary: managerId == _primaryManagerId,
      );
    }

    // Update primary manager if changed
    final originalPrimary = _originalManagers
        .firstWhere((m) => m['is_primary'] == true, orElse: () => {});
    final originalPrimaryId =
        originalPrimary.isNotEmpty ? originalPrimary['users']['user_id'] : null;

    if (_primaryManagerId != null && _primaryManagerId != originalPrimaryId) {
      await BranchManagerService.setPrimaryManager(
        branchId: widget.branchId,
        userId: _primaryManagerId!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth || _isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('แก้ไขสาขา'),
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
              Text(_isCheckingAuth
                  ? 'กำลังตรวจสอบสิทธิ์...'
                  : 'กำลังโหลดข้อมูล...'),
            ],
          ),
        ),
      );
    }

    final hasEditAccess = _currentUser != null &&
        (_currentUser!.hasAnyPermission([
              DetailedPermission.all,
              DetailedPermission.manageBranches,
            ]) ||
            _isAdminBranchManager);

    if (!hasEditAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('แก้ไขสาขา'),
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
                _currentUser == null
                    ? 'กรุณาเข้าสู่ระบบ'
                    : 'คุณไม่มีสิทธิ์เข้าถึงหน้านี้',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentUser == null
                    ? 'คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถแก้ไขสาขาได้'
                    : 'เฉพาะ SuperAdmin หรือ Admin ที่เป็นผู้จัดการสาขานี้เท่านั้นที่สามารถแก้ไขสาขาได้',
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
        title: const Text('แก้ไขสาขา'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: _currentUser!.userRole == UserRole.superAdmin
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.info), text: 'ข้อมูลสาขา'),
                  Tab(icon: Icon(Icons.people), text: 'ผู้ดูแล'),
                ],
              )
            : null,
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
              child: _currentUser!.userRole == UserRole.superAdmin
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBranchInfoTab(),
                        _buildManagersTab(),
                      ],
                    )
                  : _buildBranchInfoTab(),
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
        child: _buildNavigationButtons(),
      ),
    );
  }

  Widget _buildBranchInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          const SizedBox(height: 24),
          _buildBasicInfoSection(),
          const SizedBox(height: 24),
          _buildDescriptionSection(),
          const SizedBox(height: 24),
          _buildStatusSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildManagersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'จัดการผู้ดูแลสาขา',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'แก้ไขได้',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'เลือกผู้ดูแลอย่างน้อย 1 คน (สามารถเลือกได้หลายคน)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_selectedManagerIds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'เลือกแล้ว ${_selectedManagerIds.length} คน',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_isLoadingManagers)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child:
                            CircularProgressIndicator(color: AppTheme.primary),
                      ),
                    )
                  else if (_adminUsers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ไม่พบรายการผู้ดูแล',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'ต้องมี Admin หรือ SuperAdmin ในระบบก่อนจึงจะจัดการได้',
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildManagersList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildManagersList() {
    return Column(
      children: _adminUsers.map((user) {
        final userId = user['user_id'];
        final isSelected = _selectedManagerIds.contains(userId);
        final isPrimary = _primaryManagerId == userId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppTheme.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => _toggleManagerSelection(userId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Checkbox
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleManagerSelection(userId),
                    activeColor: AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user['user_name'] ?? 'ไม่มีชื่อ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (isPrimary)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star,
                                        size: 14, color: Colors.amber.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'หลัก',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.amber.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${user['role'] == 'superadmin' ? 'SuperAdmin' : 'Admin'} • ${user['user_email'] ?? 'ไม่มีอีเมล'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Primary button
                  if (isSelected && !isPrimary)
                    IconButton(
                      icon:
                          Icon(Icons.star_border, color: Colors.grey.shade400),
                      onPressed: () => _setPrimaryManager(userId),
                      tooltip: 'ตั้งเป็นผู้ดูแลหลัก',
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationButtons() {
    final bool canSave = !_isLoading && !_isLoadingManagers;
    final bool isSuperAdmin = _currentUser?.userRole == UserRole.superAdmin;

    if (!isSuperAdmin) {
      // Simple save button for non-SuperAdmin
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: canSave ? _updateBranch : null,
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
            _isLoading ? 'กำลังบันทึก...' : 'บันทึกการแก้ไข',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: canSave ? AppTheme.primary : Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: canSave ? 2 : 0,
          ),
        ),
      );
    }

    // Navigation buttons for SuperAdmin with tabs
    return Row(
      children: [
        if (_currentTabIndex > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _tabController.animateTo(_currentTabIndex - 1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('ก่อนหน้า'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        if (_currentTabIndex > 0) const SizedBox(width: 12),
        Expanded(
          flex: _currentTabIndex == 0 ? 1 : 2,
          child: _currentTabIndex < 1
              ? ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _tabController.animateTo(_currentTabIndex + 1),
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text(
                    'ถัดไป',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: canSave ? _updateBranch : null,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _isLoading ? 'กำลังบันทึก...' : 'บันทึกการแก้ไข',
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
        ),
      ],
    );
  }

  // Section builders (same as before)
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
                Icon(Icons.image, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'รูปภาพสาขา',
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
                const Spacer(),
                if (_hasSelectedImage())
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _imageChanged ? 'รูปใหม่พร้อมแล้ว' : 'รูปปัจจุบัน',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_hasSelectedImage()) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImagePreview(),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedImageName != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedImageName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _getImageSizeText(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('เปลี่ยนรูปภาพ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _removeImage,
                      icon: const Icon(Icons.delete),
                      label: const Text('ลบรูปภาพ'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300,
                      style: BorderStyle.solid,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        kIsWeb ? Icons.upload_file : Icons.add_photo_alternate,
                        size: 48,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        kIsWeb ? 'เลือกไฟล์รูปภาพ' : 'เลือกรูปภาพสาขา',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
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
            ],
          ],
        ),
      ),
    );
  }

  bool _hasSelectedImage() {
    return _selectedImage != null ||
        _selectedImageBytes != null ||
        _currentImageUrl != null;
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
    } else if (_currentImageUrl != null) {
      return Image.network(
        _currentImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade200,
          child: Center(
            child: Icon(
              Icons.image_not_supported,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
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

  String _getImageSizeText() {
    if (_selectedImageBytes != null) {
      final sizeInMB = _selectedImageBytes!.length / (1024 * 1024);
      return '${sizeInMB.toStringAsFixed(1)} MB';
    }
    return '';
  }

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
                Icon(Icons.business, color: AppTheme.primary),
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
            TextFormField(
              controller: _branchCodeController,
              decoration: InputDecoration(
                labelText: 'รหัสสาขา *',
                prefixIcon: const Icon(Icons.qr_code),
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
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกรหัสสาขา';
                }
                if (value.trim().length < 3) {
                  return 'รหัสสาขาต้องมีอย่างน้อย 3 ตัวอักษร';
                }
                if (value.trim().length > 20) {
                  return 'รหัสสาขาต้องไม่เกิน 20 ตัวอักษร';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _branchNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อสาขา *',
                prefixIcon: const Icon(Icons.store),
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
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกชื่อสาขา';
                }
                if (value.trim().length < 2) {
                  return 'ชื่อสาขาต้องมีอย่างน้อย 2 ตัวอักษร';
                }
                if (value.trim().length > 255) {
                  return 'ชื่อสาขาต้องไม่เกิน 255 ตัวอักษร';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _branchAddressController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'ที่อยู่สาขา',
                prefixIcon: const Icon(Icons.location_on),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
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
                  'คำอธิบายเพิ่มเติม',
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
              controller: _branchDescController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'รายละเอียดสาขา',
                hintText:
                    'อธิบายเกี่ยวกับสาขา เช่น จุดเด่น, สิ่งอำนวยความสะดวก, หรือข้อมูลเพิ่มเติม',
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
                Icon(Icons.settings, color: AppTheme.primary),
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
              title: const Text('เปิดใช้งานสาขา'),
              subtitle: Text(
                _isActive
                    ? 'สาขาจะปรากฏในระบบและสามารถใช้งานได้'
                    : 'สาขาจะถูกปิดการใช้งาน',
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
}
