import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:manager_room_project/views/superadmin/editbranch_ui.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
// Import Screen
import 'package:manager_room_project/views/superadmin/addbranch_ui.dart';
import 'package:manager_room_project/views/superadmin/branchlistdetail_ui.dart';

class BranchlistUi extends StatefulWidget {
  const BranchlistUi({Key? key}) : super(key: key);

  @override
  State<BranchlistUi> createState() => _BranchlistUiState();
}

final supabase = Supabase.instance.client;

class _BranchlistUiState extends State<BranchlistUi> {
  // Lightweight in-memory cache for decoded branch images (limits memory usage)
  final Map<String, Uint8List> _imageCache = {};
  int _imageCacheLimit = 40; // keep only most recent ~40 decoded images

  Uint8List? _getDecodedImage(Map<String, dynamic> branch) {
    final String? id = branch['branch_id']?.toString();
    final String? b64 = branch['branch_image']?.toString();
    if (id == null || b64 == null || b64.isEmpty) return null;

    final key =
        id; // Use branch id as cache key (image rarely changes per session)
    final cached = _imageCache[key];
    if (cached != null) return cached;

    try {
      // Decode base64 lazily and store with a soft cap
      final bytes = const Base64Decoder().convert(b64);
      if (_imageCache.length >= _imageCacheLimit) {
        // remove a random/first key to keep memory bounded
        _imageCache.remove(_imageCache.keys.first);
      }
      _imageCache[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _filteredBranches = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();

      late List<dynamic> response;

      if (currentUser?.isSuperAdmin ?? false) {
        // Super Admin เห็นทุกสาขา
        print('Loading branches for Super Admin'); // Debug log
        response = await supabase
            .from('branches')
            .select('*')
            .order('created_at', ascending: false);
      } else if (currentUser?.isAdmin ?? false) {
        // Admin เห็นเฉพาะสาขาตัวเอง
        print(
            'Loading branches for Admin: ${currentUser!.userId}'); // Debug log
        response = await supabase
            .from('branches')
            .select('*')
            .eq('owner_id', currentUser.userId)
            .order('created_at', ascending: false);
      } else {
        // User อื่นๆ เห็นเฉพาะสาขาที่ตนเองสังกัด
        print(
            'Loading branches for User: ${currentUser?.branchId}'); // Debug log
        if (currentUser?.branchId != null &&
            currentUser!.branchId!.isNotEmpty) {
          response = await supabase
              .from('branches')
              .select('*')
              .eq('branch_id', currentUser.branchId!)
              .order('created_at', ascending: false);
        } else {
          // ถ้าไม่มี branchId ให้ return empty list
          response = [];
        }
      }

      print('Raw branches response: ${response.length} items'); // Debug log

      // โหลดข้อมูล owner แยกต่างหาก (แบบ parallel เพื่อเร็วขึ้น)
      List<Map<String, dynamic>> branchesWithOwner = [];

      if (response.isNotEmpty) {
        // สร้าง list ของ Future สำหรับโหลดข้อมูล owner พร้อมกัน
        List<Future<Map<String, dynamic>>> branchFutures =
            response.map<Future<Map<String, dynamic>>>((branch) async {
          Map<String, dynamic> branchData = Map<String, dynamic>.from(branch);

          // ถ้ามี owner_id ให้ไปหาข้อมูลใน users table
          if (branch['owner_id'] != null &&
              branch['owner_id'].toString().isNotEmpty) {
            try {
              print(
                  'Loading owner data for: ${branch['owner_id']}'); // Debug log
              final ownerResponse = await supabase
                  .from('users')
                  .select('username, user_email, user_profile')
                  .eq('user_id', branch['owner_id'])
                  .maybeSingle(); // ใช้ maybeSingle แทน single เพื่อหลีกเลี่ยง error เมื่อไม่พบ

              if (ownerResponse != null) {
                branchData['owner_name'] = ownerResponse['username'] ??
                    branch['owner_name'] ??
                    'ไม่ระบุ';
                branchData['owner_email'] = ownerResponse['user_email'] ?? '';
                branchData['owner_profile'] = ownerResponse['user_profile'];
              } else {
                // ถ้าไม่พบใน users table ให้ใช้ owner_name ที่มีอยู่ใน branches
                branchData['owner_name'] = branch['owner_name'] ?? 'ไม่ระบุ';
                branchData['owner_email'] = '';
              }
            } catch (e) {
              print('Error loading owner data: $e'); // Debug log
              // ถ้าเกิด error ให้ใช้ owner_name ที่มีอยู่ใน branches
              branchData['owner_name'] = branch['owner_name'] ?? 'ไม่ระบุ';
              branchData['owner_email'] = '';
            }
          } else {
            // ถ้าไม่มี owner_id ให้ใช้ owner_name ที่มีอยู่ใน branches
            branchData['owner_name'] = branch['owner_name'] ?? 'ไม่ระบุ';
            branchData['owner_email'] = '';
          }

          return branchData;
        }).toList();

        // รอให้ทุก Future เสร็จ
        branchesWithOwner = await Future.wait(branchFutures);
      }

      print(
          'Processed branches: ${branchesWithOwner.length} items'); // Debug log

      setState(() {
        _branches = branchesWithOwner;
        _filteredBranches = _branches;
        _isLoading = false;
      });

      // แสดงผลลัพธ์
      if (mounted) {
        if (_branches.isEmpty) {
          print('No branches found for current user'); // Debug log
        } else {
          print(
              'Successfully loaded ${_branches.length} branches'); // Debug log
        }
      }
    } catch (e, stackTrace) {
      print('Error loading branches: $e'); // Debug log
      print('Stack trace: $stackTrace'); // Debug log

      setState(() {
        _isLoading = false;
        _branches = [];
        _filteredBranches = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'ลองใหม่',
                textColor: Colors.white,
                onPressed: _loadBranches,
              )),
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

        final matchesStatus = _selectedStatus == 'all' ||
            (branch['branch_status'] ?? 'active') == _selectedStatus;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _toggleBranchStatus(
      String branchId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'active' ? 'inactive' : 'active';

      await supabase.from('branches').update({
        'branch_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('branch_id', branchId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('อัพเดทสถานะสาขาสำเร็จ'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2)),
        );
      }

      await _loadBranches(); // Refresh the list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _deleteBranch(String branchId, String branchName) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('ยืนยันการลบ'),
              content: Text('คุณต้องการลบสาขา "' +
                  branchName +
                  '" ใช่หรือไม่?\n\nการลบไม่สามารถกู้คืนได้ และจะส่งผลกระทบต่อข้อมูลที่เกี่ยวข้องทั้งหมด'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('ยืนยัน'),
                ),
              ],
            ));
    if (confirm == true) {
      try {
        // อาจต้องเช็คก่อนว่ามีข้อมูลที่เกี่ยวข้องหรือไม่
        await supabase.from('branches').delete().eq('branch_id', branchId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('ลบสาขาสำเร็จ'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2)),
          );
        }

        await _loadBranches(); // Refresh the list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3)),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'maintenance':
        return Colors.blue;
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
      case 'maintenance':
        return 'ซ่อมบำรุง';
      default:
        return 'ไม่ทราบ';
    }
  }

  // UI
  Widget build(BuildContext context) {
    final currentUser = AuthService.getCurrentUser();
    final canManage = currentUser?.isSuperAdmin ?? false;
    final canAdd = currentUser?.isSuperAdmin ?? currentUser?.isAdmin ?? false;

    return Scaffold(
        appBar: AppBar(
          title: Text(
            'จัดการสาขา',
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadBranches,
            ),
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
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('ทั้งหมด'),
                      ],
                    )),
                PopupMenuItem(
                    value: 'active',
                    child: Row(
                      children: [
                        Icon(
                          _selectedStatus == 'active'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('เปิดใช้งาน'),
                      ],
                    )),
                PopupMenuItem(
                    value: 'inactive',
                    child: Row(
                      children: [
                        Icon(
                          _selectedStatus == 'inactive'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('ปิดใช้งาน'),
                      ],
                    )),
                PopupMenuItem(
                    value: 'maintenance',
                    child: Row(
                      children: [
                        Icon(
                          _selectedStatus == 'maintenance'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('ซ่อมบำรุง'),
                      ],
                    )),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                          hintText: 'ค้นหาสาขา',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[700],
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[700],
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  })
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
                          )),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    SizedBox
                        .shrink(), // เว้นที่ว่างไว้สำหรับเพิ่ม widget อื่นๆ ในอนาคต
                  ],
                )),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        Text(
                          'กำลังโหลดข้อมูล...',
                        )
                      ],
                    ))
                  : _filteredBranches.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadBranches,
                          color: AppColors.primary,
                          child: ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: _filteredBranches.length,
                              itemBuilder: (context, index) {
                                final branch = _filteredBranches[index];
                                return _buildBranchCard(branch, canManage);
                              })),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (canAdd) {
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AddBranchScreen()))
                    .then((result) {
                  if (result == true) {
                    _loadBranches();
                  }
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('คุณไม่มีสิทธิ์ในการเพิ่มสาขา'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3)),
                );
              }
            },
            backgroundColor: AppColors.primary,
            child: Icon(Icons.add, color: Colors.white)),
        bottomNavigationBar: const AppBottomNav(currentIndex: 1));
  }

  Widget _buildEmptyState() {
    final canAdd = AuthService.getCurrentUser()?.isSuperAdmin ??
        AuthService.getCurrentUser()?.isAdmin ??
        false;

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
        Text(_searchQuery.isNotEmpty ? 'ไม่พบสาขาที่ค้นหา' : 'ยังไม่มีสาขา',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            )),
        SizedBox(height: 8),
        Text(
            _searchQuery.isNotEmpty
                ? 'ลองเปลี่ยนคำค้นหา หรือกรองสถานะ'
                : 'เริ่มต้นโดยการเพิ่มสาขาแรก',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            )),
        if (_searchQuery.isEmpty && canAdd)
          Padding(
              padding: EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AddBranchScreen()));
                  if (result == true) {
                    await _loadBranches();
                  }
                },
                icon: Icon(Icons.add),
                label: Text('เพิ่มสาขาใหม่'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              )),
      ],
    ));
  }

  Widget _buildBranchCard(Map<String, dynamic> branch, bool canManage) {
    final status = branch['branch_status'] ?? 'active';
    final statusColor = _getStatusColor(status);
    final hasImage = branch['branch_image'] != null &&
        branch['branch_image'].toString().isNotEmpty;

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
                  builder: (context) => BranchDetailScreen(branch: branch)),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  // รูปปกสาขา
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Builder(builder: (context) {
                          final bytes = _getDecodedImage(branch);
                          if (bytes == null) return _imageFallback();
                          final screenWidth =
                              MediaQuery.of(context).size.width *
                                  MediaQuery.of(context).devicePixelRatio;
                          return Image.memory(bytes,
                              fit: BoxFit.cover,
                              cacheWidth: screenWidth.toInt(),
                              filterQuality: FilterQuality.low,
                              errorBuilder: (context, error, stackTrace) {
                            return _imageFallback();
                          });
                        })),
                  ), // ไล่เฉดมืดด้านล่างเพื่อให้ตัวอักษรอ่านง่าย
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
                      )),
                    )),
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
                            child: Text(branch['branch_name'] ?? 'ไม่มีชื่อ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 6,
                                        color: Colors.black54,
                                        offset: Offset(0, 1))
                                  ],
                                )),
                          ),
                          const SizedBox(width: 8),
                          _pill(
                            _getStatusText(status),
                            bg: statusColor.withOpacity(.15),
                            fg: statusColor,
                          ),
                        ],
                      )),

                  // เมนูจัดการ (มุมขวาบน)
                  if (canManage)
                    Positioned(
                        right: 6,
                        top: 6,
                        child: Material(
                          type: MaterialType.transparency,
                          child: PopupMenuButton<String>(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) async {
                                switch (value) {
                                  case 'edit':
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              EditBranchScreen(branch: branch)),
                                    );
                                    if (result == true) await _loadBranches();
                                    break;
                                  case 'toggle_status':
                                    await _toggleBranchStatus(
                                        branch['branch_id'], status);
                                    break;
                                  case 'delete':
                                    await _deleteBranch(branch['branch_id'],
                                        branch['branch_name']);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: const [
                                            Icon(Icons.edit,
                                                size: 20, color: Colors.green),
                                            SizedBox(width: 8),
                                            Text('แก้ไขสาขา',
                                                style: TextStyle(
                                                    color: Colors.green)),
                                          ],
                                        )),
                                    PopupMenuItem(
                                        value: 'toggle_status',
                                        child: Row(
                                          children: [
                                            Icon(
                                              status == 'active'
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              size: 20,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(status == 'active'
                                                ? 'ปิดใช้งาน'
                                                : 'เปิดใช้งาน'),
                                          ],
                                        )),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: const [
                                            Icon(Icons.delete,
                                                size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('ลบสาขา',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        )),
                                  ],
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white)),
                        )),
                ],
              ),

              // ========= Content =========
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _iconText(
                        Icons.location_on,
                        branch['branch_address'] ?? 'ไม่มีที่อยู่',
                        color: Colors.grey[700],
                        iconSize: 18,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      _iconText(
                        Icons.phone,
                        branch['branch_phone'] ?? 'ไม่มีเบอร์โทร',
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 8),
                      _iconText(
                        Icons.person,
                        'เจ้าของ: ${branch['owner_name'] ?? 'ไม่ระบุ'}',
                        color: Colors.grey[700],
                      ),

                      if (branch['description'] != null &&
                          branch['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          branch['description'],
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1),

                      // ========= Footer =========
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                    'อัพเดท: ${_formatDate(branch['updated_at'])}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    )),
                              ),
                              Icon(Icons.arrow_forward_ios,
                                  size: 16, color: Colors.grey[400]),
                            ],
                          )),
                    ],
                  )),
            ],
          )),
    );
  }

// ---------- Helpers (ถ้ายังไม่มีในไฟล์ ให้วางเพิ่มได้เลย) ----------

  Widget _imageFallback() {
    return Container(
        height: 180,
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 6),
            Text('ไม่มีรูปสาขา',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ));
  }

  Widget _pill(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withOpacity(.25))),
      child: Text(text,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )),
    );
  }

  Widget _iconText(
    IconData icon,
    String text, {
    Color? color,
    double iconSize = 16,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: iconSize, color: color ?? Colors.grey[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? Colors.grey[700],
                fontSize: 14,
              )),
        ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'ไม่ทราบ';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'ไม่ทราบ';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
