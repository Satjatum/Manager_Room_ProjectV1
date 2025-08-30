import 'package:flutter/material.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

final supabase = Supabase.instance.client;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _filteredNotifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _selectedPriority = 'all';
  late TabController _tabController;

  // Stats
  int _unreadCount = 0;
  Map<String, int> _priorityCount = {
    'urgent': 0,
    'high': 0,
    'normal': 0,
    'low': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();
      late List<dynamic> response;

      if (currentUser?.isSuperAdmin ?? false) {
        // Super Admin เห็นทุกแจ้งเตือน
        response = await supabase.from('notifications').select('''
              *,
              branches!notifications_branch_id_fkey(branch_name),
              tenants!notifications_tenant_id_fkey(tenant_full_name),
              rooms!notifications_room_id_fkey(room_number, room_name)
            ''').order('created_at', ascending: false);
      } else if (currentUser?.isAdmin ?? false) {
        // Admin เห็นเฉพาะแจ้งเตือนของสาขาตัวเอง
        final branchIds = await supabase
            .from('branches')
            .select('branch_id')
            .eq('owner_id', currentUser!.userId);

        if (branchIds.isNotEmpty) {
          final ids = branchIds.map((b) => b['branch_id']).toList();
          response = await supabase
              .from('notifications')
              .select('''
                *,
                branches!notifications_branch_id_fkey(branch_name),
                tenants!notifications_tenant_id_fkey(tenant_full_name),
                rooms!notifications_room_id_fkey(room_number, room_name)
              ''')
              .inFilter('branch_id', ids)
              .order('created_at', ascending: false);
        } else {
          response = [];
        }
      } else {
        // User อื่นๆ เห็นเฉพาะแจ้งเตือนของสาขาที่สังกัด
        if (currentUser?.branchId != null) {
          response = await supabase
              .from('notifications')
              .select('''
                *,
                branches!notifications_branch_id_fkey(branch_name),
                tenants!notifications_tenant_id_fkey(tenant_full_name),
                rooms!notifications_room_id_fkey(room_number, room_name)
              ''')
              .eq('branch_id', currentUser!.branchId!)
              .order('created_at', ascending: false);
        } else {
          response = [];
        }
      }

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _filteredNotifications = _notifications;
        _calculateStats();
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateStats() {
    _unreadCount = _notifications.where((n) => !n['is_read']).length;

    _priorityCount = {
      'urgent':
          _notifications.where((n) => n['noti_priority'] == 'urgent').length,
      'high': _notifications.where((n) => n['noti_priority'] == 'high').length,
      'normal':
          _notifications.where((n) => n['noti_priority'] == 'normal').length,
      'low': _notifications.where((n) => n['noti_priority'] == 'low').length,
    };
  }

  void _applyFilters() {
    setState(() {
      _filteredNotifications = _notifications.where((notification) {
        // Read status filter
        bool matchesRead = true;
        if (_selectedFilter == 'unread') {
          matchesRead = !notification['is_read'];
        } else if (_selectedFilter == 'read') {
          matchesRead = notification['is_read'];
        }

        // Priority filter
        bool matchesPriority = _selectedPriority == 'all' ||
            notification['noti_priority'] == _selectedPriority;

        return matchesRead && matchesPriority;
      }).toList();
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await supabase.from('notifications').update({
        'is_read': true,
        'notiRead_at': DateTime.now().toIso8601String(),
      }).eq('noti_id', notificationId);

      // Update local data
      setState(() {
        final index =
            _notifications.indexWhere((n) => n['noti_id'] == notificationId);
        if (index >= 0) {
          _notifications[index]['is_read'] = true;
          _notifications[index]['notiRead_at'] =
              DateTime.now().toIso8601String();
        }
        _calculateStats();
      });

      _applyFilters();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final currentUser = AuthService.getCurrentUser();

      // Get unread notifications for current user's scope
      List<String> notificationIds = [];

      if (currentUser?.isSuperAdmin ?? false) {
        // Super Admin - all unread notifications
        notificationIds = _notifications
            .where((n) => !n['is_read'])
            .map((n) => n['noti_id'] as String)
            .toList();
      } else if (currentUser?.isAdmin ?? false) {
        // Admin - unread notifications in their branches
        final branchIds = await supabase
            .from('branches')
            .select('branch_id')
            .eq('owner_id', currentUser!.userId);

        final ids = branchIds.map((b) => b['branch_id']).toList();
        notificationIds = _notifications
            .where((n) => !n['is_read'] && ids.contains(n['branch_id']))
            .map((n) => n['noti_id'] as String)
            .toList();
      } else {
        // User - unread notifications in their branch
        notificationIds = _notifications
            .where(
                (n) => !n['is_read'] && n['branch_id'] == currentUser?.branchId)
            .map((n) => n['noti_id'] as String)
            .toList();
      }

      if (notificationIds.isNotEmpty) {
        await supabase.from('notifications').update({
          'is_read': true,
          'notiRead_at': DateTime.now().toIso8601String(),
        }).inFilter('noti_id', notificationIds);

        await _loadNotifications();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ทำเครื่องหมายอ่านแล้วทั้งหมด'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('noti_id', notificationId);

      setState(() {
        _notifications.removeWhere((n) => n['noti_id'] == notificationId);
        _calculateStats();
      });

      _applyFilters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ลบการแจ้งเตือนสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
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
        return 'เร่งด่วน';
      case 'high':
        return 'สำคัญ';
      case 'normal':
        return 'ปกติ';
      case 'low':
        return 'ต่ำ';
      default:
        return 'ไม่ทราบ';
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'urgent':
        return Icons.priority_high;
      case 'high':
        return Icons.warning;
      case 'normal':
        return Icons.info;
      case 'low':
        return Icons.low_priority;
      default:
        return Icons.notifications;
    }
  }

  IconData _getNotificationTypeIcon(String type) {
    switch (type) {
      case 'rentDue':
        return Icons.payment;
      case 'contractExpiring':
        return Icons.schedule;
      case 'maintenance':
        return Icons.build;
      case 'payment':
        return Icons.monetization_on;
      case 'general':
        return Icons.announcement;
      case 'emergency':
        return Icons.emergency;
      default:
        return Icons.notifications;
    }
  }

  String _getNotificationTypeText(String type) {
    switch (type) {
      case 'rentDue':
        return 'ค่าเช่าครบกำหนด';
      case 'contractExpiring':
        return 'สัญญาใกล้หมดอายุ';
      case 'maintenance':
        return 'การซ่อมบำรุง';
      case 'payment':
        return 'การชำระเงิน';
      case 'general':
        return 'ทั่วไป';
      case 'emergency':
        return 'เหตุฉุกเฉิน';
      default:
        return 'แจ้งเตือน';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('การแจ้งเตือน'),
            if (_unreadCount > 0)
              Container(
                margin: EdgeInsets.only(left: 8),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.list), text: 'รายการ'),
            Tab(icon: Icon(Icons.analytics), text: 'สถิติ'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'รีเฟรชข้อมูล',
          ),
          if (_unreadCount > 0)
            IconButton(
              icon: Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'ทำเครื่องหมายอ่านแล้วทั้งหมด',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationListTab(),
          _buildStatsTab(),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildNotificationListTab() {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
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
              // Read Status Filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ทั้งหมด', 'all', _selectedFilter,
                        (value) {
                      setState(() {
                        _selectedFilter = value ?? 'all';
                      });
                      _applyFilters();
                    }),
                    SizedBox(width: 8),
                    _buildFilterChip('ยังไม่อ่าน', 'unread', _selectedFilter,
                        (value) {
                      setState(() {
                        _selectedFilter = value ?? 'all';
                      });
                      _applyFilters();
                    }),
                    SizedBox(width: 8),
                    _buildFilterChip('อ่านแล้ว', 'read', _selectedFilter,
                        (value) {
                      setState(() {
                        _selectedFilter = value ?? 'all';
                      });
                      _applyFilters();
                    }),
                  ],
                ),
              ),

              SizedBox(height: 8),

              // Priority Filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ทุกระดับ', 'all', _selectedPriority,
                        (value) {
                      setState(() {
                        _selectedPriority = value ?? 'all';
                      });
                      _applyFilters();
                    }),
                    SizedBox(width: 8),
                    _buildFilterChip('เร่งด่วน', 'urgent', _selectedPriority,
                        (value) {
                      setState(() {
                        _selectedPriority = value ?? 'all';
                      });
                      _applyFilters();
                    }),
                    SizedBox(width: 8),
                    _buildFilterChip('สำคัญ', 'high', _selectedPriority,
                        (value) {
                      setState(() {
                        _selectedPriority = value ?? 'all';
                      });
                      _applyFilters();
                    }),
                    SizedBox(width: 8),
                    _buildFilterChip('ปกติ', 'normal', _selectedPriority,
                        (value) {
                      setState(() {
                        _selectedPriority = value ?? 'all';
                      });
                      _applyFilters();
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Notification Count
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'แสดง ${_filteredNotifications.length} จาก ${_notifications.length} รายการ',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Notification List
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('กำลังโหลดข้อมูล...'),
                    ],
                  ),
                )
              : _filteredNotifications.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = _filteredNotifications[index];
                          return _buildNotificationCard(notification);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Overview Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'ทั้งหมด',
                  _notifications.length.toString(),
                  Icons.notifications,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'ยังไม่อ่าน',
                  _unreadCount.toString(),
                  Icons.mark_email_unread,
                  Colors.red,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Priority Stats
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'การแจกแจงตามระดับความสำคัญ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  ...['urgent', 'high', 'normal', 'low'].map((priority) {
                    final count = _priorityCount[priority] ?? 0;
                    final total = _notifications.length;
                    final percentage = total > 0 ? (count / total) : 0.0;

                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getPriorityColor(priority),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(_getPriorityText(priority)),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _getPriorityColor(priority)),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('$count'),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Type Distribution
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'การแจกแจงตามประเภท',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildTypeDistribution(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeDistribution() {
    Map<String, int> typeCount = {};
    for (var notification in _notifications) {
      final type = notification['noti_type'] ?? 'general';
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }

    return Column(
      children: typeCount.entries.map((entry) {
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              _getNotificationTypeIcon(entry.key),
              color: AppColors.primary,
            ),
            title: Text(_getNotificationTypeText(entry.key)),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entry.value}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue,
      Function(String?) onChanged) {
    final isSelected = currentValue == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onChanged(value),
      selectedColor: Colors.white.withOpacity(0.2),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: Colors.white54),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            _selectedFilter == 'unread'
                ? 'ไม่มีการแจ้งเตือนที่ยังไม่อ่าน'
                : 'ไม่มีการแจ้งเตือน',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'การแจ้งเตือนจะปรากฏที่นี่',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] ?? false;
    final priority = notification['noti_priority'] ?? 'normal';
    final type = notification['noti_type'] ?? 'general';
    final priorityColor = _getPriorityColor(priority);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      color: isRead ? Colors.grey[50] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.grey[300]! : priorityColor.withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!isRead) {
            _markAsRead(notification['noti_id']);
          }
          _showNotificationDetail(notification);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Priority Icon
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getPriorityIcon(priority),
                      size: 16,
                      color: priorityColor,
                    ),
                  ),
                  SizedBox(width: 8),

                  // Type Icon
                  Icon(
                    _getNotificationTypeIcon(type),
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 4),

                  // Type Text
                  Text(
                    _getNotificationTypeText(type),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),

                  Spacer(),

                  // Priority Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getPriorityText(priority),
                      style: TextStyle(
                        fontSize: 10,
                        color: priorityColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  SizedBox(width: 8),

                  // Unread Indicator
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),

                  // Menu
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'mark_read':
                          if (!isRead) {
                            await _markAsRead(notification['noti_id']);
                          }
                          break;
                        case 'delete':
                          await _deleteNotification(notification['noti_id']);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isRead)
                        PopupMenuItem(
                          value: 'mark_read',
                          child: Row(
                            children: [
                              Icon(Icons.mark_email_read, size: 20),
                              SizedBox(width: 8),
                              Text('ทำเครื่องหมายอ่านแล้ว'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('ลบ', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Title
              Text(
                notification['noti_title'] ?? 'ไม่มีหัวข้อ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isRead ? Colors.grey[700] : Colors.black,
                ),
              ),

              SizedBox(height: 8),

              // Message
              Text(
                notification['noti_message'] ?? 'ไม่มีข้อความ',
                style: TextStyle(
                  fontSize: 14,
                  color: isRead ? Colors.grey[600] : Colors.grey[800],
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: 12),

              // Footer Info
              Row(
                children: [
                  // Branch
                  if (notification['branches'] != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.business,
                              size: 14, color: Colors.grey[500]),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              notification['branches']['branch_name'] ??
                                  'ไม่ระบุสาขา',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Room
                  if (notification['rooms'] != null) ...[
                    SizedBox(width: 12),
                    Row(
                      children: [
                        Icon(Icons.hotel, size: 14, color: Colors.grey[500]),
                        SizedBox(width: 4),
                        Text(
                          notification['rooms']['room_number'] ?? 'ไม่ระบุห้อง',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],

                  Spacer(),

                  // Time
                  Text(
                    _formatDateTime(notification['created_at']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
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

  void _showNotificationDetail(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getNotificationTypeIcon(notification['noti_type'] ?? 'general'),
              color: AppColors.primary,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                notification['noti_title'] ?? 'ไม่มีหัวข้อ',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Priority
              Row(
                children: [
                  Text('ระดับความสำคัญ: '),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(
                              notification['noti_priority'] ?? 'normal')
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getPriorityText(
                          notification['noti_priority'] ?? 'normal'),
                      style: TextStyle(
                        color: _getPriorityColor(
                            notification['noti_priority'] ?? 'normal'),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Message
              Text(
                'ข้อความ:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              Text(
                notification['noti_message'] ?? 'ไม่มีข้อความ',
                style: TextStyle(height: 1.5),
              ),

              SizedBox(height: 16),

              // Details
              if (notification['branches'] != null ||
                  notification['rooms'] != null ||
                  notification['tenants'] != null) ...[
                Text(
                  'รายละเอียด:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                if (notification['branches'] != null)
                  _buildDetailRow('สาขา',
                      notification['branches']['branch_name'], Icons.business),
                if (notification['rooms'] != null)
                  _buildDetailRow(
                      'ห้อง',
                      '${notification['rooms']['room_number']} - ${notification['rooms']['room_name']}',
                      Icons.hotel),
                if (notification['tenants'] != null)
                  _buildDetailRow(
                      'ผู้เช่า',
                      notification['tenants']['tenant_full_name'],
                      Icons.person),
                SizedBox(height: 16),
              ],

              // Timestamps
              _buildDetailRow('สร้างเมื่อ',
                  _formatDateTime(notification['created_at']), Icons.schedule),
              if (notification['notiRead_at'] != null)
                _buildDetailRow('อ่านเมื่อ',
                    _formatDateTime(notification['notiRead_at']), Icons.check),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ปิด'),
          ),
          if (notification['notiAction_url'] != null &&
              notification['notiAction_url'].toString().isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Navigate to action URL
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ฟีเจอร์กำลังพัฒนา')),
                );
              },
              child: Text('ดำเนินการ'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(value ?? 'ไม่ระบุ'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'ไม่ทราบ';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} นาทีที่แล้ว';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} ชั่วโมงที่แล้ว';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} วันที่แล้ว';
      } else {
        return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return 'ไม่ทราบ';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
