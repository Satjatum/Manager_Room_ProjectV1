import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bill;
  final VoidCallback? onPaymentComplete;

  const PaymentScreen({
    Key? key,
    required this.bill,
    this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;

  // Controllers
  final _paymentAmountController = TextEditingController();
  final _paymentNotesController = TextEditingController();
  final _paymentReferenceController = TextEditingController();

  // Form variables
  String _selectedPaymentMethod = 'cash';
  bool _isPartialPayment = false;

  // Current User
  dynamic _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.getCurrentUser();
    _paymentAmountController.text =
        widget.bill['outstanding_amount'].toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'รับชำระเงิน',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill Information Card
            _buildBillInfoCard(),
            SizedBox(height: 20),

            // Payment Amount Section
            _buildPaymentAmountSection(),
            SizedBox(height: 20),

            // Payment Method Section
            _buildPaymentMethodSection(),
            SizedBox(height: 20),

            // Payment Reference Section (for non-cash payments)
            if (_selectedPaymentMethod != 'cash') ...[
              _buildPaymentReferenceSection(),
              SizedBox(height: 20),
            ],

            // Payment Notes Section
            _buildPaymentNotesSection(),
            SizedBox(height: 30),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBillInfoCard() {
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
                      widget.bill['bill_number'] ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.bill['tenant_full_name'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
              Icon(Icons.home, color: Colors.white.withOpacity(0.8), size: 16),
              SizedBox(width: 8),
              Text(
                'ห้อง ${widget.bill['room_number']} - ${widget.bill['branch_name']}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Text(
                '${NumberFormat('#,##0.00').format(widget.bill['total_amount'])} บาท',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ชำระแล้ว:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Text(
                '${NumberFormat('#,##0.00').format(widget.bill['paid_amount'])} บาท',
                style: TextStyle(
                  color: Colors.green[200],
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'คงเหลือ:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Text(
                '${NumberFormat('#,##0.00').format(widget.bill['outstanding_amount'])} บาท',
                style: TextStyle(
                  color: Colors.yellow[200],
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAmountSection() {
    return _buildCard(
      title: 'จำนวนเงินที่รับ',
      icon: Icons.monetization_on,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Partial Payment Toggle
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isPartialPayment,
                  onChanged: (value) {
                    setState(() {
                      _isPartialPayment = value ?? false;
                      if (!_isPartialPayment) {
                        _paymentAmountController.text =
                            widget.bill['outstanding_amount'].toString();
                      } else {
                        _paymentAmountController.clear();
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ชำระบางส่วน',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'เลือกหากต้องการรับชำระไม่เต็มจำนวน',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Amount Input
          Text(
            'จำนวนเงิน *',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _paymentAmountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              suffixText: 'บาท',
              prefixIcon: Icon(Icons.monetization_on, color: AppColors.primary),
              hintText: 'ระบุจำนวนเงินที่รับ',
            ),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),

          // Quick Amount Buttons
          Text(
            'จำนวนที่ใช้บ่อย',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickAmountButton(
                  'ครบจำนวน', widget.bill['outstanding_amount']),
              _buildQuickAmountButton('1,000', 1000),
              _buildQuickAmountButton('2,000', 2000),
              _buildQuickAmountButton('5,000', 5000),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(String label, num amount) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _paymentAmountController.text = amount.toString();
          _isPartialPayment = amount < widget.bill['outstanding_amount'];
        });
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildPaymentMethodSection() {
    return _buildCard(
      title: 'วิธีการชำระ',
      icon: Icons.payment,
      child: Column(
        children: [
          _buildPaymentMethodOption(
              'cash', 'เงินสด', Icons.money, 'รับชำระด้วยเงินสดทันที'),
          SizedBox(height: 12),
          _buildPaymentMethodOption('transfer', 'โอนเงิน',
              Icons.account_balance, 'โอนผ่านธนาคาร / Mobile Banking'),
          SizedBox(height: 12),
          _buildPaymentMethodOption('card', 'บัตรเครดิต/เดบิต',
              Icons.credit_card, 'ชำระด้วยบัตรเครดิตหรือเดบิต'),
          SizedBox(height: 12),
          _buildPaymentMethodOption(
              'check', 'เช็ค', Icons.receipt_long, 'รับชำระด้วยเช็คธนาคาร'),
          SizedBox(height: 12),
          _buildPaymentMethodOption('online', 'ออนไลน์', Icons.phone_android,
              'ชำระผ่านแอปพลิเคชัน / QR Code'),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption(
      String value, String title, IconData icon, String description) {
    final isSelected = _selectedPaymentMethod == value;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _selectedPaymentMethod,
        onChanged: (newValue) {
          setState(() {
            _selectedPaymentMethod = newValue!;
          });
        },
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey[600],
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : Colors.black,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        activeColor: AppColors.primary,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildPaymentReferenceSection() {
    return _buildCard(
      title: 'เลขที่อ้างอิง',
      icon: Icons.confirmation_number,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'เลขที่อ้างอิง / Transaction ID',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _paymentReferenceController,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              prefixIcon: Icon(Icons.tag, color: AppColors.primary),
              hintText: 'ระบุเลขที่อ้างอิงการชำระ (ถ้ามี)',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'เช่น เลขที่ Transaction, เลขที่เช็ค หรือ Reference Number',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentNotesSection() {
    return _buildCard(
      title: 'หมายเหตุการชำระ',
      icon: Icons.note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'หมายเหตุเพิ่มเติม',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _paymentNotesController,
            maxLines: 3,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              hintText: 'หมายเหตุเพิ่มเติม (ถ้ามี)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'ยกเลิก',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'บันทึกการชำระ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'กรุณาตรวจสอบข้อมูลให้ถูกต้องก่อนบันทึก เมื่อบันทึกแล้วจะไม่สามารถแก้ไขได้',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[800],
                  ),
                ),
              ),
            ],
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

  Future<void> _processPayment() async {
    final paymentAmount = double.tryParse(_paymentAmountController.text);
    if (paymentAmount == null || paymentAmount <= 0) {
      _showErrorSnackBar('กรุณาใส่จำนวนเงินที่ถูกต้อง');
      return;
    }

    if (paymentAmount > widget.bill['outstanding_amount']) {
      final confirm = await _showConfirmationDialog(
        title: 'ยืนยันการชำระ',
        message:
            'จำนวนเงินที่รับมากกว่ายอดค้างชำระ ต้องการดำเนินการต่อหรือไม่?',
      );

      if (!confirm) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Insert payment record
      await supabase.from('payment_history').insert({
        'bill_id': widget.bill['bill_id'],
        'payment_amount': paymentAmount,
        'payment_method': _selectedPaymentMethod,
        'payment_reference': _paymentReferenceController.text.trim().isNotEmpty
            ? _paymentReferenceController.text.trim()
            : null,
        'payment_notes': _paymentNotesController.text.trim().isNotEmpty
            ? _paymentNotesController.text.trim()
            : null,
        'received_by': _currentUser?.userId,
        'payment_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSuccessSnackBar('บันทึกการชำระเงินสำเร็จ');

      // Call the callback to refresh parent screens
      widget.onPaymentComplete?.call();

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar(
          'เกิดข้อผิดพลาดในการบันทึกการชำระเงิน: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.help_outline, color: Colors.orange[600]),
                SizedBox(width: 12),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('ดำเนินการ'),
              ),
            ],
          ),
        ) ??
        false;
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
              child: Text(
                message,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
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

  @override
  void dispose() {
    _paymentAmountController.dispose();
    _paymentNotesController.dispose();
    _paymentReferenceController.dispose();
    super.dispose();
  }
}
