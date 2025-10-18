import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/utility_rate_service.dart';
import '../services/branch_service.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';
import '../widgets/colors.dart';

class UtilityRatesManagementUi extends StatefulWidget {
  const UtilityRatesManagementUi({Key? key}) : super(key: key);

  @override
  State<UtilityRatesManagementUi> createState() =>
      _UtilityRatesManagementUiState();
}

class _UtilityRatesManagementUiState extends State<UtilityRatesManagementUi> {
  bool isLoading = true;
  List<Map<String, dynamic>> utilityRates = [];
  String? selectedBranchId;
  List<Map<String, dynamic>> branches = [];
  UserModel? currentUser;

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
            utilityRates = [];
            selectedBranchId = null;
            isLoading = false;
          });
        }
        return;
      }

      final branchId = selectedBranchId ?? branchesData[0]['branch_id'];
      final ratesData = await UtilityRatesService.getUtilityRates(
        branchId: branchId,
      );

      if (mounted) {
        setState(() {
          branches = branchesData;
          utilityRates = ratesData;
          selectedBranchId = branchId;
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

  void _showAddEditDialog({Map<String, dynamic>? rate}) {
    final isEdit = rate != null;
    final nameController =
        TextEditingController(text: rate?['rate_name'] ?? '');
    final priceController =
        TextEditingController(text: rate?['rate_price']?.toString() ?? '0');
    final unitController =
        TextEditingController(text: rate?['rate_unit'] ?? '');
    final fixedController =
        TextEditingController(text: rate?['fixed_amount']?.toString() ?? '0');
    final additionalController = TextEditingController(
        text: rate?['additional_charge']?.toString() ?? '0');

    bool isMetered = rate?['is_metered'] ?? true;
    bool isFixed = rate?['is_fixed'] ?? false;
    bool isActive = rate?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade50],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEdit
                                ? Icons.edit_rounded
                                : Icons.add_circle_rounded,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit
                                    ? 'แก้ไขอัตราค่าบริการ'
                                    : 'เพิ่มอัตราค่าบริการใหม่',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEdit
                                    ? 'อัปเดตรายละเอียด'
                                    : 'สร้างอัตราค่าบริการใหม่',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Rate Name
                    _buildFormField(
                      label: 'ชื่ออัตราค่าบริการ *',
                      hint: 'เช่น ค่าไฟฟ้า, ค่านำ้',
                      controller: nameController,
                      icon: Icons.label_rounded,
                    ),
                    const SizedBox(height: 20),

                    // Rate Type Selection
                    _buildRateTypeSection(
                      isMetered: isMetered,
                      isFixed: isFixed,
                      onMeteredChanged: () {
                        setDialogState(() {
                          isMetered = true;
                          isFixed = false;
                        });
                      },
                      onFixedChanged: () {
                        setDialogState(() {
                          isMetered = false;
                          isFixed = true;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Metered fields
                    if (isMetered) ...[
                      _buildFormField(
                        label: 'ราคา/หน่วย *',
                        hint: '0.00',
                        controller: priceController,
                        icon: Icons.attach_money_rounded,
                        isNumeric: true,
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        label: 'หน่วย *',
                        hint: 'เช่น kwh, ลบม. ม.',
                        controller: unitController,
                        icon: Icons.straighten_rounded,
                      ),
                    ],

                    if (isFixed) ...[
                      _buildFormField(
                        label: 'จำนวนเงินคงที่ *',
                        hint: '0.00',
                        controller: fixedController,
                        icon: Icons.attach_money_rounded,
                        isNumeric: true,
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        label: 'หน่วย',
                        hint: 'เช่น ต่อเดือน',
                        controller: unitController,
                        icon: Icons.calendar_month_rounded,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Additional charge
                    _buildFormField(
                      label: 'ค่าใช้จ่ายเพิ่มเติม',
                      hint: 'ถ้าไม่มีใส่ 0',
                      controller: additionalController,
                      icon: Icons.add_circle_rounded,
                      isNumeric: true,
                    ),
                    const SizedBox(height: 20),

                    // Active toggle
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? Colors.green.shade200
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isActive
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'สถานะการใช้งาน',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isActive
                                      ? 'อัตราค่านี้กำลังใช้งาน'
                                      : 'อัตราค่านี้ปิดการใช้งาน',
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
                              setDialogState(() => isActive = value);
                            },
                            activeColor: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'ยกเลิก',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) {
                                _showErrorSnackBar(
                                    'กรุณากรอกชื่ออัตราค่าบริการ');
                                return;
                              }

                              if (isMetered &&
                                  (priceController.text.isEmpty ||
                                      unitController.text.isEmpty)) {
                                _showErrorSnackBar(
                                    'กรุณากรอกราคาและหน่วยสำหรับค่าบริการแบบมิเตอร์');
                                return;
                              }

                              if (isFixed && fixedController.text.isEmpty) {
                                _showErrorSnackBar('กรุณากรอกจำนวนเงินคงที่');
                                return;
                              }

                              try {
                                if (isEdit) {
                                  await UtilityRatesService.updateUtilityRate(
                                    rateId: rate!['rate_id'],
                                    rateName: nameController.text,
                                    ratePrice:
                                        double.tryParse(priceController.text) ??
                                            0,
                                    rateUnit: unitController.text,
                                    isMetered: isMetered,
                                    isFixed: isFixed,
                                    fixedAmount:
                                        double.tryParse(fixedController.text) ??
                                            0,
                                    additionalCharge: double.tryParse(
                                            additionalController.text) ??
                                        0,
                                    isActive: isActive,
                                  );
                                } else {
                                  await UtilityRatesService.createUtilityRate(
                                    branchId: selectedBranchId!,
                                    rateName: nameController.text,
                                    ratePrice:
                                        double.tryParse(priceController.text) ??
                                            0,
                                    rateUnit: unitController.text,
                                    isMetered: isMetered,
                                    isFixed: isFixed,
                                    fixedAmount:
                                        double.tryParse(fixedController.text) ??
                                            0,
                                    additionalCharge: double.tryParse(
                                            additionalController.text) ??
                                        0,
                                    isActive: isActive,
                                  );
                                }

                                Navigator.pop(context);
                                _showSuccessSnackBar(isEdit
                                    ? 'แก้ไขอัตราค่าบริการเรียบร้อย'
                                    : 'เพิ่มอัตราค่าบริการเรียบร้อย');
                                _loadData();
                              } catch (e) {
                                _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isEdit ? 'บันทึก' : 'เพิ่ม',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : [],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRateTypeSection({
    required bool isMetered,
    required bool isFixed,
    required VoidCallback onMeteredChanged,
    required VoidCallback onFixedChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.category_rounded,
                  color: Colors.blue.shade700, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'ประเภทอัตราค่าบริการ *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRateTypeOption(
          title: 'คิดตามมิเตอร์ (Metered)',
          subtitle: 'คิดตามจำนวนที่ใช้จริง',
          isSelected: isMetered,
          onTap: onMeteredChanged,
        ),
        const SizedBox(height: 10),
        _buildRateTypeOption(
          title: 'ค่าคงที่ (Fixed)',
          subtitle: 'คิดเป็นจำนวนเงินคงที่ทุกเดือน',
          isSelected: isFixed,
          onTap: onFixedChanged,
        ),
      ],
    );
  }

  Widget _buildRateTypeOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? AppTheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color:
                          isSelected ? AppTheme.primary : Colors.grey.shade700,
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

  void _deleteRate(Map<String, dynamic> rate) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ยืนยันการลบ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'คุณต้องการลบอัตราค่าบริการ "${rate['rate_name']}" หรือไม่?\n\nการลบจะส่งผลต่อการคำนวณบิลในอนาคต',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await UtilityRatesService.deleteUtilityRate(
                              rate['rate_id']);
                          Navigator.pop(context);
                          _showSuccessSnackBar('ลบอัตราค่าบริการเรียบร้อย');
                          _loadData();
                        } catch (e) {
                          Navigator.pop(context);
                          _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('ลบ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ตั้งค่าอัตราค่าบริการ'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('เพิ่มอัตรา'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      body: SafeArea(
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'กำลังโหลดข้อมูล...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Branch selector
                  Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.apartment_rounded,
                                color: AppTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedBranchId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'เลือกสาขา',
                                border: InputBorder.none,
                                labelStyle: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
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
                          IconButton(
                            tooltip: 'รีเฟรช',
                            onPressed: _loadData,
                            icon: Icon(Icons.refresh_rounded,
                                color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // List items
                  Expanded(
                    child: utilityRates.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(Icons.receipt_long_rounded,
                                      size: 48, color: Colors.grey.shade400),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'ยังไม่มีอัตราค่าบริการ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'แตะ "เพิ่มอัตรา" เพื่อสร้างรายการแรก',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                            itemCount: utilityRates.length,
                            itemBuilder: (context, index) {
                              final item = utilityRates[index];
                              final name = item['rate_name'] ?? '-';
                              final unit = item['rate_unit'] ?? '';
                              final price = item['rate_price'] ?? 0;
                              final isActive = item['is_active'] ?? true;
                              final isMetered = item['is_metered'] ?? true;
                              final isFixed = item['is_fixed'] ?? false;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () => _showAddEditDialog(rate: item),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.energy_savings_leaf_rounded,
                                            color: AppTheme.primary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isActive
                                                          ? const Color(
                                                              0xFFD1FAE5)
                                                          : const Color(
                                                              0xFFF3F4F6),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
                                                    child: Text(
                                                      isActive
                                                          ? 'ใช้งาน'
                                                          : 'ปิด',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isActive
                                                            ? const Color(
                                                                0xFF065F46)
                                                            : const Color(
                                                                0xFF6B7280),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                isMetered
                                                    ? 'แบบมิเตอร์ • ${price.toString()} / $unit'
                                                    : (isFixed
                                                        ? 'เหมาจ่าย • ${price.toString()}'
                                                        : 'อัตรา ${price.toString()}'),
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                children: [
                                                  if (isMetered)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.blue.shade50,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                          color: Colors
                                                              .blue.shade200,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .straighten_rounded,
                                                            size: 12,
                                                            color: Colors
                                                                .blue.shade700,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            'คิดตามมิเตอร์',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors.blue
                                                                  .shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (isFixed)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .purple.shade50,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                          color: Colors
                                                              .purple.shade200,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .lock_clock_rounded,
                                                            size: 12,
                                                            color: Colors.purple
                                                                .shade700,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            'เหมาจ่าย',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .purple
                                                                  .shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_rounded,
                                                      color: AppTheme.primary,
                                                      size: 18),
                                                  const SizedBox(width: 8),
                                                  const Text('แก้ไข'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: Colors.red,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'ลบ',
                                                    style: TextStyle(
                                                        color: Colors.red),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showAddEditDialog(rate: item);
                                            } else if (value == 'delete') {
                                              _deleteRate(item);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
