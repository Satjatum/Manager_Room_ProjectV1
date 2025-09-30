import 'package:flutter/material.dart';
import 'package:manager_room_project/widgets/navbar.dart';
import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../services/branch_service.dart';
import 'branch_add_ui.dart';
import 'branchlist_detail_ui.dart';
import 'branch_edit_ui.dart';
import '../../widgets/colors.dart';

class BranchlistUi extends StatefulWidget {
  const BranchlistUi({Key? key}) : super(key: key);

  @override
  State<BranchlistUi> createState() => _BranchlistUiState();
}

class _BranchlistUiState extends State<BranchlistUi> {
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _filteredBranches = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  UserModel? _currentUser;
  bool _isAnonymous = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthMiddleware.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isAnonymous = user == null;
      });
    } catch (e) {
      setState(() {
        _currentUser = null;
        _isAnonymous = true;
      });
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> branches;

      // Handle different user types
      if (_isAnonymous) {
        // Anonymous users see only active branches
        branches = await BranchService.getActiveBranches();
      } else if (_currentUser!.userRole == UserRole.superAdmin) {
        branches = await BranchService.getAllBranches();
      } else if (_currentUser!.userRole == UserRole.admin) {
        branches = await BranchService.getBranchesByUser();
      } else {
        branches = await BranchService.getBranchesByUser();
      }

      if (mounted) {
        setState(() {
          _branches = branches;
          _filteredBranches = _branches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _branches = [];
          _filteredBranches = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ลองใหม่',
              textColor: Colors.white,
              onPressed: _loadBranches,
            ),
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterBranches();
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status ?? 'all';
    });
    _filterBranches();
  }

  void _filterBranches() {
    if (!mounted) return;
    setState(() {
      _filteredBranches = _branches.where((branch) {
        final searchTerm = _searchQuery.toLowerCase();
        final matchesSearch = (branch['branch_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (branch['branch_address'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (branch['owner_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm);

        final branchStatus =
            branch['is_active'] == true ? 'active' : 'inactive';
        final matchesStatus =
            _selectedStatus == 'all' || branchStatus == _selectedStatus;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  // Show login prompt for anonymous users trying to manage branches
  void _showLoginPrompt(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.login, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('ต้องเข้าสู่ระบบ'),
          ],
        ),
        content: Text('คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถ$actionได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to login page - adjust route as needed
              // Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  // Function for toggling branch status (authenticated users only)
  Future<void> _toggleBranchStatus(
      String branchId, String branchName, bool currentStatus) async {
    if (_isAnonymous) {
      _showLoginPrompt('เปลี่ยนสถานะสาขา');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    currentStatus ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                currentStatus
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color:
                    currentStatus ? Colors.red.shade600 : Colors.green.shade600,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(currentStatus ? 'ปิดใช้งานสาขา' : 'เปิดใช้งานสาขา'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'คุณต้องการ${currentStatus ? 'ปิด' : 'เปิด'}ใช้งานสาขา "$branchName" ใช่หรือไม่?'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade600, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentStatus
                          ? 'สาขาจะถูกซ่อนจากการแสดงผล แต่ข้อมูลจะยังคงอยู่'
                          : 'สาขาจะแสดงในรายการและสามารถใช้งานได้ปกติ',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus
                  ? Colors.orange.withOpacity(0.1)
                  : AppTheme.primary.withOpacity(0.1),
              foregroundColor: currentStatus ? Colors.orange : AppTheme.primary,
            ),
            child: Text(currentStatus ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 16),
                Text('กำลัง${currentStatus ? 'ปิด' : 'เปิด'}ใช้งานสาขา...'),
              ],
            ),
          ),
        );

        final result = await BranchService.toggleBranchStatus(branchId);

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text(result['message'])),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
            await _loadBranches();
          } else {
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(e.toString().replaceAll('Exception: ', ''))),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  // Function to delete branch permanently (SuperAdmin only)
  Future<void> _deleteBranch(String branchId, String branchName) async {
    if (_isAnonymous) {
      _showLoginPrompt('ลบสาขา');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade400, Colors.red.shade600],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.warning_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'ยืนยันการลบสาขาถาวร',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'คุณต้องการลบสาขา "$branchName" ออกจากระบบถาวรใช่หรือไม่?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'คำเตือน',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'การลบถาวรจะทำให้ข้อมูลสาขาหายไปจากระบบทั้งหมด และไม่สามารถกู้คืนได้อีก',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Text(
                    'ยกเลิก',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'ลบถาวร',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // แสดง loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'กำลังลบสาขาถาวร...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'กรุณารอสักครู่',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );

        final result = await BranchService.permanentDeleteBranch(branchId);

        // ปิด loading dialog
        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(Icons.check_circle,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(result['message'] ?? 'ลบสาขาสำเร็จ')),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                duration: Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
              ),
            );
            await _loadBranches();
          } else {
            throw Exception(result['message'] ?? 'ไม่สามารถลบสาขาได้');
          }
        }
      } catch (e) {
        // ปิด loading dialog หากยังเปิดอยู่
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child:
                        const Icon(Icons.error, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      e.toString().replaceAll('Exception: ', ''),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              duration: Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.primary;
      case 'inactive':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'เปิดใช้งาน';
      case 'inactive':
        return 'ปิดใช้งาน';
      default:
        return 'ไม่ทราบ';
    }
  }

  bool get _canManage =>
      !_isAnonymous &&
      (_currentUser?.userRole == UserRole.superAdmin ||
          _currentUser?.userRole == UserRole.admin);
  bool get _canAdd =>
      !_isAnonymous && _currentUser?.userRole == UserRole.superAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการสาขา'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isAnonymous) // Show filter only for authenticated users
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) => _onStatusChanged(value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'all',
                  child: Row(
                    children: [
                      Icon(
                        _selectedStatus == 'all'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('ทั้งหมด'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'active',
                  child: Row(
                    children: [
                      Icon(
                        _selectedStatus == 'active'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('เปิดใช้งาน'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'inactive',
                  child: Row(
                    children: [
                      Icon(
                        _selectedStatus == 'inactive'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('ปิดใช้งาน'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBranches,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาสาขา',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[700]),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
                if (_isAnonymous) ...[
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade600, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'คุณกำลังดูในโหมดผู้เยี่ยมชม เข้าสู่ระบบเพื่อใช้งานเต็มรูปแบบ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
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
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text('กำลังโหลดข้อมูล...'),
                      ],
                    ),
                  )
                : _filteredBranches.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadBranches,
                        color: AppTheme.primary,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredBranches.length,
                          itemBuilder: (context, index) {
                            final branch = _filteredBranches[index];
                            return _buildBranchCard(branch, _canManage);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BranchAddPage()),
                ).then((result) {
                  if (result == true) {
                    _loadBranches();
                  }
                });
              },
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'ไม่พบสาขาที่ค้นหา' : 'ยังไม่มีสาขา',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'ลองเปลี่ยนคำค้นหา หรือกรองสถานะ'
                : _isAnonymous
                    ? 'ไม่มีสาขาที่เปิดใช้งานในขณะนี้'
                    : 'เริ่มต้นโดยการเพิ่มสาขาแรก',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          if (_searchQuery.isEmpty && _canAdd)
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BranchAddPage()),
                  );
                  if (result == true) {
                    await _loadBranches();
                  }
                },
                icon: Icon(Icons.add),
                label: Text('เพิ่มสาขาใหม่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(Map<String, dynamic> branch, bool canManage) {
    final isActive = branch['is_active'] ?? false;
    final status = isActive ? 'active' : 'inactive';
    final statusColor = _getStatusColor(status);

    return Card(
      margin: EdgeInsets.only(bottom: 20),
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BranchListDetail(
                branchId: branch['branch_id'],
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // รูปภาพสาขา
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: branch['branch_image'] != null &&
                            branch['branch_image'].toString().isNotEmpty
                        ? Image.network(
                            branch['branch_image'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _imageFallback();
                            },
                          )
                        : _imageFallback(),
                  ),
                ),
                // ไล่เฉดมืดด้านล่างเพื่อให้ตัวอักษรอ่านง่าย
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ชื่อสาขา + สถานะ
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          branch['branch_name'] ?? 'ไม่มีชื่อ',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          _getStatusText(status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppTheme.primary : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ข้อมูลสาขา
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // รหัสสาขา
                  if (branch['branch_code'] != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.qr_code,
                              size: 16, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Text(
                            'รหัส: ${branch['branch_code']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ที่อยู่
                  if (branch['branch_address'] != null &&
                      branch['branch_address'].toString().isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              branch['branch_address'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // เจ้าของสาขา
                  if (branch['primary_manager_name'] != null &&
                      branch['primary_manager_name'].toString().isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ผู้ดูแลหลัก: ${branch['primary_manager_name']}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (branch['manager_count'] != null &&
                              branch['manager_count'] > 1)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${branch['manager_count'] - 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // ปุ่มจัดการ (สำหรับ Admin และ SuperAdmin)
                  if (canManage)
                    Row(
                      children: [
                        // ปุ่มดูรายละเอียด
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BranchListDetail(
                                    branchId: branch['branch_id'],
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.visibility, size: 16),
                            label: Text('ดู'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: BorderSide(color: AppTheme.primary),
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),

                        // ปุ่มแก้ไข
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BranchEditPage(
                                    branchId: branch['branch_id'],
                                  ),
                                ),
                              );
                              if (result == true) {
                                await _loadBranches();
                              }
                            },
                            icon: Icon(Icons.edit, size: 16),
                            label: Text('แก้ไข'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),

                        // ปุ่ม Menu เพิ่มเติม
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'toggle':
                                _toggleBranchStatus(
                                  branch['branch_id'],
                                  branch['branch_name'] ?? '',
                                  isActive,
                                );
                                break;
                              case 'delete':
                                if (_currentUser?.userRole ==
                                    UserRole.superAdmin) {
                                  _deleteBranch(
                                    branch['branch_id'],
                                    branch['branch_name'] ?? '',
                                  );
                                }
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 16,
                                    color:
                                        isActive ? Colors.orange : Colors.green,
                                  ),
                                  SizedBox(width: 8),
                                  Text(isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
                                ],
                              ),
                            ),
                            if (_currentUser?.userRole == UserRole.superAdmin)
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_forever,
                                        size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'ลบถาวร',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  else if (_isAnonymous)
                    // แสดงปุ่มดูรายละเอียดเฉพาะสำหรับผู้เยี่ยมชม
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BranchListDetail(
                                branchId: branch['branch_id'],
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.visibility, size: 16),
                        label: Text('ดูรายละเอียด'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withOpacity(0.8),
            AppTheme.primary,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 48,
              color: Colors.white.withOpacity(0.8),
            ),
            SizedBox(height: 8),
            Text(
              'ไม่มีรูปภาพ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
