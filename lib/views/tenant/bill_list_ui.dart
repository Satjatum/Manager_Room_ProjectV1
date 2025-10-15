import 'package:flutter/material.dart';
import 'package:manager_room_project/middleware/auth_middleware.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/widgets/navbar.dart';
import 'package:manager_room_project/views/tenant/bill_detail_ui.dart';

class TenantBillsListPage extends StatefulWidget {
  const TenantBillsListPage({super.key});

  @override
  State<TenantBillsListPage> createState() => _TenantBillsListPageState();
}

class _TenantBillsListPageState extends State<TenantBillsListPage> {
  String _status = 'all';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

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
                    final total = _asDouble(bill['total_amount']);
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
                            builder: (_) => TenantBillDetailUi(
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
              onChanged: (v) =>
                  setState(() => _selectedMonth = v ?? _selectedMonth),
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
              onChanged: (v) =>
                  setState(() => _selectedYear = v ?? _selectedYear),
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
        style: TextStyle(
            color: _color(), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
