import 'package:flutter/material.dart';
import 'package:manager_room_project/widgets/colors.dart';
import '../../services/issue_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_models.dart';

class IssueDetailScreen extends StatefulWidget {
  final String issueId;

  const IssueDetailScreen({
    Key? key,
    required this.issueId,
  }) : super(key: key);

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  bool _isLoading = true;
  UserModel? _currentUser;
  Map<String, dynamic>? _issue;
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _availableUsers = [];

  final _resolutionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _resolutionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      _currentUser = await AuthService.getCurrentUser();
      _issue = await IssueService.getIssueById(widget.issueId);

      if (_issue != null) {
        _images = await IssueService.getIssueImages(widget.issueId);
      }

      if (_currentUser != null &&
          _currentUser!.hasAnyPermission([
            DetailedPermission.all,
            DetailedPermission.manageIssues,
          ])) {
        _availableUsers = await UserService.getAllUsers(limit: 50);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getStatusColor(status).withOpacity(0.8),
                    _getStatusColor(status),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStatusIcon(status),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'เปลี่ยนสถานะเป็น\n${_getStatusText(status)}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: status == 'resolved'
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'กรุณาระบุรายละเอียดการแก้ไข',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _resolutionController,
                    decoration: InputDecoration(
                      hintText: 'อธิบายวิธีการแก้ไขปัญหา...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                    maxLines: 4,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ต้องการเปลี่ยนสถานะเป็น ${_getStatusText(status)} ใช่หรือไม่?',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'การเปลี่ยนสถานะจะถูกบันทึกในประวัติ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(status),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final updateResult = await IssueService.updateIssueStatus(
          widget.issueId,
          status,
          resolutionNotes:
              status == 'resolved' ? _resolutionController.text.trim() : null,
        );

        if (updateResult['success']) {
          if (mounted) {
            _showSuccessSnackBar(updateResult['message']);
            _resolutionController.clear();
            _loadData();
          }
        } else {
          if (mounted) {
            _showErrorSnackBar(updateResult['message']);
          }
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
        }
      }
    }
  }

  Future<void> _assignToUser() async {
    if (_availableUsers.isEmpty) return;

    final selectedUserId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.8),
                    AppTheme.primary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.person_add, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('มอบหมายงาน', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'เลือกผู้รับผิดชอบงาน',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = _availableUsers[index];
                    final isAssigned =
                        _issue?['assigned_to'] == user['user_id'];

                    return Card(
                      elevation: isAssigned ? 4 : 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isAssigned
                              ? AppTheme.primary
                              : Colors.grey.shade200,
                          width: isAssigned ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isAssigned
                              ? AppTheme.primary
                              : AppTheme.primary.withOpacity(0.1),
                          child: Text(
                            user['user_name'][0].toUpperCase(),
                            style: TextStyle(
                              color:
                                  isAssigned ? Colors.white : AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          user['user_name'],
                          style: TextStyle(
                            fontWeight: isAssigned
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(user['user_email']),
                        trailing: isAssigned
                            ? Icon(Icons.check_circle, color: AppTheme.primary)
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.pop(context, user['user_id']),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );

    if (selectedUserId != null) {
      try {
        final result =
            await IssueService.assignIssue(widget.issueId, selectedUserId);

        if (result['success']) {
          if (mounted) {
            _showSuccessSnackBar(result['message']);
            _loadData();
          }
        } else {
          if (mounted) {
            _showErrorSnackBar(result['message']);
          }
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
        }
      }
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_outlined;
      case 'in_progress':
        return Icons.autorenew;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
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
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
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
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _currentUser?.hasAnyPermission([
          DetailedPermission.all,
          DetailedPermission.manageIssues,
        ]) ??
        false;

    final isTenant = _currentUser?.userRole == UserRole.tenant;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('รายละเอียดปัญหา'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
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
        ),
      );
    }

    if (_issue == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('รายละเอียดปัญหา'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline,
                    size: 64, color: Colors.grey[400]),
              ),
              const SizedBox(height: 24),
              Text(
                'ไม่พบข้อมูลปัญหา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final status = _issue!['issue_status'] ?? '';
    final priority = _issue!['issue_priority'] ?? '';
    final type = _issue!['issue_type'] ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isTenant ? 'รายละเอียดปัญหา' : 'จัดการปัญหา',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'assign':
                    _assignToUser();
                    break;
                  case 'in_progress':
                  case 'resolved':
                  case 'cancelled':
                    _updateStatus(value);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'assign',
                  child: Row(
                    children: [
                      Icon(Icons.person_add, color: AppTheme.primary, size: 20),
                      SizedBox(width: 12),
                      Text('มอบหมายงาน'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                if (status == 'pending')
                  const PopupMenuItem(
                    value: 'in_progress',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow, color: Colors.blue, size: 20),
                        SizedBox(width: 12),
                        Text('เริ่มดำเนินการ'),
                      ],
                    ),
                  ),
                if (status == 'in_progress')
                  const PopupMenuItem(
                    value: 'resolved',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 12),
                        Text('เสร็จสิ้น'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'cancelled',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.grey, size: 20),
                      SizedBox(width: 12),
                      Text('ยกเลิก'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(status, priority),
              const SizedBox(height: 20),
              _buildBasicInfoCard(type),
              const SizedBox(height: 16),
              _buildDescriptionCard(),
              const SizedBox(height: 16),
              if (_images.isNotEmpty) ...[
                _buildImagesCard(),
                const SizedBox(height: 16),
              ],
              if (_issue!['assigned_user_name'] != null) ...[
                _buildAssignmentCard(),
                const SizedBox(height: 16),
              ],
              if (_issue!['resolution_notes'] != null) ...[
                _buildResolutionCard(),
                const SizedBox(height: 16),
              ],
              _buildTimelineCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String status, String priority) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _issue!['issue_num'] ?? '',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _issue!['issue_title'] ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      size: 16,
                      color: _getStatusColor(status),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getStatusText(status),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPriorityColor(priority).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flag,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getPriorityText(priority),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard(String type) {
    return _buildModernCard(
      'ข้อมูลพื้นฐาน',
      Icons.info_outline,
      AppTheme.primary,
      [
        _buildModernInfoRow(
          Icons.category_outlined,
          'ประเภท',
          _getIssueTypeText(type),
        ),
        _buildModernInfoRow(
          Icons.meeting_room_outlined,
          'ห้องพัก',
          _issue!['room_number'] ?? '',
        ),
        _buildModernInfoRow(
          Icons.business_outlined,
          'สาขา',
          _issue!['branch_name'] ?? '',
        ),
        if (_issue!['tenant_fullname'] != null)
          _buildModernInfoRow(
            Icons.person_outline,
            'ผู้เช่า',
            _issue!['tenant_fullname'],
          ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return _buildModernCard(
      'รายละเอียดปัญหา',
      Icons.description_outlined,
      Colors.blue,
      [
        Text(
          _issue!['issue_desc'] ?? '',
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildImagesCard() {
    return _buildModernCard(
      'รูปภาพประกอบ (${_images.length})',
      Icons.photo_library_outlined,
      Colors.green,
      [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _images.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Image.network(_images[index]['image_url']),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _images[index]['image_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error_outline),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAssignmentCard() {
    return _buildModernCard(
      'ผู้รับผิดชอบ',
      Icons.person_pin_outlined,
      Colors.purple,
      [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              radius: 24,
              child: Text(
                _issue!['assigned_user_name'][0].toUpperCase(),
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _issue!['assigned_user_name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'รับผิดชอบงานนี้',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResolutionCard() {
    return _buildModernCard(
      'การแก้ไขปัญหา',
      Icons.check_circle_outline,
      Colors.green,
      [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.task_alt, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _issue!['resolution_notes'],
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard() {
    return _buildModernCard(
      'ประวัติการดำเนินงาน',
      Icons.timeline,
      Colors.orange,
      [
        _buildTimeline(),
      ],
    );
  }

  Widget _buildModernCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    List<Map<String, dynamic>> timeline = [];

    if (_issue!['created_at'] != null) {
      timeline.add({
        'date': _issue!['created_at'],
        'status': 'pending',
        'title': 'รายงานปัญหา',
        'user': _issue!['created_user_name'] ?? 'ระบบ',
        'icon': Icons.report_problem,
        'description': 'สร้างรายการแจ้งปัญหาในระบบ',
      });
    }

    if (_issue!['assigned_user_name'] != null) {
      timeline.add({
        'date': _issue!['updated_at'],
        'status': 'in_progress',
        'title': 'มอบหมายงาน',
        'user': _issue!['assigned_user_name'],
        'icon': Icons.person_add,
        'description': 'ได้รับมอบหมายให้ดำเนินการแก้ไข',
      });
    }

    if (_issue!['resolved_date'] != null) {
      timeline.add({
        'date': _issue!['resolved_date'],
        'status': 'resolved',
        'title': 'แก้ไขเสร็จสิ้น',
        'user': _issue!['assigned_user_name'] ?? 'ระบบ',
        'icon': Icons.check_circle,
        'description': 'ปัญหาได้รับการแก้ไขเรียบร้อย',
      });
    }

    if (timeline.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text(
                'ไม่มีข้อมูลประวัติ',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: timeline.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == timeline.length - 1;
        final date = DateTime.parse(item['date']);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getStatusColor(item['status']),
                          _getStatusColor(item['status']).withOpacity(0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              _getStatusColor(item['status']).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      item['icon'],
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _getStatusColor(item['status']).withOpacity(0.5),
                              Colors.grey.shade300,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(item['status'])
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getStatusText(item['status']),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(item['status']),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['description'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.person, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item['user'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
