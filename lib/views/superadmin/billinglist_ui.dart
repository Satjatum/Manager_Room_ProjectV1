import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_room_project/views/superadmin/addbiling_ui.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

class BillListScreen extends StatefulWidget {
  const BillListScreen({Key? key}) : super(key: key);

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  bool _isLoading = true;
  bool _isPaymentLoading = false;
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _filteredBills = [];

  // Filters
  String _selectedStatus = 'all';
  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  // Current User
  dynamic _currentUser;

  // Payment Controllers
  final _paymentAmountController = TextEditingController();
  final _paymentNotesController = TextEditingController();
  String _selectedPaymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.getCurrentUser();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
    });

    try {
      late List<dynamic> response;

      if (_currentUser?.isSuperAdmin ?? false) {
        response = await supabase
            .from('bill_summary')
            .select('*')
            .order('created_at', ascending: false);
      } else if (_currentUser?.isAdmin ?? false) {
        // Admin เห็นเฉพาะสาขาของตน
        response = await supabase
            .from('bill_summary')
            .select('*')
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('bill_summary')
            .select('*')
            .eq('branch_id', _currentUser?.branchId ?? '')
            .order('created_at', ascending: false);
      }

      setState(() {
        _bills = List<Map<String, dynamic>>.from(response);
        _filteredBills = _bills;
        _applyFilters();
      });
    } catch (e) {
      print('Error loading bills: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูลบิล: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredBills = _bills.where((bill) {
        // Status filter
        if (_selectedStatus != 'all' &&
            bill['bill_status'] != _selectedStatus) {
          return false;
        }

        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final tenantName =
              (bill['tenant_full_name'] ?? '').toString().toLowerCase();
          final billNumber =
              (bill['bill_number'] ?? '').toString().toLowerCase();
          final roomNumber =
              (bill['room_number'] ?? '').toString().toLowerCase();

          if (!tenantName.contains(query) &&
              !billNumber.contains(query) &&
              !roomNumber.contains(query)) {
            return false;
          }
        }

        // Date range filter
        if (_fromDate != null) {
          final billDate = DateTime.parse(bill['billing_period_start']);
          if (billDate.isBefore(_fromDate!)) {
            return false;
          }
        }

        if (_toDate != null) {
          final billDate = DateTime.parse(bill['billing_period_start']);
          if (billDate.isAfter(_toDate!.add(Duration(days: 1)))) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  Future<void> _showPaymentDialog(Map<String, dynamic> bill) async {
    _paymentAmountController.text = bill['outstanding_amount'].toString();
    _paymentNotesController.clear();
    _selectedPaymentMethod = 'cash';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.payment, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'รับชำระเงิน',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bill Info
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('เลขที่บิล: ${bill['bill_number']}'),
                      Text('ผู้เช่า: ${bill['tenant_full_name']}'),
                      Text('ห้อง: ${bill['room_number']}'),
                      Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ยอดรวม:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                              '${NumberFormat('#,##0.00').format(bill['total_amount'])} บาท'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ชำระแล้ว:',
                              style: TextStyle(color: Colors.green)),
                          Text(
                              '${NumberFormat('#,##0.00').format(bill['paid_amount'])} บาท',
                              style: TextStyle(color: Colors.green)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('คงเหลือ:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red)),
                          Text(
                              '${NumberFormat('#,##0.00').format(bill['outstanding_amount'])} บาท',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Payment Amount
                Text('จำนวนเงินที่รับ *',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _paymentAmountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    suffixText: 'บาท',
                    prefixIcon:
                        Icon(Icons.monetization_on, color: AppColors.primary),
                  ),
                ),
                SizedBox(height: 16),

                // Payment Method
                Text('วิธีการชำระ *',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPaymentMethod,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                            value: 'cash',
                            child: Row(
                              children: [
                                Icon(Icons.money, size: 20),
                                SizedBox(width: 8),
                                Text('เงินสด'),
                              ],
                            )),
                        DropdownMenuItem(
                            value: 'transfer',
                            child: Row(
                              children: [
                                Icon(Icons.account_balance, size: 20),
                                SizedBox(width: 8),
                                Text('โอนเงิน'),
                              ],
                            )),
                        DropdownMenuItem(
                            value: 'card',
                            child: Row(
                              children: [
                                Icon(Icons.credit_card, size: 20),
                                SizedBox(width: 8),
                                Text('บัตรเครดิต/เดบิต'),
                              ],
                            )),
                        DropdownMenuItem(
                            value: 'check',
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long, size: 20),
                                SizedBox(width: 8),
                                Text('เช็ค'),
                              ],
                            )),
                        DropdownMenuItem(
                            value: 'online',
                            child: Row(
                              children: [
                                Icon(Icons.phone_android, size: 20),
                                SizedBox(width: 8),
                                Text('ออนไลน์'),
                              ],
                            )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Payment Notes
                Text('หมายเหตุการชำระ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _paymentNotesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    hintText: 'หมายเหตุเพิ่มเติม (ถ้ามี)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: _isPaymentLoading ? null : () => _processPayment(bill),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: _isPaymentLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('บันทึกการชำระ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(Map<String, dynamic> bill) async {
    final paymentAmount = double.tryParse(_paymentAmountController.text);
    if (paymentAmount == null || paymentAmount <= 0) {
      _showErrorSnackBar('กรุณาใส่จำนวนเงินที่ถูกต้อง');
      return;
    }

    if (paymentAmount > bill['outstanding_amount']) {
      final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('ยืนยันการชำระ'),
              content: Text(
                  'จำนวนเงินที่รับมากกว่ายอดค้างชำระ ต้องการดำเนินการต่อหรือไม่?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('ยกเลิก')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('ดำเนินการ')),
              ],
            ),
          ) ??
          false;

      if (!confirm) return;
    }

    setState(() {
      _isPaymentLoading = true;
    });

    try {
      // Insert payment record
      await supabase.from('payment_history').insert({
        'bill_id': bill['bill_id'],
        'payment_amount': paymentAmount,
        'payment_method': _selectedPaymentMethod,
        'payment_notes': _paymentNotesController.text.trim().isNotEmpty
            ? _paymentNotesController.text.trim()
            : null,
        'received_by': _currentUser?.userId,
        'payment_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      Navigator.of(context).pop(); // Close dialog
      _showSuccessSnackBar('บันทึกการชำระเงินสำเร็จ');
      _loadBills(); // Refresh the list
    } catch (e) {
      _showErrorSnackBar(
          'เกิดข้อผิดพลาดในการบันทึกการชำระเงิน: ${e.toString()}');
    } finally {
      setState(() {
        _isPaymentLoading = false;
      });
    }
  }

  Future<void> _showBillDetails(Map<String, dynamic> bill) async {
    try {
      // Load detailed bill information
      final billDetails = await supabase
          .from('rental_bills')
          .select('*')
          .eq('bill_id', bill['bill_id'])
          .single();

      final utilityItems = await supabase
          .from('bill_utility_details')
          .select('*')
          .eq('bill_id', bill['bill_id']);

      final otherItems = await supabase
          .from('bill_other_items')
          .select('*')
          .eq('bill_id', bill['bill_id']);

      final paymentHistory = await supabase
          .from('payment_history')
          .select('*')
          .eq('bill_id', bill['bill_id'])
          .order('payment_date', ascending: false);

      showDialog(
        context: context,
        builder: (context) => _buildBillDetailsDialog(
            bill, billDetails, utilityItems, otherItems, paymentHistory),
      );
    } catch (e) {
      _showErrorSnackBar(
          'เกิดข้อผิดพลาดในการโหลดรายละเอียดบิล: ${e.toString()}');
    }
  }

  Widget _buildBillDetailsDialog(
    Map<String, dynamic> bill,
    Map<String, dynamic> billDetails,
    List<dynamic> utilityItems,
    List<dynamic> otherItems,
    List<dynamic> paymentHistory,
  ) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'รายละเอียดบิล ${bill['bill_number']}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bill Info
                    _buildInfoSection('ข้อมูลบิล', [
                      _buildInfoRow('เลขที่บิล', bill['bill_number']),
                      _buildInfoRow('ผู้เช่า', bill['tenant_full_name']),
                      _buildInfoRow('ห้อง',
                          '${bill['room_number']} - ${bill['room_name'] ?? ''}'),
                      _buildInfoRow('สาขา', bill['branch_name']),
                      _buildInfoRow('ระยะเวลา',
                          '${DateFormat('dd/MM/yyyy').format(DateTime.parse(bill['billing_period_start']))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(bill['billing_period_end']))}'),
                      _buildInfoRow(
                          'ครบกำหนดชำระ',
                          DateFormat('dd/MM/yyyy')
                              .format(DateTime.parse(bill['due_date']))),
                      _buildInfoRow(
                          'สถานะ', _getBillStatusText(bill['bill_status']),
                          isStatus: true),
                    ]),

                    SizedBox(height: 16),

                    // Utility Items
                    if (utilityItems.isNotEmpty) ...[
                      _buildInfoSection(
                        'ค่าสาธารณูปโภค',
                        utilityItems
                            .map((item) => _buildUtilityRow(item))
                            .toList(),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Other Items
                    if (otherItems.isNotEmpty) ...[
                      _buildInfoSection(
                        'ค่าใช้จ่ายอื่นๆ',
                        otherItems.map((item) => _buildOtherRow(item)).toList(),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Summary
                    _buildSummarySection(billDetails),

                    SizedBox(height: 16),

                    // Payment History
                    if (paymentHistory.isNotEmpty) ...[
                      _buildInfoSection(
                        'ประวัติการชำระเงิน',
                        paymentHistory
                            .map((payment) => _buildPaymentRow(payment))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Text(': '),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isStatus ? FontWeight.w600 : FontWeight.normal,
                color: isStatus ? _getStatusColor(value) : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityRow(Map<String, dynamic> item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(item['utility_name'] ?? ''),
          ),
          Expanded(
            child: Text(
                '${item['previous_reading']?.toString() ?? '0'} ${item['unit_name'] ?? ''}',
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
                '${item['current_reading']?.toString() ?? '0'} ${item['unit_name'] ?? ''}',
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
                '${item['consumption']?.toString() ?? '0'} ${item['unit_name'] ?? ''}',
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
                '${NumberFormat('#,##0.00').format(item['amount'] ?? 0)} บาท',
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherRow(Map<String, dynamic> item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(item['item_name'] ?? ''),
          ),
          Expanded(
            child: Text('${item['quantity']?.toString() ?? '0'}',
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
                '${NumberFormat('#,##0.00').format(item['unit_price'] ?? 0)}',
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
                '${NumberFormat('#,##0.00').format(item['amount'] ?? 0)} บาท',
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(Map<String, dynamic> payment) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.parse(payment['payment_date']))),
          ),
          Expanded(
            child: Text(_getPaymentMethodText(payment['payment_method']),
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
                '${NumberFormat('#,##0.00').format(payment['payment_amount'])} บาท',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(Map<String, dynamic> bill) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildSummaryRow('ค่าเช่าห้อง', bill['room_rent']),
          _buildSummaryRow('ค่าสาธารณูปโภค', bill['total_utilities']),
          _buildSummaryRow('ค่าใช้จ่ายอื่นๆ', bill['other_charges']),
          Divider(),
          _buildSummaryRow('ยอดรวมย่อย', bill['subtotal'], isBold: true),
          _buildSummaryRow('ส่วนลด', -bill['discount'], isNegative: true),
          _buildSummaryRow('ภาษี', bill['tax_amount']),
          _buildSummaryRow('ค่าปรับ', bill['late_fee']),
          Divider(thickness: 2),
          _buildSummaryRow('ยอดรวมสุทธิ', bill['total_amount'],
              isBold: true, isTotal: true),
          _buildSummaryRow('ชำระแล้ว', bill['paid_amount'], isPayment: true),
          _buildSummaryRow('คงเหลือ', bill['outstanding_amount'],
              isOutstanding: true),
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
      padding: EdgeInsets.symmetric(vertical: 2),
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
      case 'ชำระครบแล้ว':
        return Colors.green;
      case 'overdue':
      case 'เกินกำหนด':
        return Colors.red;
      case 'partial':
      case 'ชำระบางส่วน':
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

  void _showSuccessSnackBar(String message) {
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
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
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
                child: Text(message,
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'รายการบิลค่าเช่า',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadBills,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'ค้นหาด้วยชื่อผู้เช่า, เลขที่บิล, หรือเลขห้อง',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
                SizedBox(height: 12),

                // Status Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilter('all', 'ทั้งหมด', Colors.grey),
                      _buildStatusFilter('pending', 'รอชำระ', Colors.blue),
                      _buildStatusFilter(
                          'partial', 'ชำระบางส่วน', Colors.orange),
                      _buildStatusFilter('paid', 'ชำระแล้ว', Colors.green),
                      _buildStatusFilter('overdue', 'เกินกำหนด', Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bill List
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
                : _filteredBills.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredBills.length,
                        itemBuilder: (context, index) {
                          final bill = _filteredBills[index];
                          return _buildBillCard(bill);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to AddBillingScreen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddBillingScreen()),
          ).then((result) {
            if (result == true) {
              _loadBills();
            }
          });
        },
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildStatusFilter(String status, String label, Color color) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = status;
            _applyFilters();
          });
        },
        selectedColor: color,
        backgroundColor: color.withOpacity(0.1),
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'ไม่มีรายการบิลค่าเช่า',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'เพิ่มบิลค่าเช่าใหม่โดยกดปุ่ม + ด้านล่าง',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final status = bill['bill_status'] ?? 'pending';
    final isOverdue = status == 'overdue';
    final isPaid = status == 'paid';
    final isPartial = status == 'partial';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showBillDetails(bill),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOverdue
                  ? Colors.red.withOpacity(0.3)
                  : isPaid
                      ? Colors.green.withOpacity(0.3)
                      : isPartial
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill['bill_number'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          bill['tenant_full_name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'ห้อง ${bill['room_number']} - ${bill['branch_name']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _getStatusColor(status).withOpacity(0.3)),
                        ),
                        child: Text(
                          _getBillStatusText(status),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy')
                            .format(DateTime.parse(bill['due_date'])),
                        style: TextStyle(
                          color: isOverdue ? Colors.red : Colors.grey[600],
                          fontSize: 12,
                          fontWeight:
                              isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 12),
              Divider(height: 1),
              SizedBox(height: 12),

              // Amount Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ยอดรวม',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        Text(
                          '${NumberFormat('#,##0.00').format(bill['total_amount'] ?? 0)} บาท',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isPaid) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'คงเหลือ',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                          Text(
                            '${NumberFormat('#,##0.00').format(bill['outstanding_amount'] ?? 0)} บาท',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isPaid) ...[
                    ElevatedButton.icon(
                      onPressed: () => _showPaymentDialog(bill),
                      icon: Icon(Icons.payment, size: 16),
                      label: Text('รับชำระ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ],
              ),

              // Period Info
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ระยะเวลา: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(bill['billing_period_start']))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(bill['billing_period_end']))}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 12, color: Colors.grey[400]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }
}
