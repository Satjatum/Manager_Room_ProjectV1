import 'package:flutter/material.dart';
import 'package:manager_room_project/views/superadmin/contractlist_detail_ui.dart';
import '../../services/contract_service.dart';
import '../../middleware/auth_middleware.dart';
import '../../models/user_models.dart';
import '../../widgets/colors.dart';
import 'contract_add_ui.dart';

class ContractListUI extends StatefulWidget {
  final String? tenantId; // ถ้ามี = แสดงเฉพาะสัญญาของผู้เช่านี้
  final String? tenantName;
  final String? roomId; // ถ้ามี = แสดงเฉพาะสัญญาของห้องนี้

  const ContractListUI({
    Key? key,
    this.tenantId,
    this.tenantName,
    this.roomId,
  }) : super(key: key);

  @override
  State<ContractListUI> createState() => _ContractListUIState();
}

class _ContractListUIState extends State<ContractListUI> {
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _filteredContracts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all'; // all, active, expired, terminated, pending
  UserModel? _currentUser;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await AuthMiddleware.getCurrentUser();
      final contracts = await ContractService.getAllContracts(
        tenantId: widget.tenantId,
        roomId: widget.roomId,
      );

      if (mounted) {
        setState(() {
          _currentUser = currentUser;
          _contracts = contracts;
          _filteredContracts = contracts;
          _isLoading = false;
        });
        _filterContracts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _filterContracts();
  }

  void _onStatusChanged(String? status) {
    setState(() => _selectedStatus = status ?? 'all');
    _filterContracts();
  }

  void _filterContracts() {
    setState(() {
      _filteredContracts = _contracts.where((contract) {
        // กรองตามคำค้นหา
        final searchLower = _searchQuery.toLowerCase();
        final matchesSearch = _searchQuery.isEmpty ||
            (contract['contract_num'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchLower) ||
            (contract['tenant_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchLower) ||
            (contract['room_number'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchLower);

        // กรองตามสถานะ
        final matchesStatus = _selectedStatus == 'all' ||
            contract['contract_status'] == _selectedStatus;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'active':
        return 'ใช้งานอยู่';
      case 'expired':
        return 'หมดอายุ';
      case 'terminated':
        return 'ยกเลิก';
      case 'pending':
        return 'รอดำเนินการ';
      default:
        return 'ไม่ทราบ';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.orange;
      case 'terminated':
        return Colors.red;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'expired':
        return Icons.event_busy;
      case 'terminated':
        return Icons.cancel;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year + 543}';
    } catch (e) {
      return dateStr;
    }
  }

  bool get _canManage =>
      _currentUser != null &&
      _currentUser!.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageContracts,
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tenantName != null
            ? 'สัญญาของ ${widget.tenantName}'
            : 'จัดการสัญญาเช่า'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // ปุ่มกรอง
          PopupMenuButton<String>(
            icon: Stack(
              children: [
                Icon(Icons.filter_list),
                if (_selectedStatus != 'all')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(minWidth: 8, minHeight: 8),
                    ),
                  ),
              ],
            ),
            onSelected: _onStatusChanged,
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
                    ),
                    SizedBox(width: 8),
                    Text('ทั้งหมด'),
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
                      color: Colors.green,
                    ),
                    SizedBox(width: 8),
                    Text('ใช้งานอยู่'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(
                      _selectedStatus == 'pending'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Text('รอดำเนินการ'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'expired',
                child: Row(
                  children: [
                    Icon(
                      _selectedStatus == 'expired'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 8),
                    Text('หมดอายุ'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'terminated',
                child: Row(
                  children: [
                    Icon(
                      _selectedStatus == 'terminated'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: Colors.red,
                    ),
                    SizedBox(width: 8),
                    Text('ยกเลิก'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: Column(
        children: [
          // ช่องค้นหา
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ค้นหาเลขที่สัญญา, ผู้เช่า, หมายเลขห้อง',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // รายการสัญญา
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _filteredContracts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredContracts.length,
                          itemBuilder: (context, index) {
                            final contract = _filteredContracts[index];
                            return _buildContractCard(contract);
                          },
                        ),
                      ),
          ),
        ],
      ),
      // ปุ่มเพิ่มสัญญา
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContractAddUI(
                      tenantId: widget.tenantId,
                    ),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.add, color: Colors.white),
              tooltip: 'สร้างสัญญาใหม่',
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'ไม่พบสัญญาที่ค้นหา'
                : 'ยังไม่มีสัญญาเช่า',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'ลองเปลี่ยนคำค้นหาหรือกรองสถานะ'
                : _canManage
                    ? 'เริ่มต้นโดยการสร้างสัญญาใหม่'
                    : '',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          if (_searchQuery.isEmpty && _canManage) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContractAddUI(
                      tenantId: widget.tenantId,
                    ),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
              icon: Icon(Icons.add),
              label: Text('สร้างสัญญาใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContractCard(Map<String, dynamic> contract) {
    final status = contract['contract_status'] ?? 'unknown';
    final statusColor = _getStatusColor(status);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContractDetailUI(
                contractId: contract['contract_id'],
              ),
            ),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.description,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contract['contract_num'] ?? 'ไม่ระบุ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          contract['tenant_name'] ?? '-',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // สถานะ
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(status),
                            size: 14, color: statusColor),
                        SizedBox(width: 4),
                        Text(
                          _getStatusText(status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Divider(height: 1),
              SizedBox(height: 12),

              // รายละเอียด
              Row(
                children: [
                  Icon(Icons.home, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    'ห้อง: ${contract['room_number'] ?? '-'}',
                    style: TextStyle(fontSize: 13),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    '${_formatDate(contract['start_date'])} - ${_formatDate(contract['end_date'])}',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    '฿${contract['contract_price']?.toStringAsFixed(0) ?? '0'}/เดือน',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
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
}
