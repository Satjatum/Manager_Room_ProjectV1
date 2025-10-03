import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentSettingsUi extends StatefulWidget {
  const PaymentSettingsUi({Key? key}) : super(key: key);

  @override
  State<PaymentSettingsUi> createState() => _PaymentSettingsUiState();
}

class _PaymentSettingsUiState extends State<PaymentSettingsUi> {
  bool isLoading = true;
  String? selectedBranchId;
  List<Map<String, dynamic>> branches = [];

  // Late Fee Settings
  bool enableLateFee = false;
  String lateFeeType = 'fixed'; // fixed, percentage, daily
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

    // TODO: Load from Supabase
    await Future.delayed(const Duration(milliseconds: 500));

    // Sample data
    setState(() {
      branches = [
        {'branch_id': '1', 'branch_name': 'สาขาหลัก'},
        {'branch_id': '2', 'branch_name': 'สาขา 2'},
      ];

      selectedBranchId = branches.isNotEmpty ? branches[0]['branch_id'] : null;

      // Load existing settings (sample)
      enableLateFee = true;
      lateFeeType = 'daily';
      lateFeeAmountController.text = '50';
      lateFeeStartDayController.text = '3';
      lateFeeMaxAmountController.text = '1000';

      enableDiscount = true;
      earlyPaymentDiscountController.text = '5';
      earlyPaymentDaysController.text = '7';

      isActive = true;
      isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
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
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // TODO: Save to Supabase
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกการตั้งค่าเรียบร้อย'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าค่าปรับและส่วนลด'),
        backgroundColor: const Color(0xff10B981),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'บันทึกการตั้งค่า',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch Selector
                  if (branches.length > 1)
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.apartment,
                                color: Color(0xff10B981)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedBranchId,
                                decoration: const InputDecoration(
                                  labelText: 'เลือกสาขา',
                                  border: OutlineInputBorder(),
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

                  if (branches.length > 1) const SizedBox(height: 16),

                  // Info Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'การตั้งค่านี้จะส่งผลต่อการคำนวณบิลอัตโนมัติ\nกรุณาตรวจสอบความถูกต้องก่อนบันทึก',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ========== LATE FEE SECTION ==========
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: enableLateFee
                            ? Colors.red.withOpacity(0.3)
                            : Colors.grey[300]!,
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red[700],
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'คิดค่าปรับเมื่อผู้เช่าชำระเงินล่าช้า',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
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
                                activeColor: Colors.red,
                              ),
                            ],
                          ),

                          if (enableLateFee) ...[
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 20),

                            // Late Fee Type Selection
                            const Text(
                              'ประเภทค่าปรับ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),

                            RadioListTile<String>(
                              title: const Text('คงที่ (Fixed)'),
                              subtitle:
                                  const Text('คิดค่าปรับเป็นจำนวนเงินคงที่'),
                              value: 'fixed',
                              groupValue: lateFeeType,
                              onChanged: (value) {
                                setState(() {
                                  lateFeeType = value!;
                                });
                              },
                              activeColor: Colors.red,
                            ),

                            RadioListTile<String>(
                              title: const Text('เปอร์เซ็นต์ (Percentage)'),
                              subtitle: const Text(
                                  'คิดค่าปรับเป็นเปอร์เซ็นต์ของยอดค้างชำระ'),
                              value: 'percentage',
                              groupValue: lateFeeType,
                              onChanged: (value) {
                                setState(() {
                                  lateFeeType = value!;
                                });
                              },
                              activeColor: Colors.red,
                            ),

                            RadioListTile<String>(
                              title: const Text('รายวัน (Daily)'),
                              subtitle:
                                  const Text('คิดค่าปรับทุกวันที่เกินกำหนด'),
                              value: 'daily',
                              groupValue: lateFeeType,
                              onChanged: (value) {
                                setState(() {
                                  lateFeeType = value!;
                                });
                              },
                              activeColor: Colors.red,
                            ),

                            const SizedBox(height: 20),

                            // Late Fee Amount
                            TextField(
                              controller: lateFeeAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                              decoration: InputDecoration(
                                labelText: lateFeeType == 'percentage'
                                    ? 'เปอร์เซ็นต์ค่าปรับ (%)'
                                    : 'จำนวนเงินค่าปรับ (บาท)',
                                hintText:
                                    lateFeeType == 'percentage' ? '5' : '50',
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(
                                  lateFeeType == 'percentage'
                                      ? Icons.percent
                                      : Icons.attach_money,
                                  color: Colors.red,
                                ),
                                suffixText:
                                    lateFeeType == 'percentage' ? '%' : 'บาท',
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Start Day
                            TextField(
                              controller: lateFeeStartDayController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'เริ่มคิดค่าปรับหลังครบกำหนด (วัน)',
                                hintText: '3',
                                border: OutlineInputBorder(),
                                prefixIcon:
                                    Icon(Icons.event, color: Colors.red),
                                suffixText: 'วัน',
                                helperText:
                                    'เช่น กรอก 3 = เริ่มคิดค่าปรับหลังเกินกำหนด 3 วัน',
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Max Amount (Optional)
                            TextField(
                              controller: lateFeeMaxAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'ค่าปรับสูงสุด (บาท) - ถ้ามี',
                                hintText: '1000',
                                border: OutlineInputBorder(),
                                prefixIcon:
                                    Icon(Icons.money_off, color: Colors.red),
                                suffixText: 'บาท',
                                helperText: 'จำกัดค่าปรับไม่ให้เกินจำนวนนี้',
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Example Calculation
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calculate,
                                          size: 16, color: Colors.red[700]),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ตัวอย่างการคำนวณ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[900],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getLateFeeExample(),
                                    style: TextStyle(
                                      color: Colors.red[800],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ========== DISCOUNT SECTION ==========
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: enableDiscount
                            ? Colors.green.withOpacity(0.3)
                            : Colors.grey[300]!,
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.discount,
                                  color: Colors.green[700],
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'ให้ส่วนลดเมื่อผู้เช่าชำระก่อนกำหนด',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
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
                                activeColor: Colors.green,
                              ),
                            ],
                          ),

                          if (enableDiscount) ...[
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 20),

                            // Discount Percentage
                            TextField(
                              controller: earlyPaymentDiscountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'เปอร์เซ็นต์ส่วนลด (%)',
                                hintText: '5',
                                border: OutlineInputBorder(),
                                prefixIcon:
                                    Icon(Icons.percent, color: Colors.green),
                                suffixText: '%',
                                helperText:
                                    'เช่น 5% หมายถึงลด 5% จากยอดค่าเช่า',
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Days Before Due Date
                            TextField(
                              controller: earlyPaymentDaysController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'ชำระก่อนกำหนดกี่วัน',
                                hintText: '7',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.event_available,
                                    color: Colors.green),
                                suffixText: 'วัน',
                                helperText:
                                    'เช่น กรอก 7 = ชำระก่อนกำหนด 7 วันขึ้นไปได้ส่วนลด',
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Example Calculation
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calculate,
                                          size: 16, color: Colors.green[700]),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ตัวอย่างการคำนวณ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[900],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getDiscountExample(),
                                    style: TextStyle(
                                      color: Colors.green[800],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Additional Notes
                  TextField(
                    controller: settingDescController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'หมายเหตุเพิ่มเติม (ถ้ามี)',
                      hintText: 'ระบุรายละเอียดเพิ่มเติมเกี่ยวกับการตั้งค่า...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Active Status
                  Card(
                    elevation: 2,
                    child: SwitchListTile(
                      title: const Text('เปิดใช้งานการตั้งค่านี้'),
                      subtitle: Text(
                        isActive
                            ? 'การตั้งค่ากำลังใช้งานอยู่'
                            : 'การตั้งค่าถูกปิดใช้งาน',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      value: isActive,
                      onChanged: (value) {
                        setState(() {
                          isActive = value;
                        });
                      },
                      activeColor: const Color(0xff10B981),
                      secondary: Icon(
                        isActive ? Icons.check_circle : Icons.cancel,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'บันทึกการตั้งค่า',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  String _getLateFeeExample() {
    final amount = double.tryParse(lateFeeAmountController.text) ?? 0;
    final startDay = int.tryParse(lateFeeStartDayController.text) ?? 1;

    if (lateFeeType == 'fixed') {
      return 'หากชำระล่าช้า เกิน $startDay วัน จะเพิ่มค่าปรับ ${amount.toStringAsFixed(0)} บาท';
    } else if (lateFeeType == 'percentage') {
      return 'หากค่าเช่า 5,000 บาท และล่าช้าเกิน $startDay วัน\n'
          'จะเพิ่มค่าปรับ $amount% = ${(5000 * amount / 100).toStringAsFixed(0)} บาท';
    } else {
      return 'ค่าปรับ ${amount.toStringAsFixed(0)} บาท/วัน หลังเกิน $startDay วัน\n'
          'ตัวอย่าง: ล่าช้า 5 วัน = ${(amount * (5 - startDay + 1)).toStringAsFixed(0)} บาท';
    }
  }

  String _getDiscountExample() {
    final discount = double.tryParse(earlyPaymentDiscountController.text) ?? 0;
    final days = int.tryParse(earlyPaymentDaysController.text) ?? 7;

    return 'หากค่าเช่า 5,000 บาท และชำระก่อนกำหนด $days วัน\n'
        'จะได้ส่วนลด $discount% = ${(5000 * discount / 100).toStringAsFixed(0)} บาท\n'
        'ชำระเพียง ${(5000 - (5000 * discount / 100)).toStringAsFixed(0)} บาท';
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
