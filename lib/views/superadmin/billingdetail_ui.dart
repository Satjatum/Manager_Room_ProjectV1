import 'package:flutter/material.dart';
import 'package:manager_room_project/views/superadmin/payment_ui.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

class BillDetailScreen extends StatefulWidget {
  final String billId;
  final VoidCallback? onBillUpdated;

  const BillDetailScreen({
    Key? key,
    required this.billId,
    this.onBillUpdated,
  }) : super(key: key);

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _billData;
  Map<String, dynamic>? _billDetails;
  List<dynamic> _utilityItems = [];
  List<dynamic> _otherItems = [];
  List<dynamic> _paymentHistory = [];

  @override
  void initState() {
    super.initState();
    _loadBillDetails();
  }

  Future<void> _loadBillDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load bill summary
      final billSummary = await supabase
          .from('bill_summary')
          .select('*')
          .eq('bill_id', widget.billId)
          .single();

      // Load detailed bill information
      final billDetails = await supabase
          .from('rental_bills')
          .select('*')
          .eq('bill_id', widget.billId)
          .single();

      // Load utility items
      final utilityItems = await supabase
          .from('bill_utility_details')
          .select('*')
          .eq('bill_id', widget.billId);

      // Load other items
      final otherItems = await supabase
          .from('bill_other_items')
          .select('*')
          .eq('bill_id', widget.billId);

      // Load payment history
      final paymentHistory = await supabase
          .from('payment_history')
          .select('*, users!inner(username)')
          .eq('bill_id', widget.billId)
          .order('payment_date', ascending: false);

