import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/utility_rate_service.dart';
import '../services/branch_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // โหลดข้อมูลสาขา
      final branchesData = await BranchService.getBranchesByUser();

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

      // เลือกสาขาแรกหากยังไม่เคยเลือก
      final branchId = selectedBranchId ?? branchesData[0]['branch_id'];

      // โหลดข้อมูลอัตราค่าบริการ
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
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit : Icons.add,
                color: const Color(0xff10B981),
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'แก้ไขอัตราค่าบริการ' : 'เพิ่มอัตราค่าบริการ'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rate Name
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อค่าบริการ *',
                      hintText: 'เช่น ค่าไฟฟ้า, ค่าน้ำ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rate Type Selection
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ประเภทการคิดค่าบริการ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text('คิดตามมิเตอร์ (Metered)'),
                          subtitle: const Text('คิดตามจำนวนที่ใช้จริง'),
                          value: isMetered,
                          onChanged: (value) {
                            setDialogState(() {
                              isMetered = value ?? false;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          title: const Text('ค่าคงที่ (Fixed)'),
                          subtitle: const Text('คิดเป็นจำนวนเงินคงที่ทุกเดือน'),
                          value: isFixed,
                          onChanged: (value) {
                            setDialogState(() {
                              isFixed = value ?? false;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price per unit (if metered)
                  if (isMetered) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'ราคาต่อหน่วย (บาท) *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: unitController,
                            decoration: const InputDecoration(
                              labelText: 'หน่วย *',
                              hintText: 'kWh',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Fixed Amount (if fixed)
                  if (isFixed) ...[
                    TextField(
                      controller: fixedController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'จำนวนเงินคงที่ (บาท) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.money),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'หน่วยเวลา',
                        hintText: 'เช่น เดือน',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Additional Charge
                  TextField(
                    controller: additionalController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'ค่าใช้จ่ายเพิ่มเติม (บาท)',
                      hintText: 'ถ้ามี',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_circle_outline),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Active Status
                  SwitchListTile(
                    title: const Text('เปิดใช้งาน'),
                    subtitle: Text(
                      isActive ? 'อัตรานี้กำลังใช้งาน' : 'อัตรานี้ไม่ใช้งาน',
                      style: TextStyle(
                        color: isActive ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() {
                        isActive = value;
                      });
                    },
                    activeColor: const Color(0xff10B981),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
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
                    // แก้ไข
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
                    // เพิ่มใหม่
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
                      content: Text(isEdit
                          ? 'แก้ไขอัตราค่าบริการเรียบร้อย'
                          : 'เพิ่มอัตราค่าบริการเรียบร้อย'),
                      backgroundColor: Colors.green,
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
                backgroundColor: const Color(0xff10B981),
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRate(Map<String, dynamic> rate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('ยืนยันการลบ'),
          ],
        ),
        content: Text(
          'คุณต้องการลบอัตราค่าบริการ "${rate['rate_name']}" หรือไม่?\n\n'
          'การลบจะส่งผลต่อการคำนวณบิลในอนาคต',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await UtilityRatesService.deleteUtilityRate(rate['rate_id']);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ลบอัตราค่าบริการเรียบร้อย'),
                    backgroundColor: Colors.green,
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
            ),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าอัตราค่าบริการ'),
        backgroundColor: const Color(0xff10B981),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Branch Selector
                if (branches.length > 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Row(
                      children: [
                        const Icon(Icons.apartment, color: Color(0xff10B981)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedBranchId,
                            decoration: const InputDecoration(
                              labelText: 'เลือกสาขา',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
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

                // Info Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.amber[50],
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ตั้งค่าอัตราค่าบริการก่อนออกบิล เพื่อให้ระบบคำนวณค่าใช้จ่ายได้ถูกต้อง',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Utility Rates List
                Expanded(
                  child: utilityRates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'ยังไม่มีอัตราค่าบริการ',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'กดปุ่ม + ด้านล่างเพื่อเพิ่มอัตราค่าบริการ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
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
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isActive
                                      ? const Color(0xff10B981).withOpacity(0.3)
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: isActive
                                      ? const Color(0xff10B981).withOpacity(0.1)
                                      : Colors.grey[200],
                                  child: Icon(
                                    _getIconForRate(rate['rate_name']),
                                    color: isActive
                                        ? const Color(0xff10B981)
                                        : Colors.grey,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rate['rate_name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isActive
                                              ? Colors.black
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    if (!isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'ปิดใช้งาน',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    if (isMetered)
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[100],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'มิเตอร์',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue[900],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${rate['rate_price']} บาท/${rate['rate_unit']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (isFixed)
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.purple[100],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'คงที่',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.purple[900],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${rate['fixed_amount']} บาท/${rate['rate_unit']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (rate['additional_charge'] > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'ค่าเพิ่มเติม: +${rate['additional_charge']} บาท',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
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
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('แก้ไข'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('ลบ',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
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
        backgroundColor: const Color(0xff10B981),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('เพิ่มอัตราค่าบริการ',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

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
  void dispose() {
    super.dispose();
  }
}
