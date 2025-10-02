import 'package:flutter/material.dart';
import '../../services/contract_service.dart';
import '../../middleware/auth_middleware.dart';
import '../../models/user_models.dart';
import '../../widgets/colors.dart';
import 'contract_edit_ui.dart';

class ContractDetailUI extends StatefulWidget {
  final String contractId;

  const ContractDetailUI({
    Key? key,
    required this.contractId,
  }) : super(key: key);

  @override
  State<ContractDetailUI> createState() => _ContractDetailUIState();
}

class _ContractDetailUIState extends State<ContractDetailUI> {
  Map<String, dynamic>? _contract;
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await AuthMiddleware.getCurrentUser();
      final contract = await ContractService.getContractById(widget.contractId);

      if (mounted) {
        setState(() {
          _currentUser = currentUser;
          _contract = contract;
          _isLoading = false;
        });
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

  // จัดการการเปิดใช้งานสัญญา
  Future<void> _activateContract() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการเปิดใช้งานสัญญา'),
        content: Text('คุณต้องการเปิดใช้งานสัญญานี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await ContractService.activateContract(widget.contractId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );

        if (result['success']) {
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // จัดการการยกเลิกสัญญา
  Future<void> _terminateContract() async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการยกเลิกสัญญา'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('กรุณาระบุเหตุผลในการยกเลิกสัญญา'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'เหตุผล',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      reasonController.dispose();
      return;
    }

    try {
      final result = await ContractService.terminateContract(
        widget.contractId,
        reasonController.text.trim(),
      );

      reasonController.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );

        if (result['success']) {
          _loadData();
        }
      }
    } catch (e) {
      reasonController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // จัดการการต่อสัญญา
  Future<void> _renewContract() async {
    DateTime? newEndDate;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('ต่ออายุสัญญา'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('เลือกวันที่สิ้นสุดใหม่'),
              SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(_contract!['end_date'])
                        .add(Duration(days: 365)),
                    firstDate: DateTime.parse(_contract!['end_date']),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() => newEndDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'วันที่สิ้นสุดใหม่',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    newEndDate == null
                        ? 'เลือกวันที่'
                        : '${newEndDate!.day}/${newEndDate!.month}/${newEndDate!.year + 543}',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: newEndDate == null
                  ? null
                  : () => Navigator.pop(context, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: Text('ยืนยัน'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || newEndDate == null) return;

    try {
      final result = await ContractService.renewContract(
        widget.contractId,
        newEndDate!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );

        if (result['success']) {
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        title: Text('รายละเอียดสัญญา'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_canManage && _contract != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContractEditUI(
                          contractId: widget.contractId,
                        ),
                      ),
                    ).then((_) => _loadData());
                    break;
                  case 'activate':
                    _activateContract();
                    break;
                  case 'renew':
                    _renewContract();
                    break;
                  case 'terminate':
                    _terminateContract();
                    break;
                }
              },
              itemBuilder: (context) {
                final status = _contract!['contract_status'];
                return [
                  if (status == 'pending' || status == 'expired')
                    PopupMenuItem(
                      value: 'activate',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('เปิดใช้งานสัญญา'),
                        ],
                      ),
                    ),
                  if (status == 'active')
                    PopupMenuItem(
                      value: 'renew',
                      child: Row(
                        children: [
                          Icon(Icons.update, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('ต่อสัญญา'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('แก้ไขสัญญา'),
                      ],
                    ),
                  ),
                  if (status == 'active' || status == 'pending')
                    PopupMenuItem(
                      value: 'terminate',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red),
                          SizedBox(width: 8),
                          Text('ยกเลิกสัญญา'),
                        ],
                      ),
                    ),
                ];
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _contract == null
              ? Center(child: Text('ไม่พบข้อมูลสัญญา'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [
                      // สถานะสัญญา
                      Card(
                        elevation: 2,
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getStatusColor(_contract!['contract_status']),
                                _getStatusColor(_contract!['contract_status'])
                                    .withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.description,
                                size: 48,
                                color: Colors.white,
                              ),
                              SizedBox(height: 12),
                              Text(
                                _contract!['contract_num'] ?? 'ไม่ระบุ',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStatusText(_contract!['contract_status']),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // ข้อมูลผู้เช่า
                      _buildInfoCard(
                        'ข้อมูลผู้เช่า',
                        Icons.person,
                        [
                          _buildInfoRow(
                              'ชื่อ-นามสกุล', _contract!['tenant_name']),
                          _buildInfoRow('เบอร์โทร', _contract!['tenant_phone']),
                        ],
                      ),
                      SizedBox(height: 16),

                      // ข้อมูลห้อง
                      _buildInfoCard(
                        'ข้อมูลห้อง',
                        Icons.home,
                        [
                          _buildInfoRow(
                              'หมายเลขห้อง', _contract!['room_number']),
                          _buildInfoRow('สาขา', _contract!['branch_name']),
                        ],
                      ),
                      SizedBox(height: 16),

                      // ระยะเวลาสัญญา
                      _buildInfoCard(
                        'ระยะเวลาสัญญา',
                        Icons.calendar_today,
                        [
                          _buildInfoRow('วันที่เริ่มสัญญา',
                              _formatDate(_contract!['start_date'])),
                          _buildInfoRow('วันที่สิ้นสุดสัญญา',
                              _formatDate(_contract!['end_date'])),
                          _buildInfoRow(
                              'วันชำระเงินประจำเดือน',
                              _contract!['payment_day'] != null
                                  ? 'วันที่ ${_contract!['payment_day']}'
                                  : '-'),
                        ],
                      ),
                      SizedBox(height: 16),

                      // รายละเอียดการเงิน
                      _buildInfoCard(
                        'รายละเอียดการเงิน',
                        Icons.attach_money,
                        [
                          _buildInfoRow('ค่าเช่าต่อเดือน',
                              '฿${_contract!['contract_price']?.toStringAsFixed(0) ?? '0'}'),
                          _buildInfoRow('ค่าประกัน',
                              '฿${_contract!['contract_deposit']?.toStringAsFixed(0) ?? '0'}'),
                          _buildInfoRow(
                              'สถานะชำระค่าประกัน',
                              _contract!['contract_paid'] == true
                                  ? 'ชำระแล้ว'
                                  : 'ยังไม่ชำระ'),
                        ],
                      ),
                      SizedBox(height: 16),

                      // หมายเหตุ
                      if (_contract!['contract_note'] != null &&
                          _contract!['contract_note'].toString().isNotEmpty)
                        _buildInfoCard(
                          'หมายเหตุ',
                          Icons.note,
                          [
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                _contract!['contract_note'],
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
