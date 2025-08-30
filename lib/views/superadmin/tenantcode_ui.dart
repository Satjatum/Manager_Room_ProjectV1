import 'package:flutter/material.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/tenant_service.dart';

class TenantCodeManagerScreen extends StatefulWidget {
  const TenantCodeManagerScreen({Key? key}) : super(key: key);

  @override
  State<TenantCodeManagerScreen> createState() =>
      _TenantCodeManagerScreenState();
}

class _TenantCodeManagerScreenState extends State<TenantCodeManagerScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = false;
  bool _isGeneratingCodes = false;
  String? _selectedBranchId;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
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
        if (_branches.isNotEmpty) {
          _selectedBranchId = _branches.first['branch_id'];
        }
      });

      if (_selectedBranchId != null) {
        _loadTenants();
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
    }
  }

  Future<void> _loadTenants() async {
    if (_selectedBranchId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('tenants')
          .select('''
            tenant_id, tenant_full_name, tenant_phone, tenant_card, 
            tenant_code, has_account, tenant_status, room_number,
            rooms!inner(room_name)
          ''')
          .eq('branch_id', _selectedBranchId!)
          .eq('tenant_status', 'active')
          .order('room_number');

      setState(() {
        _tenants = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้เช่า: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateAllMissingCodes() async {
    final tenantsWithoutCode = _tenants
        .where((tenant) =>
            tenant['tenant_code'] == null ||
            tenant['tenant_code'].toString().isEmpty)
        .toList();

    if (tenantsWithoutCode.isEmpty) {
      _showSuccessSnackBar('ผู้เช่าทุกคนมีรหัสแล้ว');
      return;
    }

    setState(() {
      _isGeneratingCodes = true;
    });

    try {
      for (final tenant in tenantsWithoutCode) {
        final code = await TenantCodeService.generateSequentialCode(
          branchId: _selectedBranchId!,
          prefix: 'T',
        );

        await TenantCodeService.updateTenantCode(tenant['tenant_id'], code);
      }

      _showSuccessSnackBar(
          'สร้างรหัสผู้เช่าสำเร็จ ${tenantsWithoutCode.length} คน');
      _loadTenants(); // โหลดข้อมูลใหม่
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการสร้างรหัส: $e');
    } finally {
      setState(() {
        _isGeneratingCodes = false;
      });
    }
  }

  Future<void> _generateSingleCode(String tenantId, String roomNumber) async {
    try {
      final code = await TenantCodeService.generateUniqueCode(
        branchId: _selectedBranchId!,
        roomNumber: roomNumber,
        customPrefix: 'T',
      );

      await TenantCodeService.updateTenantCode(tenantId, code);
      _showSuccessSnackBar('สร้างรหัสสำเร็จ: $code');
      _loadTenants();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการสร้างรหัส: $e');
    }
  }

  Future<void> _createTenantAccount(Map<String, dynamic> tenant) async {
    final tenantCode = tenant['tenant_code'];
    if (tenantCode == null || tenantCode.toString().isEmpty) {
      _showErrorSnackBar('กรุณาสร้างรหัสผู้เช่าก่อน');
      return;
    }

    try {
      await TenantCodeService.createTenantAccount(
        tenantId: tenant['tenant_id'],
        tenantCode: tenantCode,
        tenantName: tenant['tenant_full_name'],
        tenantPhone: tenant['tenant_phone'],
      );

      _showSuccessSnackBar('สร้างบัญชีผู้ใช้สำเร็จ');
      _loadTenants();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการสร้างบัญชี: $e');
    }
  }

  Future<void> _showEditCodeDialog(Map<String, dynamic> tenant) async {
    final controller = TextEditingController(text: tenant['tenant_code'] ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('แก้ไขรหัสผู้เช่า'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ผู้เช่า: ${tenant['tenant_full_name']}'),
            Text('ห้อง: ${tenant['room_number']}'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'รหัสผู้เช่า',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result != null &&
        result.isNotEmpty &&
        result != tenant['tenant_code']) {
      try {
        // ตรวจสอบว่ารหัสซ้ำหรือไม่
        final exists = await TenantCodeService.isCodeExists(result);
        if (exists) {
          _showErrorSnackBar('รหัสผู้เช่านี้มีอยู่แล้ว');
          return;
        }

        await TenantCodeService.updateTenantCode(tenant['tenant_id'], result);
        _showSuccessSnackBar('แก้ไขรหัสสำเร็จ');
        _loadTenants();
      } catch (e) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการแก้ไขรหัส: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการรหัสผู้เช่า'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isGeneratingCodes)
            Center(
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
            )
          else
            PopupMenuButton(
              icon: Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'generate_all',
                  child: Row(
                    children: [
                      Icon(Icons.auto_fix_high, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('สร้างรหัสที่ขาดหายไป'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'generate_all') {
                  _generateAllMissingCodes();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // เลือกสาขา
          if (_branches.length > 1)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Icon(Icons.business, color: AppColors.primary),
                  SizedBox(width: 12),
                  Text('สาขา: ', style: TextStyle(fontWeight: FontWeight.w500)),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBranchId,
                        items: _branches.map((branch) {
                          return DropdownMenuItem<String>(
                            value: branch['branch_id'],
                            child: Text(branch['branch_name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBranchId = value;
                          });
                          if (value != null) {
                            _loadTenants();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // สถิติ
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatCard(
                  'ทั้งหมด',
                  _tenants.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
                SizedBox(width: 12),
                _buildStatCard(
                  'มีรหัส',
                  _tenants
                      .where((t) =>
                          t['tenant_code'] != null &&
                          t['tenant_code'].toString().isNotEmpty)
                      .length
                      .toString(),
                  Icons.qr_code,
                  Colors.green,
                ),
                SizedBox(width: 12),
                _buildStatCard(
                  'มีบัญชี',
                  _tenants
                      .where((t) => t['has_account'] == true)
                      .length
                      .toString(),
                  Icons.account_circle,
                  Colors.orange,
                ),
              ],
            ),
          ),

          // รายการผู้เช่า
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _tenants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('ไม่มีผู้เช่าในสาขานี้',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _tenants.length,
                        itemBuilder: (context, index) {
                          final tenant = _tenants[index];
                          return _buildTenantCard(tenant);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant) {
    final hasCode = tenant['tenant_code'] != null &&
        tenant['tenant_code'].toString().isNotEmpty;
    final hasAccount = tenant['has_account'] == true;
    final roomName =
        tenant['rooms'] != null ? tenant['rooms']['room_name'] : '';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ข้อมูลพื้นฐาน
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant['tenant_full_name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ห้อง ${tenant['room_number']} - $roomName',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        'โทร: ${tenant['tenant_phone']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // สถานะรหัส
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasCode
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasCode ? 'มีรหัส' : 'ไม่มีรหัส',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasCode ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    // สถานะบัญชี
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasAccount
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasAccount ? 'มีบัญชี' : 'ไม่มีบัญชี',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              hasAccount ? Colors.blue[700] : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // รหัสผู้เช่า
            if (hasCode) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'รหัส: ${tenant['tenant_code']}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Spacer(),
                    InkWell(
                      onTap: () => _showEditCodeDialog(tenant),
                      child:
                          Icon(Icons.edit, color: Colors.grey[600], size: 16),
                    ),
                  ],
                ),
              ),
            ],

            // ปุ่มดำเนินการ
            SizedBox(height: 12),
            Row(
              children: [
                if (!hasCode) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _generateSingleCode(
                        tenant['tenant_id'],
                        tenant['room_number'],
                      ),
                      icon: Icon(Icons.add, size: 16),
                      label: Text('สร้างรหัส'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditCodeDialog(tenant),
                      icon: Icon(Icons.edit, size: 16),
                      label: Text('แก้ไขรหัส'),
                    ),
                  ),
                  SizedBox(width: 8),
                  if (!hasAccount)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _createTenantAccount(tenant),
                        icon: Icon(Icons.account_circle, size: 16),
                        label: Text('สร้างบัญชี'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'มีบัญชีแล้ว',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
