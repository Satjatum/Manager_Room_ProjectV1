import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/invoice_service.dart';
import '../../services/room_service.dart';
import '../../services/tenant_service.dart';
import '../../services/contract_service.dart';
import '../../services/utility_rate_service.dart';
import '../../services/payment_rate_service.dart';
import '../../services/auth_service.dart';
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

  // Data
  UserModel? _currentUser;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _utilityRates = [];
  Map<String, dynamic>? _paymentSettings;

  // Form data
  String? _selectedRoomId;
  String? _selectedTenantId;
  String? _selectedContractId;
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

  // Utility usage
  List<Map<String, dynamic>> _utilityUsages = [];
  List<Map<String, dynamic>> _otherChargesList = [];

  // UI State
  bool _isLoading = false;
  bool _isSubmitting = false;
  int _currentStep = 0;
  final int _totalSteps = 4;

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
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      _currentUser = await AuthService.getCurrentUser();

      if (widget.initialData != null) {
        _applyInitialData();
      }

      await _loadBasicData();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyInitialData() {
    final data = widget.initialData!;
    _selectedRoomId = data['room_id'];
    _selectedTenantId = data['tenant_id'];
    _selectedContractId = data['contract_id'];
    _invoiceMonth = data['invoice_month'] ?? DateTime.now().month;
    _invoiceYear = data['invoice_year'] ?? DateTime.now().year;

    // เพิ่มข้อมูลการใช้งานน้ำ-ไฟจาก meter reading
    if (data['water_usage'] != null || data['electric_usage'] != null) {
      _utilityUsages = [
        if (data['water_usage'] != null)
          {
            'rate_id': 'water', // temporary
            'utility_name': 'ค่าน้ำ',
            'usage_amount': data['water_usage'],
            'unit_price': 0.0,
            'total_amount': 0.0,
          },
        if (data['electric_usage'] != null)
          {
            'rate_id': 'electric', // temporary
            'utility_name': 'ค่าไฟ',
            'usage_amount': data['electric_usage'],
            'unit_price': 0.0,
            'total_amount': 0.0,
          },
      ];
    }
  }

  Future<void> _loadBasicData() async {
    try {
      // โหลดห้องทั้งหมด
      _rooms = await RoomService.getAllRooms();

      if (_selectedRoomId != null) {
        await _loadRoomRelatedData();
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error loading basic data: $e');
    }
  }

  Future<void> _loadRoomRelatedData() async {
    if (_selectedRoomId == null) return;

    try {
      // โหลดสัญญาเช่าของห้องนี้
      _contracts = await ContractService.getContractsByRoom(_selectedRoomId!);

      // ถ้ามีสัญญาและยังไม่ได้เลือก ให้เลือกสัญญาที่ active
      if (_contracts.isNotEmpty && _selectedContractId == null) {
        final activeContract = _contracts.firstWhere(
          (contract) => contract['contract_status'] == 'active',
          orElse: () => _contracts.first,
        );
        _selectedContractId = activeContract['contract_id'];
        _selectedTenantId = activeContract['tenant_id'];
        _rentalAmount = (activeContract['contract_price'] ?? 0.0).toDouble();
      }

      // โหลดอัตราค่าบริการ
      final room = _rooms.firstWhere((r) => r['room_id'] == _selectedRoomId);
      if (room['branch_id'] != null) {
        _utilityRates = await UtilityRatesService.getActiveRatesForBranch(
            room['branch_id']);
        _paymentSettings =
            await PaymentSettingsService.getActivePaymentSettings(
                room['branch_id']);
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error loading room related data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างใบแจ้งหนี้'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _currentStep > 0 ? _previousStep : null,
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

          // เลือกห้อง
          _buildDropdownField(
            label: 'เลือกห้อง *',
            value: _selectedRoomId,
            items: _rooms.map((room) {
              return DropdownMenuItem<String>(
                value: room['room_id'],
                child: Text(
                    'ห้อง ${room['room_number']} - ${room['branch_name'] ?? ''}'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoomId = value;
                _selectedContractId = null;
                _selectedTenantId = null;
                _contracts.clear();
                _rentalAmount = 0.0;
              });
              _loadRoomRelatedData();
            },
          ),

          const SizedBox(height: 16),

          // เลือกสัญญา
          if (_contracts.isNotEmpty)
            _buildDropdownField(
              label: 'เลือกสัญญาเช่า *',
              value: _selectedContractId,
              items: _contracts.map((contract) {
                return DropdownMenuItem<String>(
                  value: contract['contract_id'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${contract['contract_num']}'),
                      Text(
                        '${contract['tenant_name']} - ${contract['contract_price']} บาท',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedContractId = value;
                  final contract =
                      _contracts.firstWhere((c) => c['contract_id'] == value);
                  _selectedTenantId = contract['tenant_id'];
                  _rentalAmount =
                      (contract['contract_price'] ?? 0.0).toDouble();
                });
              },
            ),

          const SizedBox(height: 16),

          // เลือกเดือน/ปี
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'เดือน *',
                  value: _invoiceMonth,
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem<int>(
                      value: month,
                      child: Text(_getMonthName(month)),
                    );
                  }),
                  onChanged: (value) {
                    setState(() => _invoiceMonth = value!);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'ปี *',
                  value: _invoiceYear,
                  items: List.generate(5, (index) {
                    final year = DateTime.now().year - 2 + index;
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text('$year'),
                    );
                  }),
                  onChanged: (value) {
                    setState(() => _invoiceYear = value!);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // วันครบกำหนดชำระ
          _buildDateField(
            label: 'วันครบกำหนดชำระ *',
            value: _dueDate,
            onChanged: (date) {
              setState(() => _dueDate = date);
            },
          ),

          const SizedBox(height: 16),

          // แสดงข้อมูลห้องและผู้เช่า
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ค่าบริการ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _addUtilityUsage,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มค่าบริการ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // รายการค่าบริการ
          if (_utilityUsages.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.electrical_services,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('ยังไม่มีค่าบริการ'),
                    Text('กดปุ่ม "เพิ่มค่าบริการ" เพื่อเริ่มต้น'),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_utilityUsages.length, (index) {
              return _buildUtilityUsageCard(index);
            }),

          const SizedBox(height: 16),

          // สรุปค่าบริการ
          if (_utilityUsages.isNotEmpty)
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

          // ค่าใช้จ่ายอื่นๆ
          _buildSectionCard(
            title: 'ค่าใช้จ่ายอื่นๆ',
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('รายการค่าใช้จ่าย'),
                    TextButton.icon(
                      onPressed: _addOtherCharge,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('เพิ่ม'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_otherChargesList.isEmpty)
                  const Text('ไม่มีค่าใช้จ่ายเพิ่มเติม')
                else
                  ...List.generate(_otherChargesList.length, (index) {
                    return _buildOtherChargeItem(index);
                  }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ส่วนลด
          _buildSectionCard(
            title: 'ส่วนลด',
            child: Column(
              children: [
                _buildDropdownField(
                  label: 'ประเภทส่วนลด',
                  value: _discountType,
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('ไม่มีส่วนลด')),
                    DropdownMenuItem(
                        value: 'early_payment', child: Text('ชำระก่อนกำหนด')),
                    DropdownMenuItem(value: 'custom', child: Text('กำหนดเอง')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _discountType = value!;
                      if (value == 'none') {
                        _discountAmount = 0.0;
                        _discountAmountController.clear();
                      } else if (value == 'early_payment' &&
                          _paymentSettings != null) {
                        _calculateEarlyPaymentDiscount();
                      }
                    });
                  },
                ),
                if (_discountType != 'none') ...[
                  const SizedBox(height: 12),
                  _buildNumberField(
                    controller: _discountAmountController,
                    label: 'จำนวนเงินส่วนลด',
                    suffix: 'บาท',
                    onChanged: (value) {
                      setState(() {
                        _discountAmount = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _discountReasonController,
                    decoration: const InputDecoration(
                      labelText: 'เหตุผลการให้ส่วนลด',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ค่าปรับ
          _buildSectionCard(
            title: 'ค่าปรับ',
            child: Column(
              children: [
                _buildNumberField(
                  controller: _lateFeeAmountController,
                  label: 'ค่าปรับ',
                  suffix: 'บาท',
                  onChanged: (value) {
                    setState(() {
                      _lateFeeAmount = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lateFeeReasonController,
                  decoration: const InputDecoration(
                    labelText: 'เหตุผลการปรับ',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                if (_paymentSettings != null &&
                    _paymentSettings!['enable_late_fee'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'หมายเหตุ: ระบบจะคิดค่าปรับอัตโนมัติตามการตั้งค่า',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // หมายเหตุ
          _buildSectionCard(
            title: 'หมายเหตุ',
            child: TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุเพิ่มเติม',
                border: OutlineInputBorder(),
                hintText: 'ระบุข้อมูลเพิ่มเติมเกี่ยวกับใบแจ้งหนี้นี้...',
              ),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    final subtotal = _rentalAmount + _utilitiesAmount + _otherCharges;
    final total = subtotal - _discountAmount + _lateFeeAmount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปใบแจ้งหนี้',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ข้อมูลผู้เช่า
          _buildSummaryCard(
            title: 'ข้อมูลผู้เช่า',
            children: [
              _buildSummaryRow('ห้อง:', _getRoomDisplay()),
              _buildSummaryRow('ผู้เช่า:', _getTenantDisplay()),
              _buildSummaryRow(
                  'เดือน:', '${_getMonthName(_invoiceMonth)} $_invoiceYear'),
              _buildSummaryRow('ครบกำหนด:', _formatDate(_dueDate)),
            ],
          ),

          const SizedBox(height: 16),

          // รายละเอียดค่าใช้จ่าย
          _buildSummaryCard(
            title: 'รายละเอียดค่าใช้จ่าย',
            children: [
              _buildSummaryRow(
                  'ค่าเช่า:', '${_rentalAmount.toStringAsFixed(2)} บาท'),
              _buildSummaryRow(
                  'ค่าบริการ:', '${_utilitiesAmount.toStringAsFixed(2)} บาท'),
              if (_otherCharges > 0)
                _buildSummaryRow('ค่าใช้จ่ายอื่นๆ:',
                    '${_otherCharges.toStringAsFixed(2)} บาท'),
              const Divider(),
              _buildSummaryRow('รวม:', '${subtotal.toStringAsFixed(2)} บาท',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_discountAmount > 0)
                _buildSummaryRow(
                    'ส่วนลด:', '-${_discountAmount.toStringAsFixed(2)} บาท',
                    style: const TextStyle(color: Colors.green)),
              if (_lateFeeAmount > 0)
                _buildSummaryRow(
                    'ค่าปรับ:', '+${_lateFeeAmount.toStringAsFixed(2)} บาท',
                    style: const TextStyle(color: Colors.red)),
              const Divider(),
              _buildSummaryRow(
                  'ยอดรวมสุทธิ:', '${total.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary)),
            ],
          ),

          const SizedBox(height: 16),

          // รายละเอียดค่าบริการ
          if (_utilityUsages.isNotEmpty)
            _buildSummaryCard(
              title: 'รายละเอียดค่าบริการ',
              children: _utilityUsages.map((usage) {
                return _buildSummaryRow(
                  '${usage['utility_name']}:',
                  '${usage['usage_amount']} x ${usage['unit_price']} = ${usage['total_amount'].toStringAsFixed(2)} บาท',
                );
              }).toList(),
            ),

          const SizedBox(height: 16),

          // หมายเหตุ
          if (_notesController.text.isNotEmpty)
            _buildSummaryCard(
              title: 'หมายเหตุ',
              children: [
                Text(_notesController.text),
              ],
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
                child: const Text('ย้อนกลับ'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleNextStep,
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
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_currentStep == _totalSteps - 1
                      ? 'สร้างใบแจ้งหนี้'
                      : 'ถัดไป'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: onChanged,
      validator: (value) => value == null ? 'กรุณาเลือก$label' : null,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      readOnly: true,
      controller: TextEditingController(text: _formatDate(value)),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          onChanged(date);
        }
      },
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: suffix,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildInfoCard() {
    final room = _rooms.firstWhere((r) => r['room_id'] == _selectedRoomId);
    final contract =
        _contracts.firstWhere((c) => c['contract_id'] == _selectedContractId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ข้อมูลห้องและผู้เช่า',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('ห้อง:', 'ห้อง ${room['room_number']}'),
          _buildInfoRow('สาขา:', room['branch_name'] ?? '-'),
          _buildInfoRow('ผู้เช่า:', contract['tenant_name'] ?? '-'),
          _buildInfoRow('สัญญา:', contract['contract_num'] ?? '-'),
          _buildInfoRow('ค่าเช่า:', '${_rentalAmount.toStringAsFixed(2)} บาท'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildUtilityUsageCard(int index) {
    final usage = _utilityUsages[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    usage['utility_name'] ?? 'ค่าบริการ',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeUtilityUsage(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    controller: TextEditingController(
                      text: usage['usage_amount']?.toString() ?? '0',
                    ),
                    label: 'จำนวนการใช้งาน',
                    suffix: 'หน่วย',
                    onChanged: (value) {
                      setState(() {
                        _utilityUsages[index]['usage_amount'] =
                            double.tryParse(value) ?? 0.0;
                        _calculateUtilityTotal(index);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    controller: TextEditingController(
                      text: usage['unit_price']?.toString() ?? '0',
                    ),
                    label: 'ราคาต่อหน่วย',
                    suffix: 'บาท',
                    onChanged: (value) {
                      setState(() {
                        _utilityUsages[index]['unit_price'] =
                            double.tryParse(value) ?? 0.0;
                        _calculateUtilityTotal(index);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('รวม:'),
                  Text(
                    '${usage['total_amount']?.toStringAsFixed(2) ?? '0.00'} บาท',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildOtherChargeItem(int index) {
    final charge = _otherChargesList[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  charge['charge_name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${charge['charge_amount']?.toStringAsFixed(2) ?? '0.00'} บาท',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeOtherCharge(index),
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      {required String title, required List<Widget> children}) {
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: style),
        ],
      ),
    );
  }

  // Helper Methods
  String _getMonthName(int month) {
    const monthNames = [
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
    return monthNames[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getRoomDisplay() {
    if (_selectedRoomId == null) return '-';
    final room = _rooms.firstWhere((r) => r['room_id'] == _selectedRoomId);
    return 'ห้อง ${room['room_number']} (${room['branch_name'] ?? ''})';
  }

  String _getTenantDisplay() {
    if (_selectedContractId == null) return '-';
    final contract =
        _contracts.firstWhere((c) => c['contract_id'] == _selectedContractId);
    return contract['tenant_name'] ?? '-';
  }

  void _calculateUtilityTotal(int index) {
    final usage = _utilityUsages[index];
    final usageAmount = usage['usage_amount'] ?? 0.0;
    final unitPrice = usage['unit_price'] ?? 0.0;
    final total = usageAmount * unitPrice;

    _utilityUsages[index]['total_amount'] = total;

    // คำนวณยอดรวมค่าบริการ
    _utilitiesAmount = _utilityUsages.fold(
        0.0, (sum, item) => sum + (item['total_amount'] ?? 0.0));
  }

  void _calculateOtherChargesTotal() {
    _otherCharges = _otherChargesList.fold(
        0.0, (sum, item) => sum + (item['charge_amount'] ?? 0.0));
  }

  void _calculateEarlyPaymentDiscount() {
    if (_paymentSettings == null ||
        _paymentSettings!['enable_discount'] != true) return;

    final subtotal = _rentalAmount + _utilitiesAmount + _otherCharges;
    final discountPercent = _paymentSettings!['early_payment_discount'] ?? 0.0;
    final discount = subtotal * (discountPercent / 100);

    setState(() {
      _discountAmount = discount;
      _discountAmountController.text = discount.toStringAsFixed(2);
    });
  }

  // Actions
  void _addUtilityUsage() async {
    if (_utilityRates.isEmpty) {
      _showErrorSnackBar('ไม่มีอัตราค่าบริการในสาขานี้');
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _UtilitySelectionDialog(utilityRates: _utilityRates),
    );

    if (result != null) {
      setState(() {
        _utilityUsages.add({
          'rate_id': result['rate_id'],
          'utility_name': result['rate_name'],
          'usage_amount': 0.0,
          'unit_price': result['rate_price'],
          'total_amount': 0.0,
        });
      });
    }
  }

  void _removeUtilityUsage(int index) {
    setState(() {
      _utilityUsages.removeAt(index);
      _utilitiesAmount = _utilityUsages.fold(
          0.0, (sum, item) => sum + (item['total_amount'] ?? 0.0));
    });
  }

  void _addOtherCharge() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _OtherChargeDialog(),
    );

    if (result != null) {
      setState(() {
        _otherChargesList.add(result);
        _calculateOtherChargesTotal();
      });
    }
  }

  void _removeOtherCharge(int index) {
    setState(() {
      _otherChargesList.removeAt(index);
      _calculateOtherChargesTotal();
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleNextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _submitInvoice();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _selectedRoomId != null &&
            _selectedContractId != null &&
            _selectedTenantId != null;
      case 1:
        return true; // ค่าบริการไม่บังคับ
      case 2:
        return true; // ค่าใช้จ่ายเพิ่มเติมไม่บังคับ
      case 3:
        return true;
      default:
        return false;
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
        'invoice_month': _invoiceMonth,
        'invoice_year': _invoiceYear,
        'rental_amount': _rentalAmount,
        'utilities_amount': _utilitiesAmount,
        'other_charges': _otherCharges,
        'discount_type': _discountType,
        'discount_amount': _discountAmount,
        'discount_reason': _discountReasonController.text.trim(),
        'late_fee_amount': _lateFeeAmount,
        'due_date': _dueDate.toIso8601String().split('T')[0],
        'invoice_notes': _notesController.text.trim(),
      };

      final result = await InvoiceService.createInvoice(invoiceData);

      if (result['success']) {
        _showSuccessSnackBar('สร้างใบแจ้งหนี้สำเร็จ');
        Navigator.pop(context, result);
      } else {
        _showErrorSnackBar(result['message']);
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Dialog สำหรับเลือกค่าบริการ
class _UtilitySelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> utilityRates;

  const _UtilitySelectionDialog({required this.utilityRates});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เลือกค่าบริการ'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: utilityRates.length,
          itemBuilder: (context, index) {
            final rate = utilityRates[index];
            return ListTile(
              title: Text(rate['rate_name'] ?? ''),
              subtitle: Text('${rate['rate_price']} บาท/${rate['rate_unit']}'),
              onTap: () => Navigator.pop(context, rate),
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
    );
  }
}

// Dialog สำหรับเพิ่มค่าใช้จ่ายอื่นๆ
class _OtherChargeDialog extends StatefulWidget {
  const _OtherChargeDialog();

  @override
  State<_OtherChargeDialog> createState() => _OtherChargeDialogState();
}

class _OtherChargeDialogState extends State<_OtherChargeDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มค่าใช้จ่าย'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'ชื่อค่าใช้จ่าย *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'จำนวนเงิน *',
              border: OutlineInputBorder(),
              suffixText: 'บาท',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'รายละเอียด',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty &&
                _amountController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'charge_name': _nameController.text.trim(),
                'charge_amount': double.tryParse(_amountController.text) ?? 0.0,
                'charge_desc': _descController.text.trim(),
              });
            }
          },
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }
}
