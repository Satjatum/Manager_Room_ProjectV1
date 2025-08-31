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
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedPriority = 'all';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();

      late List<dynamic> response;

      if (currentUser?.isSuperAdmin == true) {
        // Super Admin เห็นทุกปัญหา
        response = await supabase
            .from('issues_detailed')
            .select('*')
            .order('reported_date', ascending: false);
      } else if (currentUser?.isAdmin == true || currentUser?.isUser == true) {
        // Admin และ User เห็นเฉพาะปัญหาในสาขาของตน
        response = await supabase
            .from('issues_detailed')
            .select('*')
            .eq('branch_id', currentUser!.branchId!)
            .order('reported_date', ascending: false);
      } else {
        response = [];
      }

      setState(() {
        _issues = List<Map<String, dynamic>>.from(response);
        _applyFilters();
      });
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _issues;

    // กรองตามสถานะ tab
    String tabStatus = _getStatusFromTab(_tabController.index);
    if (tabStatus != 'all') {
      filtered = filtered
          .where((issue) => issue['issue_status'] == tabStatus)
          .toList();
    }

    // กรองตาม priority
    if (_selectedPriority != 'all') {
      filtered = filtered
          .where((issue) => issue['issue_priority'] == _selectedPriority)
          .toList();
    }

    // กรองตาม category
    if (_selectedCategory != 'all') {
      filtered = filtered
          .where((issue) => issue['issue_category'] == _selectedCategory)
          .toList();
    }

    setState(() {
      _filteredIssues = filtered;
    });
  }

  String _getStatusFromTab(int index) {
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

  Future<void> _updateIssueStatus(String issueId, String newStatus,
      {String? notes}) async {
    try {
      final currentUser = AuthService.getCurrentUser();
      final now = DateTime.now().toIso8601String();

      Map<String, dynamic> updateData = {
        'issue_status': newStatus,
        'updated_at': now,
      };

      // อัปเดตฟิลด์เพิ่มเติมตามสถานะ
      switch (newStatus) {
        case 'acknowledged':
          updateData['acknowledged_date'] = now;
          updateData['assigned_to'] = currentUser!.userId;
          break;
        case 'in_progress':
          updateData['started_date'] = now;
          if (updateData['assigned_to'] == null) {
            updateData['assigned_to'] = currentUser!.userId;
          }
          break;
        case 'resolved':
          updateData['resolved_date'] = now;
          updateData['resolved_by'] = currentUser!.userId;
          if (notes != null) {
            updateData['resolution_notes'] = notes;
          }
          break;
        case 'closed':
          updateData['closed_date'] = now;
          break;
      }

      // อัปเดตในฐานข้อมูล
      await supabase.from('issues').update(updateData).eq('issue_id', issueId);

      // เพิ่ม update record
      await supabase.from('issue_updates').insert({
        'issue_id': issueId,
        'updated_by': currentUser!.userId,
        'update_type': 'status_change',
        'new_status': newStatus,
        'update_message':
            notes ?? 'เปลี่ยนสถานะเป็น ${_getStatusText(newStatus)}',
        'created_at': now,
      });

      _showSuccessSnackBar('อัปเดตสถานะสำเร็จ');
      _loadIssues(); // โหลดข้อมูลใหม่
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการอัปเดต: $e');
    }
  }

  void _showIssueDetails(Map<String, dynamic> issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildIssueDetailsSheet(issue),
    );
  }

  void _showUpdateDialog(Map<String, dynamic> issue) {
    String selectedStatus = issue['issue_status'];
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('อัปเดตสถานะปัญหา'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ปัญหา: ${issue['issue_title']}'),
              SizedBox(height: 16),
              Text('สถานะปัจจุบัน: ${_getStatusText(issue['issue_status'])}'),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'สถานะใหม่',
                  border: OutlineInputBorder(),
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
                  selectedStatus = value!;
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'หมายเหตุ (ไม่บังคับ)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
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
            child: Text('อัปเดต'),
          ),
        ],
      ),
    );
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
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการปัญหา'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadIssues,
            icon: Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: null,
                child: Text('ประเภท'),
                enabled: false,
              ),
              PopupMenuItem<String>(
                value: 'category_all',
                child: Text('ทั้งหมด'),
              ),
              PopupMenuItem<String>(
                value: 'category_plumbing',
                child: Text('น้ำ/ประปา'),
              ),
              PopupMenuItem<String>(
                value: 'category_electrical',
                child: Text('ไฟฟ้า'),
              ),
              PopupMenuItem<String>(
                value: 'category_maintenance',
                child: Text('ซ่อมบำรุง'),
              ),
              PopupMenuItem<String>(
                value: 'category_cleaning',
                child: Text('ความสะอาด'),
              ),
              PopupMenuItem<String>(
                value: 'category_other',
                child: Text('อื่นๆ'),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: null,
                child: Text('ความเร่งด่วน'),
                enabled: false,
              ),
              PopupMenuItem<String>(
                value: 'priority_all',
                child: Text('ทั้งหมด'),
              ),
              PopupMenuItem<String>(
                value: 'priority_urgent',
                child: Text('ด่วนมาก'),
              ),
              PopupMenuItem<String>(
                value: 'priority_high',
                child: Text('สูง'),
              ),
              PopupMenuItem<String>(
                value: 'priority_normal',
                child: Text('ปกติ'),
              ),
              PopupMenuItem<String>(
                value: 'priority_low',
                child: Text('ต่ำ'),
              ),
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (index) => _applyFilters(),
          tabs: [
            Tab(text: 'ทั้งหมด (${_issues.length})'),
            Tab(
                text:
                    'รอตอบรับ (${_issues.where((i) => i['issue_status'] == 'reported').length})'),
            Tab(
                text:
                    'รับทราบ (${_issues.where((i) => i['issue_status'] == 'acknowledged').length})'),
            Tab(
                text:
                    'ดำเนินการ (${_issues.where((i) => i['issue_status'] == 'in_progress').length})'),
            Tab(
                text:
                    'เสร็จสิ้น (${_issues.where((i) => i['issue_status'] == 'resolved').length})'),
            Tab(
                text:
                    'ปิดงาน (${_issues.where((i) => i['issue_status'] == 'closed').length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: List.generate(6, (index) => _buildIssuesList()),
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildIssuesList() {
    if (_filteredIssues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'ไม่มีปัญหาในหมวดนี้',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadIssues,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _filteredIssues.length,
        itemBuilder: (context, index) {
          final issue = _filteredIssues[index];
          return _buildIssueCard(issue);
        },
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final reportedDate = DateTime.parse(issue['reported_date']);
    final priority = issue['issue_priority'];
    final status = issue['issue_status'];
    final hoursElapsed = issue['hours_elapsed']?.toDouble() ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showIssueDetails(issue),
        borderRadius: BorderRadius.circular(8),
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
                          issue['issue_title'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            _buildPriorityBadge(priority),
                            SizedBox(width: 8),
                            _buildCategoryBadge(issue['issue_category']),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),

              SizedBox(height: 12),

              // Details
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text('${issue['tenant_full_name']}',
                      style: TextStyle(fontSize: 12)),
                  SizedBox(width: 12),
                  Icon(Icons.home, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text('ห้อง ${issue['room_number']}',
                      style: TextStyle(fontSize: 12)),
                ],
              ),

              SizedBox(height: 8),

              Text(
                issue['issue_description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),

              SizedBox(height: 12),

              // Footer
              Row(
                children: [
                  Text(
                    '${reportedDate.day}/${reportedDate.month}/${reportedDate.year} ${reportedDate.hour.toString().padLeft(2, '0')}:${reportedDate.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '(${hoursElapsed.toInt()} ชม.)',
                    style: TextStyle(
                      fontSize: 12,
                      color: hoursElapsed > 24 ? Colors.red : Colors.grey[600],
                    ),
                  ),
                  Spacer(),
                  if (issue['assigned_to_name'] != null) ...[
                    Icon(Icons.person_pin, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      issue['assigned_to_name'],
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                  SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showUpdateDialog(issue),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'อัปเดต',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    String text;

    switch (priority) {
      case 'urgent':
        color = Colors.red;
        text = 'ด่วนมาก';
        break;
      case 'high':
        color = Colors.orange;
        text = 'สูง';
        break;
      case 'normal':
        color = Colors.blue;
        text = 'ปกติ';
        break;
      case 'low':
        color = Colors.green;
        text = 'ต่ำ';
        break;
      default:
        color = Colors.grey;
        text = priority;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    IconData icon;
    String text;

    switch (category) {
      case 'plumbing':
        icon = Icons.plumbing;
        text = 'น้ำ/ประปา';
        break;
      case 'electrical':
        icon = Icons.electrical_services;
        text = 'ไฟฟ้า';
        break;
      case 'cleaning':
        icon = Icons.cleaning_services;
        text = 'ความสะอาด';
        break;
      case 'maintenance':
        icon = Icons.build;
        text = 'ซ่อมบำรุง';
        break;
      case 'security':
        icon = Icons.security;
        text = 'ความปลอดภัย';
        break;
      default:
        icon = Icons.help_outline;
        text = 'อื่นๆ';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        SizedBox(width: 2),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'reported':
        color = Colors.orange;
        text = 'รอตอบรับ';
        break;
      case 'acknowledged':
        color = Colors.blue;
        text = 'รับทราบ';
        break;
      case 'in_progress':
        color = Colors.purple;
        text = 'ดำเนินการ';
        break;
      case 'resolved':
        color = Colors.green;
        text = 'เสร็จสิ้น';
        break;
      case 'closed':
        color = Colors.grey;
        text = 'ปิดงาน';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildIssueDetailsSheet(Map<String, dynamic> issue) {
    final images = issue['issue_images'] != null
        ? List<String>.from(jsonDecode(issue['issue_images']))
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
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'รายละเอียดปัญหา',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          issue['issue_title'],
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 8),
                      _buildStatusBadge(issue['issue_status']),
                    ],
                  ),

                  SizedBox(height: 8),

                  Row(
                    children: [
                      _buildPriorityBadge(issue['issue_priority']),
                      SizedBox(width: 8),
                      _buildCategoryBadge(issue['issue_category']),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Reporter Info
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ข้อมูลผู้รายงาน',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        SizedBox(height: 8),
                        Text('ชื่อ: ${issue['tenant_full_name']}'),
                        Text('เบอร์โทร: ${issue['tenant_phone']}'),
                        Text(
                            'ห้อง: ${issue['room_number']} - ${issue['room_name']}'),
                        Text('สาขา: ${issue['branch_name']}'),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Description
                  Text('รายละเอียดปัญหา',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(issue['issue_description']),

                  SizedBox(height: 16),

                  // Images
                  if (images.isNotEmpty) ...[
                    Text('รูปภาพแนบ',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(images[index]),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Timeline
                  Text('ประวัติการดำเนินการ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _buildTimeline(issue),

                  SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showUpdateDialog(issue);
                      },
                      child: Text('อัปเดตสถานะ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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

  Widget _buildTimeline(Map<String, dynamic> issue) {
    List<Map<String, dynamic>> timeline = [];

    timeline.add({
      'date': issue['reported_date'],
      'status': 'reported',
      'title': 'รายงานปัญหา',
      'user': issue['reported_by_name'],
    });

    if (issue['acknowledged_date'] != null) {
      timeline.add({
        'date': issue['acknowledged_date'],
        'status': 'acknowledged',
        'title': 'รับทราบปัญหา',
        'user': issue['assigned_to_name'],
      });
    }

    if (issue['started_date'] != null) {
      timeline.add({
        'date': issue['started_date'],
        'status': 'in_progress',
        'title': 'เริ่มดำเนินการ',
        'user': issue['assigned_to_name'],
      });
    }

    if (issue['resolved_date'] != null) {
      timeline.add({
        'date': issue['resolved_date'],
        'status': 'resolved',
        'title': 'แก้ไขเสร็จสิ้น',
        'user': issue['resolved_by_name'],
      });
    }

    if (issue['closed_date'] != null) {
      timeline.add({
        'date': issue['closed_date'],
        'status': 'closed',
        'title': 'ปิดงาน',
        'user': issue['resolved_by_name'],
      });
    }

    return Column(
      children: timeline.map((item) {
        final date = DateTime.parse(item['date']);
        return Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(item['status']),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (item['user'] != null)
                      Text(
                        'โดย: ${item['user']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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