      setState(() {
        _billData = billSummary;
        _billDetails = billDetails;
        _utilityItems = utilityItems;
        _otherItems = otherItems;
        _paymentHistory = paymentHistory;
      });
    } catch (e) {
      _showErrorSnackBar(
          'เกิดข้อผิดพลาดในการโหลดรายละเอียดบิล: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'รายละเอียดบิล',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_billData != null && _billData!['bill_status'] != 'paid')
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentScreen(
                    bill: _billData!,
                    onPaymentComplete: () {
                      _loadBillDetails();
                      widget.onBillUpdated?.call();
                    },
                  ),
                ),
              ),
              icon: Icon(Icons.payment),
              tooltip: 'รับชำระเงิน',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('กำลังโหลดรายละเอียด...'),
                ],
              ),
            )
          : _billData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'ไม่พบข้อมูลบิล',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bill Header
                      _buildBillHeader(),
                      SizedBox(height: 16),

                      // Bill Info
                      _buildBillInfo(),
                      SizedBox(height: 16),

                      // Utility Items
                      if (_utilityItems.isNotEmpty) ...[
                        _buildUtilityItems(),
                        SizedBox(height: 16),
                      ],

                      // Other Items
                      if (_otherItems.isNotEmpty) ...[
                        _buildOtherItems(),
                        SizedBox(height: 16),
                      ],

                      // Summary
                      _buildSummary(),
                      SizedBox(height: 16),

                      // Payment History
                      if (_paymentHistory.isNotEmpty) ...[
                        _buildPaymentHistory(),
                        SizedBox(height: 16),
                      ],

                      // Action Buttons
                      if (_billData!['bill_status'] != 'paid')
                        _buildActionButtons(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBillHeader() {
    final status = _billData!['bill_status'] ?? 'pending';
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _billData!['bill_number'] ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getBillStatusText(status),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.person,
                  color: Colors.white.withOpacity(0.8), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _billData!['tenant_full_name'] ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.home, color: Colors.white.withOpacity(0.8), size: 16),
              SizedBox(width: 8),
              Text(
                'ห้อง ${_billData!['room_number']} - ${_billData!['branch_name']}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillInfo() {
    return _buildCard(
      title: 'ข้อมูลบิล',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _buildInfoRow('ระยะเวลา',
              '${DateFormat('dd/MM/yyyy').format(DateTime.parse(_billData!['billing_period_start']))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(_billData!['billing_period_end']))}'),
          _buildInfoRow(
              'ครบกำหนดชำระ',
              DateFormat('dd/MM/yyyy')
                  .format(DateTime.parse(_billData!['due_date']))),
          _buildInfoRow(
              'วันที่สร้างบิล',
              DateFormat('dd/MM/yyyy HH:mm')
                  .format(DateTime.parse(_billData!['created_at']))),
          if (_billData!['created_by_name'] != null)
            _buildInfoRow('สร้างโดย', _billData!['created_by_name']),
        ],
      ),
    );
  }

  Widget _buildUtilityItems() {
    return _buildCard(
      title: 'ค่าสาธารณูปโภค',
      icon: Icons.electrical_services,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('รายการ',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                    child: Text('ครั้งก่อน',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                    child: Text('ครั้งนี้',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                    child: Text('ใช้',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                    child: Text('จำนวนเงิน',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
              ],
            ),
          ),
          Divider(),
          ...(_utilityItems.map((item) => _buildUtilityRow(item)).toList()),
        ],
      ),
    );
  }

  Widget _buildUtilityRow(Map<String, dynamic> item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['utility_name'] ?? '',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (item['unit_name'] != null)
                  Text(
                    'หน่วย: ${item['unit_name']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${item['previous_reading']?.toString() ?? '0'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              '${item['current_reading']?.toString() ?? '0'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              '${item['consumption']?.toString() ?? '0'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              '${NumberFormat('#,##0.00').format(item['amount'] ?? 0)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherItems() {
    return _buildCard(
      title: 'ค่าใช้จ่ายอื่นๆ',
      icon: Icons.more_horiz,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('รายการ',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                    child: Text('จำนวน',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                    child: Text('ราคา/หน่วย',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                    child: Text('จำนวนเงิน',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
              ],
            ),
          ),
          Divider(),
          ...(_otherItems.map((item) => _buildOtherRow(item)).toList()),
        ],
      ),
    );
  }

  Widget _buildOtherRow(Map<String, dynamic> item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['item_name'] ?? '',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (item['item_description'] != null)
                  Text(
                    item['item_description'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${item['quantity']?.toString() ?? '0'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              '${NumberFormat('#,##0.00').format(item['unit_price'] ?? 0)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              '${NumberFormat('#,##0.00').format(item['amount'] ?? 0)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return _buildCard(
      title: 'สรุปยอดเงิน',
      icon: Icons.calculate,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildSummaryRow('ค่าเช่าห้อง', _billData!['room_rent']),
            _buildSummaryRow('ค่าสาธารณูปโภค', _billData!['total_utilities']),
            _buildSummaryRow('ค่าใช้จ่ายอื่นๆ', _billData!['other_charges']),
            Divider(),
            _buildSummaryRow('ยอดรวมย่อย', _billData!['subtotal'],
                isBold: true),
            _buildSummaryRow('ส่วนลด', -(_billData!['discount'] ?? 0),
                isNegative: true),
            _buildSummaryRow('ภาษี', _billData!['tax_amount']),
            _buildSummaryRow('ค่าปรับ', _billData!['late_fee']),
            Divider(thickness: 2),
            _buildSummaryRow('ยอดรวมสุทธิ', _billData!['total_amount'],
                isBold: true, isTotal: true),
            _buildSummaryRow('ชำระแล้ว', _billData!['paid_amount'],
                isPayment: true),
            _buildSummaryRow('คงเหลือ', _billData!['outstanding_amount'],
                isOutstanding: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return _buildCard(
      title: 'ประวัติการชำระเงิน',
      icon: Icons.history,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                    child: Text('วันที่/เวลา',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                    child: Text('วิธีชำระ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(
                    child: Text('จำนวนเงิน',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
              ],
            ),
          ),
          Divider(),
          ...(_paymentHistory
              .map((payment) => _buildPaymentRow(payment))
              .toList()),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(Map<String, dynamic> payment) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(DateTime.parse(payment['payment_date'])),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  _getPaymentMethodText(payment['payment_method']),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  '${NumberFormat('#,##0.00').format(payment['payment_amount'])} บาท',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          if (payment['payment_notes'] != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.note, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    payment['payment_notes'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
          if (payment['users'] != null) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  'รับโดย: ${payment['users']['username']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentScreen(
                  bill: _billData!,
                  onPaymentComplete: () {
                    _loadBillDetails();
                    widget.onBillUpdated?.call();
                  },
                ),
              ),
            ),
            icon: Icon(Icons.payment, size: 20),
            label: Text('รับชำระเงิน'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(': '),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, num amount,
      {bool isBold = false,
      bool isTotal = false,
      bool isNegative = false,
      bool isPayment = false,
      bool isOutstanding = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight:
                  isBold || isTotal ? FontWeight.w700 : FontWeight.normal,
              color: isTotal
                  ? AppColors.primary
                  : isPayment
                      ? Colors.green
                      : isOutstanding
                          ? Colors.red
                          : Colors.black,
            ),
          ),
          Text(
            '${isNegative && amount > 0 ? '-' : ''}${NumberFormat('#,##0.00').format(amount.abs())} บาท',
            style: TextStyle(
              fontWeight:
                  isBold || isTotal ? FontWeight.w700 : FontWeight.normal,
              color: isTotal
                  ? AppColors.primary
                  : isPayment
                      ? Colors.green
                      : isOutstanding
                          ? Colors.red
                          : isNegative
                              ? Colors.red
                              : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'partial':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _getBillStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'ร่าง';
      case 'pending':
        return 'รอชำระ';
      case 'paid':
        return 'ชำระครบแล้ว';
      case 'overdue':
        return 'เกินกำหนด';
      case 'cancelled':
        return 'ยกเลิก';
      case 'partial':
        return 'ชำระบางส่วน';
      default:
        return status;
    }
  }

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'เงินสด';
      case 'transfer':
        return 'โอนเงิน';
      case 'card':
        return 'บัตร';
      case 'check':
        return 'เช็ค';
      case 'online':
        return 'ออนไลน์';
      default:
        return method;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.error_rounded, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 4),
      ),
    );
  }
}
