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

  /// โหลดข้อมูลผู้ใช้และสาขาตามสิทธิ์
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

  /// แสดง Dialog สำหรับเพิ่ม/แก้ไขอัตราค่าบริการ
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
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit : Icons.add_circle_outline,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'แก้ไขอัตราค่าบริการ' : 'เพิ่มอัตราค่าบริการ',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อค่าบริการ
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อค่าบริการ *',
                      hintText: 'เช่น ค่าไฟฟ้า, ค่าน้ำ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.label),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ประเภทการคิดค่าบริการ
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.category,
                                color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'ประเภทการคิดค่าบริการ *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // คิดตามมิเตอร์
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              isMetered = true;
                              isFixed = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMetered
                                  ? AppTheme.primary.withOpacity(0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isMetered
                                    ? AppTheme.primary
                                    : Colors.grey.shade300,
                                width: isMetered ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isMetered
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: isMetered
                                      ? AppTheme.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'คิดตามมิเตอร์ (Metered)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isMetered
                                              ? AppTheme.primary
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'คิดตามจำนวนที่ใช้จริง',
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
                        ),
                        const SizedBox(height: 8),
                        // ค่าคงที่
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              isMetered = false;
                              isFixed = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isFixed
                                  ? AppTheme.primary.withOpacity(0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isFixed
                                    ? AppTheme.primary
                                    : Colors.grey.shade300,
                                width: isFixed ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isFixed
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color:
                                      isFixed ? AppTheme.primary : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ค่าคงที่ (Fixed)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isFixed
                                              ? AppTheme.primary
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'คิดเป็นจำนวนเงินคงที่ทุกเดือน',
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ฟิลด์สำหรับค่าบริการแบบมิเตอร์
                  if (isMetered) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'ราคาต่อหน่วย (บาท) *',
                              prefixIcon: const Icon(Icons.attach_money),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppTheme.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: unitController,
                            decoration: InputDecoration(
                              labelText: 'หน่วย *',
                              hintText: 'kWh',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppTheme.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ฟิลด์สำหรับค่าบริการแบบคงที่
                  if (isFixed) ...[
                    TextFormField(
                      controller: fixedController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'จำนวนเงินคงที่ (บาท) *',
                        prefixIcon: const Icon(Icons.money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppTheme.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: unitController,
                      decoration: InputDecoration(
                        labelText: 'หน่วยเวลา',
                        hintText: 'เช่น เดือน',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppTheme.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ค่าใช้จ่ายเพิ่มเติม
                  TextFormField(
                    controller: additionalController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'ค่าใช้จ่ายเพิ่มเติม (บาท)',
                      hintText: 'ถ้าไม่มีใส่ 0',
                      prefixIcon: const Icon(Icons.add_circle_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // สถานะการใช้งาน
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.toggle_on : Icons.toggle_off,
                          color: isActive ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'เปิดใช้งาน',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isActive
                                    ? 'อัตรานี้กำลังใช้งาน'
                                    : 'อัตรานี้ไม่ใช้งาน',
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
                            setDialogState(() {
                              isActive = value;
                            });
                          },
                          activeColor: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ยกเลิก',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validation
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณากรอกชื่อค่าบริการ'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (isMetered &&
                    (priceController.text.isEmpty ||
                        unitController.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'กรุณากรอกราคาและหน่วยสำหรับค่าบริการแบบมิเตอร์'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (isFixed && fixedController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณากรอกจำนวนเงินคงที่'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  if (isEdit) {
                    await UtilityRatesService.updateUtilityRate(
                      rateId: rate!['rate_id'],
                      rateName: nameController.text,
                      ratePrice: double.tryParse(priceController.text) ?? 0,
                      rateUnit: unitController.text,
                      isMetered: isMetered,
                      isFixed: isFixed,
                      fixedAmount: double.tryParse(fixedController.text) ?? 0,
                      additionalCharge:
                          double.tryParse(additionalController.text) ?? 0,
                      isActive: isActive,
                    );
                  } else {
                    await UtilityRatesService.createUtilityRate(
                      branchId: selectedBranchId!,
                      rateName: nameController.text,
                      ratePrice: double.tryParse(priceController.text) ?? 0,
                      rateUnit: unitController.text,
                      isMetered: isMetered,
                      isFixed: isFixed,
                      fixedAmount: double.tryParse(fixedController.text) ?? 0,
                      additionalCharge:
                          double.tryParse(additionalController.text) ?? 0,
                      isActive: isActive,
                    );
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(isEdit
                                ? 'แก้ไขอัตราค่าบริการเรียบร้อย'
                                : 'เพิ่มอัตราค่าบริการเรียบร้อย'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('เกิดข้อผิดพลาด: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
            ),
          ],
        ),
      ),
    );
  }

  /// ลบอัตราค่าบริการ
  void _deleteRate(Map<String, dynamic> rate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text(
              'ยืนยันการลบ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'คุณต้องการลบอัตราค่าบริการ "${rate['rate_name']}" หรือไม่?\n\n'
          'การลบจะส่งผลต่อการคำนวณบิลในอนาคต',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ยกเลิก',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await UtilityRatesService.deleteUtilityRate(rate['rate_id']);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('ลบอัตราค่าบริการเรียบร้อย'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _loadData();
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เกิดข้อผิดพลาด: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  /// ฟังก์ชันเลือกไอคอนตามชื่อค่าบริการ
  IconData _getIconForRate(String rateName) {
    if (rateName.contains('ไฟ')) return Icons.bolt;
    if (rateName.contains('น้ำ')) return Icons.water_drop;
    if (rateName.contains('ส่วนกลาง')) return Icons.apartment;
    if (rateName.contains('อินเทอร์เน็ต') || rateName.contains('เน็ต')) {
      return Icons.wifi;
    }
    return Icons.receipt_long;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าอัตราค่าบริการ'),
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
          : Column(
              children: [
                // ตัวเลือกสาขา
                if (branches.length > 1)
                  Card(
                    margin: const EdgeInsets.all(16),
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
                                  borderSide: BorderSide(
                                      color: AppTheme.primary, width: 2),
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

                // แสดงชื่อสาขาเมื่อมีเพียง 1 สาขา
                if (branches.length == 1)
                  Card(
                    margin: const EdgeInsets.all(16),
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

                // ข้อมูลแจ้งเตือน
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ตั้งค่าอัตราค่าบริการก่อนออกบิล เพื่อให้ระบบคำนวณค่าใช้จ่ายได้ถูกต้อง',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // รายการอัตราค่าบริการ
                Expanded(
                  child: utilityRates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.bolt_outlined,
                                    size: 64, color: Colors.grey.shade400),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'ยังไม่มีอัตราค่าบริการ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'กดปุ่ม + ด้านล่างเพื่อเพิ่มอัตราค่าบริการ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: utilityRates.length,
                          itemBuilder: (context, index) {
                            final rate = utilityRates[index];
                            final isMetered = rate['is_metered'] as bool;
                            final isFixed = rate['is_fixed'] as bool;
                            final isActive = rate['is_active'] as bool;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isActive
                                      ? AppTheme.primary.withOpacity(0.3)
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _showAddEditDialog(rate: rate),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // ไอคอน
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? AppTheme.primary
                                                  .withOpacity(0.1)
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _getIconForRate(rate['rate_name']),
                                          color: isActive
                                              ? AppTheme.primary
                                              : Colors.grey.shade600,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // ข้อมูล
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    rate['rate_name'],
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16,
                                                      color: isActive
                                                          ? Colors.black87
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                if (!isActive)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade300,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      'ปิดใช้งาน',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors
                                                            .grey.shade700,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (isMetered)
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.blue.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      'มิเตอร์',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .blue.shade900,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${rate['rate_price']} บาท/${rate['rate_unit']}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.blue.shade700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            if (isFixed)
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors
                                                          .purple.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      'คงที่',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .purple.shade900,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${rate['fixed_amount']} บาท/${rate['rate_unit']}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors
                                                          .purple.shade700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            if (rate['additional_charge'] > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 6),
                                                child: Text(
                                                  'ค่าเพิ่มเติม: +${rate['additional_charge']} บาท',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // เมนู
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Colors.grey.shade600,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showAddEditDialog(rate: rate);
                                          } else if (value == 'delete') {
                                            _deleteRate(rate);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit,
                                                    size: 20,
                                                    color: Color(0xff10B981)),
                                                SizedBox(width: 12),
                                                Text('แก้ไข'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete,
                                                    size: 20,
                                                    color: Colors.red),
                                                SizedBox(width: 12),
                                                Text('ลบ',
                                                    style: TextStyle(
                                                        color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primary,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'เพิ่มอัตราค่าบริการ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
