import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:intl/intl.dart';

class EditTenantUi extends StatefulWidget {
  final String tenantId;
  final VoidCallback? onTenantUpdated;

  const EditTenantUi({
    Key? key,
    required this.tenantId,
    this.onTenantUpdated,
  }) : super(key: key);

  @override
  State<EditTenantUi> createState() => _EditTenantUiState();
}

class _EditTenantUiState extends State<EditTenantUi>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cardController = TextEditingController();
  final _tenantCodeController = TextEditingController();

  // Data
  Map<String, dynamic>? _tenantDetail;

  // Form Values
  String? _selectedStatus = 'active';
  String? _selectedContactStatus = 'pending';
  DateTime? _tenantIn;
  DateTime? _tenantOut;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasAccount = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTenantData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _cardController.dispose();
    _tenantCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadTenantData() async {
    setState(() => _isLoading = true);

    try {
      // Load tenant data
      final tenantResponse = await supabase.from('tenants').select('''
            *, 
            rooms!inner(room_number, room_name),
            branches!inner(branch_name)
          ''').eq('tenant_id', widget.tenantId).single();

      setState(() {
        _tenantDetail = tenantResponse;

        // Populate form fields
        _fullNameController.text = tenantResponse['tenant_full_name'] ?? '';
        _phoneController.text = tenantResponse['tenant_phone'] ?? '';
        _cardController.text = tenantResponse['tenant_card'] ?? '';
        _tenantCodeController.text = tenantResponse['tenant_code'] ?? '';

        _selectedStatus = tenantResponse['tenant_status'];
        _selectedContactStatus = tenantResponse['contact_status'];
        _hasAccount = tenantResponse['has_account'] == true;

        _tenantIn = DateTime.parse(tenantResponse['tenant_in']);
        _tenantOut = DateTime.parse(tenantResponse['tenant_out']);
      });
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTenantData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tenantIn == null || _tenantOut == null) {
      _showErrorSnackBar('กรุณาเลือกวันที่ให้ครบถ้วน');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Check if card number is unique (excluding current tenant)
      final existingCard = await supabase
          .from('tenants')
          .select('tenant_id')
          .eq('tenant_card', _cardController.text.trim())
          .neq('tenant_id', widget.tenantId)
          .maybeSingle();

      if (existingCard != null) {
        _showErrorSnackBar('เลขบัตรประชาชนนี้มีอยู่ในระบบแล้ว');
        return;
      }

      // Check if tenant code is unique (excluding current tenant)
      if (_tenantCodeController.text.trim().isNotEmpty) {
        final existingCode = await supabase
            .from('tenants')
            .select('tenant_id')
            .eq('tenant_code', _tenantCodeController.text.trim())
            .neq('tenant_id', widget.tenantId)
            .maybeSingle();

        if (existingCode != null) {
          _showErrorSnackBar('รหัสผู้เช่านี้มีอยู่ในระบบแล้ว');
          return;
        }
      }

      // Update tenant data
      await supabase.from('tenants').update({
        'tenant_full_name': _fullNameController.text.trim(),
        'tenant_phone': _phoneController.text.trim(),
        'tenant_card': _cardController.text.trim(),
        'tenant_code': _tenantCodeController.text.trim().isEmpty
            ? null
            : _tenantCodeController.text.trim(),
        'tenant_status': _selectedStatus,
        'contact_status': _selectedContactStatus,
        'tenant_in': _tenantIn!.toIso8601String(),
        'tenant_out': _tenantOut!.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', widget.tenantId);

      _showSuccessSnackBar('บันทึกข้อมูลสำเร็จ');
      widget.onTenantUpdated?.call();
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('แก้ไขข้อมูลผู้เช่า'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_tenantDetail == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('แก้ไขข้อมูลผู้เช่า'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text('ไม่พบข้อมูลผู้เช่า', style: TextStyle(fontSize: 18)),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('กลับ'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('แก้ไขข้อมูลผู้เช่า'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            Container(
              margin: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveTenantData,
              child: Text(
                'บันทึก',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.person), text: 'ข้อมูลผู้เช่า'),
            Tab(icon: Icon(Icons.description), text: 'ข้อมูลสัญญา'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPersonalInfoTab(),
            _buildContractInfoTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Room Info (Read-only)
          _buildSectionCard(
            'ห้องพักปัจจุบัน',
            Icons.home,
            [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.home, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ห้อง ${_tenantDetail!['room_number']} - ${_tenantDetail!['rooms']['room_name']}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'สาขา: ${_tenantDetail!['branches']['branch_name']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          _buildSectionCard(
            'ข้อมูลส่วนตัว',
            Icons.person,
            [
              _buildTextFormField(
                controller: _fullNameController,
                label: 'ชื่อ-นามสกุล',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อ-นามสกุล';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: _phoneController,
                label: 'เบอร์โทรศัพท์',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกเบอร์โทรศัพท์';
                  }
                  if (value.trim().length != 10) {
                    return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: _cardController,
                label: 'เลขบัตรประชาชน',
                icon: Icons.credit_card,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกเลขบัตรประชาชน';
                  }
                  if (value.trim().length != 13) {
                    return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: _tenantCodeController,
                label: 'รหัสผู้เช่า (ไม่บังคับ)',
                icon: Icons.qr_code,
                hint: 'รหัสสำหรับระบบ QR Code',
              ),
            ],
          ),

          SizedBox(height: 20),

          _buildSectionCard(
            'สถานะ',
            Icons.settings,
            [
              _buildDropdownField(
                label: 'สถานะผู้เช่า',
                value: _selectedStatus,
                icon: Icons.person_pin_circle,
                items: [
                  {
                    'value': 'active',
                    'label': 'เข้าพักแล้ว',
                    'color': Colors.green
                  },
                  {
                    'value': 'suspended',
                    'label': 'ระงับชั่วคราว',
                    'color': Colors.orange
                  },
                  {
                    'value': 'checkout',
                    'label': 'ออกจากห้อง',
                    'color': Colors.red
                  },
                  {
                    'value': 'terminated',
                    'label': 'ยกเลิกสัญญา',
                    'color': Colors.grey
                  },
                ],
                onChanged: (value) => setState(() => _selectedStatus = value),
              ),
              SizedBox(height: 16),
              _buildDropdownField(
                label: 'สถานะการติดต่อ',
                value: _selectedContactStatus,
                icon: Icons.phone,
                items: [
                  {
                    'value': 'reachable',
                    'label': 'ติดต่อได้',
                    'color': Colors.green
                  },
                  {
                    'value': 'unreachable',
                    'label': 'ติดต่อไม่ได้',
                    'color': Colors.red
                  },
                  {
                    'value': 'pending',
                    'label': 'รอติดต่อ',
                    'color': Colors.orange
                  },
                ],
                onChanged: (value) =>
                    setState(() => _selectedContactStatus = value),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _hasAccount ? Colors.green[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasAccount ? Colors.green[300]! : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasAccount ? Icons.check_circle : Icons.cancel,
                      color: _hasAccount ? Colors.green : Colors.grey,
                    ),
                    SizedBox(width: 12),
                    Text(
                      _hasAccount ? 'มีบัญชีผู้ใช้' : 'ไม่มีบัญชีผู้ใช้',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            _hasAccount ? Colors.green[700] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContractInfoTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'ข้อมูลสัญญา',
            Icons.description,
            [
              _buildDateField(
                label: 'วันที่เข้าพัก',
                value: _tenantIn,
                icon: Icons.login,
                onTap: () => _selectDate(context, true),
              ),
              SizedBox(height: 16),
              _buildDateField(
                label: 'วันที่สิ้นสุดสัญญา',
                value: _tenantOut,
                icon: Icons.logout,
                onTap: () => _selectDate(context, false),
              ),
              if (_tenantIn != null && _tenantOut != null) ...[
                SizedBox(height: 16),
                _buildContractSummary(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items.map<DropdownMenuItem<String>>((item) {
        return DropdownMenuItem<String>(
          value: item['value'],
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item['color'],
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(item['label']),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value != null
                      ? DateFormat('dd/MM/yyyy').format(value)
                      : 'เลือกวันที่',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: value != null ? Colors.black87 : Colors.grey[500],
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(Icons.calendar_today, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContractSummary() {
    if (_tenantIn == null || _tenantOut == null) return SizedBox.shrink();

    final duration = _tenantOut!.difference(_tenantIn!).inDays;
    final daysLeft = _tenantOut!.difference(DateTime.now()).inDays;
    final isExpired = daysLeft < 0;
    final isExpiringSoon = daysLeft <= 30 && daysLeft >= 0;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red[50]
            : isExpiringSoon
                ? Colors.orange[50]
                : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExpired
              ? Colors.red[300]!
              : isExpiringSoon
                  ? Colors.orange[300]!
                  : Colors.blue[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExpired
                    ? Icons.error
                    : isExpiringSoon
                        ? Icons.warning
                        : Icons.info,
                color: isExpired
                    ? Colors.red[600]
                    : isExpiringSoon
                        ? Colors.orange[600]
                        : Colors.blue[600],
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'สรุปสัญญา',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isExpired
                      ? Colors.red[700]
                      : isExpiringSoon
                          ? Colors.orange[700]
                          : Colors.blue[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'ระยะเวลาสัญญา: $duration วัน',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 4),
          Text(
            isExpired
                ? 'หมดอายุแล้ว ${(-daysLeft)} วัน'
                : isExpiringSoon
                    ? 'เหลืออีก $daysLeft วัน'
                    : 'เหลืออีก $daysLeft วัน',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isExpired
                  ? Colors.red[700]
                  : isExpiringSoon
                      ? Colors.orange[700]
                      : Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_tenantIn ?? DateTime.now())
          : (_tenantOut ?? DateTime.now().add(Duration(days: 365))),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _tenantIn = picked;
          // Auto adjust end date if it's before start date
          if (_tenantOut != null && _tenantOut!.isBefore(_tenantIn!)) {
            _tenantOut = _tenantIn!.add(Duration(days: 365));
          }
        } else {
          _tenantOut = picked;
          // Auto adjust start date if it's after end date
          if (_tenantIn != null && _tenantIn!.isAfter(_tenantOut!)) {
            _tenantIn = _tenantOut!.subtract(Duration(days: 365));
          }
        }
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.error_rounded, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 4),
      ),
    );
  }
}
