import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/issuelist_detail_ui.dart';
import 'package:manager_room_project/views/tenant/issue_add_ui.dart';
import 'package:manager_room_project/widgets/navbar.dart';
import '../../services/issue_service.dart';
import '../../services/auth_service.dart';
import '../../services/branch_service.dart';
import '../../models/user_models.dart';
import '../../widgets/colors.dart';

class IssuesListScreen extends StatefulWidget {
  const IssuesListScreen({Key? key}) : super(key: key);

  @override
  State<IssuesListScreen> createState() => _IssuesListScreenState();
}

class _IssuesListScreenState extends State<IssuesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  UserModel? _currentUser;

  List<Map<String, dynamic>> _allIssues = [];
  List<Map<String, dynamic>> _filteredIssues = [];
  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _branches = [];

  String _selectedPriority = 'all';
  String _selectedType = 'all';
  String? _selectedBranchId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _applyFilters();
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      _currentUser = await AuthService.getCurrentUser();

      if (_currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load sequentially to ensure issues are ready before computing statistics
      await _loadBranches();
      await _loadIssues();
      await _loadStatistics();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  Future<void> _loadBranches() async {
    try {
      if (_currentUser?.userRole == UserRole.superAdmin) {
        _branches = await BranchService.getAllBranches();
      } else if (_currentUser?.userRole == UserRole.admin) {
        _branches = await BranchService.getBranchesByUser();
      }
    } catch (e) {
      print('Error loading branches: $e');
      _branches = [];
    }
  }

  Future<void> _loadIssues() async {
    try {
      _allIssues = await IssueService.getIssuesByUser(
        branchId: _selectedBranchId,
      );
      _applyFilters();
    } catch (e) {
      print('Error loading issues: $e');
      _allIssues = [];
      _filteredIssues = [];
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // For Admin without a specific branch filter, aggregate from loaded issues (managed branches only)
      if (_currentUser?.userRole == UserRole.admin &&
          (_selectedBranchId == null || _selectedBranchId!.isEmpty)) {
        _statistics = _computeStatisticsFromIssues(_allIssues);
        setState(() {});
        return;
      }

      _statistics = await IssueService.getIssueStatistics(
        branchId: _selectedBranchId,
      );
      setState(() {});
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Map<String, dynamic> _computeStatisticsFromIssues(
      List<Map<String, dynamic>> issues) {
    int total = issues.length;
    int pending = issues.where((i) => i['issue_status'] == 'pending').length;
    int inProgress =
        issues.where((i) => i['issue_status'] == 'in_progress').length;
    int resolved = issues.where((i) => i['issue_status'] == 'resolved').length;
    int cancelled =
        issues.where((i) => i['issue_status'] == 'cancelled').length;

    return {
      'total': total,
      'pending': pending,
      'in_progress': inProgress,
      'resolved': resolved,
      'cancelled': cancelled,
    };
  }

  void _applyFilters() {
    if (!mounted || _allIssues.isEmpty) {
      setState(() => _filteredIssues = []);
      return;
    }

    List<Map<String, dynamic>> filtered = List.from(_allIssues);

    // Filter by tab status
    String tabStatus = _getStatusFromTab(_tabController.index);
    if (tabStatus != 'all') {
      filtered = filtered
          .where((issue) => issue['issue_status'] == tabStatus)
          .toList();
    }

    // Filter by branch (for superadmin/admin)
    if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty) {
      filtered = filtered
          .where((issue) => issue['branch_id'] == _selectedBranchId)
          .toList();
    }

    // Filter by priority
    if (_selectedPriority != 'all') {
      filtered = filtered
          .where((issue) => issue['issue_priority'] == _selectedPriority)
          .toList();
    }

    // Filter by type
    if (_selectedType != 'all') {
      filtered = filtered
          .where((issue) => issue['issue_type'] == _selectedType)
          .toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((issue) {
        final issueNum = issue['issue_num']?.toString().toLowerCase() ?? '';
        final title = issue['issue_title']?.toString().toLowerCase() ?? '';
        final roomNumber = issue['room_number']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return issueNum.contains(query) ||
            title.contains(query) ||
            roomNumber.contains(query);
      }).toList();
    }

    setState(() => _filteredIssues = filtered);
  }

  String _getStatusFromTab(int index) {
    switch (index) {
      case 0:
        return 'all';
      case 1:
        return 'pending';
      case 2:
        return 'in_progress';
      case 3:
        return 'resolved';
      case 4:
        return 'cancelled';
      default:
        return 'all';
    }
  }

  int _getIssueCountByStatus(String status) {
    if (_statistics.isEmpty) return 0;
    if (status == 'all') return _statistics['total'] ?? 0;
    return _statistics[status] ?? 0;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'urgent':
        return 'ด่วนมาก';
      case 'high':
        return 'สูง';
      case 'medium':
        return 'ปานกลาง';
      case 'low':
        return 'ต่ำ';
      default:
        return priority;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอดำเนินการ';
      case 'in_progress':
        return 'กำลังดำเนินการ';
      case 'resolved':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  String _getIssueTypeText(String type) {
    switch (type) {
      case 'repair':
        return 'ซ่อมแซม';
      case 'maintenance':
        return 'บำรุงรักษา';
      case 'complaint':
        return 'ร้องเรียน';
      case 'suggestion':
        return 'ข้อเสนอแนะ';
      case 'other':
        return 'อื่นๆ';
      default:
        return type;
    }
  }

  IconData _getIssueTypeIcon(String type) {
    switch (type) {
      case 'repair':
        return Icons.build;
      case 'maintenance':
        return Icons.engineering;
      case 'complaint':
        return Icons.report_problem;
      case 'suggestion':
        return Icons.lightbulb;
      case 'other':
        return Icons.more_horiz;
      default:
        return Icons.info;
    }
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreateIssue = _currentUser?.hasAnyPermission([
          DetailedPermission.all,
          DetailedPermission.manageIssues,
          DetailedPermission.createIssues,
        ]) ??
        false;

    final isTenant = _currentUser?.userRole == UserRole.tenant;
    final canFilterByBranch = _currentUser?.hasAnyPermission([
          DetailedPermission.all,
          DetailedPermission.manageBranches,
        ]) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTenant ? 'ปัญหาของฉัน' : 'จัดการปัญหา',
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'ตัวกรอง',
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: null,
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.category, size: 20, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text('ประเภท',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                  value: 'type_all', child: Text('ทั้งหมด')),
              const PopupMenuItem<String>(
                  value: 'type_repair', child: Text('🔧 ซ่อมแซม')),
              const PopupMenuItem<String>(
                  value: 'type_maintenance', child: Text('🛠️ บำรุงรักษา')),
              const PopupMenuItem<String>(
                  value: 'type_complaint', child: Text('⚠️ ร้องเรียน')),
              const PopupMenuItem<String>(
                  value: 'type_suggestion', child: Text('💡 ข้อเสนอแนะ')),
              const PopupMenuItem<String>(
                  value: 'type_other', child: Text('📋 อื่นๆ')),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: null,
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.priority_high, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('ความเร่งด่วน',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                  value: 'priority_all', child: Text('ทั้งหมด')),
              const PopupMenuItem<String>(
                  value: 'priority_urgent', child: Text('🔴 ด่วนมาก')),
              const PopupMenuItem<String>(
                  value: 'priority_high', child: Text('🟠 สูง')),
              const PopupMenuItem<String>(
                  value: 'priority_medium', child: Text('🔵 ปานกลาง')),
              const PopupMenuItem<String>(
                  value: 'priority_low', child: Text('🟢 ต่ำ')),
            ],
            onSelected: (String? value) {
              if (value != null) {
                if (value.startsWith('type_')) {
                  setState(() {
                    _selectedType = value.replaceFirst('type_', '');
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
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with search and filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาเลขที่แจ้ง, หัวข้อ, หมายเลขห้อง...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _applyFilters();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _applyFilters();
                  },
                ),

                // Branch filter (for superadmin/admin)
                if (canFilterByBranch && _branches.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedBranchId,
                        hint: const Text('เลือกสาขา (ทั้งหมด)'),
                        icon: const Icon(Icons.arrow_drop_down),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('ทุกสาขา'),
                          ),
                          ..._branches.map((branch) {
                            return DropdownMenuItem<String>(
                              value: branch['branch_id'],
                              child: Text(branch['branch_name'] ?? ''),
                            );
                          }).toList(),
                        ],
                        onChanged: (String? value) async {
                          setState(() {
                            _selectedBranchId = value;
                          });
                          await _loadIssues();
                          await _loadStatistics();
                        },
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Statistics tracking bar
                _buildTrackingBar(),

                const SizedBox(height: 12),

                // Tab bar
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  onTap: (index) => _applyFilters(),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: 'ทั้งหมด (${_getIssueCountByStatus('all')})'),
                    Tab(
                        text:
                            'รอดำเนินการ (${_getIssueCountByStatus('pending')})'),
                    Tab(
                        text:
                            'กำลังดำเนินการ (${_getIssueCountByStatus('in_progress')})'),
                    Tab(
                        text:
                            'เสร็จสิ้น (${_getIssueCountByStatus('resolved')})'),
                    Tab(
                        text:
                            'ยกเลิก (${_getIssueCountByStatus('cancelled')})'),
                  ],
                ),
              ],
            ),
          ),

          // Issues list
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'กำลังโหลดข้อมูล...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _filteredIssues.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppTheme.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredIssues.length,
                          itemBuilder: (context, index) {
                            final issue = _filteredIssues[index];
                            return _buildIssueCard(issue);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: isTenant
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateIssueScreen(),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: 'แจ้งปัญหาใหม่',
            )
          : null,
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildTrackingBar() {
    final total = _getIssueCountByStatus('all');
    final pending = _getIssueCountByStatus('pending');
    final inProgress = _getIssueCountByStatus('in_progress');
    final resolved = _getIssueCountByStatus('resolved');

    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'สถิติการแจ้งปัญหา',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                'ทั้งหมด $total รายการ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (pending > 0)
                    Expanded(
                      flex: pending,
                      child: Container(color: Colors.orange),
                    ),
                  if (inProgress > 0)
                    Expanded(
                      flex: inProgress,
                      child: Container(color: Colors.blue),
                    ),
                  if (resolved > 0)
                    Expanded(
                      flex: resolved,
                      child: Container(color: Colors.green),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.orange, 'รอดำเนินการ', pending, total),
              _buildLegendItem(
                  Colors.blue, 'กำลังดำเนินการ', inProgress, total),
              _buildLegendItem(Colors.green, 'เสร็จสิ้น', resolved, total),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int count, int total) {
    final percentage =
        total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
            child: Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ไม่มีปัญหาในหมวดนี้',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เมื่อมีการรายงานปัญหา จะแสดงในที่นี่',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final issueNum = issue['issue_num'] ?? '';
    final title = issue['issue_title'] ?? '';
    final roomNumber = issue['room_number'] ?? '';
    final branchName = issue['branch_name'] ?? '';
    final status = issue['issue_status'] ?? '';
    final priority = issue['issue_priority'] ?? '';
    final type = issue['issue_type'] ?? '';
    final createdAt = issue['created_at'] != null
        ? DateTime.parse(issue['created_at'])
        : null;
    final assignedUserName = issue['assigned_user_name'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IssueDetailScreen(
                issueId: issue['issue_id'],
              ),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getStatusColor(status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag,
                          size: 12,
                          color: _getPriorityColor(priority),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getPriorityText(priority),
                          style: TextStyle(
                            color: _getPriorityColor(priority),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    issueNum,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Row(
                children: [
                  Icon(
                    _getIssueTypeIcon(type),
                    size: 20,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.category, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          _getIssueTypeText(type),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.meeting_room,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          roomNumber,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.business, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            branchName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Footer
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    createdAt != null ? _formatDateTime(createdAt) : 'ไม่ระบุ',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  if (assignedUserName != null) ...[
                    const SizedBox(width: 12),
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
                          Icon(
                            Icons.person_pin,
                            size: 14,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            assignedUserName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
