import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/tenant_service.dart';

class AddTenantScreen extends StatefulWidget {
  final String? preSelectedBranchId;
  final String? preSelectedRoomId;

  const AddTenantScreen({
    Key? key,
    this.preSelectedBranchId,
    this.preSelectedRoomId,
  }) : super(key: key);

  @override
  State<AddTenantScreen> createState() => _AddTenantScreenState();
}

final supabase = Supabase.instance.client;

class _AddTenantScreenState extends State<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantNameController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _tenantCardController = TextEditingController();
  final _tenantCodeController = TextEditingController();

  DateTime _selectedCheckInDate = DateTime.now();
  DateTime _selectedCheckOutDate = DateTime.now().add(Duration(days: 365));

  String? _selectedBranchId;
  String? _selectedRoomId;
  String _selectedTenantStatus = 'active';
  String _codeGenerationType = 'auto';

  bool _isLoading = false;
  bool _isLoadingBranches = false;
  bool _isLoadingRooms = false;
  bool _autoGenerateCode = true;
  bool _createTenantAccount = false;

  List<Map<String, dynamic>> _availableBranches = [];
  List<Map<String, dynamic>> _availableRooms = [];
  Map<String, dynamic>? _selectedRoomDetails;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.preSelectedBranchId;
    _selectedRoomId = widget.preSelectedRoomId;
    _loadAvailableBranches();
  }

  Future<void> _loadAvailableBranches() async {
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();
      late List<dynamic> response;

      if (currentUser?.isSuperAdmin ?? false) {
        // Super Admin เห็นทุกสาขา
        response = await supabase
            .from('branches')
            .select('branch_id, branch_name, branch_status')
            .eq('branch_status', 'active')
            .order('branch_name');
      } else if (currentUser?.isAdmin ?? false) {
        // Admin เห็นเฉพาะสาขาตัวเอง
        response = await supabase
            .from('branches')
            .select('branch_id, branch_name, branch_status')
            .eq('owner_id', currentUser!.userId)
            .eq('branch_status', 'active')
            .order('branch_name');
      } else {
        // User เห็นเฉพาะสาขาที่ตนเองสังกัด
        if (currentUser?.branchId != null) {
          response = await supabase
              .from('branches')
              .select('branch_id, branch_name, branch_status')
              .eq('branch_id', currentUser!.branchId!)
              .eq('branch_status', 'active');
        } else {
          response = [];
        }
      }

      setState(() {
        _availableBranches = List<Map<String, dynamic>>.from(response);
      });

      // ถ้ามีการเลือกสาขาไว้แล้ว ให้โหลดห้องของสาขานั้น
      if (_selectedBranchId != null) {
        await _loadAvailableRooms(_selectedBranchId!);
      }
    } catch (e) {
      print('Error loading branches: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingBranches = false;
      });
    }
  }

  Future<void> _loadAvailableRooms(String branchId) async {
    setState(() {
      _isLoadingRooms = true;
      _availableRooms = [];
      _selectedRoomId = null;
      _selectedRoomDetails = null;
    });

    try {
      final response = await supabase
          .from('rooms')
          .select('*')
          .eq('branch_id', branchId)
          .inFilter(
              'room_status', ['available', 'maintenance']).order('room_number');

      setState(() {
        _availableRooms = List<Map<String, dynamic>>.from(response);
      });

      // ถ้ามีการเลือกห้องไว้แล้ว ให้โหลดรายละเอียดห้องนั้น
      if (widget.preSelectedRoomId != null) {
        await _loadRoomDetails(widget.preSelectedRoomId!);
      }
    } catch (e) {
      print('Error loading rooms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลห้อง: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingRooms = false;
      });
    }
  }

  Future<void> _loadRoomDetails(String roomId) async {
    try {
      final response = await supabase
          .from('rooms')
          .select('*')
          .eq('room_id', roomId)
          .single();

      setState(() {
        _selectedRoomDetails = response;
        _selectedRoomId = roomId;
      });
    } catch (e) {
      print('Error loading room details: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn ? _selectedCheckInDate : _selectedCheckOutDate,
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now().add(Duration(days: 1095)), // 3 years
      locale: const Locale('th', 'TH'),
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _selectedCheckInDate = picked;
          // ถ้าวันเข้าพักใหม่มากกว่าวันออก ให้ปรับวันออกเป็น 1 ปีหลังจากวันเข้าพัก
          if (_selectedCheckInDate.isAfter(_selectedCheckOutDate)) {
            _selectedCheckOutDate =
                _selectedCheckInDate.add(Duration(days: 365));
          }
        } else {
          _selectedCheckOutDate = picked;
        }
      });
    }
  }

  // เพิ่มเมธอดสำหรับสร้างรหัสผู้เช่าอัตโนมัติ
  Future<void> _generateTenantCode() async {
    if (_selectedBranchId == null || _selectedRoomId == null) return;

    try {
      String generatedCode;

      switch (_codeGenerationType) {
        case 'sequential':
          generatedCode = await TenantCodeService.generateSequentialCode(
            branchId: _selectedBranchId!,
            prefix: 'T',
          );
          break;
        case 'custom':
          // ให้ผู้ใช้กรอกเอง
          return;
        default: // auto
          generatedCode = await TenantCodeService.generateUniqueCode(
            branchId: _selectedBranchId!,
            roomNumber: _selectedRoomDetails?['room_number'] ?? '',
            customPrefix: 'T',
          );
      }

      setState(() {
        _tenantCodeController.text = generatedCode;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการสร้างรหัสผู้เช่า: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBranchId == null || _selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกสาขาและห้องพัก'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ตรวจสอบรหัสผู้เช่าว่าซ้ำหรือไม่
    if (_tenantCodeController.text.isNotEmpty) {
      final codeExists =
          await TenantCodeService.isCodeExists(_tenantCodeController.text);
      if (codeExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รหัสผู้เช่านี้มีอยู่แล้วในระบบ'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_selectedCheckOutDate.isBefore(_selectedCheckInDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('วันที่ออกต้องมากกว่าวันที่เข้าพัก'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();

      // ตรวจสอบว่าเลขบัตรประชาชนซ้ำหรือไม่
      final existingTenant = await supabase
          .from('tenants')
          .select('tenant_id')
          .eq('tenant_card', _tenantCardController.text.trim())
          .maybeSingle();

      if (existingTenant != null) {
        throw Exception('เลขบัตรประชาชนนี้มีอยู่ในระบบแล้ว');
      }

      // ตรวจสอบว่าห้องยังว่างอยู่หรือไม่
      final roomCheck = await supabase
          .from('tenants')
          .select('tenant_id')
          .eq('room_id', _selectedRoomId!)
          .eq('tenant_status', 'active')
          .maybeSingle();

      if (roomCheck != null) {
        throw Exception('ห้องนี้มีผู้เช่าอยู่แล้ว');
      }

      // สร้างรหัสผู้เช่าหากยังไม่มี
      String tenantCode = _tenantCodeController.text.trim();
      if (tenantCode.isEmpty && _autoGenerateCode) {
        tenantCode = await TenantCodeService.generateUniqueCode(
          branchId: _selectedBranchId!,
          roomNumber: _selectedRoomDetails?['room_number'] ?? '',
        );
      }

      // เพิ่มข้อมูลผู้เช่าใหม่
      final tenantData = {
        'branch_id': _selectedBranchId,
        'room_id': _selectedRoomId,
        'room_number': _selectedRoomDetails?['room_number'] ?? '',
        'tenant_full_name': _tenantNameController.text.trim(),
        'tenant_phone': _tenantPhoneController.text.trim(),
        'tenant_card': _tenantCardController.text.trim(),
        'tenant_code': tenantCode.isNotEmpty ? tenantCode : null,
        'tenant_in': _selectedCheckInDate.toIso8601String(),
        'tenant_out': _selectedCheckOutDate.toIso8601String(),
        'tenant_status': _selectedTenantStatus,
        'has_account': _createTenantAccount,
        'created_by': currentUser?.userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final tenantResponse = await supabase
          .from('tenants')
          .insert(tenantData)
          .select('tenant_id')
          .single();

      final tenantId = tenantResponse['tenant_id'];

      // สร้างบัญชีผู้ใช้สำหรับผู้เช่า (หากต้องการ)
      if (_createTenantAccount && tenantCode.isNotEmpty) {
        try {
          await TenantCodeService.createTenantAccount(
            tenantId: tenantId,
            tenantCode: tenantCode,
            tenantName: _tenantNameController.text.trim(),
            tenantPhone: _tenantPhoneController.text.trim(),
          );
        } catch (e) {
          print('Warning: Could not create tenant account: $e');
          // ไม่ให้ error นี้หยุดการสร้างผู้เช่า
        }
      }

      // อัพเดทสถานะห้องเป็น occupied (ถ้าผู้เช่าเป็น active)
      if (_selectedTenantStatus == 'active') {
        await supabase.from('rooms').update({
          'room_status': 'occupied',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('room_id', _selectedRoomId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('เพิ่มผู้เช่าสำเร็จ'),
                if (tenantCode.isNotEmpty) Text('รหัสผู้เช่า: $tenantCode'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
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
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // เพิ่มเมธอดสำหรับสร้างส่วน Tenant Code
  Widget _buildTenantCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('รหัสผู้เช่า'),
        const SizedBox(height: 8),

        // ตัวเลือกประเภทการสร้างรหัส
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('การสร้างรหัสผู้เช่า',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                SizedBox(height: 12),

                // Auto generate checkbox
                CheckboxListTile(
                  value: _autoGenerateCode,
                  onChanged: (value) {
                    setState(() {
                      _autoGenerateCode = value ?? false;
                      if (_autoGenerateCode &&
                          _selectedBranchId != null &&
                          _selectedRoomId != null) {
                        _generateTenantCode();
                      }
                    });
                  },
                  title: Text('สร้างรหัสอัตโนมัติ'),
                  subtitle: Text('ระบบจะสร้างรหัสให้อัตโนมัติ'),
                  dense: true,
                ),

                if (_autoGenerateCode) ...[
                  // ตัวเลือกประเภทการสร้าง
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'auto',
                          groupValue: _codeGenerationType,
                          onChanged: (value) {
                            setState(() {
                              _codeGenerationType = value!;
                            });
                            _generateTenantCode();
                          },
                          title:
                              Text('รหัสแบบสุ่ม (T + สาขา + ห้อง + เลขสุ่ม)'),
                          dense: true,
                        ),
                        RadioListTile<String>(
                          value: 'sequential',
                          groupValue: _codeGenerationType,
                          onChanged: (value) {
                            setState(() {
                              _codeGenerationType = value!;
                            });
                            _generateTenantCode();
                          },
                          title:
                              Text('รหัสแบบเรียงลำดับ (T + สาขา + เลขลำดับ)'),
                          dense: true,
                        ),
                        RadioListTile<String>(
                          value: 'custom',
                          groupValue: _codeGenerationType,
                          onChanged: (value) {
                            setState(() {
                              _codeGenerationType = value!;
                              _tenantCodeController.clear();
                            });
                          },
                          title: Text('กำหนดรหัสเอง'),
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ช่องกรอกรหัสผู้เช่า
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                controller: _tenantCodeController,
                label: 'รหัสผู้เช่า',
                icon: Icons.qr_code,
                validator: (value) {
                  if (!_autoGenerateCode && (value?.trim().isEmpty ?? true)) {
                    return 'กรุณากรอกรหัสผู้เช่า';
                  }
                  if (value != null && value.trim().length < 3) {
                    return 'รหัสผู้เช่าต้องมีอย่างน้อย 3 ตัวอักษร';
                  }
                  return null;
                },
                enabled: _autoGenerateCode && _codeGenerationType != 'custom',
              ),
            ),
            if (_autoGenerateCode && _codeGenerationType != 'custom') ...[
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _generateTenantCode,
                icon: Icon(Icons.refresh, size: 16),
                label: Text('สร้างใหม่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // สร้างบัญชีผู้ใช้
        CheckboxListTile(
          value: _createTenantAccount,
          onChanged: (value) {
            setState(() {
              _createTenantAccount = value ?? false;
            });
          },
          title: Text('สร้างบัญชีผู้ใช้สำหรับผู้เช่า'),
          subtitle: Text('ผู้เช่าจะสามารถเข้าสู่ระบบด้วยรหัสผู้เช่าได้'),
          secondary: Icon(Icons.account_circle, color: AppColors.primary),
        ),

        if (_createTenantAccount)
          Container(
            margin: EdgeInsets.only(left: 16, top: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ระบบจะสร้าง username และ password เป็นรหัสผู้เช่า',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มผู้เช่าใหม่'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ข้อมูลส่วนตัว
              _buildSectionTitle('ข้อมูลส่วนตัว'),
              const SizedBox(height: 8),

              _buildTextFormField(
                controller: _tenantNameController,
                label: 'ชื่อ-นามสกุล',
                icon: Icons.person,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'กรุณากรอกชื่อ-นามสกุล';
                  }
                  if (value!.trim().length < 2) {
                    return 'ชื่อ-นามสกุลต้องมีอย่างน้อย 2 ตัวอักษร';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _tenantPhoneController,
                label: 'เบอร์โทรศัพท์',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'กรุณากรอกเบอร์โทรศัพท์';
                  }
                  if (value!.trim().length < 9 || value.trim().length > 10) {
                    return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _tenantCardController,
                label: 'เลขบัตรประชาชน/Passport',
                icon: Icons.credit_card,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'กรุณากรอกเลขบัตรประชาชนหรือ Passport';
                  }
                  if (value!.trim().length < 8) {
                    return 'เลขบัตรประชาชนหรือ Passport ไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ข้อมูลการเช่า
              _buildSectionTitle('ข้อมูลการเช่า'),
              const SizedBox(height: 8),

              // เลือกสาขา
              _buildBranchDropdown(),
              const SizedBox(height: 16),

              // เลือกห้อง
              _buildRoomDropdown(),
              const SizedBox(height: 16),

              // รายละเอียดห้อง
              if (_selectedRoomDetails != null) ...[
                _buildRoomDetailsCard(),
                const SizedBox(height: 16),
              ],

              // วันที่เข้าพัก
              _buildDateSelector(
                label: 'วันที่เข้าพัก',
                selectedDate: _selectedCheckInDate,
                onTap: () => _selectDate(context, true),
                icon: Icons.login,
              ),
              const SizedBox(height: 16),

              // วันที่ออก
              _buildDateSelector(
                label: 'วันที่ออก/สิ้นสุดสัญญา',
                selectedDate: _selectedCheckOutDate,
                onTap: () => _selectDate(context, false),
                icon: Icons.logout,
              ),
              const SizedBox(height: 16),

              // สถานะผู้เช่า
              _buildStatusDropdown(),
              const SizedBox(height: 32),

              // ปุ่มบันทึก
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTenant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('กำลังบันทึก...'),
                          ],
                        )
                      : const Text(
                          'บันทึกข้อมูลผู้เช่า',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            Icon(icon, color: enabled ? AppColors.primary : Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[50],
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สาขา',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingBranches)
          Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: CircularProgressIndicator()),
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedBranchId,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.business, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            hint: const Text('เลือกสาขา'),
            items: _availableBranches.map((branch) {
              return DropdownMenuItem<String>(
                value: branch['branch_id'],
                child: Text(branch['branch_name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBranchId = value;
                _selectedRoomId = null;
                _selectedRoomDetails = null;
              });
              if (value != null) {
                _loadAvailableRooms(value);
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'กรุณาเลือกสาขา';
              }
              return null;
            },
          ),
      ],
    );
  }

  Widget _buildRoomDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ห้องพัก',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingRooms)
          Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: CircularProgressIndicator()),
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedRoomId,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.hotel, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            hint: const Text('เลือกห้องพัก'),
            items: _availableRooms.map((room) {
              final status =
                  room['room_status'] == 'maintenance' ? ' (ปิดซ่อมบำรุง)' : '';
              return DropdownMenuItem<String>(
                value: room['room_id'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        '${room['room_number']} - ${room['room_name']}$status'),
                    Text(
                      '${room['room_cate']} | ${room['room_rate']} บาท/เดือน',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _loadRoomDetails(value);
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'กรุณาเลือกห้องพัก';
              }
              return null;
            },
          ),
      ],
    );
  }

  Widget _buildRoomDetailsCard() {
    final room = _selectedRoomDetails!;
    final facilities = List<String>.from(room['room_fac'] ?? []);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'รายละเอียดห้อง ${room['room_number']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ค่าเช่า: ${room['room_rate']} บาท/เดือน'),
                      Text('เงินมัดจำ: ${room['room_deposit']} บาท'),
                      Text('ขนาด: ${room['room_size']} ตร.ม.'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'ประเภท: ${_getRoomCategoryText(room['room_cate'])}'),
                      Text('ชนิด: ${_getRoomTypeText(room['room_type'])}'),
                      Text('ผู้พักสูงสุด: ${room['room_max']} คน'),
                    ],
                  ),
                ),
              ],
            ),
            if (facilities.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'สิ่งอำนวยความสะดวก:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: facilities
                    .map((facility) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            facility,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime selectedDate,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สถานะผู้เช่า',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTenantStatus,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.flag, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'active',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('เข้าพักแล้ว'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'suspended',
              child: Row(
                children: [
                  Icon(Icons.pause_circle, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('ระงับชั่วคราว'),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedTenantStatus = value!;
            });
          },
        ),
      ],
    );
  }

  String _getRoomCategoryText(String category) {
    switch (category) {
      case 'economy':
        return 'ประหยัด';
      case 'standard':
        return 'มาตรฐาน';
      case 'deluxe':
        return 'ดีลักซ์';
      case 'premium':
        return 'พรีเมี่ยม';
      case 'vip':
        return 'วีไอพี';
      default:
        return category;
    }
  }

  String _getRoomTypeText(String type) {
    switch (type) {
      case 'single':
        return 'เดี่ยว';
      case 'twin':
        return 'แฝด';
      case 'double':
        return 'คู่';
      case 'family':
        return 'ครอบครัว';
      case 'studio':
        return 'สตูดิโอ';
      case 'suite':
        return 'สวีท';
      default:
        return type;
    }
  }

  @override
  void dispose() {
    _tenantNameController.dispose();
    _tenantPhoneController.dispose();
    _tenantCardController.dispose();
    super.dispose();
  }
}
