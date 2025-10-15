import 'package:flutter/material.dart';
import 'package:manager_room_project/middleware/auth_middleware.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/widgets/navbar.dart';

class TenantBillsListPage extends StatefulWidget {
  const TenantBillsListPage({super.key});

  @override
  State<TenantBillsListPage> createState() => _TenantBillsListPageState();
}

class _TenantBillsListPageState extends State<TenantBillsListPage> {
  String _status = 'all';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  Future<List<Map<String, dynamic>>> _loadBills() async {
    final user = await AuthMiddleware.getCurrentUser();
    if (user == null || user.tenantId == null) return [];

    return InvoiceService.getAllInvoices(
      tenantId: user.tenantId,
      invoiceMonth: _selectedMonth,
      invoiceYear: _selectedYear,
      status: _status,
      orderBy: 'invoice_year',
      ascending: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('บิลของฉัน'),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadBills(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('ไม่พบรายการบิล'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bill = items[index];
                    final month = bill['invoice_month'] ?? _selectedMonth;
                    final year = bill['invoice_year'] ?? _selectedYear;
                    final total = (bill['total_amount'] ?? 0).toDouble();
                    final status = (bill['invoice_status'] ?? '').toString();
                    final number = (bill['invoice_number'] ?? '').toString();

                    return ListTile(
                      title: Text('เดือน $month/$year'),
                      subtitle: Text('เลขบิล: $number'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            total.toStringAsFixed(2),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _StatusChip(status: status),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TenantBillDetailPage(
                              invoiceId: bill['invoice_id'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          // Month
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedMonth,
              decoration: const InputDecoration(
                labelText: 'เดือน',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: List.generate(12, (i) => i + 1)
                  .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMonth = v ?? _selectedMonth),
              onSaved: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // Year (current +/- 1)
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(
                labelText: 'ปี',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _yearOptions()
                  .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                  .toList(),
              onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),
            ),
          ),
          const SizedBox(width: 8),
          // Status
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'สถานะ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                DropdownMenuItem(value: 'pending', child: Text('ค้างชำระ')),
                DropdownMenuItem(value: 'partial', child: Text('ชำระบางส่วน')),
                DropdownMenuItem(value: 'paid', child: Text('ชำระแล้ว')),
                DropdownMenuItem(value: 'overdue', child: Text('เกินกำหนด')),
                DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('กรอง'),
          ),
        ],
      ),
    );
  }

  List<int> _yearOptions() {
    final now = DateTime.now().year;
    return [now - 1, now, now + 1];
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color().withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color().withOpacity(0.3)),
      ),
      child: Text(
        _label(),
        style: TextStyle(color: _color(), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class TenantBillDetailPage extends StatelessWidget {
  final String invoiceId;
  const TenantBillDetailPage({super.key, required this.invoiceId});

  Future<Map<String, dynamic>?> _load() {
    return InvoiceService.getInvoiceById(invoiceId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดบิล')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('ไม่พบบิล'));
          }

          final status = (data['invoice_status'] ?? '').toString();
          final rental = (data['rental_amount'] ?? 0).toDouble();
          final utilities = (data['utilities_amount'] ?? 0).toDouble();
          final others = (data['other_charges'] ?? 0).toDouble();
          final discount = (data['discount_amount'] ?? 0).toDouble();
          final lateFee = (data['late_fee_amount'] ?? 0).toDouble();
          final subtotal = (data['subtotal'] ?? 0).toDouble();
          final total = (data['total_amount'] ?? 0).toDouble();
          final paid = (data['paid_amount'] ?? 0).toDouble();
          final remain = (total - paid);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('เลขบิล: ${data['invoice_number'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('ห้อง: ${data['room_number'] ?? '-'}'),
                Text('ผู้เช่า: ${data['tenant_name'] ?? '-'}'),
                const SizedBox(height: 16),
                _row('ค่าเช่า', rental),
                _row('ค่าสาธารณูปโภค', utilities),
                _row('ค่าใช้จ่ายอื่น', others),
                const Divider(),
                _row('ส่วนลด', -discount),
                _row('ค่าปรับล่าช้า', lateFee),
                const Divider(),
                _row('ยอดก่อนชำระ', subtotal),
                _row('ยอดรวม', total, emphasize: true),
                _row('ชำระแล้ว', paid),
                _row('คงเหลือ', remain, emphasize: true),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (status != 'paid')
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final result = await InvoiceService.updateInvoicePaymentStatus(invoiceId, remain > 0 ? remain : 0);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result['message'] ?? 'ดำเนินการเสร็จสิ้น')),
                              );
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('ชำระเงิน'),
                        ),
                      ),
                    if (status == 'paid')
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ดาวน์โหลดสลิป: ยังไม่รองรับ')),
                            );
                          },
                          child: const Text('ดาวน์โหลดสลิป'),
                        ),
                      ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, double value, {bool emphasize = false}) {
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
}
