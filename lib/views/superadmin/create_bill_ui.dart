import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CreateBillScreen extends StatefulWidget {
  final String? branchId;
  final String? branchName;
  final String? tenantId;
  final String? roomId;

  const CreateBillScreen({
    Key? key,
    this.branchId,
    this.branchName,
    this.tenantId,
    this.roomId,
  }) : super(key: key);

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form Controllers
  final _billTitleController = TextEditingController();
  final _billAmountController = TextEditingController();
  final _notesController = TextEditingController();

  // Form Values
  String? _selectedBranchId;
  String? _selectedBranchName;
  String? _selectedTenantId;
  String? _selectedTenantName;
  String? _selectedRoomId;
  String? _selectedRoomNumber;
  String _selectedBillType = 'rent';
  String _selectedPaymentMethod = 'cash';
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(Duration(days: 7));

  // Data Lists
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _billItems = [];

  // Bill Types
  final List<Map<String, dynamic>> _billTypes = [
    {'value': 'rent', 'label': 'ค่าเช่า', 'icon': Icons.home},
    {
      'value': 'utilities',
      'label': 'ค่าสาธารณูปโภค',
      'icon': Icons.electrical_services
    },
    {
      'value': 'deposit',
      'label': 'เงินมัดจำ',
      'icon': Icons.account_balance_wallet
    },
    {'value': 'maintenance', 'label': 'ค่าซ่อมบำรุง', 'icon': Icons.build},
    {'value': 'penalty', 'label': 'ค่าปรับ', 'icon': Icons.warning},
    {'value': 'other', 'label': 'อื่นๆ', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    _selectedBranchName = widget.branchName;
    _selectedTenantId = widget.tenantId;
    _selectedRoomId = widget.roomId;

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadBranches();
    if (_selectedBranchId != null) {
      await _loadTenants();
      await _loadRooms();
    }
  }

  Future<void> _loadBranches() async {
    try {
      final currentUser = AuthService.getCurrentUser();
      late List<dynamic> response;

      if (currentUser?.isSuperAdmin ?? false) {
        response = await supabase
            .from('branches')
            .select('branch_id, branch_name')
            .eq('branch_status', 'active')
            .order('branch_name');
      } else if (currentUser?.isAdmin ?? false) {
        response = await supabase
            .from('branches')
            .select('branch_id, branch_name')
            .eq('owner_id', currentUser!.userId)
            .eq('branch_status', 'active')
            .order('branch_name');
      } else {
        if (currentUser?.branchId != null) {
          response = await supabase
              .from('branches')
              .select('branch_id, branch_name')
              .eq('branch_id', currentUser!.branchId!)
              .eq('branch_status', 'active');
        } else {
          response = [];
        }
      }

      setState(() {
        _branches = List<Map<String, dynamic>>.from(response);
        if (_selectedBranchId == null && _branches.isNotEmpty) {
          _selectedBranchId = _branches.first['branch_id'];
          _selectedBranchName = _branches.first['branch_name'];
        }
      });
    } catch (e) {
      print('Error loading branches: $e');
    }
  }

  Future<void> _loadTenants() async {
    if (_selectedBranchId == null) return;

    try {
      final response = await supabase
          .from('tenants')
          .select('''
            tenant_id, 
            tenant_full_name, 
            tenant_phone,
            room_id,
            room_number
          ''')
          .eq('branch_id', _selectedBranchId!)
          .eq('tenant_status', 'active')
          .order('tenant_full_name');

      setState(() {
        _tenants = List<Map<String, dynamic>>.from(response);

        // ถ้ามี tenantId ที่กำหนดมาแล้ว ให้เลือกอัตโนมัติ
        if (_selectedTenantId != null) {
          final tenant = _tenants.firstWhere(
            (t) => t['tenant_id'] == _selectedTenantId,
            orElse: () => <String, dynamic>{},
          );
          if (tenant.isNotEmpty) {
            _selectedTenantName = tenant['tenant_full_name'];
            _selectedRoomId = tenant['room_id'];
            _selectedRoomNumber = tenant['room_number'];
          }
        }
      });
    } catch (e) {
      print('Error loading tenants: $e');
    }
  }

  Future<void> _loadRooms() async {
    if (_selectedBranchId == null) return;

    try {
      final response = await supabase
          .from('rooms')
          .select('room_id, room_number, room_name, room_rate')
          .eq('branch_id', _selectedBranchId!)
          .order('room_number');

      setState(() {
        _rooms = List<Map<String, dynamic>>.from(response);

        // ถ้ามี roomId ที่กำหนดมาแล้ว ให้เลือกอัตโนมัติ
        if (_selectedRoomId != null) {
          final room = _rooms.firstWhere(
            (r) => r['room_id'] == _selectedRoomId,
            orElse: () => <String, dynamic>{},
          );
          if (room.isNotEmpty) {
            _selectedRoomNumber = room['room_number'];
            // ถ้าเป็นค่าเช่า ให้ใส่จำนวนเงินอัตโนมัติ
            if (_selectedBillType == 'rent' &&
                _billAmountController.text.isEmpty) {
              _billAmountController.text = (room['room_rate'] ?? 0).toString();
            }
          }
        }
      });
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId;
      _selectedBranchName = branchId != null
          ? _branches
              .firstWhere((b) => b['branch_id'] == branchId)['branch_name']
          : null;
      _selectedTenantId = null;
      _selectedTenantName = null;
      _selectedRoomId = null;
      _selectedRoomNumber = null;
      _tenants.clear();
      _rooms.clear();
    });

    if (branchId != null) {
      _loadTenants();
      _loadRooms();
    }
  }

  void _onTenantChanged(String? tenantId) {
    setState(() {
      _selectedTenantId = tenantId;
      if (tenantId != null) {
        final tenant = _tenants.firstWhere((t) => t['tenant_id'] == tenantId);
        _selectedTenantName = tenant['tenant_full_name'];
        _selectedRoomId = tenant['room_id'];
        _selectedRoomNumber = tenant['room_number'];

        // อัพเดทจำนวนเงินถ้าเป็นค่าเช่า
        if (_selectedBillType == 'rent') {
          final room = _rooms.firstWhere(
            (r) => r['room_id'] == _selectedRoomId,
            orElse: () => <String, dynamic>{},
          );
          if (room.isNotEmpty) {
            _billAmountController.text = (room['room_rate'] ?? 0).toString();
          }
        }
      } else {
        _selectedTenantName = null;
        _selectedRoomId = null;
        _selectedRoomNumber = null;
      }
    });
  }

  void _onBillTypeChanged(String? type) {
    setState(() {
      _selectedBillType = type ?? 'rent';

      // อัพเดทชื่อบิลและจำนวนเงินตามประเภท
      final typeData =
          _billTypes.firstWhere((t) => t['value'] == _selectedBillType);
      _billTitleController.text = typeData['label'];

      if (_selectedBillType == 'rent' && _selectedRoomId != null) {
        final room = _rooms.firstWhere(
          (r) => r['room_id'] == _selectedRoomId,
          orElse: () => <String, dynamic>{},
        );
        if (room.isNotEmpty) {
          _billAmountController.text = (room['room_rate'] ?? 0).toString();
        }
      } else if (_selectedBillType != 'rent') {
        _billAmountController.clear();
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isIssueDate) async {
    final initialDate = isIssueDate ? _issueDate : _dueDate;
    final firstDate = DateTime.now().subtract(Duration(days: 365));
    final lastDate = DateTime.now().add(Duration(days: 365));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: Locale('th'),
    );

    if (pickedDate != null) {
      setState(() {
        if (isIssueDate) {
          _issueDate = pickedDate;
          // ถ้าเป็นวันออกบิล ให้อัพเดทวันครบกำหนดด้วย
          if (_dueDate.isBefore(_issueDate)) {
            _dueDate = _issueDate.add(Duration(days: 7));
          }
        } else {
          _dueDate = pickedDate;
        }
      });
    }
  }

  void _addBillItem() {
    showDialog(
      context: context,
      builder: (context) => _BillItemDialog(
        onAdd: (item) {
          setState(() {
            _billItems.add(item);
            _calculateTotalAmount();
          });
        },
      ),
    );
  }

  void _editBillItem(int index) {
    showDialog(
      context: context,
      builder: (context) => _BillItemDialog(
        item: _billItems[index],
        onAdd: (item) {
          setState(() {
            _billItems[index] = item;
            _calculateTotalAmount();
          });
        },
      ),
    );
  }

  void _removeBillItem(int index) {
    setState(() {
      _billItems.removeAt(index);
      _calculateTotalAmount();
    });
  }

  void _calculateTotalAmount() {
    double total = _billItems.fold(0.0, (sum, item) => sum + item['amount']);
    _billAmountController.text = total.toString();
  }

  Future<void> _createBill() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranchId == null || _selectedTenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณาเลือกสาขาและผู้เช่า')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();

      // สร้างบิล
      final billData = {
        'branch_id': _selectedBranchId,
        'room_id': _selectedRoomId,
        'tenant_id': _selectedTenantId,
        'tenant_name': _selectedTenantName,
        'room_number': _selectedRoomNumber,
        'bill_type': _selectedBillType,
        'bill_title': _billTitleController.text.trim(),
        'bill_amount': double.parse(_billAmountController.text.trim()),
        'issue_date': _issueDate.toIso8601String(),
        'due_date': _dueDate.toIso8601String(),
        'payment_status': 'pending',
        'payment_method': _selectedPaymentMethod,
        'created_by': currentUser?.userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final billResult =
          await supabase.from('bills').insert(billData).select().single();

      final billId = billResult['bills_id'];

      // สร้าง bill_details ถ้ามี
      if (_billItems.isNotEmpty) {
        final billDetailsList = _billItems
            .map((item) => {
                  'bills_id': billId,
                  'item_type': item['type'],
                  'item_name': item['name'],
                  'item_desc': item['description'],
                  'quantity': item['quantity'],
                  'unit_price': item['unit_price'],
                  'amount': item['amount'],
                  'created_at': DateTime.now().toIso8601String(),
                })
            .toList();

        await supabase.from('bill_details').insert(billDetailsList);
      }

      // สร้างการแจ้งเตือน
      await _createNotification(billId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สร้างบิลสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createNotification(String billId) async {
    try {
      await supabase.from('notifications').insert({
        'branch_id': _selectedBranchId,
        'tenant_id': _selectedTenantId,
        'room_id': _selectedRoomId,
        'noti_type': 'payment',
        'noti_title': 'บิลใหม่: ${_billTitleController.text}',
        'noti_message':
            'คุณมีบิล${_billTitleController.text} จำนวน ฿${_billAmountController.text} กำหนดชำระ ${_formatDate(_dueDate)}',
        'noti_priority': 'normal',
        'is_read': false,
        'metadata': {
          'bill_id': billId,
          'amount': double.parse(_billAmountController.text),
          'due_date': _dueDate.toIso8601String(),
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('สร้างบิล'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _createBill,
              child: Text(
                'สร้าง',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('กำลังสร้างบิล...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Branch & Tenant Selection
                    _buildSectionTitle('เลือกสาขาและผู้เช่า', Icons.business),
                    _buildSelectionCard(),

                    SizedBox(height: 24),

                    // Bill Information
                    _buildSectionTitle('ข้อมูลบิล', Icons.receipt),
                    _buildBillInfoCard(),

                    SizedBox(height: 24),

                    // Dates
                    _buildSectionTitle('วันที่', Icons.date_range),
                    _buildDatesCard(),

                    SizedBox(height: 24),

                    // Bill Items (Optional)
                    _buildSectionTitle('รายการในบิล (ไม่บังคับ)', Icons.list),
                    _buildBillItemsCard(),

                    SizedBox(height: 24),

                    // Notes
                    _buildSectionTitle('หมายเหตุ', Icons.note),
                    _buildNotesCard(),

                    SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createBill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          'สร้างบิล',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
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

  Widget _buildSelectionCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Branch Selection
            if (_branches.length > 1)
              DropdownButtonFormField<String>(
                value: _selectedBranchId,
                decoration: InputDecoration(
                  labelText: 'เลือกสาขา',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                items: _branches.map((branch) {
                  return DropdownMenuItem<String>(
                    value: branch['branch_id'],
                    child: Text(branch['branch_name']),
                  );
                }).toList(),
                onChanged: _onBranchChanged,
                validator: (value) => value == null ? 'กรุณาเลือกสาขา' : null,
              )
            else if (_selectedBranchName != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.grey[600]),
                    SizedBox(width: 12),
                    Text(
                      'สาขา: $_selectedBranchName',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),

            if (_branches.length > 1) SizedBox(height: 16),

            // Tenant Selection
            DropdownButtonFormField<String>(
              value: _selectedTenantId,
              decoration: InputDecoration(
                labelText: 'เลือกผู้เช่า',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: _tenants.map((tenant) {
                return DropdownMenuItem<String>(
                  value: tenant['tenant_id'],
                  child: Text(
                      '${tenant['tenant_full_name']} (ห้อง ${tenant['room_number']})'),
                );
              }).toList(),
              onChanged: _tenants.isNotEmpty ? _onTenantChanged : null,
              validator: (value) => value == null ? 'กรุณาเลือกผู้เช่า' : null,
            ),

            if (_selectedTenantName != null && _selectedRoomNumber != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ผู้เช่า: $_selectedTenantName\nห้อง: $_selectedRoomNumber',
                        style: TextStyle(color: Colors.blue[800]),
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

  Widget _buildBillInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Bill Type
            DropdownButtonFormField<String>(
              value: _selectedBillType,
              decoration: InputDecoration(
                labelText: 'ประเภทบิล',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _billTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['value'],
                  child: Row(
                    children: [
                      Icon(type['icon'], size: 20),
                      SizedBox(width: 8),
                      Text(type['label']),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _onBillTypeChanged,
            ),

            SizedBox(height: 16),

            // Bill Title
            TextFormField(
              controller: _billTitleController,
              decoration: InputDecoration(
                labelText: 'หัวข้อบิล',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณาใส่หัวข้อบิล';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Bill Amount
            TextFormField(
              controller: _billAmountController,
              decoration: InputDecoration(
                labelText: 'จำนวนเงิน',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
                suffixText: 'บาท',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณาใส่จำนวนเงิน';
                }
                if (double.tryParse(value) == null ||
                    double.parse(value) <= 0) {
                  return 'กรุณาใส่จำนวนเงินที่ถูกต้อง';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Payment Method
            DropdownButtonFormField<String>(
              value: _selectedPaymentMethod,
              decoration: InputDecoration(
                labelText: 'วิธีการชำระเงิน',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              items: [
                DropdownMenuItem(value: 'cash', child: Text('เงินสด')),
                DropdownMenuItem(value: 'transfer', child: Text('โอนเงิน')),
                DropdownMenuItem(value: 'qr', child: Text('QR Code')),
                DropdownMenuItem(value: 'card', child: Text('บัตรเครดิต')),
                DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value ?? 'cash';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Issue Date
            InkWell(
              onTap: () => _selectDate(context, true),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'วันที่ออกบิล',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_formatDate(_issueDate)),
              ),
            ),

            SizedBox(height: 16),

            // Due Date
            InkWell(
              onTap: () => _selectDate(context, false),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'วันที่ครบกำหนด',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event),
                ),
                child: Text(
                  _formatDate(_dueDate),
                  style: TextStyle(
                    color: _dueDate.isBefore(DateTime.now())
                        ? Colors.red
                        : Colors.black,
                  ),
                ),
              ),
            ),

            if (_dueDate.difference(_issueDate).inDays > 0) ...[
              SizedBox(height: 8),
              Text(
                'ระยะเวลาชำระ: ${_dueDate.difference(_issueDate).inDays} วัน',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillItemsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'รายการในบิล',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: _addBillItem,
                  icon: Icon(Icons.add, size: 16),
                  label: Text('เพิ่มรายการ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_billItems.isEmpty)
              Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'ยังไม่มีรายการ (ไม่บังคับ)',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              Column(
                children: _billItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item['name']),
                      subtitle: Text(
                        '${item['quantity']} x ฿${item['unit_price']} = ฿${item['amount']}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, size: 20),
                            onPressed: () => _editBillItem(index),
                          ),
                          IconButton(
                            icon:
                                Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _removeBillItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            if (_billItems.isNotEmpty) ...[
              SizedBox(height: 8),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'รวม ${_billItems.length} รายการ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'ทั้งหมด: ฿${_billItems.fold<double>(0.0, (sum, item) => sum + item['amount']).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'หมายเหตุเพิ่มเติม (ไม่บังคับ)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.note),
            hintText: 'เช่น เงื่อนไขการชำระ, ข้อมูลเพิ่มเติม...',
          ),
          maxLines: 3,
          maxLength: 500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _billTitleController.dispose();
    _billAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// Dialog สำหรับเพิ่ม/แก้ไข Bill Item
class _BillItemDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  final Function(Map<String, dynamic>) onAdd;

  const _BillItemDialog({
    this.item,
    required this.onAdd,
  });

  @override
  State<_BillItemDialog> createState() => _BillItemDialogState();
}

class _BillItemDialogState extends State<_BillItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();

  String _selectedType = 'other';

  final List<Map<String, String>> _itemTypes = [
    {'value': 'rent', 'label': 'ค่าเช่า'},
    {'value': 'electric', 'label': 'ค่าไฟ'},
    {'value': 'water', 'label': 'ค่าน้ำ'},
    {'value': 'common_fee', 'label': 'ค่าส่วนกลาง'},
    {'value': 'internet', 'label': 'ค่าอินเทอร์เน็ต'},
    {'value': 'cleaning', 'label': 'ค่าทำความสะอาด'},
    {'value': 'parking', 'label': 'ค่าจอดรถ'},
    {'value': 'other', 'label': 'อื่นๆ'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _selectedType = widget.item!['type'] ?? 'other';
      _nameController.text = widget.item!['name'] ?? '';
      _descriptionController.text = widget.item!['description'] ?? '';
      _quantityController.text = widget.item!['quantity']?.toString() ?? '1';
      _unitPriceController.text = widget.item!['unit_price']?.toString() ?? '';
    }
  }

  double get _totalAmount {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;
    return quantity * unitPrice;
  }

  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;

    final item = {
      'type': _selectedType,
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'quantity': double.parse(_quantityController.text.trim()),
      'unit_price': double.parse(_unitPriceController.text.trim()),
      'amount': _totalAmount,
    };

    widget.onAdd(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'เพิ่มรายการ' : 'แก้ไขรายการ'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'ประเภทรายการ',
                  border: OutlineInputBorder(),
                ),
                items: _itemTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),

              SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อรายการ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณาใส่ชื่อรายการ';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'รายละเอียด (ไม่บังคับ)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              SizedBox(height: 16),

              // Quantity and Unit Price
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'จำนวน',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณาใส่จำนวน';
                        }
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) {
                          return 'จำนวนต้องมากกว่า 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      decoration: InputDecoration(
                        labelText: 'ราคาต่อหน่วย',
                        border: OutlineInputBorder(),
                        suffixText: 'บาท',
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณาใส่ราคา';
                        }
                        if (double.tryParse(value) == null ||
                            double.parse(value) < 0) {
                          return 'ราคาต้องเป็นตัวเลข';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Total Amount
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('รวม'),
                    Text(
                      '฿${_totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
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
          child: Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _saveItem,
          child: Text('บันทึก'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }
}
