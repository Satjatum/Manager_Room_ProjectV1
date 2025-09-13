import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:manager_room_project/views/tenant/tenantreport_ui.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';

class TenantIssuesScreen extends StatefulWidget {
  const TenantIssuesScreen({super.key});

  @override
  State<TenantIssuesScreen> createState() => _TenantIssuesScreenState();
}

class _TenantIssuesScreenState extends State<TenantIssuesScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController _tabController;
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _filteredIssues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _applyFilters();
      }
    });
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

      if (response is List) {
        setState(() {
          _issues = List<Map<String, dynamic>>.from(response);
          _applyFilters();
        });
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    if (!mounted) return;

    List<Map<String, dynamic>> filtered = List.from(_issues);

    String tabStatus = _getStatusFromTab(_tabController.index);
    if (tabStatus == 'active') {
      // แสดงปัญหาที่ยังไม่ได้ปิด
      filtered = filtered
          .where((issue) =>
              issue['issue_status'] != null &&
              issue['issue_status'] != 'closed')
          .toList();
    } else if (tabStatus == 'completed') {
      // แสดงปัญหาที่แก้ไขเสร็จแล้วและปิดแล้ว
      filtered = filtered
          .where((issue) =>
              issue['issue_status'] != null &&
              (issue['issue_status'] == 'resolved' ||
                  issue['issue_status'] == 'closed'))
          .toList();
    } else if (tabStatus != 'all') {
      filtered = filtered
          .where((issue) =>
              issue['issue_status'] != null &&
              issue['issue_status'] == tabStatus)
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
        return 'reported';
      default:
        return 'all';
    }
  }

  int _getIssueCountByStatus(String status) {
    if (_issues.isEmpty) return 0;

    switch (status) {
      case 'all':
        return _issues.length;
      case 'active':
        return _issues
            .where((i) =>
                i['issue_status'] != null &&
                i['issue_status'] != 'closed' &&
                i['issue_status'] != 'resolved')
            .length;
      case 'completed':
        return _issues
            .where((i) =>
                i['issue_status'] != null &&
                (i['issue_status'] == 'resolved' ||
                    i['issue_status'] == 'closed'))
            .length;
      case 'reported':
        return _issues
            .where((i) =>
                i['issue_status'] != null && i['issue_status'] == 'reported')
            .length;
      default:
        return 0;
    }
  }

  Future<void> _rateFeedback(String issueId) async {
    int rating = 5;
    final feedbackController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.star, color: Colors.amber),
            ),
            const SizedBox(width: 12),
            const Text('ให้คะแนนและความคิดเห็น'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ความพึงพอใจในการแก้ไขปัญหา'),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              rating = index + 1;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'ความคิดเห็นเพิ่มเติม (ไม่บังคับ)',
                  hintText: 'แบ่งปันประสบการณ์การใช้บริการ...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.feedback),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('ส่งความคิดเห็น'),
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

        if (mounted) {
          _showSuccessSnackBar('ขอบคุณสำหรับความคิดเห็น');
          _loadTenantIssues();
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('เกิดข้อผิดพลาดในการส่งความคิดเห็น: $e');
        }
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

  Future<void> _navigateToReportIssue() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportIssueScreen(),
      ),
    );

    if (result == true && mounted) {
      _loadTenantIssues();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('ปัญหาของฉัน',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
          IconButton(
            onPressed: _loadTenantIssues,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'ทั้งหมด (${_getIssueCountByStatus('all')})'),
                Tab(text: 'รอตอบรับ (${_getIssueCountByStatus('reported')})'),
                Tab(
                    text:
                        'กำลังดำเนินการ (${_getIssueCountByStatus('active')})'),
                Tab(text: 'เสร็จสิ้น (${_getIssueCountByStatus('completed')})'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('กำลังโหลดข้อมูล...',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: List.generate(4, (index) => _buildIssuesList()),
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            _navigateToReportIssue();
          },
          backgroundColor: AppColors.primary,
          child: Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildIssuesList() {
    if (_filteredIssues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_outlined,
                  size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'ไม่มีปัญหาในหมวดนี้',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (_tabController.index == 0) ...[
              Text(
                'แตะปุ่ม + เพื่อรายงานปัญหาใหม่',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ] else ...[
              Text(
                'เมื่อมีปัญหาใหม่ จะแสดงในที่นี่',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTenantIssues,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredIssues.length,
        itemBuilder: (context, index) {
          if (index >= _filteredIssues.length) return const SizedBox.shrink();
          final issue = _filteredIssues[index];
          return _buildIssueCard(issue);
        },
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final reportedDate = _getFormattedDate(issue['reported_date']);
    final priority = issue['issue_priority'] ?? 'normal';
    final status = issue['issue_status'] ?? 'reported';
    final hoursElapsed = (issue['hours_elapsed'] ?? 0).toDouble();
    final hasRating = issue['tenant_rating'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 2),
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
            padding: const EdgeInsets.all(16),
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
                            issue['issue_title'] ?? 'ไม่มีหัวข้อ',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'รหัส: ${_getSafeIssueId(issue['issue_id'])}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(status),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    _buildPriorityBadge(priority),
                    const SizedBox(width: 8),
                    _buildCategoryBadge(issue['issue_category'] ?? 'อื่นๆ'),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  issue['issue_description'] ?? 'ไม่มีรายละเอียด',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], height: 1.4),
                ),

                const SizedBox(height: 16),

                // Progress Timeline
                _buildProgressIndicator(status),

                const SizedBox(height: 16),

                // Footer
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        reportedDate,
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hoursElapsed > 48
                            ? Colors.red[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${hoursElapsed.toInt()} ชม.',
                        style: TextStyle(
                          fontSize: 11,
                          color: hoursElapsed > 48
                              ? Colors.red[700]
                              : Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (issue['assigned_to_name'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_pin,
                                size: 12, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              issue['assigned_to_name'],
                              style: TextStyle(
                                  fontSize: 11, color: Colors.green[700]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (status == 'resolved' && !hasRating) ...[
                      Material(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _rateFeedback(issue['issue_id']),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_outline,
                                    size: 14, color: Colors.amber[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'ให้คะแนน',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else if (hasRating) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star,
                                size: 12, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Text(
                              issue['tenant_rating'].toString(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
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
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color:
                      isActive ? _getStatusColor(stepStatus) : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: _getStatusColor(stepStatus).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _getStatusIcon(stepStatus),
                  size: 12,
                  color: Colors.white,
                ),
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _getStatusColor(stepStatus)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'reported':
        return Icons.report_problem;
      case 'acknowledged':
        return Icons.visibility;
      case 'in_progress':
        return Icons.build;
      case 'resolved':
        return Icons.check;
      default:
        return Icons.help_outline;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withOpacity(0.8)),
          const SizedBox(width: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
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
    final images = issue['issue_images'] != null
        ? List<String>.from(jsonDecode(issue['issue_images']))
        : <String>[];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.assignment, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'รายละเอียดปัญหา',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          issue['issue_title'] ?? 'ไม่มีหัวข้อ',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusBadge(issue['issue_status'] ?? 'reported'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _buildPriorityBadge(issue['issue_priority'] ?? 'normal'),
                      const SizedBox(width: 8),
                      _buildCategoryBadge(issue['issue_category'] ?? 'อื่นๆ'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Issue Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue[600], size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'ข้อมูลการรายงาน',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'รหัส: ${_getSafeIssueId(issue['issue_id'])}',
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w500)),
                                  Text(
                                      'ห้อง: ${issue['room_number'] ?? 'ไม่ระบุ'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getFormattedDate(issue['reported_date']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                            Icon(Icons.description, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text('รายละเอียดปัญหา',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.green[700])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          issue['issue_description'] ?? 'ไม่มีรายละเอียด',
                          style: const TextStyle(height: 1.5, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Images
                  if (images.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
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
                              Icon(Icons.photo_library,
                                  color: Colors.purple[700]),
                              const SizedBox(width: 8),
                              Text('รูปภาพแนบ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.purple[700])),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildSafeImage(images[index]),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Timeline
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timeline, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text('ความคืบหน้า',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.orange[700])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDetailedTimeline(issue),
                      ],
                    ),
                  ),

                  // Resolution Notes
                  if (issue['resolution_notes'] != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[600], size: 20),
                              const SizedBox(width: 8),
                              Text('วิธีการแก้ไข',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[700])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(issue['resolution_notes']),
                        ],
                      ),
                    ),
                  ],

                  // Rating Section
                  if (issue['tenant_rating'] != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star,
                                  color: Colors.amber[600], size: 20),
                              const SizedBox(width: 8),
                              Text('คะแนนที่ให้: ${issue['tenant_rating']}/5',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber[700])),
                            ],
                          ),
                          if (issue['tenant_feedback'] != null) ...[
                            const SizedBox(height: 8),
                            Text(issue['tenant_feedback']),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action Button
                  if (issue['issue_status'] == 'resolved' &&
                      issue['tenant_rating'] == null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _rateFeedback(issue['issue_id']);
                        },
                        icon: const Icon(Icons.star_outline),
                        label: const Text('ให้คะแนนและความคิดเห็น'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSafeIssueId(dynamic issueId) {
    if (issueId == null) return 'ไม่มีรหัส';
    final idString = issueId.toString();
    return idString.length >= 8 ? idString.substring(0, 8) : idString;
  }

  String _getFormattedDate(dynamic dateString) {
    if (dateString == null) return 'ไม่ระบุวันที่';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'วันที่ไม่ถูกต้อง';
    }
  }

  Widget _buildSafeImage(String base64String) {
    try {
      return Image.memory(
        base64Decode(base64String),
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 120,
            height: 120,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    } catch (e) {
      return Container(
        width: 120,
        height: 120,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
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
        final isLast = index == timeline.length - 1;

        if (item['date'] == null) return const SizedBox.shrink();

        final date = DateTime.parse(item['date']);

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
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
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
