import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';

class TenantIssuesScreen extends StatefulWidget {
  const TenantIssuesScreen({Key? key}) : super(key: key);

  @override
  State<TenantIssuesScreen> createState() => _TenantIssuesScreenState();
}

class _TenantIssuesScreenState extends State<TenantIssuesScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController _tabController;
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _filteredIssues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTenantIssues();
  }

  Future<void> _loadTenantIssues() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser?.tenantId == null) {
        throw Exception('ไม่พบข้อมูลผู้เช่า');
      }

      final response = await supabase
          .from('issues_detailed')
          .select('*')
          .eq('tenant_id', currentUser!.tenantId!)
          .order('reported_date', ascending: false);

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

    String tabStatus = _getStatusFromTab(_tabController.index);
    if (tabStatus == 'active') {
      // แสดงปัญหาที่ยังไม่ได้ปิด
      filtered =
          filtered.where((issue) => issue['issue_status'] != 'closed').toList();
    } else if (tabStatus == 'completed') {
      // แสดงปัญหาที่แก้ไขเสร็จแล้วและปิดแล้ว
      filtered = filtered
          .where((issue) =>
              issue['issue_status'] == 'resolved' ||
              issue['issue_status'] == 'closed')
          .toList();
    } else if (tabStatus != 'all') {
      filtered = filtered
          .where((issue) => issue['issue_status'] == tabStatus)
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
        return 'active';
      case 2:
        return 'completed';
      case 3:
        return 'pending';
      default:
        return 'all';
    }
  }

  Future<void> _rateFeedback(String issueId) async {
    int rating = 5;
    final feedbackController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ให้คะแนนและความคิดเห็น'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ความพึงพอใจในการแก้ไขปัญหา'),
              SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () {
                          setDialogState(() {
                            rating = index + 1;
                          });
                        },
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  );
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'ความคิดเห็นเพิ่มเติม (ไม่บังคับ)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('ส่งความคิดเห็น'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await supabase.from('issues').update({
          'tenant_rating': rating,
          'tenant_feedback': feedbackController.text.trim().isEmpty
              ? null
              : feedbackController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('issue_id', issueId);

        _showSuccessSnackBar('ขอบคุณสำหรับความคิดเห็น');
        _loadTenantIssues();
      } catch (e) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการส่งความคิดเห็น: $e');
      }
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
        title: Text('ปัญหาของฉัน'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadTenantIssues,
            icon: Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => _applyFilters(),
          tabs: [
            Tab(text: 'ทั้งหมด (${_issues.length})'),
            Tab(
                text:
                    'กำลังดำเนินการ (${_issues.where((i) => i['issue_status'] != 'closed' && i['issue_status'] != 'resolved').length})'),
            Tab(
                text:
                    'เสร็จสิ้น (${_issues.where((i) => i['issue_status'] == 'resolved' || i['issue_status'] == 'closed').length})'),
            Tab(
                text:
                    'รอตอบรับ (${_issues.where((i) => i['issue_status'] == 'reported').length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: List.generate(4, (index) => _buildIssuesList()),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/report-issue')
              ?.then((_) => _loadTenantIssues());
        },
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: Colors.white),
      ),
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
            if (_tabController.index == 0) ...[
              SizedBox(height: 8),
              Text(
                'แตะปุ่ม + เพื่อรายงานปัญหาใหม่',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTenantIssues,
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
    final hasRating = issue['tenant_rating'] != null;

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
                        Text(
                          'รหัส: ${issue['issue_id'].toString().substring(0, 8)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),

              SizedBox(height: 8),

              Row(
                children: [
                  _buildPriorityBadge(priority),
                  SizedBox(width: 8),
                  _buildCategoryBadge(issue['issue_category']),
                ],
              ),

              SizedBox(height: 12),

              Text(
                issue['issue_description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),

              SizedBox(height: 12),

              // Progress Timeline
              _buildProgressIndicator(status),

              SizedBox(height: 12),

              // Footer
              Row(
                children: [
                  Text(
                    '${reportedDate.day}/${reportedDate.month}/${reportedDate.year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '(${hoursElapsed.toInt()} ชม.)',
                    style: TextStyle(
                      fontSize: 12,
                      color: hoursElapsed > 48 ? Colors.red : Colors.grey[600],
                    ),
                  ),
                  Spacer(),
                  if (issue['assigned_to_name'] != null) ...[
                    Icon(Icons.person_pin, size: 14, color: Colors.blue),
                    SizedBox(width: 2),
                    Text(
                      issue['assigned_to_name'],
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                    SizedBox(width: 8),
                  ],
                  if (status == 'resolved' && !hasRating) ...[
                    InkWell(
                      onTap: () => _rateFeedback(issue['issue_id']),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_outline,
                                size: 12, color: Colors.orange),
                            SizedBox(width: 2),
                            Text(
                              'ให้คะแนน',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (hasRating) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(
                          issue['tenant_rating'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(String status) {
    final steps = ['reported', 'acknowledged', 'in_progress', 'resolved'];
    final currentIndex = steps.indexOf(status);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final stepStatus = entry.value;
        final isActive = index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color:
                      isActive ? _getStatusColor(stepStatus) : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: isCurrent
                    ? Icon(Icons.radio_button_checked,
                        size: 12, color: Colors.white)
                    : isActive
                        ? Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isActive
                        ? _getStatusColor(stepStatus)
                        : Colors.grey[300],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
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
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'รหัส: ${issue['issue_id'].toString().substring(0, 8)}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Text(
                          'ห้อง ${issue['room_number']}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('รายละเอียดปัญหา',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(issue['issue_description']),
                  SizedBox(height: 16),
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
                  Text('ความคืบหน้า',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _buildDetailedTimeline(issue),
                  if (issue['resolution_notes'] != null) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Text('วิธีการแก้ไข',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(issue['resolution_notes']),
                        ],
                      ),
                    ),
                  ],
                  if (issue['tenant_rating'] != null) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              SizedBox(width: 8),
                              Text('คะแนนที่ให้: ${issue['tenant_rating']}/5',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                          if (issue['tenant_feedback'] != null) ...[
                            SizedBox(height: 8),
                            Text(issue['tenant_feedback']),
                          ],
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 20),
                  if (issue['issue_status'] == 'resolved' &&
                      issue['tenant_rating'] == null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _rateFeedback(issue['issue_id']);
                        },
                        icon: Icon(Icons.star_outline),
                        label: Text('ให้คะแนนและความคิดเห็น'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedTimeline(Map<String, dynamic> issue) {
    List<Map<String, dynamic>> timeline = [];

    timeline.add({
      'date': issue['reported_date'],
      'status': 'reported',
      'title': 'รายงานปัญหา',
      'description': 'คุณได้รายงานปัญหานี้เข้าสู่ระบบ',
      'icon': Icons.report_problem,
      'color': Colors.orange,
    });

    if (issue['acknowledged_date'] != null) {
      timeline.add({
        'date': issue['acknowledged_date'],
        'status': 'acknowledged',
        'title': 'รับทราบปัญหา',
        'description': 'ทีมงานได้รับทราบและกำลังเตรียมดำเนินการ',
        'icon': Icons.visibility,
        'color': Colors.blue,
      });
    }

    if (issue['started_date'] != null) {
      timeline.add({
        'date': issue['started_date'],
        'status': 'in_progress',
        'title': 'เริ่มดำเนินการ',
        'description': 'ทีมงานกำลังดำเนินการแก้ไขปัญหา',
        'icon': Icons.build,
        'color': Colors.purple,
      });
    }

    if (issue['resolved_date'] != null) {
      timeline.add({
        'date': issue['resolved_date'],
        'status': 'resolved',
        'title': 'แก้ไขเสร็จสิ้น',
        'description': 'ปัญหาได้รับการแก้ไขเรียบร้อยแล้ว',
        'icon': Icons.check_circle,
        'color': Colors.green,
      });
    }

    if (issue['closed_date'] != null) {
      timeline.add({
        'date': issue['closed_date'],
        'status': 'closed',
        'title': 'ปิดงาน',
        'description': 'งานนี้ได้ถูกปิดเรียบร้อยแล้ว',
        'icon': Icons.flag,
        'color': Colors.grey,
      });
    }

    return Column(
      children: timeline.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final date = DateTime.parse(item['date']);
        final isLast = index == timeline.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item['color'],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item['icon'],
                    color: Colors.white,
                    size: 16,
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
            SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      item['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
