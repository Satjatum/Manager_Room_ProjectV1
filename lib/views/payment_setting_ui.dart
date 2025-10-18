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
              content: Text('ข้อมูลผู้ใช้ไม่ถูกต้อง'),
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
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (currentUser == null || selectedBranchId == null) {
      _showError('ข้อมูลผู้ใช้ไม่ถูกต้อง');
      return;
    }

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
        _showError('วันที่เริ่มคิดต้องอยู่ระหว่าง 1-31');
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

  String _getLateFeeTypeLabel(String type) {
    switch (type) {
      case 'fixed':
        return 'คงที่';
      case 'percentage':
        return 'เปอร์เซ็นต์';
      case 'daily':
        return 'รายวัน';
      default:
        return '';
    }
  }

  String _getLateFeeTypeDescription(String type) {
    final amount = double.tryParse(lateFeeAmountController.text) ?? 0;
    if (amount == 0) return 'ยังไม่ได้ตั้งค่า';

    switch (type) {
      case 'fixed':
        return '${amount.toStringAsFixed(0)} บาท';
      case 'percentage':
        return '$amount% ของยอดค้างชำระ';
      case 'daily':
        return '${amount.toStringAsFixed(0)} บาท/วัน';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าค่าปรับและส่วนลด'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  if (branches.isNotEmpty) _buildBranchSelector(),

                  const SizedBox(height: 20),

                  // Settings List
                  Text(
                    'การตั้งค่า',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Late Fee Item
                  _buildSettingListItem(
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red,
                    title: 'ค่าปรับชำระล่าช้า',
                    description: enableLateFee
                        ? _getLateFeeTypeDescription(lateFeeType)
                        : 'ปิดใช้งาน',
                    isActive: enableLateFee,
                    onTap: () => _openLateFeeDetail(),
                    onToggle: (value) {
                      setState(() {
                        enableLateFee = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // Discount Item
                  _buildSettingListItem(
                    icon: Icons.discount,
                    iconColor: Colors.green,
                    title: 'ส่วนลดชำระก่อนกำหนด',
                    description: enableDiscount
                        ? '${earlyPaymentDiscountController.text.isEmpty ? '0' : earlyPaymentDiscountController.text}% ในการชำระ'
                        : 'ปิดใช้งาน',
                    isActive: enableDiscount,
                    onTap: () => _openDiscountDetail(),
                    onToggle: (value) {
                      setState(() {
                        enableDiscount = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Additional Settings
                  Text(
                    'การตั้งค่าเพิ่มเติม',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Active Status Item
                  _buildStatusListItem(),

                  const SizedBox(height: 20),

                  // Notes Section
                  _buildNotesSection(),

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

  Widget _buildBranchSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.apartment, color: AppTheme.primary, size: 28),
            const SizedBox(width: 16),
            if (branches.length > 1)
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
                      borderSide:
                          const BorderSide(color: Color(0xff10B981), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey[300]!, width: 1),
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
              )
            else
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
    );
  }

  Widget _buildSettingListItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isActive,
    required VoidCallback onTap,
    required Function(bool) onToggle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isActive
                            ? Colors.grey.shade700
                            : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: isActive,
                onChanged: onToggle,
                activeColor: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusListItem() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isActive ? Icons.check_circle : Icons.cancel,
                color: isActive ? Colors.green : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'เปิดใช้งานการตั้งค่านี้',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive
                        ? 'การตั้งค่ากำลังใช้งาน'
                        : 'การตั้งค่าถูกปิดใช้งาน',
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes, color: AppTheme.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'หมายเหตุ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: settingDescController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'เพิ่มหมายเหตุเกี่ยวกับการตั้งค่า...',
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
          ],
        ),
      ),
    );
  }

  void _openLateFeeDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildLateFeeDetailSheet(),
    );
  }

  void _openDiscountDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildDiscountDetailSheet(),
    );
  }

  Widget _buildLateFeeDetailSheet() {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ตั้งค่าค่าปรับชำระล่าช้า',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ประเภทค่าปรับ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              _buildLateFeeTypeOption(
                value: 'fixed',
                title: 'คงที่ (Fixed)',
                subtitle: 'คิดค่าปรับเป็นจำนวนเงินคงที่',
                icon: Icons.monetization_on,
              ),
              const SizedBox(height: 8),
              _buildLateFeeTypeOption(
                value: 'percentage',
                title: 'เปอร์เซ็นต์ (Percentage)',
                subtitle: 'คิดค่าปรับเป็นเปอร์เซ็นต์ของยอดค้างชำระ',
                icon: Icons.percent,
              ),
              const SizedBox(height: 8),
              _buildLateFeeTypeOption(
                value: 'daily',
                title: 'รายวัน (Daily)',
                subtitle: 'คิดค่าปรับทุกวันที่เกินกำหนด',
                icon: Icons.event_repeat,
              ),
              const SizedBox(height: 20),
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
              TextFormField(
                controller: lateFeeStartDayController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'เริ่มคิดค่าปรับหลังกำหนด (วัน)',
                  hintText: '3',
                  prefixIcon: const Icon(Icons.event, color: Colors.red),
                  helperText: 'เช่น 3 = เริ่มคิดค่าปรับหลังเกิน 3 วัน',
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
                  helperText: 'จำกัดจำนวนค่าปรับไม่ให้เกินจำนวนนี้',
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
              Container(
                padding: const EdgeInsets.all(12),
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
                            size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'ตัวอย่างการคำนวณ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getLateFeeExample(),
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountDetailSheet() {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ตั้งค่าส่วนลดชำระก่อนกำหนด',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
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
                  helperText: 'เช่น 5% หมายถึงลด 5% จากยอดค้างชำระ',
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
                  helperText: 'เช่น 7 = ชำระก่อนกำหนด 7 วันขึ้นไปได้ส่วนลด',
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
              Container(
                padding: const EdgeInsets.all(12),
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
                            size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'ตัวอย่างการคำนวณ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getDiscountExample(),
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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

  String _getLateFeeExample() {
    final amount = double.tryParse(lateFeeAmountController.text) ?? 0;
    final startDay = int.tryParse(lateFeeStartDayController.text) ?? 1;

    if (amount == 0) {
      return 'กรุณากรอกจำนวนค่าปรับเพื่อดูตัวอย่างการคำนวณ';
    }

    if (lateFeeType == 'fixed') {
      return 'หากชำระล่าช้าเกิน $startDay วัน จะเพิ่มค่าปรับ ${amount.toStringAsFixed(0)} บาท\n\n'
          'ตัวอย่าง: ค่าเช่า 5,000 บาท ล่าช้า 5 วัน\n'
          'รวมชำระ = ${(5000 + amount).toStringAsFixed(0)} บาท';
    } else if (lateFeeType == 'percentage') {
      final sampleRental = 5000.0;
      final fee = sampleRental * (amount / 100);
      return 'ค่าเช่า ${sampleRental.toStringAsFixed(0)} บาท ล่าช้าเกิน $startDay วัน\n'
          'ค่าปรับ $amount% = ${fee.toStringAsFixed(0)} บาท\n'
          'รวมชำระ = ${(sampleRental + fee).toStringAsFixed(0)} บาท';
    } else {
      final sampleDays = 5;
      if (sampleDays < startDay) {
        return 'ตัวอย่าง: หากล่าช้าน้อยกว่า $startDay วัน จะไม่มีค่าปรับ';
      }
      final chargeDays = sampleDays - startDay + 1;
      final fee = amount * chargeDays;
      return 'ค่าปรับ ${amount.toStringAsFixed(0)} บาท/วัน\n'
          'ตัวอย่าง: ล่าช้า $sampleDays วัน = คิดค่าปรับ $chargeDays วัน\n'
          'ค่าปรับ = ${fee.toStringAsFixed(0)} บาท | รวม = ${(5000 + fee).toStringAsFixed(0)} บาท';
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

    return 'ค่าเช่า ${sampleRental.toStringAsFixed(0)} บาท | ชำระก่อนกำหนด $days วัน\n'
        'ส่วนลด $discount% = ${discountAmount.toStringAsFixed(0)} บาท\n'
        'ชำระเพียง ${finalAmount.toStringAsFixed(0)} บาท ประหยัดได้ ${discountAmount.toStringAsFixed(0)} บาท!';
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
