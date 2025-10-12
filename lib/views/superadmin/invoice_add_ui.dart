import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/invoice_service.dart';
import '../../services/room_service.dart';
import '../../services/contract_service.dart';
import '../../services/utility_rate_service.dart';
import '../../services/meter_service.dart';
import '../../services/auth_service.dart';
import '../../services/payment_rate_service.dart';
import '../../models/user_models.dart';
import '../../widgets/colors.dart';

class InvoiceAddPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const InvoiceAddPage({Key? key, this.initialData}) : super(key: key);

  @override
  State<InvoiceAddPage> createState() => _InvoiceAddPageState();
}

class _InvoiceAddPageState extends State<InvoiceAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Controllers
  final _discountAmountController = TextEditingController();
  final _discountReasonController = TextEditingController();
  final _lateFeeAmountController = TextEditingController();
  final _lateFeeReasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _waterCurrentController = TextEditingController();
  final _electricCurrentController = TextEditingController();

  // Data
  UserModel? _currentUser;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _fixedRates = [];
  List<Map<String, dynamic>> _selectedFixedRates = [];
  Map<String, dynamic>? _paymentSettings;

  // Form data
  String? _selectedBranchId;
  String? _selectedRoomId;
  String? _selectedTenantId;
  String? _selectedContractId;
  String? _readingId;
  String? _waterRateId;
  String? _electricRateId;
  int _invoiceMonth = DateTime.now().month;
  int _invoiceYear = DateTime.now().year;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  // Financial data
  double _rentalAmount = 0.0;
  double _utilitiesAmount = 0.0;
  double _otherCharges = 0.0;
  double _discountAmount = 0.0;
  double _lateFeeAmount = 0.0;
  String _discountType = 'none';

  // Water and Electric meter data
  double _waterPreviousReading = 0.0;
  double _waterCurrentReading = 0.0;
  double _waterUsage = 0.0;
  double _waterRate = 0.0;
  double _waterCost = 0.0;

  double _electricPreviousReading = 0.0;
  double _electricCurrentReading = 0.0;
  double _electricUsage = 0.0;
  double _electricRate = 0.0;
  double _electricCost = 0.0;

  // Other charges
  List<Map<String, dynamic>> _otherChargesList = [];

  // UI State
  bool _isLoading = false;
  bool _isSubmitting = false;
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isFromMeterReading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _discountAmountController.dispose();
    _discountReasonController.dispose();
    _lateFeeAmountController.dispose();
    _lateFeeReasonController.dispose();
    _notesController.dispose();
    _waterCurrentController.dispose();
    _electricCurrentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      // 1. โหลด user ก่อน
      _currentUser = await AuthService.getCurrentUser();

      if (_currentUser == null) {
        _showErrorSnackBar('กรุณาเข้าสู่ระบบใหม่');
        setState(() => _isLoading = false);
        return;
      }

      // 2. ตรวจสอบ initialData และ set ค่าพื้นฐาน
      if (widget.initialData != null) {
        _isFromMeterReading = widget.initialData!['reading_id'] != null;
        _selectedBranchId = widget.initialData!['branch_id'];
        _selectedRoomId = widget.initialData!['room_id'];
        _selectedTenantId = widget.initialData!['tenant_id'];
        _selectedContractId = widget.initialData!['contract_id'];
        _readingId = widget.initialData!['reading_id'];
        _invoiceMonth =
            widget.initialData!['invoice_month'] ?? DateTime.now().month;
        _invoiceYear =
            widget.initialData!['invoice_year'] ?? DateTime.now().year;

        debugPrint(
            '📋 ข้อมูลเริ่มต้น: สาขา=$_selectedBranchId, ห้อง=$_selectedRoomId, มิเตอร์=$_readingId');
      }

      // 3. โหลด branches
      try {
        _branches = await RoomService.getBranchesForRoomFilter();
        debugPrint('✅ โหลดสาขาแล้ว ${_branches.length} สาขา');
      } catch (e) {
        debugPrint('❌ ข้อผิดพลาดในการโหลดสาขา: $e');
        _showErrorSnackBar('ไม่สามารถโหลดข้อมูลสาขาได้: $e');
      }

      // 4. ถ้ามี branch_id ให้โหลดข้อมูลที่เกี่ยวข้อง
      if (_selectedBranchId != null) {
        await _loadDataForBranch();
      }

      setState(() {});
    } catch (e) {
      debugPrint('❌ ข้อผิดพลาดใน _initializeData: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ฟังก์ชันใหม่: โหลดข้อมูลเมื่อมี branch_id
  Future<void> _loadDataForBranch() async {
    try {
      final results = await Future.wait([
        RoomService.getAllRooms(branchId: _selectedBranchId),
        UtilityRatesService.getActiveRatesForBranch(_selectedBranchId!),
        PaymentSettingsService.getActivePaymentSettings(_selectedBranchId!),
        if (_readingId != null)
          MeterReadingService.getMeterReadingById(_readingId!),
      ]);

      _rooms = results[0] as List<Map<String, dynamic>>;
      final utilityRates = results[1] as List<Map<String, dynamic>>;
      _paymentSettings = results[2] as Map<String, dynamic>?;

      // แยกค่า rates ออกเป็น metered และ fixed
      _fixedRates =
          utilityRates.where((rate) => rate['is_fixed'] == true).toList();

      // ✅ เก็บ rate_id สำหรับน้ำและไฟ
      String? waterRateId;
      String? electricRateId;

      // ตั้งค่า rate สำหรับน้ำและไฟ
      for (var rate in utilityRates) {
        if (rate['is_metered'] == true) {
          final rateName = rate['rate_name'].toString().toLowerCase();
          if (rateName.contains('น้ำ') || rateName.contains('water')) {
            _waterRate = (rate['rate_price'] ?? 0.0).toDouble();
            waterRateId = rate['rate_id'];
          }
          if (rateName.contains('ไฟ') || rateName.contains('electric')) {
            _electricRate = (rate['rate_price'] ?? 0.0).toDouble();
            electricRateId = rate['rate_id'];
          }
        }
      }

      // ✅ เก็บ rate_id เป็น instance variable
      _waterRateId = waterRateId;
      _electricRateId = electricRateId;

      // ✅ Apply meter reading data ถ้ามี
      if (_readingId != null && results.length > 3) {
        final reading = results[3] as Map<String, dynamic>?;
        if (reading != null) {
          _applyMeterReadingData(reading);
        }
      }

      // ✅ โหลด contracts สำหรับห้องที่เลือก
      if (_selectedRoomId != null) {
        await _loadContractsForRoom();
      }
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    }
  }

  void _addFixedRate(Map<String, dynamic> rate) {
    setState(() {
      _selectedFixedRates.add({
        'rate_id': rate['rate_id'],
        'rate_name': rate['rate_name'],
        'fixed_amount': rate['fixed_amount'],
        'additional_charge': rate['additional_charge'] ?? 0.0,
      });
      _calculateOtherChargesTotal();
    });
  }

  void _removeFixedRate(int index) {
    setState(() {
      _selectedFixedRates.removeAt(index);
      _calculateOtherChargesTotal();
    });
  }

  void _calculateOtherChargesTotal() {
    double total = 0.0;
    for (var rate in _selectedFixedRates) {
      total += (rate['fixed_amount'] ?? 0.0).toDouble();
      total += (rate['additional_charge'] ?? 0.0).toDouble();
    }
    _otherCharges = total;
  }

  // ฟังก์ชันใหม่: Apply ข้อมูลจาก meter reading
  void _applyMeterReadingData(Map<String, dynamic> reading) {
    _waterPreviousReading =
        (reading['water_previous_reading'] ?? 0.0).toDouble();
    _waterCurrentReading = (reading['water_current_reading'] ?? 0.0).toDouble();
    _waterUsage = (reading['water_usage'] ?? 0.0).toDouble();

    _electricPreviousReading =
        (reading['electric_previous_reading'] ?? 0.0).toDouble();
    _electricCurrentReading =
        (reading['electric_current_reading'] ?? 0.0).toDouble();
    _electricUsage = (reading['electric_usage'] ?? 0.0).toDouble();

    _waterCurrentController.text = _waterCurrentReading.toStringAsFixed(0);
    _electricCurrentController.text =
        _electricCurrentReading.toStringAsFixed(0);

    // คำนวดค่าใช้จ่าย
    if (_waterUsage > 0 && _waterRate > 0) {
      _waterCost = _waterUsage * _waterRate;
    }
    if (_electricUsage > 0 && _electricRate > 0) {
      _electricCost = _electricUsage * _electricRate;
    }

    _calculateUtilitiesTotal();

    debugPrint('📊 ใช้ข้อมูลมิเตอร์: น้ำ=$_waterUsage, ไฟ=$_electricUsage');
  }

  // ⭐ ฟังก์ชันใหม่: โหลด contracts สำหรับห้อง พร้อมดึงค่าเช่า
  Future<void> _loadContractsForRoom() async {
    try {
      _contracts = await ContractService.getContractsByRoom(_selectedRoomId!);
      debugPrint('✅ โหลดสัญญาเช่าแล้ว ${_contracts.length} สัญญา');

      if (_contracts.isNotEmpty) {
        if (_selectedContractId == null) {
          // เลือก contract ที่ active
          final activeContracts = _contracts
              .where((c) => c['contract_status'] == 'active')
              .toList();

          final selectedContract = activeContracts.isNotEmpty
              ? activeContracts.first
              : _contracts.first;

          _selectedContractId = selectedContract['contract_id'];
          _selectedTenantId = selectedContract['tenant_id'];

          // ⭐ ดึงค่าเช่าจาก contract
          _rentalAmount =
              (selectedContract['contract_price'] ?? 0.0).toDouble();

          debugPrint(
              '🏠 เลือกสัญญา: $_selectedContractId, เช่า: $_rentalAmount');
        } else {
          // ⭐ ถ้ามี contract_id แล้ว ให้ดึงค่าเช่าจาก contract ที่เลือก
          final selectedContract = _contracts.firstWhere(
            (c) => c['contract_id'] == _selectedContractId,
            orElse: () => {},
          );
          if (selectedContract.isNotEmpty) {
            _rentalAmount =
                (selectedContract['contract_price'] ?? 0.0).toDouble();
            debugPrint('🏠 ค่าเช่าจากสัญญา: $_rentalAmount');
          }
        }
      }

      // ถ้าไม่ได้มาจาก meter reading ให้โหลด previous readings
      if (!_isFromMeterReading && _selectedRoomId != null) {
        final suggestions =
            await MeterReadingService.getSuggestedPreviousReadings(
                _selectedRoomId!);
        if (suggestions != null) {
          _waterPreviousReading = suggestions['water_previous'] ?? 0.0;
          _electricPreviousReading = suggestions['electric_previous'] ?? 0.0;
          debugPrint(
              '💡 ค่าก่อนหน้าที่แนะนำ: น้ำ=$_waterPreviousReading, ไฟ=$_electricPreviousReading');
        }
      }
    } catch (e) {
      debugPrint('❌ ข้อผิดพลาดในการโหลดสัญญา: $e');
    }
  }

  Future<void> _loadRoomsAndContracts() async {
    if (_selectedBranchId == null) return;

    try {
      // โหลดทั้ง 3 อย่างพร้อมกัน
      final results = await Future.wait([
        RoomService.getAllRooms(branchId: _selectedBranchId),
        UtilityRatesService.getActiveRatesForBranch(_selectedBranchId!),
        PaymentSettingsService.getActivePaymentSettings(_selectedBranchId!),
        // ถ้ามี roomId ให้โหลด contract ไปด้วย
        if (_selectedRoomId != null)
          ContractService.getContractsByRoom(_selectedRoomId!),
      ]);

      _rooms = results[0] as List<Map<String, dynamic>>;
      final utilityRates = results[1] as List<Map<String, dynamic>>;

      // ⭐ เก็บ payment settings
      _paymentSettings = results[2] as Map<String, dynamic>?;
      debugPrint(
          '💰 โหลดการตั้งค่าการชำระเงินแล้ว: ${_paymentSettings != null}');

      // ตั้งค่า rate
      for (var rate in utilityRates) {
        final rateName = rate['rate_name'].toString().toLowerCase();
        if (rateName.contains('น้ำ') || rateName.contains('water')) {
          _waterRate = (rate['rate_price'] ?? 0.0).toDouble();
        }
        if (rateName.contains('ไฟ') || rateName.contains('electric')) {
          _electricRate = (rate['rate_price'] ?? 0.0).toDouble();
        }
      }

      // คำนวดค่าใช้จ่าย
      if (_waterUsage > 0 && _waterRate > 0) {
        _waterCost = _waterUsage * _waterRate;
      }
      if (_electricUsage > 0 && _electricRate > 0) {
        _electricCost = _electricUsage * _electricRate;
      }

      _calculateUtilitiesTotal();

      // ถ้ามี contract results
      if (results.length > 3) {
        _contracts = results[3] as List<Map<String, dynamic>>;
        _applyContractData();
      }

      setState(() {});
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการโหลดห้องและสัญญา: $e');
    }
  }

  // ⭐ ฟังก์ชันใหม่: Apply contract data และดึงค่าเช่า
  void _applyContractData() {
    if (_contracts.isEmpty) return;

    if (_selectedContractId == null) {
      final activeContracts =
          _contracts.where((c) => c['contract_status'] == 'active').toList();
      final selectedContract =
          activeContracts.isNotEmpty ? activeContracts.first : _contracts.first;

      _selectedContractId = selectedContract['contract_id'];
      _selectedTenantId = selectedContract['tenant_id'];

      // ⭐ ดึงค่าเช่า
      _rentalAmount = (selectedContract['contract_price'] ?? 0.0).toDouble();
      debugPrint('🏠 ใช้ค่าเช่าจากสัญญา: $_rentalAmount');
    } else {
      final contract = _contracts.firstWhere(
        (c) => c['contract_id'] == _selectedContractId,
        orElse: () => {},
      );
      if (contract.isNotEmpty) {
        // ⭐ ดึงค่าเช่า
        _rentalAmount = (contract['contract_price'] ?? 0.0).toDouble();
        debugPrint('🏠 ใช้ค่าเช่าจากสัญญาที่เลือก: $_rentalAmount');
      }
    }
  }

  Future<void> _loadContractData() async {
    if (_selectedRoomId == null) return;

    try {
      _contracts = await ContractService.getContractsByRoom(_selectedRoomId!);

      if (_contracts.isNotEmpty && _selectedContractId == null) {
        final activeContracts =
            _contracts.where((c) => c['contract_status'] == 'active').toList();

        final selectedContract = activeContracts.isNotEmpty
            ? activeContracts.first
            : _contracts.first;

        _selectedContractId = selectedContract['contract_id'];
        _selectedTenantId = selectedContract['tenant_id'];

        // ⭐ ดึงค่าเช่า
        _rentalAmount = (selectedContract['contract_price'] ?? 0.0).toDouble();
      } else if (_selectedContractId != null) {
        final contract = _contracts.firstWhere(
          (c) => c['contract_id'] == _selectedContractId,
          orElse: () => {},
        );
        if (contract.isNotEmpty) {
          // ⭐ ดึงค่าเช่า
          _rentalAmount = (contract['contract_price'] ?? 0.0).toDouble();
        }
      }

      if (!_isFromMeterReading) {
        final suggestions =
            await MeterReadingService.getSuggestedPreviousReadings(
                _selectedRoomId!);
        if (suggestions != null) {
          _waterPreviousReading = suggestions['water_previous'] ?? 0.0;
          _electricPreviousReading = suggestions['electric_previous'] ?? 0.0;
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการโหลดข้อมูลสัญญา: $e');
    }
  }

  void _calculateUtilitiesTotal() {
    _utilitiesAmount = _waterCost + _electricCost;
  }

  double _calculateSubtotal() {
    return _rentalAmount + _utilitiesAmount + _otherCharges;
  }

  // ⭐ ฟังก์ชันใหม่: คำนวดยอดรวมพร้อมใช้ payment settings
  double _calculateGrandTotal() {
    final subtotal = _calculateSubtotal();

    // ⭐ ถ้ามี payment settings ให้คำนวดค่าปรับและส่วนลดอัตโนมัติ
    if (_paymentSettings != null) {
      // คำนวดค่าปรับ (ถ้าเปิดใช้งาน)
      if (_paymentSettings!['enable_late_fee'] == true) {
        _lateFeeAmount = PaymentSettingsService.calculateLateFeeManual(
          settings: _paymentSettings!,
          dueDate: _dueDate,
          subtotal: subtotal,
          paymentDate: DateTime.now(),
        );
        _lateFeeAmountController.text = _lateFeeAmount.toStringAsFixed(2);
        debugPrint('💸 คำนวดค่าปรับแล้ว: $_lateFeeAmount');
      }

      // คำนวดส่วนลด (ถ้าเปิดใช้งาน)
      if (_paymentSettings!['enable_discount'] == true) {
        final discount = PaymentSettingsService.calculateEarlyDiscountManual(
          settings: _paymentSettings!,
          dueDate: _dueDate,
          subtotal: subtotal,
          paymentDate: DateTime.now(),
        );

        // ใช้ส่วนลดที่คำนวดได้ ถ้าไม่มีการกรอกส่วนลดเอง
        if (_discountAmountController.text.isEmpty) {
          _discountAmount = discount;
          _discountAmountController.text = _discountAmount.toStringAsFixed(2);
          debugPrint('🎉 คำนวดส่วนลดแล้ว: $_discountAmount');
        }
      }
    }

    return subtotal - _discountAmount + _lateFeeAmount;
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedBranchId == null) {
          _showErrorSnackBar('กรุณาเลือกสาขา');
          return false;
        }
        if (_selectedRoomId == null) {
          _showErrorSnackBar('กรุณาเลือกห้อง');
          return false;
        }
        if (_selectedContractId == null) {
          _showErrorSnackBar('กรุณาเลือกสัญญาเช่า');
          return false;
        }
        // ⭐ ตรวจสอบค่าเช่า
        if (_rentalAmount <= 0) {
          _showErrorSnackBar('ไม่พบค่าเช่าจากสัญญา กรุณาตรวจสอบข้อมูล');
          return false;
        }
        return true;
      case 1:
        if (_waterCurrentReading < _waterPreviousReading) {
          _showErrorSnackBar(
              'ค่ามิเตอร์น้ำปัจจุบันต้องมากกว่าหรือเท่ากับค่าก่อนหน้า');
          return false;
        }
        if (_electricCurrentReading < _electricPreviousReading) {
          _showErrorSnackBar(
              'ค่ามิเตอร์ไฟปัจจุบันต้องมากกว่าหรือเท่ากับค่าก่อนหน้า');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final invoiceData = {
        'room_id': _selectedRoomId,
        'tenant_id': _selectedTenantId,
        'contract_id': _selectedContractId,
        'meter_reading_id': _readingId,
        'invoice_month': _invoiceMonth,
        'invoice_year': _invoiceYear,
        'issue_date': DateTime.now()
            .toIso8601String()
            .split('T')[0], // ส่งไปเพื่อให้ service รู้
        'due_date': _dueDate.toIso8601String().split('T')[0],

        // ✅ ค่าเช่า
        'room_rent': _rentalAmount,

        // ✅ รายละเอียดค่าน้ำ
        'water_usage': _waterUsage,
        'water_rate': _waterRate,
        'water_cost': _waterCost,
        'water_rate_id': _waterRateId,
        // ✅ รายละเอียดค่าไฟ
        'electric_usage': _electricUsage,
        'electric_rate': _electricRate,
        'electric_cost': _electricCost,
        'electric_rate_id': _electricRateId,

        // ✅ ค่าใช้จ่ายอื่นๆ
        'other_expenses': _otherCharges,

        // ✅ ส่วนลด
        'discount_amount': _discountAmount,

        // ✅ รายการค่าบริการคงที่
        'fixed_rates': _selectedFixedRates,

        // ✅ หมายเหตุ
        'notes': _notesController.text,
      };

      final result = await InvoiceService.createInvoice(invoiceData);

      if (result['success']) {
        if (mounted) {
          _showSuccessSnackBar('สร้างใบแจ้งหนี้สำเร็จ');
          Navigator.pop(context, {'success': true});
        }
      } else {
        print(result['message']);
        _showErrorSnackBar(result['message'] ?? 'เกิดข้อผิดพลาด');
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFromMeterReading
            ? 'สร้างใบแจ้งหนี้จากมิเตอร์'
            : 'สร้างใบแจ้งหนี้'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label:
                  const Text('ย้อนกลับ', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                _buildProgressIndicator(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildBasicInfoStep(),
                        _buildUtilitiesStep(),
                        _buildChargesDiscountsStep(),
                        _buildSummaryStep(),
                      ],
                    ),
                  ),
                ),
                _buildBottomActions(),
              ],
            ),
    );
  }

  Widget _buildOtherChargesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ค่าใช้จ่ายอื่นๆ (ค่าคงที่)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_fixedRates.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _showAddFixedRateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มค่าบริการ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // แสดงรายการค่าคงที่ที่เลือก
        if (_selectedFixedRates.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[400], size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _fixedRates.isEmpty
                        ? 'ไม่มีค่าบริการคงที่ในระบบ'
                        : 'ยังไม่มีการเลือกค่าบริการ',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              ...List.generate(_selectedFixedRates.length, (index) {
                final rate = _selectedFixedRates[index];
                final fixedAmount = (rate['fixed_amount'] ?? 0.0).toDouble();
                final additionalCharge =
                    (rate['additional_charge'] ?? 0.0).toDouble();
                final total = fixedAmount + additionalCharge;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // ไอคอน
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconForRate(rate['rate_name']),
                            color: Colors.purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ข้อมูล
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rate['rate_name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'ค่าคงที่: ${fixedAmount.toStringAsFixed(2)} บาท',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (additionalCharge > 0) ...[
                                    Text(
                                      ' + ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '${additionalCharge.toStringAsFixed(2)} บาท',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ราคารวม
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${total.toStringAsFixed(2)} บาท',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),

                        // ปุ่มลบ
                        IconButton(
                          onPressed: () => _removeFixedRate(index),
                          icon: const Icon(Icons.close, size: 20),
                          color: Colors.red,
                          tooltip: 'ลบ',
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),

              // แสดงยอดรวม
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'รวมค่าใช้จ่ายอื่นๆ:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_otherCharges.toStringAsFixed(2)} บาท',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _showAddFixedRateDialog() {
    // กรองค่าบริการที่ยังไม่ได้เลือก
    final availableRates = _fixedRates.where((rate) {
      return !_selectedFixedRates.any(
        (selected) => selected['rate_id'] == rate['rate_id'],
      );
    }).toList();

    if (availableRates.isEmpty) {
      _showErrorSnackBar('เพิ่มค่าบริการครบแล้ว');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('เลือกค่าบริการ'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableRates.length,
            itemBuilder: (context, index) {
              final rate = availableRates[index];
              final fixedAmount = (rate['fixed_amount'] ?? 0.0).toDouble();
              final additionalCharge =
                  (rate['additional_charge'] ?? 0.0).toDouble();
              final total = fixedAmount + additionalCharge;

              return Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconForRate(rate['rate_name']),
                      color: Colors.purple,
                    ),
                  ),
                  title: Text(
                    rate['rate_name'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('ค่าคงที่: ${fixedAmount.toStringAsFixed(2)} บาท'),
                      if (additionalCharge > 0)
                        Text(
                          'ค่าเพิ่มเติม: ${additionalCharge.toStringAsFixed(2)} บาท',
                        ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.purple,
                        ),
                      ),
                      const Text(
                        'บาท',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _addFixedRate(rate);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForRate(String rateName) {
    final name = rateName.toLowerCase();
    if (name.contains('ไฟ') || name.contains('electric')) {
      return Icons.electric_bolt;
    }
    if (name.contains('น้ำ') || name.contains('water')) {
      return Icons.water_drop;
    }
    if (name.contains('ส่วนกลาง') || name.contains('common')) {
      return Icons.apartment;
    }
    if (name.contains('อินเทอร์เน็ต') ||
        name.contains('เน็ต') ||
        name.contains('internet') ||
        name.contains('wifi')) {
      return Icons.wifi;
    }
    if (name.contains('ขยะ') || name.contains('trash')) {
      return Icons.delete_outline;
    }
    if (name.contains('ที่จอดรถ') || name.contains('parking')) {
      return Icons.local_parking;
    }
    if (name.contains('รักษาความปลอดภัย') || name.contains('security')) {
      return Icons.security;
    }
    return Icons.receipt_long;
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive || isCompleted
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStepTitle(index),
                    style: TextStyle(
                      color: isActive || isCompleted
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'ข้อมูลพื้นฐาน';
      case 1:
        return 'ค่าบริการ';
      case 2:
        return 'ค่าใช้จ่าย';
      case 3:
        return 'สรุป';
      default:
        return '';
    }
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ข้อมูลพื้นฐาน',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedBranchId,
            decoration: InputDecoration(
              labelText: 'เลือกสาขา *',
              border: const OutlineInputBorder(),
              enabled: !_isFromMeterReading,
            ),
            items: _branches.map((branch) {
              return DropdownMenuItem<String>(
                value: branch['branch_id'] as String,
                child:
                    Text('${branch['branch_name']} (${branch['branch_code']})'),
              );
            }).toList(),
            onChanged: _isFromMeterReading
                ? null
                : (value) {
                    setState(() {
                      _selectedBranchId = value;
                      _selectedRoomId = null;
                      _selectedContractId = null;
                      _selectedTenantId = null;
                      _rooms.clear();
                      _contracts.clear();
                      _rentalAmount = 0.0;
                      _waterRate = 0.0;
                      _electricRate = 0.0;
                      _paymentSettings = null;
                    });
                    _loadRoomsAndContracts();
                  },
            validator: (value) => value == null ? 'กรุณาเลือกสาขา' : null,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedRoomId,
            decoration: InputDecoration(
              labelText: 'เลือกห้อง *',
              border: const OutlineInputBorder(),
              enabled: !_isFromMeterReading && _rooms.isNotEmpty,
            ),
            items: _rooms.map((room) {
              return DropdownMenuItem<String>(
                value: room['room_id'] as String,
                child: Text('ห้อง ${room['room_number']}'),
              );
            }).toList(),
            onChanged: _isFromMeterReading
                ? null
                : (value) {
                    setState(() {
                      _selectedRoomId = value;
                      _selectedContractId = null;
                      _selectedTenantId = null;
                      _contracts.clear();
                      _rentalAmount = 0.0;
                    });
                    _loadContractData();
                  },
            validator: (value) => value == null ? 'กรุณาเลือกห้อง' : null,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedContractId,
            decoration: InputDecoration(
              labelText: 'เลือกสัญญาเช่า *',
              border: const OutlineInputBorder(),
              enabled: !_isFromMeterReading && _contracts.isNotEmpty,
            ),
            isExpanded: true,
            isDense: false,
            menuMaxHeight: 300,
            items: _contracts.map((contract) {
              return DropdownMenuItem<String>(
                value: contract['contract_id'] as String,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${contract['contract_num']}'),
                    Text(
                      '${contract['tenant_name']} - ${contract['contract_price']} บาท',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _isFromMeterReading
                ? null
                : (value) {
                    setState(() {
                      _selectedContractId = value;
                      final contract = _contracts
                          .firstWhere((c) => c['contract_id'] == value);
                      _selectedTenantId = contract['tenant_id'];
                      // ⭐ อัปเดตค่าเช่า
                      _rentalAmount =
                          (contract['contract_price'] ?? 0.0).toDouble();
                      debugPrint('💰 อัปเดตค่าเช่า: $_rentalAmount');
                    });
                  },
            validator: (value) => value == null ? 'กรุณาเลือกสัญญาเช่า' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _invoiceMonth,
                  decoration: InputDecoration(
                    labelText: 'เดือน *',
                    border: const OutlineInputBorder(),
                    enabled: !_isFromMeterReading,
                  ),
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem<int>(
                      value: month,
                      child: Text(_getMonthName(month)),
                    );
                  }),
                  onChanged: _isFromMeterReading
                      ? null
                      : (value) {
                          setState(() => _invoiceMonth = value!);
                        },
                  validator: (value) =>
                      value == null ? 'กรุณาเลือกเดือน' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _invoiceYear,
                  decoration: InputDecoration(
                    labelText: 'ปี *',
                    border: const OutlineInputBorder(),
                    enabled: !_isFromMeterReading,
                  ),
                  items: List.generate(5, (index) {
                    final year = DateTime.now().year - 2 + index;
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text('$year'),
                    );
                  }),
                  onChanged: _isFromMeterReading
                      ? null
                      : (value) {
                          setState(() => _invoiceYear = value!);
                        },
                  validator: (value) => value == null ? 'กรุณาเลือกปี' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            decoration: const InputDecoration(
              labelText: 'วันครบกำหนดชำระ *',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            controller: TextEditingController(text: _formatDate(_dueDate)),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dueDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _dueDate = date);
              }
            },
          ),
          const SizedBox(height: 16),

          // ⭐ แสดงข้อมูลสรุปเมื่อเลือกสัญญาแล้ว
          if (_selectedRoomId != null && _selectedContractId != null)
            _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildUtilitiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ค่าบริการน้ำ-ไฟ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isFromMeterReading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'จากมิเตอร์',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildUtilitySection(
            title: 'ค่าน้ำ',
            icon: Icons.water_drop,
            color: Colors.blue,
            previousReading: _waterPreviousReading,
            currentReading: _waterCurrentReading,
            usage: _waterUsage,
            rate: _waterRate,
            cost: _waterCost,
            controller: _waterCurrentController,
            isReadOnly: _isFromMeterReading,
            onCurrentReadingChanged: (value) {
              setState(() {
                _waterCurrentReading = double.tryParse(value) ?? 0.0;
                _waterUsage = _waterCurrentReading - _waterPreviousReading;
                _waterCost = _waterUsage * _waterRate;
                _calculateUtilitiesTotal();
              });
            },
          ),
          const SizedBox(height: 16),
          _buildUtilitySection(
            title: 'ค่าไฟ',
            icon: Icons.electric_bolt,
            color: Colors.orange,
            previousReading: _electricPreviousReading,
            currentReading: _electricCurrentReading,
            usage: _electricUsage,
            rate: _electricRate,
            cost: _electricCost,
            controller: _electricCurrentController,
            isReadOnly: _isFromMeterReading,
            onCurrentReadingChanged: (value) {
              setState(() {
                _electricCurrentReading = double.tryParse(value) ?? 0.0;
                _electricUsage =
                    _electricCurrentReading - _electricPreviousReading;
                _electricCost = _electricUsage * _electricRate;
                _calculateUtilitiesTotal();
              });
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'รวมค่าบริการ:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_utilitiesAmount.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilitySection({
    required String title,
    required IconData icon,
    required Color color,
    required double previousReading,
    required double currentReading,
    required double usage,
    required double rate,
    required double cost,
    required TextEditingController controller,
    required bool isReadOnly,
    required ValueChanged<String> onCurrentReadingChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${rate.toStringAsFixed(2)} บาท/หน่วย',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('มิเตอร์ก่อนหน้า',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        previousReading.toStringAsFixed(0),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('มิเตอร์ปัจจุบัน',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        if (isReadOnly) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.lock, size: 12, color: Colors.grey[600]),
                        ],
                      ],
                    ),
                    TextFormField(
                      controller: controller,
                      readOnly: isReadOnly,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        filled: isReadOnly,
                        fillColor: isReadOnly ? Colors.grey[100] : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                      ],
                      onChanged: isReadOnly ? null : onCurrentReadingChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('จำนวนใช้งาน',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${usage.toStringAsFixed(0)} หน่วย',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ค่าใช้จ่าย:',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700]),
                ),
                Text(
                  '${cost.toStringAsFixed(2)} บาท',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⭐ Step 3: แสดงการตั้งค่าส่วนลดและค่าปรับ (ใช้ Payment Settings เท่านั้น)
  Widget _buildChargesDiscountsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ค่าใช้จ่ายเพิ่มเติม',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // แสดงค่าเช่า
          _buildAmountCard(
            title: 'ค่าห้อง',
            amount: _rentalAmount,
            color: Colors.green,
            icon: Icons.home,
          ),

          const SizedBox(height: 12),

          // ค่าบริการ
          _buildAmountCard(
            title: 'ค่าบริการน้ำ-ไฟ',
            amount: _utilitiesAmount,
            color: Colors.blue,
            icon: Icons.water_drop,
          ),

          const SizedBox(height: 12),

          // ⭐ ใช้ widget ใหม่สำหรับค่าใช้จ่ายอื่นๆ
          _buildOtherChargesSection(),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // แสดงส่วนลดและค่าปรับที่คำนวดได้ (แบบ Read-only)
          const Text(
            'ส่วนลดและค่าปรับ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'ระบบจะคำนวดอัตโนมัติตามการตั้งค่าของสาขา',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          _buildDiscountDisplay(),
          const SizedBox(height: 16),
          _buildLateFeeDisplay(),

          const SizedBox(height: 24),

          // หมายเหตุ
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'หมายเหตุเพิ่มเติม',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ⭐ Widget แสดงส่วนลดที่คำนวดได้ (Read-only Display)
  Widget _buildDiscountDisplay() {
    final hasPaymentSettings = _paymentSettings != null;
    final isDiscountEnabled = hasPaymentSettings &&
        _paymentSettings!['is_active'] == true &&
        _paymentSettings!['enable_discount'] == true;

    if (!hasPaymentSettings || !isDiscountEnabled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.discount_outlined, color: Colors.grey[400], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ส่วนลด',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ไม่มีส่วนลด',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Text(
              '0.00 บาท',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // คำนวดส่วนลดจาก Payment Settings
    final subtotal = _calculateSubtotal();
    final discountPercent = _paymentSettings!['early_payment_discount'] ?? 0;
    final earlyDays = _paymentSettings!['early_payment_days'] ?? 0;
    final discountAmount = PaymentSettingsService.calculateEarlyDiscountManual(
      settings: _paymentSettings!,
      dueDate: _dueDate,
      subtotal: subtotal,
      paymentDate: DateTime.now(),
    );

    // อัปเดตค่าส่วนลด
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_discountAmount != discountAmount) {
        setState(() {
          _discountAmount = discountAmount;
        });
      }
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.discount, color: Colors.green[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ส่วนลด ($discountPercent%)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ชำระก่อนกำหนด $earlyDays วัน',
                      style: TextStyle(fontSize: 12, color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
              Text(
                '-${discountAmount.toStringAsFixed(2)} บาท',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate, size: 16, color: Colors.green[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ยอดรวม ${subtotal.toStringAsFixed(2)} × $discountPercent% = ลด ${discountAmount.toStringAsFixed(2)} บาท',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⭐ Widget แสดงค่าปรับที่คำนวดได้ (Read-only Display)
  Widget _buildLateFeeDisplay() {
    final hasPaymentSettings = _paymentSettings != null;
    final isLateFeeEnabled = hasPaymentSettings &&
        _paymentSettings!['is_active'] == true &&
        _paymentSettings!['enable_late_fee'] == true;

    if (!hasPaymentSettings || !isLateFeeEnabled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined,
                color: Colors.grey[400], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ค่าปรับล่าช้า',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ไม่มีค่าปรับ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Text(
              '0.00 บาท',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // คำนวดค่าปรับจาก Payment Settings
    final subtotal = _calculateSubtotal();
    final lateFeeType = _paymentSettings!['late_fee_type'] ?? 'fixed';
    final lateFeeAmount = _paymentSettings!['late_fee_amount'] ?? 0;
    final startDay = _paymentSettings!['late_fee_start_day'] ?? 1;

    final calculatedLateFee = PaymentSettingsService.calculateLateFeeManual(
      settings: _paymentSettings!,
      dueDate: _dueDate,
      subtotal: subtotal,
      paymentDate: DateTime.now(),
    );

    // อัปเดตค่าปรับ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lateFeeAmount != calculatedLateFee) {
        setState(() {
          _lateFeeAmount = calculatedLateFee;
        });
      }
    });

    // เช็คว่าถึงวันที่ต้องคิดค่าปรับหรือยัง
    final daysLate = DateTime.now().difference(_dueDate).inDays;
    final shouldCharge = daysLate >= startDay;

    if (!shouldCharge) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ค่าปรับล่าช้า',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ยังไม่ถึงวันคิดค่าปรับ (เริ่ม $startDay วันหลังครบกำหนด)',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ],
              ),
            ),
            Text(
              '0.00 บาท',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      );
    }

    // แสดงค่าปรับที่คำนวดได้
    String lateFeeTypeText = '';
    String calculationText = '';

    switch (lateFeeType) {
      case 'fixed':
        lateFeeTypeText = '${lateFeeAmount.toStringAsFixed(0)} บาท คงที่';
        calculationText =
            'คิดค่าปรับคงที่ ${calculatedLateFee.toStringAsFixed(2)} บาท';
        break;
      case 'percentage':
        lateFeeTypeText = '$lateFeeAmount% ของยอดรวม';
        calculationText =
            'ยอดรวม ${subtotal.toStringAsFixed(2)} × $lateFeeAmount% = ${calculatedLateFee.toStringAsFixed(2)} บาท';
        break;
      case 'daily':
        final chargeDays = daysLate - startDay + 1;
        lateFeeTypeText = '${lateFeeAmount.toStringAsFixed(0)} บาท/วัน';
        calculationText =
            'ล่าช้า $daysLate วัน × ${lateFeeAmount.toStringAsFixed(0)} = ${calculatedLateFee.toStringAsFixed(2)} บาท';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ค่าปรับล่าช้า',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lateFeeTypeText,
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
              Text(
                '+${calculatedLateFee.toStringAsFixed(2)} บาท',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate, size: 16, color: Colors.red[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    calculationText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    final subtotal = _calculateSubtotal();
    final grandTotal = _calculateGrandTotal();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปรายการ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ข้อมูลพื้นฐาน
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ข้อมูลพื้นฐาน',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('เดือน-ปี',
                      '${_getMonthName(_invoiceMonth)} $_invoiceYear'),
                  _buildSummaryRow('วันครบกำหนด', _formatDate(_dueDate)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // รายการค่าใช้จ่าย
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รายการค่าใช้จ่าย',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // ⭐ แสดงค่าเช่า
                  _buildSummaryRow(
                      'ค่าห้อง', '${_rentalAmount.toStringAsFixed(2)} บาท'),

                  // ค่าน้ำ
                  _buildSummaryRow(
                      'ค่าน้ำ (${_waterUsage.toStringAsFixed(0)} หน่วย)',
                      '${_waterCost.toStringAsFixed(2)} บาท'),

                  // ค่าไฟ
                  _buildSummaryRow(
                      'ค่าไฟ (${_electricUsage.toStringAsFixed(0)} หน่วย)',
                      '${_electricCost.toStringAsFixed(2)} บาท'),

                  // ⭐ แสดงค่าใช้จ่ายอื่นๆแบบแยกรายการ
                  if (_selectedFixedRates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.receipt_long,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          'ค่าใช้จ่ายอื่นๆ:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_selectedFixedRates.length, (index) {
                      final rate = _selectedFixedRates[index];
                      final fixedAmount =
                          (rate['fixed_amount'] ?? 0.0).toDouble();
                      final additionalCharge =
                          (rate['additional_charge'] ?? 0.0).toDouble();
                      final total = fixedAmount + additionalCharge;

                      return Padding(
                        padding: const EdgeInsets.only(left: 24, bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              _getIconForRate(rate['rate_name']),
                              size: 14,
                              color: Colors.purple[400],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rate['rate_name'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Text(
                              '${total.toStringAsFixed(2)} บาท',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const Divider(height: 24),
                  _buildSummaryRow(
                      'รวมย่อย', '${subtotal.toStringAsFixed(2)} บาท',
                      isBold: true),
                  if (_discountAmount > 0)
                    _buildSummaryRow(
                        'ส่วนลด', '-${_discountAmount.toStringAsFixed(2)} บาท',
                        color: Colors.green),
                  if (_lateFeeAmount > 0)
                    _buildSummaryRow('ค่าปรับล่าช้า',
                        '+${_lateFeeAmount.toStringAsFixed(2)} บาท',
                        color: Colors.red),
                  const Divider(height: 24),
                  _buildSummaryRow(
                    'รวมทั้งสิ้น',
                    '${grandTotal.toStringAsFixed(2)} บาท',
                    isBold: true,
                    isLarge: true,
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ),
          ),

          if (_notesController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'หมายเหตุ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_notesController.text),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} บาท',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLarge = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final contract = _contracts.firstWhere(
      (c) => c['contract_id'] == _selectedContractId,
      orElse: () => {},
    );

    if (contract.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'ข้อมูลสัญญา',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildInfoRow('ผู้เช่า', contract['tenant_name'] ?? '-'),
            _buildInfoRow('เบอร์โทร', contract['tenant_phone'] ?? '-'),
            // ⭐ แสดงค่าเช่า
            _buildInfoRow(
                'ค่าห้อง', '${_rentalAmount.toStringAsFixed(2)} บาท/เดือน'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('ย้อนกลับ'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : (_currentStep < _totalSteps - 1
                      ? _nextStep
                      : _submitInvoice),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep < _totalSteps - 1
                          ? 'ถัดไป'
                          : 'สร้างใบแจ้งหนี้',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
