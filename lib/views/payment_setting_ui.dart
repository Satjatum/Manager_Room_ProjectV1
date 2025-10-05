import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/payment_rate_service.dart';
import '../services/branch_service.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';
import '../widgets/colors.dart';

class PaymentSettingsUi extends StatefulWidget {
  const PaymentSettingsUi({Key? key}) : super(key: key);

  @override
  State<PaymentSettingsUi> createState() => _PaymentSettingsUiState();
}

class _PaymentSettingsUiState extends State<PaymentSettingsUi> {
  bool isLoading = true;
  String? selectedBranchId;
  List<Map<String, dynamic>> branches = [];
  UserModel? currentUser;

  // Late Fee Settings
  bool enableLateFee = false;
  String lateFeeType = 'fixed';
  final TextEditingController lateFeeAmountController = TextEditingController();
  final TextEditingController lateFeeStartDayController =
      TextEditingController();
  final TextEditingController lateFeeMaxAmountController =
      TextEditingController();

  // Discount Settings
  bool enableDiscount = false;
  final TextEditingController earlyPaymentDiscountController =
      TextEditingController();
  final TextEditingController earlyPaymentDaysController =
      TextEditingController();

  final TextEditingController settingDescController = TextEditingController();
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      currentUser = await AuthService.getCurrentUser();

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('กรุณาเข้าสู่ระบบใหม่'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      List<Map<String, dynamic>> branchesData;

      if (currentUser!.userRole == UserRole.superAdmin) {
        branchesData = await BranchService.getAllBranches(isActive: true);
      } else if (currentUser!.userRole == UserRole.admin) {
        branchesData = await BranchService.getBranchesManagedByUser(
          currentUser!.userId,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่มีสิทธิ์เข้าถึงหน้านี้'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      if (branchesData.isEmpty) {
        if (mounted) {
          setState(() {
            branches = [];
            selectedBranchId = null;
            isLoading = false;
          });
        }
        return;
      }

      final branchId = selectedBranchId ?? branchesData[0]['branch_id'];

      // Load existing settings
      final settings =
          await PaymentSettingsService.getPaymentSettings(branchId);

      if (mounted) {
        setState(() {
          branches = branchesData;
          selectedBranchId = branchId;

          if (settings != null) {
            enableLateFee = settings['enable_late_fee'] ?? false;
            lateFeeType = settings['late_fee_type'] ?? 'fixed';
            lateFeeAmountController.text =
                settings['late_fee_amount']?.toString() ?? '0';
            lateFeeStartDayController.text =
                settings['late_fee_start_day']?.toString() ?? '3';
            lateFeeMaxAmountController.text =
                settings['late_fee_max_amount']?.toString() ?? '';

            enableDiscount = settings['enable_discount'] ?? false;
            earlyPaymentDiscountController.text =
                settings['early_payment_discount']?.toString() ?? '0';
            earlyPaymentDaysController.text =
                settings['early_payment_days']?.toString() ?? '7';

            settingDescController.text = settings['setting_desc'] ?? '';
            isActive = settings['is_active'] ?? true;
          } else {
            // Default values
            enableLateFee = false;
            enableDiscount = false;
            isActive = true;
          }

          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (currentUser == null || selectedBranchId == null) {
      _showError('กรุณาเข้าสู่ระบบก่อนบันทึกการตั้งค่า');
      return;
    }

    // Validation
    if (enableLateFee) {
      if (lateFeeAmountController.text.isEmpty) {
        _showError('กรุณากรอกจำนวนค่าปรับ');
        return;
      }
      if (lateFeeStartDayController.text.isEmpty) {
        _showError('กรุณากรอกวันที่เริ่มคิดค่าปรับ');
        return;
      }

      final startDay = int.tryParse(lateFeeStartDayController.text) ?? 0;
      if (startDay < 1 || startDay > 31) {
        _showError('วันที่เริ่มคิดค่าปรับต้องอยู่ระหว่าง 1-31');
        return;
      }
    }

    if (enableDiscount) {
      if (earlyPaymentDiscountController.text.isEmpty) {
        _showError('กรุณากรอกเปอร์เซ็นต์ส่วนลด');
        return;
      }
      if (earlyPaymentDaysController.text.isEmpty) {
        _showError('กรุณากรอกจำนวนวันก่อนกำหนดชำระ');
        return;
      }

      final discount =
          double.tryParse(earlyPaymentDiscountController.text) ?? 0;
      if (discount <= 0 || discount > 100) {
        _showError('เปอร์เซ็นต์ส่วนลดต้องอยู่ระหว่าง 0-100');
        return;
      }
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );

    try {
      await PaymentSettingsService.savePaymentSettings(
        branchId: selectedBranchId!,
        enableLateFee: enableLateFee,
        lateFeeType: enableLateFee ? lateFeeType : null,
        lateFeeAmount: enableLateFee
            ? double.tryParse(lateFeeAmountController.text) ?? 0
            : null,
        lateFeeStartDay: enableLateFee
            ? int.tryParse(lateFeeStartDayController.text) ?? 1
            : null,
        lateFeeMaxAmount:
            enableLateFee && lateFeeMaxAmountController.text.isNotEmpty
                ? double.tryParse(lateFeeMaxAmountController.text)
                : null,
        enableDiscount: enableDiscount,
        earlyPaymentDiscount: enableDiscount
            ? double.tryParse(earlyPaymentDiscountController.text) ?? 0
            : null,
        earlyPaymentDays: enableDiscount
            ? int.tryParse(earlyPaymentDaysController.text) ?? 0
            : null,
        settingDesc: settingDescController.text.trim().isEmpty
            ? null
            : settingDescController.text.trim(),
        isActive: isActive,
        createdBy: currentUser!.userId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('บันทึกการตั้งค่าเรียบร้อย'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าค่าปรับและส่วนลด'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text('กำลังโหลดข้อมูล...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch Selector
                  if (branches.length > 1)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.apartment, color: AppTheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedBranchId,
                                decoration: InputDecoration(
                                  labelText: 'เลือกสาขา',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xff10B981), width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey[300]!, width: 1),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                items: branches.map((branch) {
                                  return DropdownMenuItem<String>(
                                    value: branch['branch_id'],
                                    child: Text(branch['branch_name']),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedBranchId = value;
                                  });
                                  _loadData();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (branches.length == 1)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.apartment, color: AppTheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'สาขา',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    branches[0]['branch_name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ========== LATE FEE SECTION ==========
                  _buildLateFeeSection(),

                  const SizedBox(height: 24),

                  // ========== DISCOUNT SECTION ==========
                  _buildDiscountSection(),

                  const SizedBox(height: 24),

                  // Additional Notes
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notes, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'หมายเหตุเพิ่มเติม',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: settingDescController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'ระบุรายละเอียดเพิ่มเติมเกี่ยวกับการตั้งค่า...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xff10B981), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey[300]!, width: 1),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Active Status
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.toggle_on : Icons.toggle_off,
                            color: isActive ? AppTheme.primary : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'เปิดใช้งานการตั้งค่านี้',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isActive
                                      ? 'การตั้งค่ากำลังใช้งานอยู่'
                                      : 'การตั้งค่าถูกปิดใช้งาน',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isActive,
                            onChanged: (value) {
                              setState(() {
                                isActive = value;
                              });
                            },
                            activeColor: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text(
                        'บันทึกการตั้งค่า',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildLateFeeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: enableLateFee
              ? Colors.red.withOpacity(0.3)
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Toggle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: enableLateFee
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: enableLateFee ? Colors.red.shade700 : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ค่าปรับชำระล่าช้า',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'คิดค่าปรับเมื่อผู้เช่าชำระเงินล่าช้า',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enableLateFee,
                  onChanged: (value) {
                    setState(() {
                      enableLateFee = value;
                    });
                  },
                  activeColor: Colors.red.shade600,
                ),
              ],
            ),

            if (enableLateFee) ...[
              const SizedBox(height: 20),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 20),

              // Late Fee Type Selection
              Text(
                'ประเภทค่าปรับ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // Fixed
              _buildLateFeeTypeOption(
                value: 'fixed',
                title: 'คงที่ (Fixed)',
                subtitle: 'คิดค่าปรับเป็นจำนวนเงินคงที่',
                icon: Icons.monetization_on,
              ),
              const SizedBox(height: 8),

              // Percentage
              _buildLateFeeTypeOption(
                value: 'percentage',
                title: 'เปอร์เซ็นต์ (Percentage)',
                subtitle: 'คิดค่าปรับเป็นเปอร์เซ็นต์ของยอดค้างชำระ',
                icon: Icons.percent,
              ),
              const SizedBox(height: 8),

              // Daily
              _buildLateFeeTypeOption(
                value: 'daily',
                title: 'รายวัน (Daily)',
                subtitle: 'คิดค่าปรับทุกวันที่เกินกำหนด',
                icon: Icons.event_repeat,
              ),

              const SizedBox(height: 20),

              // Late Fee Amount
              TextFormField(
                controller: lateFeeAmountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: lateFeeType == 'percentage'
                      ? 'เปอร์เซ็นต์ค่าปรับ (%)'
                      : 'จำนวนเงินค่าปรับ (บาท)',
                  hintText: lateFeeType == 'percentage' ? '5' : '50',
                  prefixIcon: Icon(
                    lateFeeType == 'percentage'
                        ? Icons.percent
                        : Icons.attach_money,
                    color: Colors.red,
                  ),
                  suffixText: lateFeeType == 'percentage' ? '%' : 'บาท',
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff10B981), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 16),

              // Start Day
              TextFormField(
                controller: lateFeeStartDayController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'เริ่มคิดค่าปรับหลังครบกำหนด (วัน)',
                  hintText: '3',
                  prefixIcon: const Icon(Icons.event, color: Colors.red),
                  suffixText: 'วัน',
                  helperText:
                      'เช่น กรอก 3 = เริ่มคิดค่าปรับหลังเกินกำหนด 3 วัน',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff10B981), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 16),

              // Max Amount (Optional)
              TextFormField(
                controller: lateFeeMaxAmountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'ค่าปรับสูงสุด (บาท) - ถ้ามี',
                  hintText: '1000',
                  prefixIcon: const Icon(Icons.money_off, color: Colors.red),
                  suffixText: 'บาท',
                  helperText: 'จำกัดค่าปรับไม่ให้เกินจำนวนนี้',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff10B981), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 16),

              // Example Calculation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate,
                            size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'ตัวอย่างการคำนวณ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _getLateFeeExample(),
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLateFeeTypeOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = lateFeeType == value;
    return InkWell(
      onTap: () {
        setState(() {
          lateFeeType = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.red.shade400 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.red.shade700 : Colors.grey,
            ),
            const SizedBox(width: 12),
            Icon(icon,
                color: isSelected ? Colors.red.shade700 : Colors.grey,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.red.shade900
                          : Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: enableDiscount
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Toggle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: enableDiscount
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.discount,
                    color: enableDiscount ? Colors.green.shade700 : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ส่วนลดชำระก่อนกำหนด',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ให้ส่วนลดเมื่อผู้เช่าชำระก่อนกำหนด',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enableDiscount,
                  onChanged: (value) {
                    setState(() {
                      enableDiscount = value;
                    });
                  },
                  activeColor: Colors.green.shade600,
                ),
              ],
            ),

            if (enableDiscount) ...[
              const SizedBox(height: 20),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 20),

              // Discount Percentage
              TextFormField(
                controller: earlyPaymentDiscountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'เปอร์เซ็นต์ส่วนลด (%)',
                  hintText: '5',
                  prefixIcon: const Icon(Icons.percent, color: Colors.green),
                  suffixText: '%',
                  helperText: 'เช่น 5% หมายถึงลด 5% จากยอดค่าเช่า',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff10B981), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 16),

              // Days Before Due Date
              TextFormField(
                controller: earlyPaymentDaysController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'ชำระก่อนกำหนดกี่วัน',
                  hintText: '7',
                  prefixIcon:
                      const Icon(Icons.event_available, color: Colors.green),
                  suffixText: 'วัน',
                  helperText:
                      'เช่น กรอก 7 = ชำระก่อนกำหนด 7 วันขึ้นไปได้ส่วนลด',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff10B981), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 16),

              // Example Calculation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate,
                            size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'ตัวอย่างการคำนวณ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _getDiscountExample(),
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getLateFeeExample() {
    final amount = double.tryParse(lateFeeAmountController.text) ?? 0;
    final startDay = int.tryParse(lateFeeStartDayController.text) ?? 1;

    if (amount == 0) {
      return 'กรุณากรอกจำนวนค่าปรับเพื่อดูตัวอย่างการคำนวณ';
    }

    if (lateFeeType == 'fixed') {
      return 'หากชำระล่าช้า เกิน $startDay วัน จะเพิ่มค่าปรับ ${amount.toStringAsFixed(0)} บาท\n\n'
          'ตัวอย่าง:\n'
          '• ค่าเช่า 5,000 บาท\n'
          '• ล่าช้า 5 วัน (เกิน $startDay วัน)\n'
          '• ค่าปรับ = ${amount.toStringAsFixed(0)} บาท\n'
          '• รวมชำระ = ${(5000 + amount).toStringAsFixed(0)} บาท';
    } else if (lateFeeType == 'percentage') {
      final sampleRental = 5000.0;
      final fee = sampleRental * (amount / 100);
      return 'หากค่าเช่า ${sampleRental.toStringAsFixed(0)} บาท และล่าช้าเกิน $startDay วัน\n'
          'จะเพิ่มค่าปรับ $amount% = ${fee.toStringAsFixed(0)} บาท\n\n'
          'ตัวอย่าง:\n'
          '• ค่าเช่า ${sampleRental.toStringAsFixed(0)} บาท\n'
          '• ล่าช้า 5 วัน (เกิน $startDay วัน)\n'
          '• ค่าปรับ $amount% = ${fee.toStringAsFixed(0)} บาท\n'
          '• รวมชำระ = ${(sampleRental + fee).toStringAsFixed(0)} บาท';
    } else {
      final sampleDays = 5;
      if (sampleDays < startDay) {
        return 'ตัวอย่าง: หากล่าช้าน้อยกว่า $startDay วัน จะไม่มีค่าปรับ';
      }
      final chargeDays = sampleDays - startDay + 1;
      final fee = amount * chargeDays;
      return 'ค่าปรับ ${amount.toStringAsFixed(0)} บาท/วัน หลังเกิน $startDay วัน\n\n'
          'ตัวอย่าง:\n'
          '• ค่าเช่า 5,000 บาท\n'
          '• ล่าช้า $sampleDays วัน (เกิน $startDay วัน = คิดค่าปรับ $chargeDays วัน)\n'
          '• ค่าปรับ = ${amount.toStringAsFixed(0)} × $chargeDays = ${fee.toStringAsFixed(0)} บาท\n'
          '• รวมชำระ = ${(5000 + fee).toStringAsFixed(0)} บาท';
    }
  }

  String _getDiscountExample() {
    final discount = double.tryParse(earlyPaymentDiscountController.text) ?? 0;
    final days = int.tryParse(earlyPaymentDaysController.text) ?? 7;

    if (discount == 0) {
      return 'กรุณากรอกเปอร์เซ็นต์ส่วนลดเพื่อดูตัวอย่างการคำนวณ';
    }

    final sampleRental = 5000.0;
    final discountAmount = sampleRental * (discount / 100);
    final finalAmount = sampleRental - discountAmount;

    return 'หากค่าเช่า ${sampleRental.toStringAsFixed(0)} บาท และชำระก่อนกำหนด $days วัน\n'
        'จะได้ส่วนลด $discount% = ${discountAmount.toStringAsFixed(0)} บาท\n\n'
        'ตัวอย่าง:\n'
        '• ค่าเช่า ${sampleRental.toStringAsFixed(0)} บาท\n'
        '• ชำระก่อนกำหนด $days วัน\n'
        '• ส่วนลด $discount% = ${discountAmount.toStringAsFixed(0)} บาท\n'
        '• ชำระเพียง ${finalAmount.toStringAsFixed(0)} บาท\n'
        '• ประหยัดได้ ${discountAmount.toStringAsFixed(0)} บาท!';
  }

  @override
  void dispose() {
    lateFeeAmountController.dispose();
    lateFeeStartDayController.dispose();
    lateFeeMaxAmountController.dispose();
    earlyPaymentDiscountController.dispose();
    earlyPaymentDaysController.dispose();
    settingDescController.dispose();
    super.dispose();
  }
}
