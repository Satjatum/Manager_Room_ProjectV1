import 'package:flutter/material.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/models/user_models.dart';
import 'package:manager_room_project/widgets/colors.dart';
import 'package:manager_room_project/widgets/navbar.dart';

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
  late TabController _tabController;
  UserModel? _currentUser;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = all (for superadmin)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final status = _tabStatus();
      final res = await PaymentService.listPaymentSlips(
        status: status,
        branchId: _currentBranchFilter(),
      );
      setState(() {
        _slips = res;
        _loading = false;
      });
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

  String _tabStatus() {
    switch (_tabController.index) {
      case 0:
        return 'pending';
      case 1:
        return 'verified';
      case 2:
        return 'rejected';
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
            Tab(text: 'รอตรวจสอบ'),
            Tab(text: 'อนุมัติแล้ว'),
            Tab(text: 'ถูกปฏิเสธ'),
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
                    child: _slips.isEmpty
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
                          ),
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

    return Card(
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
            if (canAction)
              Row(
                children: [
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
                ],
              )
            else
              const SizedBox.shrink(),
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
