import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';

class IssueManagementScreen extends StatefulWidget {
  const IssueManagementScreen({Key? key}) : super(key: key);

  @override
  State<IssueManagementScreen> createState() => _IssueManagementScreenState();
}

class _IssueManagementScreenState extends State<IssueManagementScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController _tabController;
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _filteredIssues = [];
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedPriority = 'all';
  String _selectedCategory = 'all';
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      // Add safety check for tab changes
      // if (_tabController.hasClients && _tabController.index >= 0) {
      //   _applyFilters();
      // }
    });
    _loadBranches();
    _loadIssues();
  }

  Future<void> _loadBranches() async {
    try {
      final currentUser = AuthService.getCurrentUser();

      if (currentUser?.isSuperAdmin == true) {
        final response = await supabase
            .from('branches')
            .select('branch_id, branch_name')
            .eq('branch_status', 'active')
            .order('branch_name');

        if (mounted) {
          setState(() {
            _branches = List<Map<String, dynamic>>.from(response ?? []);
          });
        }
      }
    } catch (e) {
      print('Error loading branches: $e');
      if (mounted) {
        setState(() {
          _branches = [];
        });
      }
    }
  }

  Future<void> _loadIssues() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();
      late List<dynamic> response;

      if (currentUser?.isSuperAdmin == true) {
        if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty) {
          response = await supabase
              .from('issues_detailed')
              .select('*')
              .eq('branch_id', _selectedBranchId!)
              .order('reported_date', ascending: false);
        } else {
          response = await supabase
              .from('issues_detailed')
              .select('*')
              .order('reported_date', ascending: false);
        }
      } else if (currentUser?.isAdmin == true || currentUser?.isUser == true) {
        if (currentUser!.branchId != null) {
          response = await supabase
              .from('issues_detailed')
              .select('*')
              .eq('branch_id', currentUser.branchId!)
              .order('reported_date', ascending: false);
        } else {
          response = [];
        }
      } else {
        response = [];
      }

      if (mounted) {
        setState(() {
          _issues = List<Map<String, dynamic>>.from(response ?? []);
          _applyFilters();
        });
      }
    } catch (e) {
      print('Error loading issues: $e');
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
        setState(() {
          _issues = [];
          _filteredIssues = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    if (!mounted || _issues.isEmpty) {
      setState(() {
        _filteredIssues = [];
      });
      return;
    }

    try {
      List<Map<String, dynamic>> filtered = List.from(_issues);

      // Filter by tab status
      String tabStatus = _getStatusFromTab(_tabController.index);
      if (tabStatus != 'all') {
        filtered = filtered
            .where((issue) =>
                issue != null &&
                issue.containsKey('issue_status') &&
                issue['issue_status'] == tabStatus)
            .toList();
      }

      // Filter by priority
      if (_selectedPriority != 'all') {
        filtered = filtered
            .where((issue) =>
                issue != null &&
                issue.containsKey('issue_priority') &&
                issue['issue_priority'] == _selectedPriority)
            .toList();
      }

      // Filter by category
      if (_selectedCategory != 'all') {
        filtered = filtered
            .where((issue) =>
                issue != null &&
                issue.containsKey('issue_category') &&
                issue['issue_category'] == _selectedCategory)
            .toList();
      }

      if (mounted) {
        setState(() {
          _filteredIssues = filtered;
        });
      }
    } catch (e) {
      print('Error applying filters: $e');
      if (mounted) {
        setState(() {
          _filteredIssues = [];
        });
      }
    }
  }

  String _getStatusFromTab(int index) {
    if (index < 0 || index >= 6) return 'all';

    switch (index) {
      case 0:
        return 'all';
      case 1:
        return 'reported';
      case 2:
        return 'acknowledged';
      case 3:
        return 'in_progress';
      case 4:
        return 'resolved';
      case 5:
        return 'closed';
      default:
        return 'all';
    }
  }

  int _getIssueCountByStatus(String status) {
    if (_issues.isEmpty) return 0;

    try {
      if (status == 'all') return _issues.length;
      return _issues
          .where((issue) =>
              issue != null &&
              issue.containsKey('issue_status') &&
              issue['issue_status'] == status)
          .length;
    } catch (e) {
      print('Error counting issues: $e');
      return 0;
    }
  }

  Future<void> _updateIssueStatus(String issueId, String newStatus,
      {String? notes}) async {
    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) {
        _showErrorSnackBar('ไม่พบข้อมูลผู้ใช้');
        return;
      }

      final now = DateTime.now().toIso8601String();

      Map<String, dynamic> updateData = {
        'issue_status': newStatus,
        'updated_at': now,
      };

      switch (newStatus) {
        case 'acknowledged':
          updateData['acknowledged_date'] = now;
          updateData['assigned_to'] = currentUser.userId;
          break;
        case 'in_progress':
          updateData['started_date'] = now;
          if (updateData['assigned_to'] == null) {
            updateData['assigned_to'] = currentUser.userId;
          }
          break;
        case 'resolved':
          updateData['resolved_date'] = now;
          updateData['resolved_by'] = currentUser.userId;
          if (notes != null && notes.isNotEmpty) {
            updateData['resolution_notes'] = notes;
          }
          break;
        case 'closed':
          updateData['closed_date'] = now;
          break;
      }

      await supabase.from('issues').update(updateData).eq('issue_id', issueId);

      await supabase.from('issue_updates').insert({
        'issue_id': issueId,
        'updated_by': currentUser.userId,
        'update_type': 'status_change',
        'new_status': newStatus,
        'update_message':
            notes ?? 'เปลี่ยนสถานะเป็น ${_getStatusText(newStatus)}',
        'created_at': now,
      });

      _showSuccessSnackBar('อัปเดตสถานะสำเร็จ');
      _loadIssues();
    } catch (e) {
      print('Error updating issue status: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการอัปเดต: $e');
    }
  }

  void _showIssueDetails(Map<String, dynamic> issue) {
    if (issue == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildIssueDetailsSheet(issue),
    );
  }

  void _showUpdateDialog(Map<String, dynamic> issue) {
    if (issue == null || !issue.containsKey('issue_status')) return;

    String selectedStatus = issue['issue_status'] ?? 'reported';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Text('อัปเดตสถานะปัญหา', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ปัญหา:',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600])),
                    SizedBox(height: 4),
                    Text(issue['issue_title'] ?? 'ไม่ระบุ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('สถานะปัจจุบัน:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      _getStatusColor(issue['issue_status']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _getStatusColor(issue['issue_status'])
                          .withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle,
                        size: 8, color: _getStatusColor(issue['issue_status'])),
                    SizedBox(width: 8),
                    Text(_getStatusText(issue['issue_status'])),
                  ],
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'สถานะใหม่',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'reported', child: Text('รอการตอบรับ')),
                  DropdownMenuItem(
                      value: 'acknowledged', child: Text('รับทราบแล้ว')),
                  DropdownMenuItem(
                      value: 'in_progress', child: Text('กำลังดำเนินการ')),
                  DropdownMenuItem(
                      value: 'resolved', child: Text('แก้ไขเสร็จสิ้น')),
                  DropdownMenuItem(value: 'closed', child: Text('ปิดงาน')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    selectedStatus = value;
                  }
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'หมายเหตุ (ไม่บังคับ)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.note_add),
                  hintText: 'เพิ่มรายละเอียดการอัปเดต...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateIssueStatus(
                issue['issue_id'],
                selectedStatus,
                notes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('อัปเดต'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _safeWidget(Widget Function() builder) {
    try {
      return builder();
    } catch (e) {
      print('Widget building error: $e');
      return Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('เกิดข้อผิดพลาดในการแสดงผล',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.getCurrentUser();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title:
            Text('จัดการปัญหา', style: TextStyle(fontWeight: FontWeight.bold)),
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
        actions: [
          if (currentUser?.isSuperAdmin == true && _branches.isNotEmpty) ...[
            Container(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBranchId,
                  hint: Text('เลือกสาขา',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                  dropdownColor: AppColors.primary,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('ทุกสาขา',
                          style: TextStyle(color: Colors.white)),
                    ),
                    ..._branches
                        .map((branch) => DropdownMenuItem<String>(
                              value: branch['branch_id'],
                              child: Text(branch['branch_name'] ?? '',
                                  style: TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBranchId = value;
                    });
                    _loadIssues();
                  },
                ),
              ),
            ),
          ],
          IconButton(
            onPressed: _loadIssues,
            icon: Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: 'ตัวกรอง',
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.category, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('ประเภท',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                enabled: false,
              ),
              PopupMenuItem<String>(
                  value: 'category_all', child: Text('ทั้งหมด')),
              PopupMenuItem<String>(
                  value: 'category_plumbing', child: Text('🔧 น้ำ/ประปา')),
              PopupMenuItem<String>(
                  value: 'category_electrical', child: Text('⚡ ไฟฟ้า')),
              PopupMenuItem<String>(
                  value: 'category_maintenance', child: Text('🛠️ ซ่อมบำรุง')),
              PopupMenuItem<String>(
                  value: 'category_cleaning', child: Text('🧹 ความสะอาด')),
              PopupMenuItem<String>(
                  value: 'category_other', child: Text('📋 อื่นๆ')),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.priority_high, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('ความเร่งด่วน',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                enabled: false,
              ),
              PopupMenuItem<String>(
                  value: 'priority_all', child: Text('ทั้งหมด')),
              PopupMenuItem<String>(
                  value: 'priority_urgent', child: Text('🔴 ด่วนมาก')),
              PopupMenuItem<String>(
                  value: 'priority_high', child: Text('🟠 สูง')),
              PopupMenuItem<String>(
                  value: 'priority_normal', child: Text('🔵 ปกติ')),
              PopupMenuItem<String>(
                  value: 'priority_low', child: Text('🟢 ต่ำ')),
            ],
            onSelected: (String? value) {
              if (value != null) {
                if (value.startsWith('category_')) {
                  setState(() {
                    _selectedCategory = value.replaceFirst('category_', '');
                  });
                } else if (value.startsWith('priority_')) {
                  setState(() {
                    _selectedPriority = value.replaceFirst('priority_', '');
                  });
                }
                _applyFilters();
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: _safeWidget(() => TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  onTap: (index) => _applyFilters(),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: 'ทั้งหมด (${_getIssueCountByStatus('all')})'),
                    Tab(
                        text:
                            'รอตอบรับ (${_getIssueCountByStatus('reported')})'),
                    Tab(
                        text:
                            'รับทราบ (${_getIssueCountByStatus('acknowledged')})'),
                    Tab(
                        text:
                            'ดำเนินการ (${_getIssueCountByStatus('in_progress')})'),
                    Tab(
                        text:
                            'เสร็จสิ้น (${_getIssueCountByStatus('resolved')})'),
                    Tab(text: 'ปิดงาน (${_getIssueCountByStatus('closed')})'),
                  ],
                )),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('กำลังโหลดข้อมูล...',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          : _safeWidget(() => TabBarView(
                controller: _tabController,
                children: List.generate(6, (index) => _buildIssuesList()),
              )),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildIssuesList() {
    if (_filteredIssues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_outlined,
                  size: 64, color: Colors.grey[400]),
            ),
            SizedBox(height: 24),
            Text(
              'ไม่มีปัญหาในหมวดนี้',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'เมื่อมีการรายงานปัญหา จะแสดงในที่นี่',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadIssues,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _filteredIssues.length,
        itemBuilder: (context, index) {
          if (index >= _filteredIssues.length) return Container();
          final issue = _filteredIssues[index];
          if (issue == null) return Container();
          return _buildIssueCard(issue);
        },
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    if (issue == null) return Container();

    try {
      final reportedDate = issue['reported_date'] != null
          ? DateTime.parse(issue['reported_date'])
          : DateTime.now();
      final priority = issue['issue_priority'] ?? 'normal';
      final status = issue['issue_status'] ?? 'reported';
      final hoursElapsed = (issue['hours_elapsed'] as num?)?.toDouble() ?? 0;

      return Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showIssueDetails(issue),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              issue['issue_title'] ?? 'ไม่ระบุหัวข้อ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                _buildPriorityBadge(priority),
                                SizedBox(width: 8),
                                _buildCategoryBadge(
                                    issue['issue_category'] ?? 'other'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      _buildStatusBadge(status),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Details
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person,
                                size: 16, color: Colors.grey[600]),
                            SizedBox(width: 6),
                            Text('${issue['tenant_full_name'] ?? 'ไม่ระบุ'}',
                                style: TextStyle(fontSize: 13)),
                            SizedBox(width: 16),
                            Icon(Icons.home, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 6),
                            Text('ห้อง ${issue['room_number'] ?? 'ไม่ระบุ'}',
                                style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        if (issue['branch_name'] != null) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.business,
                                  size: 16, color: Colors.grey[600]),
                              SizedBox(width: 6),
                              Text('${issue['branch_name']}',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 12),

                  Text(
                    issue['issue_description'] ?? 'ไม่มีรายละเอียด',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], height: 1.4),
                  ),

                  SizedBox(height: 16),

                  // Footer
                  Row(
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${reportedDate.day}/${reportedDate.month}/${reportedDate.year} ${reportedDate.hour.toString().padLeft(2, '0')}:${reportedDate.minute.toString().padLeft(2, '0')}',
                          style:
                              TextStyle(fontSize: 11, color: Colors.blue[700]),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: hoursElapsed > 24
                              ? Colors.red[50]
                              : Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${hoursElapsed.toInt()} ชม.',
                          style: TextStyle(
                            fontSize: 11,
                            color: hoursElapsed > 24
                                ? Colors.red[700]
                                : Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Spacer(),
                      if (issue['assigned_to_name'] != null) ...[
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_pin,
                                  size: 14, color: Colors.green[700]),
                              SizedBox(width: 4),
                              Text(
                                issue['assigned_to_name'],
                                style: TextStyle(
                                    fontSize: 11, color: Colors.green[700]),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                      ],
                      Material(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _showUpdateDialog(issue),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit,
                                    size: 14, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'อัปเดต',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error building issue card: $e');
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Text('เกิดข้อผิดพลาดในการแสดงข้อมูล'),
      );
    }
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    String text;
    IconData icon;

    switch (priority) {
      case 'urgent':
        color = Colors.red;
        text = 'ด่วนมาก';
        icon = Icons.priority_high;
        break;
      case 'high':
        color = Colors.orange;
        text = 'สูง';
        icon = Icons.keyboard_arrow_up;
        break;
      case 'normal':
        color = Colors.blue;
        text = 'ปกติ';
        icon = Icons.remove;
        break;
      case 'low':
        color = Colors.green;
        text = 'ต่ำ';
        icon = Icons.keyboard_arrow_down;
        break;
      default:
        color = Colors.grey;
        text = priority;
        icon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    IconData icon;
    String text;
    Color color;

    switch (category) {
      case 'plumbing':
        icon = Icons.plumbing;
        text = 'น้ำ/ประปา';
        color = Colors.blue;
        break;
      case 'electrical':
        icon = Icons.electrical_services;
        text = 'ไฟฟ้า';
        color = Colors.amber;
        break;
      case 'cleaning':
        icon = Icons.cleaning_services;
        text = 'ความสะอาด';
        color = Colors.teal;
        break;
      case 'maintenance':
        icon = Icons.build;
        text = 'ซ่อมบำรุง';
        color = Colors.orange;
        break;
      case 'security':
        icon = Icons.security;
        text = 'ความปลอดภัย';
        color = Colors.red;
        break;
      default:
        icon = Icons.help_outline;
        text = 'อื่นๆ';
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withOpacity(0.8)),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'reported':
        color = Colors.orange;
        text = 'รอตอบรับ';
        icon = Icons.schedule;
        break;
      case 'acknowledged':
        color = Colors.blue;
        text = 'รับทราบ';
        icon = Icons.visibility;
        break;
      case 'in_progress':
        color = Colors.purple;
        text = 'ดำเนินการ';
        icon = Icons.settings;
        break;
      case 'resolved':
        color = Colors.green;
        text = 'เสร็จสิ้น';
        icon = Icons.check_circle;
        break;
      case 'closed':
        color = Colors.grey;
        text = 'ปิดงาน';
        icon = Icons.lock;
        break;
      default:
        color = Colors.grey;
        text = status;
        icon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueDetailsSheet(Map<String, dynamic> issue) {
    if (issue == null) return Container();

    final images = issue['issue_images'] != null
        ? (issue['issue_images'] is String
            ? List<String>.from(jsonDecode(issue['issue_images']))
            : <String>[])
        : <String>[];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.assignment, color: AppColors.primary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'รายละเอียดปัญหา',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    padding: EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          issue['issue_title'] ?? 'ไม่ระบุหัวข้อ',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 12),
                      _buildStatusBadge(issue['issue_status'] ?? 'reported'),
                    ],
                  ),

                  SizedBox(height: 12),

                  Row(
                    children: [
                      _buildPriorityBadge(issue['issue_priority'] ?? 'normal'),
                      SizedBox(width: 8),
                      _buildCategoryBadge(issue['issue_category'] ?? 'other'),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Reporter Info
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('ข้อมูลผู้รายงาน',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildInfoRow(Icons.badge, 'ชื่อ',
                            '${issue['tenant_full_name'] ?? 'ไม่ระบุ'}'),
                        _buildInfoRow(Icons.phone, 'เบอร์โทร',
                            '${issue['tenant_phone'] ?? 'ไม่ระบุ'}'),
                        _buildInfoRow(Icons.home, 'ห้อง',
                            '${issue['room_number'] ?? 'ไม่ระบุ'} - ${issue['room_name'] ?? 'ไม่ระบุ'}'),
                        _buildInfoRow(Icons.business, 'สาขา',
                            '${issue['branch_name'] ?? 'ไม่ระบุ'}'),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Description
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Text('รายละเอียดปัญหา',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.blue[700])),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          issue['issue_description'] ?? 'ไม่มีรายละเอียด',
                          style: TextStyle(height: 1.5, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Images
                  if (images.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.photo_library,
                                  color: Colors.green[700]),
                              SizedBox(width: 8),
                              Text('รูปภาพแนบ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.green[700])),
                            ],
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                if (index >= images.length) return Container();
                                try {
                                  return Container(
                                    margin: EdgeInsets.only(right: 12),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(images[index]),
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            width: 120,
                                            height: 120,
                                            color: Colors.grey[300],
                                            child: Icon(Icons.error),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  return Container(
                                    width: 120,
                                    height: 120,
                                    margin: EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.broken_image),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                  ],

                  // Timeline
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timeline, color: Colors.purple[700]),
                            SizedBox(width: 8),
                            Text('ประวัติการดำเนินการ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.purple[700])),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildTimeline(issue),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showUpdateDialog(issue);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('อัปเดตสถานะ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Map<String, dynamic> issue) {
    List<Map<String, dynamic>> timeline = [];

    try {
      if (issue['reported_date'] != null) {
        timeline.add({
          'date': issue['reported_date'],
          'status': 'reported',
          'title': 'รายงานปัญหา',
          'user': issue['reported_by_name'] ?? 'ไม่ระบุ',
          'icon': Icons.report_problem,
        });
      }

      if (issue['acknowledged_date'] != null) {
        timeline.add({
          'date': issue['acknowledged_date'],
          'status': 'acknowledged',
          'title': 'รับทราบปัญหา',
          'user': issue['assigned_to_name'] ?? 'ไม่ระบุ',
          'icon': Icons.visibility,
        });
      }

      if (issue['started_date'] != null) {
        timeline.add({
          'date': issue['started_date'],
          'status': 'in_progress',
          'title': 'เริ่มดำเนินการ',
          'user': issue['assigned_to_name'] ?? 'ไม่ระบุ',
          'icon': Icons.play_arrow,
        });
      }

      if (issue['resolved_date'] != null) {
        timeline.add({
          'date': issue['resolved_date'],
          'status': 'resolved',
          'title': 'แก้ไขเสร็จสิ้น',
          'user': issue['resolved_by_name'] ?? 'ไม่ระบุ',
          'icon': Icons.check_circle,
        });
      }

      if (issue['closed_date'] != null) {
        timeline.add({
          'date': issue['closed_date'],
          'status': 'closed',
          'title': 'ปิดงาน',
          'user': issue['resolved_by_name'] ?? 'ไม่ระบุ',
          'icon': Icons.lock,
        });
      }

      if (timeline.isEmpty) {
        return Text('ไม่มีข้อมูลประวัติ');
      }

      return Column(
        children: timeline.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == timeline.length - 1;

          try {
            final date = DateTime.parse(item['date']);

            return Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getStatusColor(item['status']),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item['icon'],
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                  ],
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'],
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (item['user'] != null && item['user'] != 'ไม่ระบุ')
                          Text(
                            'โดย: ${item['user']}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } catch (e) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('ข้อมูลไม่ถูกต้อง',
                  style: TextStyle(color: Colors.red[600])),
            );
          }
        }).toList(),
      );
    } catch (e) {
      return Text('เกิดข้อผิดพลาดในการแสดงประวัติ');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'reported':
        return Colors.orange;
      case 'acknowledged':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'reported':
        return 'รอตอบรับ';
      case 'acknowledged':
        return 'รับทราบแล้ว';
      case 'in_progress':
        return 'กำลังดำเนินการ';
      case 'resolved':
        return 'แก้ไขเสร็จสิ้น';
      case 'closed':
        return 'ปิดงาน';
      default:
        return status;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
