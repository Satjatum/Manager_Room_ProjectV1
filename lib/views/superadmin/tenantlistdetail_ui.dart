import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class TenantListDetailUi extends StatefulWidget {
  final String tenantId;
  final VoidCallback? onTenantUpdated;

  const TenantListDetailUi({
    Key? key,
    required this.tenantId,
    this.onTenantUpdated,
  }) : super(key: key);

  @override
  State<TenantListDetailUi> createState() => _TenantListDetailUiState();
}

class _TenantListDetailUiState extends State<TenantListDetailUi>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? _tenantDetail;
  List<Map<String, dynamic>> _tenantBills = [];
  List<Map<String, dynamic>> _tenantUtilities = [];

  bool _isLoading = true;
  bool _isUpdating = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTenantDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTenantDetail() async {
    setState(() => _isLoading = true);

    try {
      // ดึงข้อมูลผู้เช่าพร้อมรายละเอียดห้องและสาขา
      final tenantResponse = await supabase.from('tenants').select('''
          *, 
          rooms!inner(
            room_id, room_number, room_name, room_rate, room_deposit, 
            room_cate, room_type, room_status, room_fac, room_images
          ),
          branches!inner(branch_name, branch_address, branch_phone),
          users!tenants_user_id_fkey(user_profile, user_email, username)
        ''').eq('tenant_id', widget.tenantId).single();

      // ดึงข้อมูลบิลของผู้เช่า
      final billsResponse = await supabase
          .from('rental_bills')
          .select('*')
          .eq('tenant_id', widget.tenantId)
          .order('created_at', ascending: false);

      // ดึงข้อมูลค่าสาธารณูปโภคผ่าน rental_bills
      // เนื่องจาก bill_utility_details ไม่มี tenant_id ต้อง join ผ่าน bill_id
      List<Map<String, dynamic>> utilitiesData = [];

      if (billsResponse.isNotEmpty) {
        // รวบรวม bill_id ทั้งหมด
        final billIds = billsResponse.map((bill) => bill['bill_id']).toList();

        // Query utilities จาก bill_utility_details โดยใช้ bill_id
        final utilitiesResponse = await supabase
            .from('bill_utility_details')
            .select('*')
            .inFilter('bill_id', billIds)
            .order('billing_period_start', ascending: false);

        utilitiesData = List<Map<String, dynamic>>.from(utilitiesResponse);
      }

      setState(() {
        _tenantDetail = tenantResponse;
        _tenantBills = List<Map<String, dynamic>>.from(billsResponse);
        _tenantUtilities = utilitiesData;
      });
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      print('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTenantStatus(String newStatus) async {
    setState(() => _isUpdating = true);

    try {
      await supabase.from('tenants').update({
        'tenant_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', widget.tenantId);

      _showSuccessSnackBar('อัพเดทสถานะผู้เช่าสำเร็จ');
      await _loadTenantDetail();
      widget.onTenantUpdated?.call();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการอัพเดทสถานะ: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateContactStatus(String newContactStatus) async {
    setState(() => _isUpdating = true);

    try {
      await supabase.from('tenants').update({
        'contact_status': newContactStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', widget.tenantId);

      _showSuccessSnackBar('อัพเดทสถานะการติดต่อสำเร็จ');
      await _loadTenantDetail();
      widget.onTenantUpdated?.call();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการอัพเดทสถานะการติดต่อ: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('รายละเอียดผู้เช่า'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_tenantDetail == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('รายละเอียดผู้เช่า'),
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

    final tenant = _tenantDetail!;
    final room = tenant['rooms'];
    final branch = tenant['branches'];
    final user = tenant['users'];

    return Scaffold(
      appBar: AppBar(
        title: Text('รายละเอียดผู้เช่า'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isUpdating)
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
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              tooltip: 'ตัวเลือก',
              onSelected: (value) => _handleMenuAction(value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit_status',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 20, color: Colors.blue[600]),
                      SizedBox(width: 8),
                      Text('แก้ไขสถานะ'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit_contact',
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 20, color: Colors.green[600]),
                      SizedBox(width: 8),
                      Text('แก้ไขสถานะการติดต่อ'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text('รีเฟรชข้อมูล'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.info_outline), text: 'ข้อมูล'),
            Tab(icon: Icon(Icons.receipt_long), text: 'บิล'),
            Tab(icon: Icon(Icons.electrical_services), text: 'สาธารณูปโภค'),
            Tab(icon: Icon(Icons.history), text: 'ประวัติ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(tenant, room, branch, user),
          _buildBillsTab(),
          _buildUtilitiesTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab(Map<String, dynamic> tenant, Map<String, dynamic> room,
      Map<String, dynamic> branch, Map<String, dynamic>? user) {
    final tenantIn = DateTime.parse(tenant['tenant_in']);
    final tenantOut = DateTime.parse(tenant['tenant_out']);
    final isExpiringSoon = tenantOut.difference(DateTime.now()).inDays <= 30;
    final daysLeft = tenantOut.difference(DateTime.now()).inDays;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: user?['user_profile'] != null
                        ? MemoryImage(base64Decode(user?['user_profile']))
                        : null,
                    child: user?['user_profile'] == null
                        ? Text(
                            tenant['tenant_full_name'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant['tenant_full_name'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ห้อง ${tenant['room_number']} - ${room['room_name']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(tenant['tenant_status'])
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(tenant['tenant_status']),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getStatusText(tenant['tenant_status']),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Contract Status Warning
          if (isExpiringSoon && daysLeft >= 0) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สัญญาใกล้หมดอายุ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          ),
                        ),
                        Text(
                          'เหลืออีก $daysLeft วัน (${_formatDate(tenantOut)})',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ] else if (daysLeft < 0) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_rounded, color: Colors.red[700]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สัญญาหมดอายุแล้ว',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red[800],
                          ),
                        ),
                        Text(
                          'เกินมาแล้ว ${(-daysLeft)} วัน (${_formatDate(tenantOut)})',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],

          // Personal Information
          _buildInfoSection(
            'ข้อมูลส่วนตัว',
            Icons.person,
            [
              _buildInfoRow('ชื่อ-นามสกุล', tenant['tenant_full_name']),
              _buildInfoRow('เบอร์โทรศัพท์', tenant['tenant_phone'],
                  trailing: IconButton(
                    icon: Icon(Icons.phone, color: Colors.green, size: 20),
                    onPressed: () => _makePhoneCall(tenant['tenant_phone']),
                  )),
              _buildInfoRow('เลขบัตรประชาชน', tenant['tenant_card']),
              if (tenant['tenant_code'] != null &&
                  tenant['tenant_code'].toString().isNotEmpty)
                _buildInfoRow('รหัสผู้เช่า', tenant['tenant_code']),
              _buildInfoRow('สถานะการติดต่อ',
                  _getContactStatusText(tenant['contact_status']),
                  valueColor: _getContactStatusColor(tenant['contact_status'])),
              if (user != null) ...[
                _buildInfoRow('อีเมล', user['user_email'] ?? '-'),
                _buildInfoRow('ชื่อผู้ใช้', user['username'] ?? '-'),
              ],
            ],
          ),

          SizedBox(height: 16),

          // Room Information
          _buildInfoSection(
            'ข้อมูลห้องพัก',
            Icons.home,
            [
              _buildInfoRow('เลขห้อง', tenant['room_number']),
              _buildInfoRow('ชื่อห้อง', room['room_name']),
              _buildInfoRow('ประเภทห้อง', room['room_cate']),
              _buildInfoRow('ชนิดห้อง', room['room_type']),
              _buildInfoRow('ค่าเช่ารายเดือน',
                  '${NumberFormat('#,##0').format(room['room_rate'])} บาท'),
              _buildInfoRow('เงินมัดจำ',
                  '${NumberFormat('#,##0').format(room['room_deposit'])} บาท'),
              _buildInfoRow('สถานะห้อง', room['room_status']),
            ],
          ),

          SizedBox(height: 16),

          // Branch Information
          _buildInfoSection(
            'ข้อมูลสาขา',
            Icons.business,
            [
              _buildInfoRow('ชื่อสาขา', branch['branch_name']),
              _buildInfoRow('ที่อยู่', branch['branch_address']),
              _buildInfoRow('เบอร์โทร', branch['branch_phone']),
            ],
          ),

          SizedBox(height: 16),

          // Contract Information
          _buildInfoSection(
            'ข้อมูลสัญญา',
            Icons.description,
            [
              _buildInfoRow('วันที่เข้าพัก', _formatDate(tenantIn)),
              _buildInfoRow('วันที่สิ้นสุดสัญญา', _formatDate(tenantOut)),
              _buildInfoRow('ระยะเวลาพัก',
                  '${tenantOut.difference(tenantIn).inDays} วัน'),
              _buildInfoRow(
                  'วันที่เข้าถึงล่าสุด',
                  tenant['last_access_at'] != null
                      ? _formatDateTime(
                          DateTime.parse(tenant['last_access_at']))
                      : 'ยังไม่เคยเข้าใช้งาน'),
              _buildInfoRow('มีบัญชีผู้ใช้',
                  tenant['has_account'] == true ? 'มี' : 'ไม่มี',
                  valueColor: tenant['has_account'] == true
                      ? Colors.green
                      : Colors.grey),
            ],
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBillsTab() {
    final paidBills =
        _tenantBills.where((bill) => bill['bill_status'] == 'paid').length;
    final pendingBills =
        _tenantBills.where((bill) => bill['bill_status'] == 'pending').length;
    final overdueBills = _tenantBills
        .where((bill) =>
            bill['bill_status'] == 'overdue' ||
            (bill['bill_status'] == 'pending' &&
                DateTime.parse(bill['due_date']).isBefore(DateTime.now())))
        .length;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: AppColors.primary),
                  SizedBox(width: 12),
                  Text(
                    'บิลทั้งหมด ${_tenantBills.length} รายการ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildBillStat('จ่ายแล้ว', paidBills, Colors.green),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child:
                        _buildBillStat('รอชำระ', pendingBills, Colors.orange),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child:
                        _buildBillStat('เกินกำหนด', overdueBills, Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _tenantBills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_outlined,
                          size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text('ยังไม่มีบิล',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _tenantBills.length,
                  itemBuilder: (context, index) {
                    final bill = _tenantBills[index];
                    return _buildRentalBillCard(bill); // เปลี่ยนชื่อ function
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRentalBillCard(Map<String, dynamic> bill) {
    final dueDate = DateTime.parse(bill['due_date']);
    final createdDate = DateTime.parse(bill['created_at']);
    final isOverdue = bill['bill_status'] == 'overdue' ||
        (bill['bill_status'] == 'pending' && dueDate.isBefore(DateTime.now()));
    final isPaid = bill['bill_status'] == 'paid';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isOverdue
              ? Colors.red[300]!
              : isPaid
                  ? Colors.green[300]!
                  : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with bill number and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill['bill_number'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ระยะเวลา: ${_formatDate(DateTime.parse(bill['billing_period_start']))} - ${_formatDate(DateTime.parse(bill['billing_period_end']))}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getBillStatusColor(bill['bill_status'])
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getBillStatusColor(bill['bill_status']),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getRentalBillStatusText(bill['bill_status']),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getBillStatusColor(bill['bill_status']),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Amount section
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.attach_money,
                          size: 20, color: Colors.green[600]),
                      SizedBox(width: 8),
                      Text(
                        'ยอดรวมสุทธิ:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${NumberFormat('#,##0.00').format(bill['total_amount'])} บาท',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  if (bill['outstanding_amount'] > 0) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.pending,
                            size: 16, color: Colors.orange[600]),
                        SizedBox(width: 8),
                        Text(
                          'คงเหลือ:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${NumberFormat('#,##0.00').format(bill['outstanding_amount'])} บาท',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 12),

            // Dates information
            Row(
              children: [
                Expanded(
                  child: _buildDateInfo(
                    'วันที่สร้าง',
                    _formatDate(createdDate),
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildDateInfo(
                    'ครบกำหนด',
                    _formatDate(dueDate),
                    Icons.schedule,
                    isOverdue ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),

            // Payment information
            if (isPaid && bill['paid_date'] != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: Colors.green[600]),
                    SizedBox(width: 8),
                    Text(
                      'จ่ายเมื่อ: ${_formatDate(DateTime.parse(bill['paid_date']))}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Overdue warning
            if (isOverdue) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.red[600]),
                    SizedBox(width: 8),
                    Text(
                      'เกินกำหนด ${DateTime.now().difference(dueDate).inDays} วัน',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Notes
            if (bill['notes'] != null &&
                bill['notes'].toString().isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'หมายเหตุ: ${bill['notes']}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUtilitiesTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.electrical_services, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'ข้อมูลค่าสาธารณูปโภค ${_tenantUtilities.length} รายการ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tenantUtilities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.electrical_services_outlined,
                          size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text('ยังไม่มีข้อมูลค่าสาธารณูปโภค',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _tenantUtilities.length,
                  itemBuilder: (context, index) {
                    final utility = _tenantUtilities[index];
                    return _buildUtilityDetailCard(
                        utility); // เปลี่ยนชื่อ function
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUtilityDetailCard(Map<String, dynamic> utility) {
    // ตรวจสอบว่าข้อมูลมาจากแหล่งไหน
    final isFromBillSummary = utility.containsKey('total_utilities');
    final isFromUtilityItems = utility.containsKey('utility_types');

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.electrical_services,
                    size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  isFromBillSummary
                      ? 'รวมค่าสาธารณูปโภค'
                      : (isFromUtilityItems
                          ? utility['utility_types']['type_name'] ?? 'ไม่ระบุ'
                          : utility['utility_name'] ?? 'ไม่ระบุ'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Spacer(),
                Text(
                  utility['bill_number'] ??
                      DateFormat('dd/MM/yyyy').format(DateTime.parse(
                          utility['billing_period_start'] ??
                              utility['created_at'])),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // แสดงข้อมูลตามประเภท
            if (isFromBillSummary) ...[
              // แสดงเฉพาะยอดรวม
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calculate, color: Colors.green[700], size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ยอดรวมค่าสาธารณูปโภค:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${NumberFormat('#,##0.00').format(utility['total_utilities'] ?? 0)} บาท',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // แสดงรายละเอียดการอ่านมิเตอร์
              if (utility['previous_reading'] != null ||
                  utility['current_reading'] != null) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('เลขเดือนก่อน:',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          Spacer(),
                          Text(
                              '${utility['previous_reading'] ?? 0} ${utility['unit_name'] ?? (isFromUtilityItems ? utility['utility_types']['unit_name'] : 'หน่วย')}',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text('เลขล่าสุด:',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          Spacer(),
                          Text(
                              '${utility['current_reading'] ?? 0} ${utility['unit_name'] ?? (isFromUtilityItems ? utility['utility_types']['unit_name'] : 'หน่วย')}',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text('หน่วยที่ใช้:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600)),
                          Spacer(),
                          Text(
                              '${utility['consumption'] ?? 0} ${utility['unit_name'] ?? (isFromUtilityItems ? utility['utility_types']['unit_name'] : 'หน่วย')}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue[700])),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
              ],

              // จำนวนเงิน
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calculate, color: Colors.green[700], size: 20),
                    SizedBox(width: 8),
                    Text(
                      'จำนวนเงิน:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${NumberFormat('#,##0.00').format(utility['amount'] ?? 0)} บาท',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
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

  Widget _buildHistoryTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text('ประวัติการเปลี่ยนแปลง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('ฟีเจอร์นี้จะเพิ่มในอนาคต',
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
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
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? valueColor, Widget? trailing}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.grey[800],
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildBillStat(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String date, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit_status':
        _showStatusEditDialog();
        break;
      case 'edit_contact':
        _showContactStatusEditDialog();
        break;
      case 'refresh':
        _loadTenantDetail();
        break;
    }
  }

  void _showStatusEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note, color: AppColors.primary),
            SizedBox(width: 8),
            Text('แก้ไขสถานะผู้เช่า'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption('active', 'เข้าพักแล้ว', Colors.green),
            _buildStatusOption('suspended', 'ระงับชั่วคราว', Colors.orange),
            _buildStatusOption('checkout', 'ออกจากห้อง', Colors.red),
            _buildStatusOption('terminated', 'ยกเลิกสัญญา', Colors.grey),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  void _showContactStatusEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.phone, color: AppColors.primary),
            SizedBox(width: 8),
            Text('แก้ไขสถานะการติดต่อ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContactStatusOption('reachable', 'ติดต่อได้', Colors.green),
            _buildContactStatusOption(
                'unreachable', 'ติดต่อไม่ได้', Colors.red),
            _buildContactStatusOption('pending', 'รอติดต่อ', Colors.orange),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String status, String label, Color color) {
    final isSelected = _tenantDetail?['tenant_status'] == status;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.pop(context);
            if (!isSelected) {
              _showConfirmDialog(
                'เปลี่ยนสถานะเป็น "$label"',
                'คุณต้องการเปลี่ยนสถานะผู้เช่าเป็น "$label" หรือไม่?',
                () => _updateTenantStatus(status),
              );
            }
          },
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected ? color.withOpacity(0.1) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? color : Colors.grey[800],
                  ),
                ),
                if (isSelected) ...[
                  Spacer(),
                  Icon(Icons.check, color: color, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactStatusOption(String status, String label, Color color) {
    final isSelected = _tenantDetail?['contact_status'] == status;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.pop(context);
            if (!isSelected) {
              _showConfirmDialog(
                'เปลี่ยนสถานะการติดต่อเป็น "$label"',
                'คุณต้องการเปลี่ยนสถานะการติดต่อเป็น "$label" หรือไม่?',
                () => _updateContactStatus(status),
              );
            }
          },
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected ? color.withOpacity(0.1) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? color : Colors.grey[800],
                  ),
                ),
                if (isSelected) ...[
                  Spacer(),
                  Icon(Icons.check, color: color, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConfirmDialog(
      String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        await Clipboard.setData(ClipboardData(text: phoneNumber));
        _showSuccessSnackBar('คัดลอกเบอร์โทรแล้ว: $phoneNumber');
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: phoneNumber));
      _showSuccessSnackBar('คัดลอกเบอร์โทรแล้ว: $phoneNumber');
    }
  }

  // Helper Methods
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  String _getRentalBillStatusText(String status) {
    switch (status) {
      case 'draft':
        return 'ร่าง';
      case 'pending':
        return 'รอชำระ';
      case 'paid':
        return 'จ่ายแล้ว';
      case 'overdue':
        return 'เกินกำหนด';
      case 'cancelled':
        return 'ยกเลิก';
      case 'partial':
        return 'ชำระบางส่วน';
      default:
        return status;
    }
  }

  IconData _getUtilityIcon(String? utilityName) {
    final name = utilityName?.toLowerCase() ?? '';
    if (name.contains('ไฟ') || name.contains('electric')) {
      return Icons.electrical_services;
    } else if (name.contains('น้ำ') || name.contains('water')) {
      return Icons.water_drop;
    } else if (name.contains('อินเทอร์เน็ต') || name.contains('internet')) {
      return Icons.wifi;
    } else {
      return Icons.build;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.orange;
      case 'checkout':
        return Colors.red;
      case 'terminated':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'เข้าพักแล้ว';
      case 'suspended':
        return 'ระงับชั่วคราว';
      case 'checkout':
        return 'ออกจากห้อง';
      case 'terminated':
        return 'ยกเลิกสัญญา';
      default:
        return status;
    }
  }

  Color _getContactStatusColor(String? status) {
    switch (status) {
      case 'reachable':
        return Colors.green;
      case 'unreachable':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getContactStatusText(String? status) {
    switch (status) {
      case 'reachable':
        return 'ติดต่อได้';
      case 'unreachable':
        return 'ติดต่อไม่ได้';
      case 'pending':
        return 'รอติดต่อ';
      default:
        return 'ไม่ระบุ';
    }
  }

  Color _getBillStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getBillStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'จ่ายแล้ว';
      case 'pending':
        return 'รอชำระ';
      case 'overdue':
        return 'เกินกำหนด';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  Color _getUtilityStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'confirmed':
        return Colors.blue;
      case 'billed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getUtilityStatusText(String status) {
    switch (status) {
      case 'draft':
        return 'ร่าง';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'billed':
        return 'ออกบิลแล้ว';
      default:
        return status;
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
