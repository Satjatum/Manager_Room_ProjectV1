import 'package:flutter/material.dart';
import 'package:manager_room_project/widgets/navbar.dart';
import '../../services/meter_service.dart';
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

class _MeterReadingDetailPageState extends State<MeterReadingDetailPage> {
  Map<String, dynamic>? _reading;
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
              : _buildContent(isMobile),
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
