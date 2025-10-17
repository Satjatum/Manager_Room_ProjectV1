import 'package:flutter/material.dart';
import '../../services/contract_service.dart';
import '../../widgets/colors.dart';

class ContractEditUI extends StatefulWidget {
  final String contractId;

  const ContractEditUI({
    Key? key,
    required this.contractId,
  }) : super(key: key);

  @override
  State<ContractEditUI> createState() => _ContractEditUIState();
}

class _ContractEditUIState extends State<ContractEditUI> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, dynamic>? _contract;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _paymentDay;

  final _contractPriceController = TextEditingController();
  final _contractDepositController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _contractPriceController.dispose();
    _contractDepositController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final contract = await ContractService.getContractById(widget.contractId);

      if (contract != null && mounted) {
        setState(() {
          _contract = contract;
          _startDate = DateTime.parse(contract['start_date']);
          _endDate = DateTime.parse(contract['end_date']);
          _paymentDay = contract['payment_day'];
          _contractPriceController.text =
              contract['contract_price']?.toString() ?? '';
          _contractDepositController.text =
              contract['contract_deposit']?.toString() ?? '';
          _noteController.text = contract['contract_note'] ?? '';
          _isLoading = false;
        });
      } else {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('th', 'TH'),
    );

    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(Duration(days: 365)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
      locale: const Locale('th', 'TH'),
    );

    if (picked != null && picked.isAfter(_startDate!)) {
      setState(() => _endDate = picked);
    } else if (picked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('วันสิ้นสุดต้องมากกว่าวันเริ่มต้น'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _updateContract() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณาเลือกวันที่เริ่มและสิ้นสุดสัญญา'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'contract_price': double.tryParse(_contractPriceController.text) ?? 0,
        'contract_deposit':
            double.tryParse(_contractDepositController.text) ?? 0,
        'payment_day': _paymentDay,
        'contract_note': _noteController.text.trim(),
      };

      final result =
          await ContractService.updateContract(widget.contractId, data);

      if (mounted) {
        setState(() => _isSaving = false);

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'เลือกวันที่';
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แก้ไขสัญญาเช่า'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // แสดงข้อมูลที่ไม่สามารถแก้ไขได้
                  Card(
                    elevation: 2,
                    color: Colors.grey[100],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'ข้อมูลพื้นฐาน (ไม่สามารถแก้ไขได้)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          _buildReadOnlyRow(
                              'เลขที่สัญญา', _contract!['contract_num']),
                          _buildReadOnlyRow(
                              'ผู้เช่า', _contract!['tenant_name']),
                          _buildReadOnlyRow(
                              'ห้อง', 'ห้อง ${_contract!['room_number']}'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // วันที่เริ่มต้นและสิ้นสุด
                  _buildSectionTitle('ระยะเวลาสัญญา'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // วันที่เริ่มสัญญา
                          InkWell(
                            onTap: _selectStartDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'วันที่เริ่มสัญญา *',
                                prefixIcon: Icon(Icons.calendar_today,
                                    color: AppTheme.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _formatDate(_startDate),
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // วันที่สิ้นสุดสัญญา
                          InkWell(
                            onTap: _selectEndDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'วันที่สิ้นสุดสัญญา *',
                                prefixIcon:
                                    Icon(Icons.event, color: AppTheme.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _formatDate(_endDate),
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // ค่าเช่าและค่าประกัน
                  _buildSectionTitle('รายละเอียดการเงิน'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // ค่าเช่า
                          TextFormField(
                            controller: _contractPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'ค่าเช่าต่อเดือน (บาท) *',
                              prefixIcon: Icon(Icons.attach_money,
                                  color: AppTheme.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณากรอกค่าเช่า';
                              }
                              if (double.tryParse(value) == null) {
                                return 'กรุณากรอกตัวเลขที่ถูกต้อง';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // ค่าประกัน
                          TextFormField(
                            controller: _contractDepositController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'ค่าประกัน (บาท) *',
                              prefixIcon:
                                  Icon(Icons.security, color: AppTheme.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณากรอกค่าประกัน';
                              }
                              if (double.tryParse(value) == null) {
                                return 'กรุณากรอกตัวเลขที่ถูกต้อง';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // วันชำระเงินประจำเดือน
                          DropdownButtonFormField<int>(
                            value: _paymentDay,
                            decoration: InputDecoration(
                              labelText: 'วันชำระเงินประจำเดือน',
                              prefixIcon: Icon(Icons.calendar_month,
                                  color: AppTheme.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              helperText: 'เลือกวันที่ 1-31 ของทุกเดือน',
                            ),
                            items: [
                              DropdownMenuItem<int>(
                                value: null,
                                child: Text('ไม่ระบุ'),
                              ),
                              ...List.generate(31, (index) => index + 1)
                                  .map<DropdownMenuItem<int>>(
                                      (day) => DropdownMenuItem<int>(
                                            value: day,
                                            child: Text('วันที่ $day'),
                                          ))
                                  .toList(),
                            ],
                            onChanged: (value) =>
                                setState(() => _paymentDay = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // หมายเหตุ
                  _buildSectionTitle('หมายเหตุ'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: TextFormField(
                        controller: _noteController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'หมายเหตุ',
                          hintText: 'เงื่อนไขพิเศษ, ข้อตกลงเพิ่มเติม...',
                          prefixIcon: Icon(Icons.note, color: AppTheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  // ปุ่มบันทึก
                  ElevatedButton(
                    onPressed: _isSaving ? null : _updateContract,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('กำลังบันทึก...',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save, size: 24),
                              SizedBox(width: 8),
                              Text('บันทึกการแก้ไข',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
