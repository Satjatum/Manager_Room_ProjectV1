import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/image_service.dart';
// Use app theme via Theme.of(context).colorScheme instead of fixed colors

class TenantPayBillUi extends StatefulWidget {
  final String invoiceId;
  const TenantPayBillUi({super.key, required this.invoiceId});

  @override
  State<TenantPayBillUi> createState() => _TenantPayBillUiState();
}

class _TenantPayBillUiState extends State<TenantPayBillUi> {
  bool _loading = true;
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _branchQrs = [];
  String? _selectedQrId;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _paymentDateTime = DateTime.now();

  XFile? _slipFile;
  bool _submitting = false;

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final inv = await InvoiceService.getInvoiceById(widget.invoiceId);
      if (inv == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบบิล')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final total = _asDouble(inv['total_amount']);
      final paid = _asDouble(inv['paid_amount']);
      final remain = (total - paid);
      _amountCtrl.text = remain > 0 ? remain.toStringAsFixed(2) : '0.00';

      final branchId = inv['rooms']?['branch_id'];
      List<Map<String, dynamic>> qrs = [];
      if (branchId != null && branchId.toString().isNotEmpty) {
        qrs = await PaymentService.getBranchQRCodes(branchId);
      }

      setState(() {
        _invoice = inv;
        _branchQrs = qrs;
        _selectedQrId = qrs.isNotEmpty ? qrs.first['qr_id'] : null;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSlip() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (file != null) {
      setState(() => _slipFile = file);
    }
  }

  Future<void> _submit() async {
    if (_invoice == null) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกจำนวนเงินให้ถูกต้อง')),
      );
      return;
    }
    if (_slipFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาอัปโหลดสลิปการโอนเงิน')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      Map<String, dynamic> uploadResult;
      if (kIsWeb) {
        final bytes = await _slipFile!.readAsBytes();
        uploadResult = await ImageService.uploadImageFromBytes(
          bytes,
          _slipFile!.name,
          'payment-slips',
          folder: widget.invoiceId,
          prefix: 'slip',
          context: 'invoice_${widget.invoiceId}',
        );
      } else {
        uploadResult = await ImageService.uploadImage(
          File(_slipFile!.path),
          'payment-slips',
          folder: widget.invoiceId,
          prefix: 'slip',
          context: 'invoice_${widget.invoiceId}',
        );
      }

      if (uploadResult['success'] != true) {
        throw uploadResult['message'] ?? 'อัปโหลดสลิปไม่สำเร็จ';
      }

      final result = await PaymentService.submitPaymentSlip(
        invoiceId: widget.invoiceId,
        tenantId: _invoice!['tenant_id'],
        qrId: _selectedQrId,
        paidAmount: amount,
        paymentDateTime: _paymentDateTime,
        slipImageUrl: uploadResult['url'],
        tenantNotes:
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'ส่งสลิปสำเร็จ')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'ส่งสลิปไม่สำเร็จ')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ชำระบิล/อัปโหลดสลิป'),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(scheme.primary)),
                  const SizedBox(height: 12),
                  const Text('กำลังโหลด...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 12),
                  _buildQrList(),
                  const SizedBox(height: 12),
                  _buildAmountCard(),
                  const SizedBox(height: 12),
                  _buildSlipUploadCard(),
                  const SizedBox(height: 12),
                  _buildNoteCard(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.upload),
                      label: const Text('ส่งสลิปเพื่อรอตรวจสอบ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final total = _asDouble(_invoice?['total_amount']);
    final paid = _asDouble(_invoice?['paid_amount']);
    final remain = (total - paid);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('สรุปยอด',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _row('ยอดรวม', total),
            _row('ชำระแล้ว', paid),
            _row('คงเหลือ', remain, emphasize: true),
          ],
        ),
      ),
    );
  }

  Widget _buildQrList() {
    final scheme = Theme.of(context).colorScheme;
    if (_branchQrs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: scheme.tertiary),
              const SizedBox(width: 8),
              const Expanded(child: Text('ยังไม่มีบัญชี/QR สำหรับสาขานี้')),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text('เลือกบัญชี/QR สำหรับโอน',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            ..._branchQrs.map((q) {
              final id = q['qr_id'].toString();
              final bank = (q['bank_name'] ?? '').toString();
              final accountName = (q['account_name'] ?? '').toString();
              final accountNumber = (q['account_number'] ?? '').toString();
              final image = (q['qr_code_image'] ?? '').toString();
              final isPrimary = (q['is_primary'] ?? false) == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _selectedQrId == id
                          ? scheme.primary
                          : Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RadioListTile<String>(
                  value: id,
                  groupValue: _selectedQrId,
                  onChanged: (v) => setState(() => _selectedQrId = v),
                  title: Text('$bank • $accountNumber'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(accountName),
                      if (isPrimary)
                        Text('บัญชีหลัก',
                            style: TextStyle(
                                color: scheme.secondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      if (image.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            image,
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('จำนวนเงินที่ชำระ',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.payments),
                border: OutlineInputBorder(),
                hintText: 'เช่น 5000.00',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${_paymentDateTime.day.toString().padLeft(2, '0')}/${_paymentDateTime.month.toString().padLeft(2, '0')}/${_paymentDateTime.year}  '
                  '${_paymentDateTime.hour.toString().padLeft(2, '0')}:${_paymentDateTime.minute.toString().padLeft(2, '0')}',
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _paymentDateTime,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 7)),
                      lastDate: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_paymentDateTime),
                    );
                    if (time == null) return;
                    setState(() {
                      _paymentDateTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('แก้ไขวันเวลา'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipUploadCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('อัปโหลดสลิป',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_slipFile == null)
              OutlinedButton.icon(
                onPressed: _pickSlip,
                icon: const Icon(Icons.upload_file),
                label: const Text('เลือกไฟล์สลิป'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kIsWeb)
                    FutureBuilder(
                      future: _slipFile!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              snapshot.data!,
                              height: 220,
                              fit: BoxFit.contain,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_slipFile!.path),
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickSlip,
                        icon: const Icon(Icons.refresh),
                        label: const Text('เปลี่ยนรูป'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _slipFile = null),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('ลบ'),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                      ),
                    ],
                  )
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('หมายเหตุผู้เช่า (ถ้ามี)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'เช่น โอนผ่านบัญชี xxx เวลา xx:xx น.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, double v, {bool emphasize = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          Text(
            v.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              fontSize: emphasize ? 16 : 14,
              color: emphasize ? scheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
