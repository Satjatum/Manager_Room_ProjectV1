import 'package:flutter/material.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/models/user_models.dart';
import 'package:manager_room_project/widgets/colors.dart';
import 'package:manager_room_project/widgets/navbar.dart';
import 'package:manager_room_project/views/sadmin/payment_verification_detail_ui.dart';

class PaymentVerificationPage extends StatefulWidget {
  const PaymentVerificationPage({super.key});

  @override
  State<PaymentVerificationPage> createState() =>
      _PaymentVerificationPageState();
}

class _PaymentVerificationPageState extends State<PaymentVerificationPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _slips = [];
  List<Map<String, dynamic>> _invoices = [];
  late TabController _tabController;
  UserModel? _currentUser;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = all (for superadmin)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _load();
    });
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.getCurrentUser();
      List<Map<String, dynamic>> branches = [];
      String? initialBranchId;

      if (user != null) {
        branches = await BranchService.getBranchesByUser();
        if (user.userRole == UserRole.admin) {
          if (branches.isNotEmpty)
            initialBranchId = branches.first['branch_id'];
        } else if (user.userRole == UserRole.superAdmin) {
          initialBranchId = null; // default see all
        }
      }

      setState(() {
        _currentUser = user;
        _branches = branches;
        _selectedBranchId = initialBranchId;
      });

      await _load();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_tabController.index == 0) {
        // ค้างชำระ: แสดงบิลที่ยังไม่ชำระ (pending/partial/overdue)
        final all = await InvoiceService.getAllInvoices(
          branchId: _currentBranchFilter(),
          limit: 500,
        );
        final unpaid = all.where((inv) {
          final st = (inv['invoice_status'] ?? '').toString();
          return st != 'paid' && st != 'cancelled';
        }).toList();
        setState(() {
          _invoices = unpaid;
          _slips = [];
          _loading = false;
        });
      } else {
        final status = _slipTabStatus();
        final res = await PaymentService.listPaymentSlips(
          status: status,
          branchId: _currentBranchFilter(),
        );
        setState(() {
          _slips = res;
          _invoices = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
        );
      }
    }
  }

  String? _currentBranchFilter() {
    if (_currentUser == null) return null;
    if (_currentUser!.userRole == UserRole.superAdmin) {
      return _selectedBranchId; // null = all branches
    }
    if (_currentUser!.userRole == UserRole.admin) {
      return _selectedBranchId ??
          (_branches.isNotEmpty
              ? _branches.first['branch_id'] as String
              : null);
    }
    return null;
  }

  String _slipTabStatus() {
    // index 1..3 => slips
    switch (_tabController.index) {
      case 1:
        return 'pending'; // รอดำเนินการ: มีสลิปรออนุมัติ
      case 2:
        return 'verified'; // ชำระแล้ว: อนุมัติแล้ว
      case 3:
        return 'rejected'; // ปฏิเสธ
      default:
        return 'pending';
    }
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _approveSlip(Map<String, dynamic> slip) async {
    final controller = TextEditingController(
      text: (_asDouble(slip['paid_amount'])).toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('อนุมัติการชำระเงิน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'จำนวนเงินที่อนุมัติ',
                prefixIcon: Icon(Icons.payments),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ (ถ้ามี)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final amount = double.tryParse(controller.text) ?? 0;
    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('จำนวนเงินไม่ถูกต้อง')),
        );
      }
      return;
    }

    try {
      setState(() => _loading = true);
      final result = await PaymentService.verifySlip(
        slipId: slip['slip_id'],
        approvedAmount: amount,
        paymentMethod: 'transfer',
        adminNotes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'สำเร็จ')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อนุมัติไม่สำเร็จ: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectSlip(Map<String, dynamic> slip) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ปฏิเสธสลิป'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'ระบุเหตุผล',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ปฏิเสธ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      setState(() => _loading = true);
      final result = await PaymentService.rejectSlip(
        slipId: slip['slip_id'],
        reason: reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'สำเร็จ')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธไม่สำเร็จ: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจสอบสลิปชำระเงิน'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ค้างชำระ'),
            Tab(text: 'รอดำเนินการ'),
            Tab(text: 'ชำระแล้ว'),
            Tab(text: 'ปฏิเสธ'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  _buildBranchFilter(),
                  Expanded(
                    child: (_tabController.index == 0)
                        ? (_invoices.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('ไม่พบข้อมูล')),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _invoices.length,
                                itemBuilder: (context, index) {
                                  final inv = _invoices[index];
                                  return _invoiceCard(inv);
                                },
                              ))
                        : (_slips.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('ไม่พบข้อมูล')),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _slips.length,
                                itemBuilder: (context, index) {
                                  final s = _slips[index];
                                  return _slipCard(s);
                                },
                              )),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildBranchFilter() {
    // SuperAdmin: show dropdown for all branches (with 'ทั้งหมด')
    // Admin: if multiple managed branches, allow selection; if single, show label only
    if (_currentUser == null) return const SizedBox.shrink();

    final isSuper = _currentUser!.userRole == UserRole.superAdmin;
    final isAdmin = _currentUser!.userRole == UserRole.admin;

    if (!isSuper && !isAdmin) return const SizedBox.shrink();

    if (_branches.isEmpty) {
      return const SizedBox.shrink();
    }

    final options = [
      if (isSuper)
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('ทุกสาขา'),
        ),
      ..._branches.map((b) => DropdownMenuItem<String>(
            value: b['branch_id'] as String,
            child: Text(b['branch_name']?.toString() ?? '-'),
          )),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          const Icon(Icons.apartment, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: DropdownButton<String?>(
                value: _selectedBranchId,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: options,
                onChanged: (val) async {
                  setState(() {
                    _selectedBranchId = val;
                  });
                  await _load();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slipCard(Map<String, dynamic> s) {
    final amount = _asDouble(s['paid_amount']);
    final status = (s['slip_status'] ?? 'pending').toString();
    final createdAt = (s['created_at'] ?? '').toString();
    final canAction = status == 'pending';

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentVerificationDetailPage(
              slipId: (s['slip_id'] ?? '').toString(),
            ),
          ),
        );
        if (mounted) await _load();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // slip image
                if ((s['slip_image'] ?? '').toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      s['slip_image'],
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image_not_supported),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            (s['invoice_number'] ?? '-').toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          _statusChip(status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('ผู้เช่า: ${(s['tenant_name'] ?? '-')}'),
                      Text(
                          'ห้อง: ${(s['room_number'] ?? '-')} • สาขา: ${(s['branch_name'] ?? '-')}'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.payments, size: 16),
                          const SizedBox(width: 6),
                          Text('${amount.toStringAsFixed(2)} บาท',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                          const Spacer(),
                          const Icon(Icons.schedule,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(createdAt.split('T').first),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (canAction) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectSlip(s),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('ปฏิเสธ',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveSlip(s),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('อนุมัติ',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentVerificationDetailPage(
                              slipId: (s['slip_id'] ?? '').toString(),
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('รายละเอียด'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _invoiceCard(Map<String, dynamic> inv) {
    double _asDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }
    final total = _asDouble(inv['total_amount']);
    final paid = _asDouble(inv['paid_amount']);
    final remain = total - paid;
    final status = (inv['invoice_status'] ?? '').toString();
    final due = (inv['due_date'] ?? '').toString();

    Color sc;
    String st;
    switch (status) {
      case 'overdue':
        sc = Colors.red;
        st = 'เกินกำหนด';
        break;
      case 'partial':
        sc = Colors.orange;
        st = 'ชำระบางส่วน';
        break;
      case 'pending':
      default:
        sc = Colors.blueGrey;
        st = 'ค้างชำระ';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 16),
                const SizedBox(width: 6),
                Text(
                  (inv['invoice_number'] ?? '-').toString(),
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.1),
                    border: Border.all(color: sc.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    st,
                    style: TextStyle(
                        color: sc, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (due.isNotEmpty) ...[
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(due.split('T').first),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text('ผู้เช่า: ${(inv['tenant_name'] ?? '-')}'),
            Text('ห้อง: ${(inv['room_number'] ?? '-')} • สาขา: ${(inv['branch_name'] ?? '-')}'),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16),
                const SizedBox(width: 6),
                Text('รวม ${total.toStringAsFixed(2)} บาท',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Text('ชำระแล้ว ${paid.toStringAsFixed(2)}'),
                const Spacer(),
                Text('คงเหลือ ${remain.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color c;
    String t;
    switch (status) {
      case 'verified':
        c = Colors.green;
        t = 'อนุมัติแล้ว';
        break;
      case 'rejected':
        c = Colors.red;
        t = 'ถูกปฏิเสธ';
        break;
      default:
        c = Colors.orange;
        t = 'รอตรวจสอบ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        border: Border.all(color: c.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
