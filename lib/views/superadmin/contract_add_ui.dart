import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/contract_service.dart';
import '../../services/tenant_service.dart';
import '../../services/room_service.dart';
import '../../widgets/colors.dart';

class ContractAddUI extends StatefulWidget {
  final String? tenantId; // ถ้ามี = เลือกผู้เช่าไว้แล้ว
  final Map<String, dynamic>? tenantData;

  const ContractAddUI({
    Key? key,
    this.tenantId,
    this.tenantData,
  }) : super(key: key);

  @override
  State<ContractAddUI> createState() => _ContractAddUIState();
}

class _ContractAddUIState extends State<ContractAddUI> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // ข้อมูลที่ต้องกรอก
  String? _selectedTenantId;
  String? _selectedRoomId;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _paymentDay;
  String? _documentPath;
  String? _documentName;

  // Controllers
  final _contractPriceController = TextEditingController();
  final _contractDepositController = TextEditingController();
  final _noteController = TextEditingController();

  // ข้อมูล dropdown
  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _availableRooms = [];

  @override
  void initState() {
    super.initState();
    _selectedTenantId = widget.tenantId;
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
      // โหลดรายชื่อผู้เช่าที่ active
      final tenants = await TenantService.getActiveTenantsForAssignment();
      // โหลดห้องที่ว่าง
      final rooms = await RoomService.getActiveRooms();

      if (mounted) {
        setState(() {
          _tenants = tenants;
          _availableRooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // เลือกไฟล์เอกสารสัญญา
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true, // สำคัญสำหรับ Web - โหลดไฟล์เป็น bytes
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          // สำหรับ Web: ใช้ bytes, สำหรับ Mobile: ใช้ path
          _documentPath = file.path ?? ''; // Mobile path
          _documentName = file.name;
          // ถ้าต้องการเก็บ bytes สำหรับ Web
          // final bytes = file.bytes; // สำหรับ upload
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเลือกไฟล์: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // เลือกวันที่เริ่มสัญญา
  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('th', 'TH'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // ถ้ายังไม่เลือกวันสิ้นสุด ให้เซ็ตเป็น 1 ปีหลังจากวันเริ่ม
        if (_endDate == null) {
          _endDate = picked.add(Duration(days: 365));
        }
      });
    }
  }

  // เลือกวันที่สิ้นสุดสัญญา
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
    } else if (picked != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('วันสิ้นสุดต้องมากกว่าวันเริ่มต้น'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // เมื่อเลือกห้อง ให้ดึงราคาเช่าและค่าประกันมาใส่อัตโนมัติ
  void _onRoomSelected(String? roomId) {
    if (roomId == null) return;

    final room = _availableRooms.firstWhere(
      (r) => r['room_id'] == roomId,
      orElse: () => {},
    );

    if (room.isNotEmpty) {
      setState(() {
        _selectedRoomId = roomId;
        _contractPriceController.text = room['room_price']?.toString() ?? '';
        _contractDepositController.text =
            room['room_deposit']?.toString() ?? '';
      });
    }
  }

  Future<void> _saveContract() async {
    if (!_formKey.currentState!.validate()) return;

    // ตรวจสอบข้อมูลที่จำเป็น
    if (_selectedTenantId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กรุณาเลือกผู้เช่า'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_selectedRoomId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กรุณาเลือกห้อง'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_startDate == null || _endDate == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กรุณาเลือกวันที่เริ่มและสิ้นสุดสัญญา'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'tenant_id': _selectedTenantId,
        'room_id': _selectedRoomId,
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'contract_price': double.tryParse(_contractPriceController.text) ?? 0,
        'contract_deposit':
            double.tryParse(_contractDepositController.text) ?? 0,
        'payment_day': _paymentDay,
        'contract_note': _noteController.text.trim(),
      };

      final result = await ContractService.createContract(data);

      if (mounted) {
        setState(() => _isSaving = false);

        if (context.mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
        title: Text('สร้างสัญญาเช่าใหม่'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // ปุ่มเคลียร์ฟอร์ม
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'ล้างฟอร์ม',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('ยืนยันการล้างฟอร์ม'),
                  content: Text('ต้องการล้างข้อมูลทั้งหมดหรือไม่?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('ยกเลิก'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: Text('ล้างฟอร์ม'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                setState(() {
                  if (widget.tenantId == null) {
                    _selectedTenantId = null;
                  }
                  _selectedRoomId = null;
                  _startDate = null;
                  _endDate = null;
                  _paymentDay = null;
                  _documentPath = null;
                  _documentName = null;
                  _contractPriceController.clear();
                  _contractDepositController.clear();
                  _noteController.clear();
                });
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ล้างฟอร์มสำเร็จ'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // เลือกผู้เช่า
                  _buildSectionTitle('ข้อมูลผู้เช่า'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedTenantId,
                        decoration: InputDecoration(
                          labelText: 'เลือกผู้เช่า *',
                          prefixIcon:
                              Icon(Icons.person, color: AppTheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _tenants.map((tenant) {
                          return DropdownMenuItem<String>(
                            value: tenant['tenant_id'],
                            child: Text(
                                '${tenant['tenant_name']} (${tenant['tenant_email']})'),
                          );
                        }).toList(),
                        onChanged: widget.tenantId == null
                            ? (value) {
                                setState(() => _selectedTenantId = value);
                              }
                            : null,
                        validator: (value) =>
                            value == null ? 'กรุณาเลือกผู้เช่า' : null,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // เลือกห้อง
                  _buildSectionTitle('ข้อมูลห้อง'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedRoomId,
                        decoration: InputDecoration(
                          labelText: 'เลือกห้อง *',
                          prefixIcon: Icon(Icons.home, color: AppTheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _availableRooms
                            .map<DropdownMenuItem<String>>((room) {
                          return DropdownMenuItem<String>(
                            value: room['room_id'] as String,
                            child: Text(
                              'ห้อง ${room['room_number']} - ${room['branch_name']} (฿${room['room_price']})',
                            ),
                          );
                        }).toList(),
                        onChanged: _onRoomSelected,
                        validator: (value) =>
                            value == null ? 'กรุณาเลือกห้อง' : null,
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
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _startDate == null
                                      ? Colors.grey
                                      : Colors.black,
                                ),
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
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _endDate == null
                                      ? Colors.grey
                                      : Colors.black,
                                ),
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
                            items: List.generate(31, (index) => index + 1)
                                .map((day) => DropdownMenuItem(
                                      value: day,
                                      child: Text('วันที่ $day'),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _paymentDay = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // เอกสารและหมายเหตุ
                  _buildSectionTitle('เอกสารและหมายเหตุ'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // อัปโหลดเอกสาร (ยังไม่ทำงาน - สำหรับเวอร์ชันต่อไป)
                          OutlinedButton.icon(
                            onPressed: _pickDocument,
                            icon: Icon(Icons.upload_file),
                            label: Text(_documentName ??
                                'อัปโหลดเอกสารสัญญา (PDF, DOC, รูปภาพ)'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          if (_documentName != null) ...[
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _documentName!,
                                      style: TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _documentPath = null;
                                        _documentName = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(height: 16),

                          // หมายเหตุ
                          TextFormField(
                            controller: _noteController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'หมายเหตุ',
                              hintText: 'เงื่อนไขพิเศษ, ข้อตกลงเพิ่มเติม...',
                              prefixIcon:
                                  Icon(Icons.note, color: AppTheme.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  // ปุ่มบันทึก
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveContract,
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
                              Text('บันทึกสัญญา',
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
}
