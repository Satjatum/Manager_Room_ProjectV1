import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

class AddBillingScreen extends StatefulWidget {
  final String? preSelectedTenantId;
  final String? preSelectedBranchId;

  const AddBillingScreen({
    Key? key,
    this.preSelectedTenantId,
    this.preSelectedBranchId,
  }) : super(key: key);

  @override
  State<AddBillingScreen> createState() => _AddBillingScreenState();
}

class _AddBillingScreenState extends State<AddBillingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Form Controllers
  final _roomRentController = TextEditingController();
  final _discountController = TextEditingController();
  final _taxAmountController = TextEditingController();
  final _lateFeeController = TextEditingController();
  final _notesController = TextEditingController();

  // Billing Data
  String? _selectedTenantId;
  String? _selectedBranchId;
  String? _selectedOtherItemTemplate;
  DateTime _billingPeriodStart = DateTime.now().subtract(Duration(days: 30));
  DateTime _billingPeriodEnd = DateTime.now();
  DateTime _dueDate = DateTime.now().add(Duration(days: 7));

  // Data Lists
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _utilityTypes = [];
  List<Map<String, dynamic>> _utilityItems = [];
  List<Map<String, dynamic>> _otherItems = [];
  List<Map<String, dynamic>> _otherItemTemplates =
      []; // Templates for other items
  Map<String, dynamic>? _selectedTenant;
  Map<String, dynamic>? _selectedRoom;

  // Current User
  dynamic _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.getCurrentUser();
    _selectedTenantId = widget.preSelectedTenantId;
    _selectedBranchId = widget.preSelectedBranchId;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      await Future.wait([
        _loadBranches(),
        _loadUtilityTypes(),
        _loadOtherItemTemplates(),
      ]);

      // For admin, auto-select their branch
      if (_currentUser?.isAdmin == true &&
          !(_currentUser?.isSuperAdmin == true)) {
        _selectedBranchId = _currentUser?.branchId;
      }

      if (_selectedBranchId != null) {
        await _loadTenants();
      }

      if (_selectedTenantId != null) {
        await _loadTenantDetails(_selectedTenantId!);
      }
    } catch (e) {
      print('Error loading data: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadBranches() async {
    try {
      if (_currentUser?.isSuperAdmin == true) {
        final response = await supabase
            .from('branches')
            .select('*')
            .eq('branch_status', 'active')
            .order('branch_name');

        setState(() {
          _branches = List<Map<String, dynamic>>.from(response);
        });
      } else if (_currentUser?.isAdmin == true &&
          _currentUser?.branchId != null) {
        // Admin ปกติเห็นเฉพาะสาขาของตัวเอง
        final response = await supabase
            .from('branches')
            .select('*')
            .eq('branch_id', _currentUser!.branchId!)
            .eq('branch_status', 'active')
            .order('branch_name');

        setState(() {
          _branches = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error loading branches: $e');
    }
  }

  Future<void> _loadTenants() async {
    if (_selectedBranchId == null) return;

    try {
      // ใช้ตาราง tenants แทน tenant_details view เพื่อให้ได้ branch_id
      final response = await supabase
          .from('tenants')
          .select('''
            tenant_id,
            tenant_full_name,
            tenant_phone,
            tenant_card,
            tenant_in,
            tenant_out,
            tenant_status,
            room_id,
            branch_id,
            rooms!inner(
              room_number,
              room_name,
              room_rate
            )
          ''')
          .eq('branch_id', _selectedBranchId!)
          .eq('tenant_status', 'active')
          .order('tenant_full_name');

      // แปลงข้อมูลให้อยู่ในรูปแบบที่ใช้ได้
      final tenants = response.map((tenant) {
        final room = tenant['rooms'] as Map<String, dynamic>;
        return {
          'tenant_id': tenant['tenant_id'],
          'tenant_full_name': tenant['tenant_full_name'],
          'tenant_phone': tenant['tenant_phone'],
          'tenant_card': tenant['tenant_card'],
          'tenant_in': tenant['tenant_in'],
          'tenant_out': tenant['tenant_out'],
          'tenant_status': tenant['tenant_status'],
          'room_id': tenant['room_id'],
          'branch_id': tenant['branch_id'],
          'room_number': room['room_number'],
          'room_name': room['room_name'],
          'room_rate': room['room_rate'],
        };
      }).toList();

      setState(() {
        _tenants = List<Map<String, dynamic>>.from(tenants);
        // Reset selected tenant if branch changes
        if (_selectedTenantId != null &&
            !_tenants.any((t) => t['tenant_id'] == _selectedTenantId)) {
          _selectedTenantId = null;
          _selectedTenant = null;
        }
      });
    } catch (e) {
      print('Error loading tenants: $e');
    }
  }

  Future<void> _loadUtilityTypes() async {
    try {
      final response = await supabase
          .from('utility_types')
          .select('*')
          .eq('is_active', true)
          .order('display_order');

      setState(() {
        _utilityTypes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading utility types: $e');
    }
  }

  Future<void> _loadOtherItemTemplates() async {
    try {
      final response = await supabase
          .from('utility_types')
          .select('*')
          .eq('is_metered', false)
          .eq('is_active', true)
          .order('display_order');
      List<Map<String, dynamic>> templates =
          List<Map<String, dynamic>>.from(response);

      setState(() {
        _otherItemTemplates = templates;
      });
    } catch (e) {
      print('Error loading other item templates: $e');
      // If table doesn't exist, create default templates
      _otherItemTemplates = [
        {'template_name': 'ค่าทำความสะอาด', 'default_price': 200.0},
        {'template_name': 'ค่าขยะ', 'default_price': 50.0},
        {'template_name': 'ค่าจอดรถ', 'default_price': 300.0},
        {'template_name': 'ค่าใช้จ่ายอื่นๆ', 'default_price': 0.0},
      ];
    }
  }

  Future<void> _loadTenantDetails(String tenantId) async {
    try {
      // 1. ดึงข้อมูล tenant ก่อน
      final tenantResponse = await supabase
          .from('tenants')
          .select('*')
          .eq('tenant_id', tenantId)
          .single();

      print('Tenant data: $tenantResponse');

      // 2. ดึงข้อมูล room
      final roomResponse = await supabase
          .from('rooms')
          .select('*')
          .eq('room_id', tenantResponse['room_id'])
          .single();

      print('Room data: $roomResponse');

      // 3. ดึงข้อมูล branch
      final branchResponse = await supabase
          .from('branches')
          .select('*')
          .eq('branch_id', tenantResponse['branch_id'])
          .single();

      print('Branch data: $branchResponse');

      setState(() {
        // รวมข้อมูลทั้งหมด
        _selectedTenant = {
          ...tenantResponse,
          'room_number': roomResponse['room_number'],
          'room_name': roomResponse['room_name'],
          'room_rate': roomResponse['room_rate'],
          'branch_name': branchResponse['branch_name'],
        };

        _roomRentController.text =
            (roomResponse['room_rate']?.toString() ?? '0');
        _selectedBranchId = tenantResponse['branch_id'];
      });

      final roomId = tenantResponse['room_id'] as String?;
      if (roomId != null) {
        await _loadMeterReadings(roomId);
      }

      _initializeUtilityItems();
      _initializeOtherItems();
    } catch (e) {
      print('Error loading tenant details: $e');
      if (mounted) {
        _showErrorSnackBar('ไม่สามารถโหลดข้อมูลผู้เช่าได้: ${e.toString()}');
      }
    }
  }

  Future<void> _loadMeterReadings(String roomId) async {
    try {
      final metersResponse = await supabase.from('room_meters').select('''
          *,
          utility_types!inner(*)
        ''').eq('room_id', roomId).eq('is_active', true);

      for (var meter in metersResponse) {
        // เพิ่ม null check
        final meterId = meter['meter_id'] as String?;
        if (meterId == null) continue;

        // Get latest reading
        final latestReading = await supabase
            .from('meter_readings')
            .select('*')
            .eq('meter_id', meterId)
            .order('reading_date', ascending: false)
            .limit(1)
            .maybeSingle();

        // Get previous reading
        final previousReading = await supabase
            .from('meter_readings')
            .select('*')
            .eq('meter_id', meterId)
            .order('reading_date', ascending: false)
            .limit(1)
            .range(1, 1)
            .maybeSingle();

        meter['latest_reading'] = latestReading;
        meter['previous_reading'] = previousReading;
      }

      if (mounted) {
        setState(() {
          // Update utility items with meter data
          for (var utility in _utilityTypes) {
            final meterList = metersResponse
                .where(
                  (m) => m['utility_type_id'] == utility['utility_type_id'],
                )
                .toList();

            final meter = meterList.isNotEmpty ? meterList.first : null;

            if (meter != null && utility['is_metered'] == true) {
              final utilityItemList = _utilityItems
                  .where(
                    (item) =>
                        item['utility_type_id'] == utility['utility_type_id'],
                  )
                  .toList();

              final utilityItem =
                  utilityItemList.isNotEmpty ? utilityItemList.first : null;

              if (utilityItem != null) {
                utilityItem['meter_id'] = meter['meter_id'];
                utilityItem['previous_reading'] =
                    (meter['previous_reading']?['current_reading'] as num?)
                            ?.toDouble() ??
                        0.0;
                utilityItem['current_reading'] =
                    (meter['latest_reading']?['current_reading'] as num?)
                            ?.toDouble() ??
                        0.0;
                utilityItem['consumption'] =
                    (utilityItem['current_reading'] ?? 0.0) -
                        (utilityItem['previous_reading'] ?? 0.0);
                _calculateUtilityAmount(utilityItem);
              }
            }
          }
        });
      }
    } catch (e) {
      print('Error loading meter readings: $e');
    }
  }

  void _initializeUtilityItems() {
    _utilityItems.clear();
    for (var utility in _utilityTypes) {
      if (utility['is_metered'] == true) {
        _utilityItems.add({
          'utility_type_id': utility['utility_type_id'],
          'type_name': utility['type_name'],
          'unit_name': utility['unit_name'],
          'is_metered': utility['is_metered'],
          'previous_reading': 0.0,
          'current_reading': 0.0,
          'consumption': 0.0,
          'rate_per_unit': utility['default_rate'] ?? 0.0,
          'minimum_charge': 0.0,
          'fixed_charge': 0.0,
          'amount': 0.0,
          'meter_id': null,
        });
      }
    }
  }

  void _initializeOtherItems() {
    // ไม่ต้องเพิ่มรายการอัตโนมัติ ให้ผู้ใช้เลือกเองจาก dropdown
    _otherItems.clear();

    // เก็บไว้เฉพาะรายการที่ผู้ใช้เพิ่มเข้ามาแล้วเท่านั้น
    // ไม่เพิ่ม utility charges (non-metered) อัตโนมัติ
  }

  void _calculateUtilityAmount(Map<String, dynamic> item) {
    final consumption = item['consumption'] ?? 0.0;
    final ratePerUnit = item['rate_per_unit'] ?? 0.0;
    final minimumCharge = item['minimum_charge'] ?? 0.0;
    final fixedCharge = item['fixed_charge'] ?? 0.0;

    final baseAmount = consumption * ratePerUnit;
    final totalAmount =
        (baseAmount > minimumCharge ? baseAmount : minimumCharge) + fixedCharge;

    setState(() {
      item['amount'] = totalAmount;
    });
  }

  void _calculateOtherAmount(Map<String, dynamic> item) {
    final quantity = item['quantity'] ?? 0.0;
    final unitPrice = item['unit_price'] ?? 0.0;

    setState(() {
      item['amount'] = quantity * unitPrice;
    });
  }

  void _addOtherItem(String templateName, double defaultPrice) {
    setState(() {
      _otherItems.add({
        'item_name': templateName,
        'item_description': '',
        'quantity': 1.0,
        'unit_price': defaultPrice,
        'amount': defaultPrice,
        'is_utility': false,
      });
    });
  }

  void _removeOtherItem(int index) {
    setState(() {
      _otherItems.removeAt(index);
    });
  }

  double _calculateSubtotal() {
    final roomRent = double.tryParse(_roomRentController.text) ?? 0.0;
    final totalUtilities =
        _utilityItems.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    final otherCharges =
        _otherItems.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));

    return roomRent + totalUtilities + otherCharges;
  }

  double _calculateTotal() {
    final subtotal = _calculateSubtotal();
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final tax = double.tryParse(_taxAmountController.text) ?? 0.0;
    final lateFee = double.tryParse(_lateFeeController.text) ?? 0.0;

    return subtotal - discount + tax + lateFee;
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    DateTime initialDate;
    DateTime firstDate;
    DateTime lastDate;

    switch (type) {
      case 'start':
        initialDate = _billingPeriodStart;
        firstDate = DateTime.now().subtract(Duration(days: 365));
        lastDate = DateTime.now();
        break;
      case 'end':
        initialDate = _billingPeriodEnd;
        firstDate = _billingPeriodStart;
        lastDate = DateTime.now().add(Duration(days: 30));
        break;
      case 'due':
        initialDate = _dueDate;
        firstDate = DateTime.now();
        lastDate = DateTime.now().add(Duration(days: 90));
        break;
      default:
        return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: Localizations.localeOf(context),
    );

    if (picked != null && mounted) {
      setState(() {
        switch (type) {
          case 'start':
            _billingPeriodStart = picked;
            break;
          case 'end':
            _billingPeriodEnd = picked;
            break;
          case 'due':
            _dueDate = picked;
            break;
        }
      });
    }
  }

  Future<String> _getBranchName() async {
    if (_branches.isNotEmpty) {
      return _branches.first['branch_name'];
    }

    // ถ้า _branches ว่าง ให้ดึงข้อมูลจากฐานข้อมูลโดยตรง
    try {
      if (_currentUser?.branchId != null) {
        final response = await supabase
            .from('branches')
            .select('branch_name')
            .eq('branch_id', _currentUser!.branchId!)
            .single();
        return response['branch_name'] ?? 'ไม่พบข้อมูล';
      }
    } catch (e) {
      print('Error getting branch name: $e');
    }

    return 'ไม่พบข้อมูลสาขา';
  }

  Future<String> _generateBillNumber() async {
    try {
      final now = DateTime.now();
      final yearMonth = DateFormat('yyyyMM').format(now);

      final latestBill = await supabase
          .from('rental_bills')
          .select('bill_number')
          .like('bill_number', 'BILL-$yearMonth-%')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      int sequenceNumber = 1;
      if (latestBill != null) {
        final billNumber = latestBill['bill_number'] as String;
        final parts = billNumber.split('-');
        if (parts.length == 3) {
          sequenceNumber = (int.tryParse(parts[2]) ?? 0) + 1;
        }
      }

      return 'BILL-$yearMonth-${sequenceNumber.toString().padLeft(4, '0')}';
    } catch (e) {
      print('Error generating bill number: $e');
      return 'BILL-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}';
    }
  }

  Future<void> _saveBilling() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenant == null) {
      _showErrorSnackBar('กรุณาเลือกผู้เช่า');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final billNumber = await _generateBillNumber();
      final subtotal = _calculateSubtotal();
      final total = _calculateTotal();

      // Debug: ตรวจสอบข้อมูล _selectedTenant
      print('Selected tenant data: $_selectedTenant');
      print('Room ID: ${_selectedTenant!['room_id']}');
      print('Branch ID: ${_selectedTenant!['branch_id']}');

      // ตรวจสอบข้อมูลที่จำเป็น
      final roomId = _selectedTenant!['room_id'] as String?;
      final branchId = _selectedTenant!['branch_id'] as String?;
      final tenantId = _selectedTenant!['tenant_id'] as String?;

      if (roomId == null || branchId == null || tenantId == null) {
        throw Exception('ข้อมูลผู้เช่าไม่สมบูรณ์ กรุณาเลือกผู้เช่าใหม่');
      }

      // Insert rental bill
      final billData = {
        'bill_number': billNumber,
        'tenant_id': tenantId,
        'room_id': roomId,
        'branch_id': branchId,
        'billing_period_start':
            _billingPeriodStart.toIso8601String().split('T')[0],
        'billing_period_end': _billingPeriodEnd.toIso8601String().split('T')[0],
        'room_rent': double.tryParse(_roomRentController.text) ?? 0.0,
        'total_utilities': _utilityItems.fold(
            0.0, (sum, item) => sum + (item['amount'] ?? 0.0)),
        'other_charges':
            _otherItems.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)),
        'subtotal': subtotal,
        'discount': double.tryParse(_discountController.text) ?? 0.0,
        'tax_amount': double.tryParse(_taxAmountController.text) ?? 0.0,
        'late_fee': double.tryParse(_lateFeeController.text) ?? 0.0,
        'total_amount': total,
        'outstanding_amount': total,
        'due_date': _dueDate.toIso8601String().split('T')[0],
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        'created_by': _currentUser?.userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Debug: ตรวจสอบข้อมูลที่จะส่ง
      print('Bill data to insert: $billData');

      final billResponse = await supabase
          .from('rental_bills')
          .insert(billData)
          .select('bill_id')
          .single();

      final billId = billResponse['bill_id'];

      // Insert utility items
      for (var item in _utilityItems) {
        if ((item['amount'] ?? 0.0) > 0) {
          await supabase.from('bill_utility_items').insert({
            'bill_id': billId,
            'utility_type_id': item['utility_type_id'],
            'meter_id': item['meter_id'],
            'previous_reading': item['previous_reading'],
            'current_reading': item['current_reading'],
            'consumption': item['consumption'],
            'rate_per_unit': item['rate_per_unit'],
            'minimum_charge': item['minimum_charge'],
            'fixed_charge': item['fixed_charge'],
            'amount': item['amount'],
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // Insert other items
      for (var item in _otherItems) {
        if ((item['amount'] ?? 0.0) > 0) {
          await supabase.from('bill_other_items').insert({
            'bill_id': billId,
            'item_name': item['item_name'],
            'item_description': item['item_description'],
            'quantity': item['quantity'],
            'unit_price': item['unit_price'],
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (mounted) {
        _showSuccessSnackBar('สร้างบิลค่าเช่าสำเร็จ\nเลขที่บิล: $billNumber');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: ${e.toString()}');
        print('เกิดข้อผิดพลาด: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
          'สร้างบิลค่าเช่า',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text('กำลังโหลดข้อมูล...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // เลือกสาขา (สำหรับ SuperAdmin)
                    if (_currentUser?.isSuperAdmin == true) ...[
                      _buildBranchSection(),
                      const SizedBox(height: 24),
                    ],

                    // เลือกผู้เช่า
                    _buildTenantSection(),
                    const SizedBox(height: 24),

                    // ระยะเวลาการเรียกเก็บ
                    _buildBillingPeriodSection(),
                    const SizedBox(height: 24),

                    // ค่าเช่าห้อง
                    _buildRoomRentSection(),
                    const SizedBox(height: 24),

                    // ค่าสาธารณูปโภค (มิเตอร์)
                    _buildUtilitiesSection(),
                    const SizedBox(height: 24),

                    // ค่าใช้จ่ายอื่นๆ
                    _buildOtherChargesSection(),
                    const SizedBox(height: 24),

                    // ส่วนลด ภาษี และค่าปรับ
                    _buildAdjustmentsSection(),
                    const SizedBox(height: 24),

                    // สรุปยอดรวม
                    _buildSummarySection(),
                    const SizedBox(height: 24),

                    // หมายเหตุ
                    _buildNotesSection(),
                    const SizedBox(height: 32),

                    // ปุ่มบันทึก
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveBilling,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'กำลังบันทึก...',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              )
                            : Text(
                                'สร้างบิลค่าเช่า',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildBranchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('เลือกสาขา'),
        const SizedBox(height: 12),

        // ถ้าเป็น Admin ปกติ แสดงข้อมูลสาขาของตัวเองแบบไม่สามารถเปลี่ยนได้
        if (_currentUser?.isAdmin == true &&
            !(_currentUser?.isSuperAdmin == true)) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.business, color: Colors.blue[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'สาขา: ${_branches.isNotEmpty ? _branches.first['branch_name'] : 'ไม่พบข้อมูลสาขา'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // สำหรับ SuperAdmin ให้เลือกสาขาได้
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedBranchId,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.business, color: AppColors.primary),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                hintText: 'เลือกสาขา',
              ),
              items: _branches.map((branch) {
                return DropdownMenuItem<String>(
                  value: branch['branch_id'],
                  child: Text(branch['branch_name']),
                );
              }).toList(),
              onChanged: (value) async {
                setState(() {
                  _selectedBranchId = value;
                  _selectedTenantId = null;
                  _selectedTenant = null;
                  _tenants.clear();
                });
                if (value != null) {
                  await _loadTenants();
                }
              },
              validator: (value) => value == null ? 'กรุณาเลือกสาขา' : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTenantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ข้อมูลผู้เช่า'),
        const SizedBox(height: 12),

        // Show branch info for Admin
        if (_currentUser?.isAdmin == true &&
            !(_currentUser?.isSuperAdmin == true)) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.business, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text(
                  'สาขา: ${_branches.firstWhere((b) => b['branch_id'] == _selectedBranchId, orElse: () => {
                        'branch_name': 'ไม่พบข้อมูล'
                      })['branch_name']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedTenantId,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.person, color: AppColors.primary),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText:
                  _selectedBranchId == null ? 'เลือกสาขาก่อน' : 'เลือกผู้เช่า',
            ),
            isDense: false, // ให้มีพื้นที่มากขึ้น
            menuMaxHeight: 300, // จำกัดความสูงของ dropdown menu
            items: _selectedBranchId == null
                ? []
                : _tenants.map((tenant) {
                    return DropdownMenuItem<String>(
                      value: tenant['tenant_id'],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tenant['tenant_full_name'],
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'ห้อง ${tenant['room_number']}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            onChanged: _selectedBranchId == null
                ? null
                : (value) {
                    if (value != null) {
                      _loadTenantDetails(value);
                    }
                  },
            validator: (value) => value == null ? 'กรุณาเลือกผู้เช่า' : null,
          ),
        ),
        if (_selectedTenant != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600]),
                    SizedBox(width: 8),
                    Text(
                      'ข้อมูลผู้เช่า',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('ชื่อ: ${_selectedTenant!['tenant_full_name']}'),
                Text(
                    'ห้อง: ${_selectedTenant!['room_number']} - ${_selectedTenant!['room_name'] ?? ''}'),
                Text('สาขา: ${_selectedTenant!['branch_name']}'),
                Text(
                    'ค่าเช่า: ${NumberFormat('#,##0').format(_selectedTenant!['room_rate'])} บาท/เดือน'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBillingPeriodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ระยะเวลาการเรียกเก็บ'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDateSelector(
                label: 'วันที่เริ่มต้น',
                selectedDate: _billingPeriodStart,
                onTap: () => _selectDate(context, 'start'),
                icon: Icons.calendar_today,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateSelector(
                label: 'วันที่สิ้นสุด',
                selectedDate: _billingPeriodEnd,
                onTap: () => _selectDate(context, 'end'),
                icon: Icons.calendar_today,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDateSelector(
          label: 'วันที่ครบกำหนดชำระ',
          selectedDate: _dueDate,
          onTap: () => _selectDate(context, 'due'),
          icon: Icons.schedule,
        ),
      ],
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime selectedDate,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomRentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ค่าเช่าห้อง'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextFormField(
            controller: _roomRentController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.home, color: AppColors.primary),
              suffixText: 'บาท',
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: 'ค่าเช่าห้อง',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณาใส่ค่าเช่าห้อง';
              }
              if (double.tryParse(value) == null || double.parse(value) < 0) {
                return 'กรุณาใส่ค่าเช่าที่ถูกต้อง';
              }
              return null;
            },
            onChanged: (value) => setState(() {}), // Refresh calculations
          ),
        ),
      ],
    );
  }

  Widget _buildUtilitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ค่าสาธารณูปโภค (มิเตอร์)'),
        const SizedBox(height: 12),
        if (_utilityItems.isEmpty)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Text(
                'ไม่มีรายการค่าสาธารณูปโภคที่ใช้มิเตอร์',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ..._utilityItems.map((item) => _buildUtilityItem(item)).toList(),
      ],
    );
  }

  Widget _buildUtilityItem(Map<String, dynamic> item) {
    final previousReading = item['previous_reading'] ?? 0.0;
    final currentReading = item['current_reading'] ?? 0.0;
    final consumption = item['consumption'] ?? 0.0;
    final ratePerUnit = item['rate_per_unit'] ?? 0.0;
    final amount = item['amount'] ?? 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  item['type_name'] == 'ค่าไฟฟ้า'
                      ? Icons.electric_bolt
                      : Icons.water_drop,
                  color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                item['type_name'],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  label: 'เลขเดือนก่อน',
                  value: previousReading.toString(),
                  onChanged: (value) {
                    setState(() {
                      item['previous_reading'] = double.tryParse(value) ?? 0.0;
                      item['consumption'] = (item['current_reading'] ?? 0.0) -
                          (item['previous_reading'] ?? 0.0);
                      _calculateUtilityAmount(item);
                    });
                  },
                  suffix: item['unit_name'],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  label: 'เลขล่าสุด',
                  value: currentReading.toString(),
                  onChanged: (value) {
                    setState(() {
                      item['current_reading'] = double.tryParse(value) ?? 0.0;
                      item['consumption'] = (item['current_reading'] ?? 0.0) -
                          (item['previous_reading'] ?? 0.0);
                      _calculateUtilityAmount(item);
                    });
                  },
                  suffix: item['unit_name'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // แสดงการคำนวณอย่างชัดเจน
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('การคำนวณ:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      '${NumberFormat('#,##0.0').format(currentReading)} - ${NumberFormat('#,##0.0').format(previousReading)} = ${NumberFormat('#,##0.0').format(consumption)} ${item['unit_name']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('อัตราค่าบริการ:', style: TextStyle(fontSize: 14)),
                    Text(
                      '${NumberFormat('#,##0.00').format(ratePerUnit)} บาท/${item['unit_name']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          // Row(
          //   children: [
          //     Expanded(
          //       child: _buildNumberField(
          //         label: 'หน่วยที่ใช้',
          //         value: consumption.toString(),
          //         enabled: false,
          //         suffix: item['unit_name'],
          //       ),
          //     ),
          //     const SizedBox(width: 12),
          //     Expanded(
          //       child: _buildNumberField(
          //         label: 'ราคาต่อหน่วย',
          //         value: ratePerUnit.toString(),
          //         onChanged: (value) {
          //           setState(() {
          //             item['rate_per_unit'] = double.tryParse(value) ?? 0.0;
          //             _calculateUtilityAmount(item);
          //           });
          //         },
          //         suffix: 'บาท',
          //       ),
          //     ),
          //   ],
          // ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ยอดรวม',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${NumberFormat('#,##0.00').format(amount)} บาท',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherChargesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ค่าใช้จ่ายอื่นๆ'),
        const SizedBox(height: 12),

        // เลือกเมนูรายการก่อน
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedOtherItemTemplate,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.list_alt, color: AppColors.primary),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    hintText: 'เลือกรายการค่าใช้จ่าย',
                  ),
                  items: _otherItemTemplates.map((template) {
                    return DropdownMenuItem<String>(
                      value: template['type_name'],
                      child: Text(
                        template['type_name'],
                        style: TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedOtherItemTemplate = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _selectedOtherItemTemplate == null
                  ? null
                  : () {
                      final template = _otherItemTemplates.firstWhere(
                        (t) => t['type_name'] == _selectedOtherItemTemplate,
                      );
                      _addOtherItem(
                        template['type_name'],
                        template['default_rate']?.toDouble() ?? 0.0,
                      );
                      // รีเซ็ต dropdown หลังเพิ่มรายการ
                      setState(() {
                        _selectedOtherItemTemplate = null;
                      });
                    },
              icon: Icon(Icons.add, size: 16),
              label: Text('เพิ่มรายการ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedOtherItemTemplate == null
                    ? Colors.grey[400]
                    : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // แสดงรายการที่เพิ่มแล้ว
        if (_otherItems.isEmpty)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.grey[200]!, style: BorderStyle.solid),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long, color: Colors.grey[400], size: 48),
                  SizedBox(height: 8),
                  Text(
                    'ยังไม่มีรายการค่าใช้จ่ายอื่นๆ',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'เลือกรายการจากเมนูด้านบนแล้วกดเพิ่มรายการ',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

        ..._otherItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildOtherItem(item, index);
        }).toList(),
      ],
    );
  }

  Widget _buildOtherItem(Map<String, dynamic> item, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item['is_utility'] == true ? Icons.build : Icons.receipt,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item['item_name'],
                  decoration: InputDecoration(
                    labelText: 'ชื่อรายการ',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  enabled: item['is_utility'] != true,
                  onChanged: (value) {
                    setState(() {
                      item['item_name'] = value;
                    });
                  },
                ),
              ),
              if (item['is_utility'] != true)
                IconButton(
                  onPressed: () => _removeOtherItem(index),
                  icon: Icon(Icons.delete, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item['item_description'],
            decoration: InputDecoration(
              labelText: 'รายละเอียด',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.all(12),
            ),
            maxLines: 2,
            onChanged: (value) {
              setState(() {
                item['item_description'] = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  label: 'จำนวน',
                  value: item['quantity']?.toString() ?? '1',
                  onChanged: (value) {
                    setState(() {
                      item['quantity'] = double.tryParse(value) ?? 1.0;
                      _calculateOtherAmount(item);
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  label: 'ราคาต่อหน่วย',
                  value: item['unit_price']?.toString() ?? '0',
                  onChanged: (value) {
                    setState(() {
                      item['unit_price'] = double.tryParse(value) ?? 0.0;
                      _calculateOtherAmount(item);
                    });
                  },
                  suffix: 'บาท',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ยอดรวม',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  '${NumberFormat('#,##0.00').format(item['amount'] ?? 0)} บาท',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ส่วนลด ภาษี และค่าปรับ'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildNumberFormField(
                controller: _discountController,
                label: 'ส่วนลด',
                icon: Icons.discount,
                suffix: 'บาท',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberFormField(
                controller: _taxAmountController,
                label: 'ภาษี',
                icon: Icons.receipt_long,
                suffix: 'บาท',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildNumberFormField(
          controller: _lateFeeController,
          label: 'ค่าปรับ',
          icon: Icons.warning,
          suffix: 'บาท',
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'สรุปยอดรวม',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ค่าเช่าห้อง
          _buildSummaryRow(
              'ค่าเช่าห้อง', double.tryParse(_roomRentController.text) ?? 0.0),

          // แสดงรายละเอียดค่าสาธารณูปโภค
          if (_utilityItems.isNotEmpty) ...[
            ...(_utilityItems
                .where((item) => (item['amount'] ?? 0.0) > 0)
                .map((item) {
              final previousReading = item['previous_reading'] ?? 0.0;
              final currentReading = item['current_reading'] ?? 0.0;
              final consumption = item['consumption'] ?? 0.0;
              final amount = item['amount'] ?? 0.0;

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['type_name'],
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${NumberFormat('#,##0.0').format(previousReading)} - ${NumberFormat('#,##0.0').format(currentReading)} = ${NumberFormat('#,##0.0').format(consumption)} ${item['unit_name']}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,##0.00').format(amount)} บาท',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList()),
          ] else ...[
            _buildSummaryRow(
                'ค่าสาธารณูปโภค',
                _utilityItems.fold(
                    0.0, (sum, item) => sum + (item['amount'] ?? 0.0))),
          ],

          // แสดงรายละเอียดค่าใช้จ่ายอื่นๆ เป็น list
          if (_otherItems.isNotEmpty) ...[
            ...(_otherItems
                .where((item) => (item['amount'] ?? 0.0) > 0)
                .map((item) {
              final quantity = item['quantity'] ?? 1.0;
              final unitPrice = item['unit_price'] ?? 0.0;
              final amount = item['amount'] ?? 0.0;

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['item_name'] ?? 'ไม่ระบุชื่อรายการ',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          if (item['item_description'] != null &&
                              item['item_description']
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                            Text(
                              item['item_description'],
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          Text(
                            '${NumberFormat('#,##0.0').format(quantity)} x ${NumberFormat('#,##0.00').format(unitPrice)} บาท',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,##0.00').format(amount)} บาท',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList()),
          ] else ...[
            // แสดงเฉพาะเมื่อไม่มีรายการแต่ยังมียอดรวม (กรณีที่มีปัญหาข้อมูล)
            if (_otherItems.fold(
                    0.0, (sum, item) => sum + (item['amount'] ?? 0.0)) >
                0)
              _buildSummaryRow(
                  'ค่าใช้จ่ายอื่นๆ',
                  _otherItems.fold(
                      0.0, (sum, item) => sum + (item['amount'] ?? 0.0))),
          ],

          Divider(thickness: 1, color: Colors.grey[300]),
          _buildSummaryRow('ยอดรวมย่อย', _calculateSubtotal(),
              isSubtotal: true),
          _buildSummaryRow(
              'ส่วนลด', -(double.tryParse(_discountController.text) ?? 0.0),
              isNegative: true),
          _buildSummaryRow(
              'ภาษี', double.tryParse(_taxAmountController.text) ?? 0.0),
          _buildSummaryRow(
              'ค่าปรับ', double.tryParse(_lateFeeController.text) ?? 0.0),
          Divider(thickness: 2, color: AppColors.primary),
          _buildSummaryRow('ยอดรวมสุทธิ', _calculateTotal(), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount,
      {bool isSubtotal = false,
      bool isTotal = false,
      bool isNegative = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight:
                  isTotal || isSubtotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? AppColors.primary : Colors.black87,
            ),
          ),
          Text(
            '${isNegative && amount > 0 ? '-' : ''}${NumberFormat('#,##0.00').format(amount.abs())} บาท',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight:
                  isTotal || isSubtotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal
                  ? AppColors.primary
                  : (isNegative ? Colors.red : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('หมายเหตุ'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextFormField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(Icons.notes, color: AppColors.primary),
              ),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: 'หมายเหตุเพิ่มเติม (ถ้ามี)',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required String label,
    required String value,
    Function(String)? onChanged,
    String? suffix,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextFormField(
            initialValue: value,
            enabled: enabled,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixText: suffix,
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.primary),
              suffixText: suffix,
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (value) => setState(() {}), // Refresh calculations
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _roomRentController.dispose();
    _discountController.dispose();
    _taxAmountController.dispose();
    _lateFeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
