import 'package:flutter/material.dart';
import 'package:manager_room_project/widgets/navbar.dart';
import '../../services/meter_service.dart';
import '../../services/invoice_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_models.dart';
import '../../widgets/colors.dart';
import 'meter_edit_ui.dart';

class MeterReadingDetailPage extends StatefulWidget {
  final String readingId;

  const MeterReadingDetailPage({
    Key? key,
    required this.readingId,
  }) : super(key: key);

  @override
  State<MeterReadingDetailPage> createState() => _MeterReadingDetailPageState();
}

class _MeterReadingDetailPageState extends State<MeterReadingDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _reading;
  bool _isLoading = true;
  UserModel? _currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _currentUser = await AuthService.getCurrentUser();
      _reading =
          await MeterReadingService.getMeterReadingById(widget.readingId);
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmReading() async {
    if (_reading == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันค่ามิเตอร์'),
        content: Text(
            'ต้องการยืนยันค่ามิเตอร์ ${_reading!['reading_number']} หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result =
            await MeterReadingService.confirmMeterReading(widget.readingId);
        if (result['success']) {
          _showSuccessSnackBar('ยืนยันค่ามิเตอร์สำเร็จ');
          _loadData(); // Reload data
        } else {
          _showErrorSnackBar(result['message']);
        }
      } catch (e) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  Future<void> _cancelReading() async {
    if (_reading == null) return;

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกค่ามิเตอร์'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'ต้องการยกเลิกค่ามิเตอร์ ${_reading!['reading_number']} หรือไม่?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'เหตุผลในการยกเลิก',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await MeterReadingService.cancelMeterReading(
          widget.readingId,
          reasonController.text,
        );
        if (result['success']) {
          _showSuccessSnackBar('ยกเลิกค่ามิเตอร์สำเร็จ');
          _loadData(); // Reload data
        } else {
          _showErrorSnackBar(result['message']);
        }
      } catch (e) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
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
        duration: const Duration(seconds: 3),
      ),
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width <= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดค่ามิเตอร์'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'รายละเอียด'),
            Tab(text: 'ใบแจ้งหนี้'),
          ],
        ),
        actions: [
          if (_reading != null && _reading!['reading_status'] == 'draft')
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => (
                    //       readingId: widget.readingId,
                    //     ),
                    //   ),
                    // ).then((_) => _loadData());
                    break;
                  case 'confirm':
                    _confirmReading();
                    break;
                  case 'cancel':
                    _cancelReading();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('แก้ไข'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'confirm',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('ยืนยัน'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 8),
                      Text('ยกเลิก'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
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
          : _reading == null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildContent(isMobile),
                    _buildInvoiceTab(),
                  ],
                ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ไม่พบข้อมูลค่ามิเตอร์',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('กลับ'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    final status = _reading!['reading_status'] ?? 'draft';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'เลขที่บันทึก',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _reading!['reading_number'] ?? '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  _buildInfoRow('สาขา', _reading!['branch_name'] ?? '-'),
                  _buildInfoRow('ห้อง', _reading!['room_number'] ?? '-'),
                  _buildInfoRow('ผู้เช่า', _reading!['tenant_name'] ?? '-'),
                  _buildInfoRow('โทรศัพท์', _reading!['tenant_phone'] ?? '-'),
                  _buildInfoRow('สัญญา', _reading!['contract_num'] ?? '-'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Period Info Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'ข้อมูลการบันทึก',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'เดือน/ปี',
                    '${_getMonthName(_reading!['reading_month'] ?? 1)} ${_reading!['reading_year'] ?? DateTime.now().year}',
                  ),
                  _buildInfoRow(
                    'วันที่บันทึก',
                    _reading!['reading_date'] != null
                        ? _formatDate(DateTime.parse(_reading!['reading_date']))
                        : '-',
                  ),
                  if (_reading!['reading_notes'] != null &&
                      _reading!['reading_notes'].isNotEmpty)
                    _buildInfoRow('หมายเหตุ', _reading!['reading_notes']),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Water Meter Card
          _buildMeterCard(
            'มิเตอร์น้ำ',
            Icons.water_drop,
            Colors.blue,
            _reading!['water_previous_reading'],
            _reading!['water_current_reading'],
            _reading!['water_usage'],
            _reading!['water_meter_image'],
          ),

          const SizedBox(height: 20),

          // Electric Meter Card
          _buildMeterCard(
            'มิเตอร์ไฟ',
            Icons.electric_bolt,
            Colors.orange,
            _reading!['electric_previous_reading'],
            _reading!['electric_current_reading'],
            _reading!['electric_usage'],
            _reading!['electric_meter_image'],
          ),

          const SizedBox(height: 20),

          // Confirmation Info (if confirmed)
          if (status == 'confirmed' || status == 'billed')
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        const Text(
                          'ข้อมูลการยืนยัน',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_reading!['confirmed_at'] != null)
                      _buildInfoRow(
                        'วันที่ยืนยัน',
                        _formatDateTime(
                            DateTime.parse(_reading!['confirmed_at'])),
                      ),
                    if (_reading!['confirmed_by'] != null)
                      _buildInfoRow('ยืนยันโดย', 'ผู้ดูแลระบบ'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // แท็บใบแจ้งหนี้
  Widget _buildInvoiceTab() {
    final invoiceId = _reading?['invoice_id'];
    if (invoiceId == null || (invoiceId is String && invoiceId.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('ยังไม่มีใบแจ้งหนี้สำหรับรายการนี้',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: InvoiceService.getInvoiceById(invoiceId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data;
        if (data == null) {
          return Center(
            child: Text('ไม่พบข้อมูลใบแจ้งหนี้',
                style: TextStyle(color: Colors.grey[600])),
          );
        }

        double _asDouble(dynamic v) {
          if (v == null) return 0;
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v) ?? 0;
          return 0;
        }

        final status = (data['invoice_status'] ?? '').toString();
        final rental = _asDouble(data['rental_amount']);
        final utilities = _asDouble(data['utilities_amount']);
        final others = _asDouble(data['other_charges']);
        final discount = _asDouble(data['discount_amount']);
        final lateFee = _asDouble(data['late_fee_amount']);
        final subtotal = _asDouble(data['subtotal']);
        final total = _asDouble(data['total_amount']);
        final paid = _asDouble(data['paid_amount']);
        final remain = (total - paid);

        final utilLines =
            (data['utilities'] as List?)?.cast<Map<String, dynamic>>() ??
                const [];
        final otherLines =
            (data['other_charges'] as List?)?.cast<Map<String, dynamic>>() ??
                const [];
        final payments =
            (data['payments'] as List?)?.cast<Map<String, dynamic>>() ??
                const [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('เลขบิล: ${data['invoice_number'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          'เดือน/ปี: ${data['invoice_month'] ?? '-'} / ${data['invoice_year'] ?? '-'}'),
                      if (data['issue_date'] != null)
                        Text('ออกบิล: ${data['issue_date']}'),
                      if (data['due_date'] != null)
                        Text('ครบกำหนด: ${data['due_date']}'),
                    ],
                  ),
                ),
                _InvoiceStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Text('ห้อง: ${data['room_number'] ?? '-'}'),
            Text('ผู้เช่า: ${data['tenant_name'] ?? '-'}'),
            const SizedBox(height: 16),
            const _SectionHeader('ค่าใช้จ่าย'),
            _kv('ค่าเช่า', rental),
            _kv('ค่าสาธารณูปโภค (รวม)', utilities),
            if (utilLines.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: utilLines.map((u) {
                    final name = (u['utility_name'] ?? '').toString();
                    final unit = _asDouble(u['unit_price']);
                    final usage = _asDouble(u['usage_amount']);
                    final fixed = _asDouble(u['fixed_amount']);
                    final add = _asDouble(u['additional_charge']);
                    final amount = _asDouble(u['total_amount']);
                    String meta = '';
                    if (unit > 0 && usage > 0) {
                      meta = '($usage x ${unit.toStringAsFixed(2)})';
                    } else if (fixed > 0) {
                      meta = '(เหมาจ่าย ${fixed.toStringAsFixed(2)})';
                    }
                    if (add > 0) {
                      meta = meta.isEmpty
                          ? '(+${add.toStringAsFixed(2)})'
                          : '$meta (+${add.toStringAsFixed(2)})';
                    }
                    return _line(name, amount, meta: meta);
                  }).toList(),
                ),
              ),
            ],
            _kv('ค่าใช้จ่ายอื่น (รวม)', others),
            if (otherLines.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: otherLines.map((o) {
                    final name = (o['charge_name'] ?? '').toString();
                    final amount = _asDouble(o['charge_amount']);
                    return _line(name, amount);
                  }).toList(),
                ),
              ),
            ],
            const Divider(height: 24),
            _kv('ส่วนลด', -discount),
            _kv('ค่าปรับล่าช้า', lateFee),
            const Divider(height: 24),
            _kv('ยอดก่อนชำระ', subtotal),
            _kv('ยอดรวม', total, emphasize: true),
            _kv('ชำระแล้ว', paid),
            _kv('คงเหลือ', remain, emphasize: true),
            const SizedBox(height: 20),
            const _SectionHeader('ประวัติการชำระเงิน'),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('— ไม่มีรายการ —'),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: payments.map((p) {
                    final amount = _asDouble(p['payment_amount']);
                    final date = (p['payment_date'] ?? '').toString();
                    final pstatus = (p['payment_status'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      title: Text(amount.toStringAsFixed(2)),
                      subtitle: Text(date),
                      trailing: Text(pstatus),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _kv(String label, double value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              fontSize: emphasize ? 16 : 14,
            ),
          )
        ],
      ),
    );
  }

  Widget _line(String label, double value, {String? meta}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      title: Text(label),
      subtitle: meta == null || meta.isEmpty ? null : Text(meta),
      trailing: Text(value.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterCard(
    String title,
    IconData icon,
    Color color,
    dynamic previousReading,
    dynamic currentReading,
    dynamic usage,
    String? imageUrl,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Meter readings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ครั้งก่อน',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${previousReading?.toStringAsFixed(2) ?? '0.00'} หน่วย',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward, color: Colors.grey[400]),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ปัจจุบัน',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${currentReading?.toStringAsFixed(2) ?? '0.00'} หน่วย',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.trending_up,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'ใช้งาน ${usage?.toStringAsFixed(2) ?? '0.00'} หน่วย',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Meter image
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'รูปภาพมิเตอร์',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'ไม่สามารถโหลดรูปภาพได้',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'billed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'draft':
        return 'ร่าง';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'billed':
        return 'ออกบิลแล้ว';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบ';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _InvoiceStatusChip extends StatelessWidget {
  final String status;
  const _InvoiceStatusChip({required this.status});

  Color _color() {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _label() {
    switch (status) {
      case 'paid':
        return 'ชำระแล้ว';
      case 'partial':
        return 'ชำระบางส่วน';
      case 'overdue':
        return 'เกินกำหนด';
      case 'cancelled':
        return 'ยกเลิก';
      case 'pending':
        return 'ค้างชำระ';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color().withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color().withOpacity(0.3)),
      ),
      child: Text(
        _label(),
        style: TextStyle(color: _color(), fontWeight: FontWeight.w700),
      ),
    );
  }
}
