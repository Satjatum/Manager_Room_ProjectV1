import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_room_project/views/superadmin/addbiling_ui.dart';
import 'package:manager_room_project/views/superadmin/billingdetail_ui.dart';
import 'package:manager_room_project/views/superadmin/payment_ui.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

final supabase = Supabase.instance.client;

class BillListScreen extends StatefulWidget {
  const BillListScreen({Key? key}) : super(key: key);

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  bool _isLoading = true;
  bool _isDownloading = false;
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _filteredBills = [];

  // Filters
  String _selectedStatus = 'all';
  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  // Current User
  dynamic _currentUser;

  // Controllers
  final _searchController = TextEditingController();

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

  Future<void> _downloadReceipt(Map<String, dynamic> bill) async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Load bill details for PDF
      final billDetails = await _loadBillDetailsForPDF(bill['bill_id']);

      // Generate PDF
      final pdf = await _generateReceiptPDF(bill, billDetails);

      // Save and share PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/receipt_${bill['bill_number']}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Share the PDF
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'ใบเสร็จค่าเช่า ${bill['bill_number']}',
        subject: 'ใบเสร็จค่าเช่า',
      );

      _showSuccessSnackBar('ดาวน์โหลดใบเสร็จสำเร็จ');
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการสร้างใบเสร็จ: ${e.toString()}');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadBillDetailsForPDF(String billId) async {
    try {
      // Load utility items
      final utilityItems = await supabase
          .from('bill_utility_details')
          .select('*')
          .eq('bill_id', billId);

      // Load other items
      final otherItems = await supabase
          .from('bill_other_items')
          .select('*')
          .eq('bill_id', billId);

      // Load payment history
      final paymentHistory = await supabase
          .from('payment_history')
          .select('*, users!inner(username)')
          .eq('bill_id', billId)
          .order('payment_date', ascending: false);

      return {
        'utilityItems': utilityItems,
        'otherItems': otherItems,
        'paymentHistory': paymentHistory,
      };
    } catch (e) {
      throw Exception('ไม่สามารถโหลดข้อมูลรายละเอียดบิลได้');
    }
  }

  Future<pw.Document> _generateReceiptPDF(
      Map<String, dynamic> bill, Map<String, dynamic> details) async {
    final pdf = pw.Document();

    // Try to load Thai fonts, fallback to default if not available
    pw.Font? regularFont;
    pw.Font? boldFont;

    try {
      final thailandFont =
          await rootBundle.load("assets/fonts/Sarabun-Regular.ttf");
      final thailandBoldFont =
          await rootBundle.load("assets/fonts/Sarabun-Bold.ttf");
      regularFont = pw.Font.ttf(thailandFont);
      boldFont = pw.Font.ttf(thailandBoldFont);
    } catch (e) {
      print('Could not load Thai fonts, using default fonts');
      // Use default fonts if Thai fonts are not available
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildPDFHeader(bill, regularFont, boldFont),
              pw.SizedBox(height: 20),

              // Bill Info
              _buildPDFBillInfo(bill, regularFont, boldFont),
              pw.SizedBox(height: 20),

              // Utility Items
              if (details['utilityItems'].isNotEmpty) ...[
                _buildPDFUtilitySection(
                    details['utilityItems'], regularFont, boldFont),
                pw.SizedBox(height: 15),
              ],

              // Other Items
              if (details['otherItems'].isNotEmpty) ...[
                _buildPDFOtherSection(
                    details['otherItems'], regularFont, boldFont),
                pw.SizedBox(height: 15),
              ],

              // Summary
              _buildPDFSummary(bill, regularFont, boldFont),
              pw.SizedBox(height: 20),

              // Payment History
              if (details['paymentHistory'].isNotEmpty) ...[
                _buildPDFPaymentHistory(
                    details['paymentHistory'], regularFont, boldFont),
                pw.SizedBox(height: 20),
              ],

              // Footer
              _buildPDFFooter(regularFont),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPDFHeader(
      Map<String, dynamic> bill, pw.Font? font, pw.Font? boldFont) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1565C0'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ใบเสร็จค่าเช่า / Rental Receipt',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 24,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'เลขที่: ${bill['bill_number']}',
            style: pw.TextStyle(
              font: font,
              fontSize: 16,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            'วันที่สร้าง: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(bill['created_at']))}',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFBillInfo(
      Map<String, dynamic> bill, pw.Font? font, pw.Font? boldFont) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ข้อมูลผู้เช่า / Tenant Information',
            style: pw.TextStyle(font: boldFont, fontSize: 16),
          ),
          pw.SizedBox(height: 10),
          _buildPDFInfoRow(
              'ชื่อผู้เช่า:', bill['tenant_full_name'], font, boldFont),
          _buildPDFInfoRow(
              'ห้อง:',
              '${bill['room_number']} - ${bill['room_name'] ?? ''}',
              font,
              boldFont),
          _buildPDFInfoRow('สาขา:', bill['branch_name'], font, boldFont),
          _buildPDFInfoRow(
              'ระยะเวลา:',
              '${DateFormat('dd/MM/yyyy').format(DateTime.parse(bill['billing_period_start']))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(bill['billing_period_end']))}',
              font,
              boldFont),
          _buildPDFInfoRow(
              'ครบกำหนดชำระ:',
              DateFormat('dd/MM/yyyy').format(DateTime.parse(bill['due_date'])),
              font,
              boldFont),
        ],
      ),
    );
  }

  pw.Widget _buildPDFInfoRow(
      String label, String value, pw.Font? font, pw.Font? boldFont) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child:
                pw.Text(label, style: pw.TextStyle(font: font, fontSize: 12)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(font: boldFont, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFUtilitySection(
      List<dynamic> items, pw.Font? font, pw.Font? boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ค่าสาธารณูปโภค / Utilities',
          style: pw.TextStyle(font: boldFont, fontSize: 16),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPDFTableCell('รายการ', boldFont, isHeader: true),
                _buildPDFTableCell('ครั้งก่อน', boldFont, isHeader: true),
                _buildPDFTableCell('ครั้งนี้', boldFont, isHeader: true),
                _buildPDFTableCell('ใช้', boldFont, isHeader: true),
                _buildPDFTableCell('จำนวนเงิน', boldFont, isHeader: true),
              ],
            ),
            // Data rows
            ...items
                .map((item) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(item['utility_name'] ?? '', font),
                        _buildPDFTableCell(
                            item['previous_reading']?.toString() ?? '0', font),
                        _buildPDFTableCell(
                            item['current_reading']?.toString() ?? '0', font),
                        _buildPDFTableCell(
                            item['consumption']?.toString() ?? '0', font),
                        _buildPDFTableCell(
                            '${NumberFormat('#,##0.00').format(item['amount'] ?? 0)} บาท',
                            font),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFOtherSection(
      List<dynamic> items, pw.Font? font, pw.Font? boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ค่าใช้จ่ายอื่นๆ / Other Charges',
          style: pw.TextStyle(font: boldFont, fontSize: 16),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPDFTableCell('รายการ', boldFont, isHeader: true),
                _buildPDFTableCell('จำนวน', boldFont, isHeader: true),
                _buildPDFTableCell('ราคา/หน่วย', boldFont, isHeader: true),
                _buildPDFTableCell('จำนวนเงิน', boldFont, isHeader: true),
              ],
            ),
            // Data rows
            ...items
                .map((item) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(item['item_name'] ?? '', font),
                        _buildPDFTableCell(
                            item['quantity']?.toString() ?? '0', font),
                        _buildPDFTableCell(
                            '${NumberFormat('#,##0.00').format(item['unit_price'] ?? 0)}',
                            font),
                        _buildPDFTableCell(
                            '${NumberFormat('#,##0.00').format(item['amount'] ?? 0)} บาท',
                            font),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFSummary(
      Map<String, dynamic> bill, pw.Font? font, pw.Font? boldFont) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#E3F2FD'),
        border: pw.Border.all(color: PdfColors.blue),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'สรุปยอดเงิน / Summary',
            style: pw.TextStyle(font: boldFont, fontSize: 16),
          ),
          pw.SizedBox(height: 10),
          _buildPDFSummaryRow('ค่าเช่าห้อง', bill['room_rent'], font, boldFont),
          _buildPDFSummaryRow(
              'ค่าสาธารณูปโภค', bill['total_utilities'], font, boldFont),
          _buildPDFSummaryRow(
              'ค่าใช้จ่ายอื่นๆ', bill['other_charges'], font, boldFont),
          pw.Divider(),
          _buildPDFSummaryRow('ยอดรวมย่อย', bill['subtotal'], font, boldFont,
              isBold: true),
          _buildPDFSummaryRow(
              'ส่วนลด', -(bill['discount'] ?? 0), font, boldFont,
              isNegative: true),
          _buildPDFSummaryRow('ภาษี', bill['tax_amount'], font, boldFont),
          _buildPDFSummaryRow('ค่าปรับ', bill['late_fee'], font, boldFont),
          pw.Divider(thickness: 2),
          _buildPDFSummaryRow(
              'ยอดรวมสุทธิ', bill['total_amount'], font, boldFont,
              isBold: true, isTotal: true),
          _buildPDFSummaryRow('ชำระแล้ว', bill['paid_amount'], font, boldFont,
              isPayment: true),
          _buildPDFSummaryRow(
              'คงเหลือ', bill['outstanding_amount'], font, boldFont,
              isOutstanding: true),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSummaryRow(
      String label, num amount, pw.Font? font, pw.Font? boldFont,
      {bool isBold = false,
      bool isTotal = false,
      bool isNegative = false,
      bool isPayment = false,
      bool isOutstanding = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: isBold || isTotal ? boldFont : font,
              fontSize: 12,
              color: isTotal
                  ? PdfColor.fromHex('#1565C0')
                  : isPayment
                      ? PdfColors.green
                      : isOutstanding
                          ? PdfColors.red
                          : PdfColors.black,
            ),
          ),
          pw.Text(
            '${isNegative && amount > 0 ? '-' : ''}${NumberFormat('#,##0.00').format(amount.abs())} บาท',
            style: pw.TextStyle(
              font: isBold || isTotal ? boldFont : font,
              fontSize: 12,
              color: isTotal
                  ? PdfColor.fromHex('#1565C0')
                  : isPayment
                      ? PdfColors.green
                      : isOutstanding
                          ? PdfColors.red
                          : isNegative
                              ? PdfColors.red
                              : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFPaymentHistory(
      List<dynamic> payments, pw.Font? font, pw.Font? boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ประวัติการชำระเงิน / Payment History',
          style: pw.TextStyle(font: boldFont, fontSize: 16),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPDFTableCell('วันที่/เวลา', boldFont, isHeader: true),
                _buildPDFTableCell('วิธีชำระ', boldFont, isHeader: true),
                _buildPDFTableCell('จำนวนเงิน', boldFont, isHeader: true),
                _buildPDFTableCell('ผู้รับ', boldFont, isHeader: true),
              ],
            ),
            // Data rows
            ...payments
                .map((payment) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(
                            DateFormat('dd/MM/yyyy HH:mm').format(
                                DateTime.parse(payment['payment_date'])),
                            font),
                        _buildPDFTableCell(
                            _getPaymentMethodText(payment['payment_method']),
                            font),
                        _buildPDFTableCell(
                            '${NumberFormat('#,##0.00').format(payment['payment_amount'])} บาท',
                            font),
                        _buildPDFTableCell(
                            payment['users']['username'] ?? '', font),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFTableCell(String text, pw.Font? font,
      {bool isHeader = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 11 : 10,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildPDFFooter(pw.Font? font) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Text(
          'ใบเสร็จนี้สร้างขึ้นโดยระบบจัดการหอพัก',
          style: pw.TextStyle(font: font, fontSize: 10),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'วันที่พิมพ์: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: pw.TextStyle(font: font, fontSize: 9),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
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
          // Filter Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: 'กรองข้อมูล',
            onSelected: (value) {
              if (value.startsWith('status_')) {
                setState(() {
                  _selectedStatus = value.replaceFirst('status_', '');
                });
              }
              _applyFilters();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'สถานะบิล',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'status_all',
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive,
                        size: 20, color: Colors.grey[600]),
                    SizedBox(width: 12),
                    Text('ทั้งหมด'),
                    Spacer(),
                    if (_selectedStatus == 'all')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status_pending',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('รอชำระ'),
                    Spacer(),
                    if (_selectedStatus == 'pending')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status_partial',
                child: Row(
                  children: [
                    Icon(Icons.pie_chart, size: 20, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('ชำระบางส่วน'),
                    Spacer(),
                    if (_selectedStatus == 'partial')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status_paid',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20, color: Colors.green),
                    SizedBox(width: 12),
                    Text('ชำระแล้ว'),
                    Spacer(),
                    if (_selectedStatus == 'paid')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status_overdue',
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('เกินกำหนด'),
                    Spacer(),
                    if (_selectedStatus == 'overdue')
                      Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _loadBills,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: 'ค้นหาด้วยชื่อผู้เช่า, เลขที่บิล, หรือเลขห้อง',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedStatus != 'all'
                ? 'ไม่พบรายการบิลตามเงื่อนไขที่กำหนด'
                : 'ไม่มีรายการบิลค่าเช่า',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          if (_searchQuery.isNotEmpty || _selectedStatus != 'all') ...[
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedStatus = 'all';
                });
                _applyFilters();
              },
              child: Text('ล้างตัวกรอง'),
            ),
          ] else ...[
            Text(
              'เพิ่มบิลค่าเช่าใหม่โดยกดปุ่ม + ด้านล่าง',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final status = bill['bill_status'] ?? 'pending';
    final isOverdue = status == 'overdue';
    final isPaid = status == 'paid';
    final isPartial = status == 'partial';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BillDetailScreen(
                billId: bill['bill_id'],
                onBillUpdated: _loadBills,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Bill Avatar
                    Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            AppColors.primary.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.receipt,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Bill Info
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            bill['tenant_full_name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ห้อง ${bill['room_number']} - ${bill['branch_name']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  ],
                ),

                SizedBox(height: 12),

                // Bill Info Section
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Amount Info
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ยอดรวม',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
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
                        ],
                      ),

                      SizedBox(height: 12),

                      // Period and Due Date
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ระยะเวลา',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                                Text(
                                  '${DateFormat('dd/MM/yyyy').format(DateTime.parse(bill['billing_period_start']))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(bill['billing_period_end']))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'ครบกำหนด',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(DateTime.parse(bill['due_date'])),
                                style: TextStyle(
                                  color:
                                      isOverdue ? Colors.red : Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: isOverdue
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BillDetailScreen(
                              billId: bill['bill_id'],
                              onBillUpdated: _loadBills,
                            ),
                          ),
                        ),
                        icon: Icon(Icons.visibility, size: 16),
                        label: Text('ดูรายละเอียด'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    // Show download button only for paid bills
                    if (isPaid) ...[
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isDownloading
                              ? null
                              : () => _downloadReceipt(bill),
                          icon: _isDownloading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey),
                                  ),
                                )
                              : Icon(Icons.download, size: 16),
                          label: Text(
                              _isDownloading ? 'กำลังสร้าง...' : 'ดาวน์โหลด'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange[700],
                            side: BorderSide(color: Colors.orange[700]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                    // Show payment button only for unpaid bills
                    if (!isPaid) ...[
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentScreen(
                                bill: bill,
                                onPaymentComplete: _loadBills,
                              ),
                            ),
                          ),
                          icon: Icon(Icons.payment, size: 16),
                          label: Text('รับชำระ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
