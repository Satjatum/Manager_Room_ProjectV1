import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/invoice_add_ui.dart';
import 'package:manager_room_project/views/sadmin/meter_add_ui.dart';
import 'package:manager_room_project/views/sadmin/meter_edit_ui.dart';
import 'package:manager_room_project/views/sadmin/meterlist_detail_ui.dart';
import 'package:manager_room_project/views/utility_setting_ui.dart';
import 'package:manager_room_project/widgets/navbar.dart';
import '../../services/meter_service.dart';
import '../../services/branch_service.dart';
import '../../services/room_service.dart';
import '../../services/auth_service.dart';
import '../../services/utility_rate_service.dart';
import '../../models/user_models.dart';
import '../../widgets/colors.dart';

class MeterReadingsListPage extends StatefulWidget {
  const MeterReadingsListPage({Key? key}) : super(key: key);

  @override
  State<MeterReadingsListPage> createState() => _MeterReadingsListPageState();
}

class _MeterReadingsListPageState extends State<MeterReadingsListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _meterReadings = [];
  List<Map<String, dynamic>> _filteredReadings = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _rooms = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _selectedBranchId;
  String? _selectedRoomId;
  String? _selectedTenantId;
  String _selectedStatus = 'all';
  int? _selectedMonth;
  int? _selectedYear;
  String _searchQuery = '';

  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMoreData = true;
  Map<String, dynamic>? _stats;
  UserModel? _currentUser;

  // แคชตรวจสอบว่าแต่ละสาขามีอัตราค่าบริการที่เปิดใช้งานหรือไม่
  final Map<String, bool> _branchHasActiveRates = {};
  bool _selectedBranchHasRates = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _applyFilters();
    }
  }

  Future<void> _updateBranchRatesCache() async {
    try {
      // รวม branch_id จากรายการที่โหลดและสาขาที่เลือกไว้
      final Set<String> branchIds = {};
      for (final r in _meterReadings) {
        final bid = r['branch_id'];
        if (bid != null && bid is String && bid.isNotEmpty) {
          branchIds.add(bid);
        }
      }
      if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty) {
        branchIds.add(_selectedBranchId!);
      }

      // เรียกดูอัตราค่าบริการเฉพาะสาขาที่ยังไม่ได้อยู่ในแคช
      for (final bid in branchIds) {
        if (_branchHasActiveRates.containsKey(bid)) continue;
        final rates = await UtilityRatesService.getActiveRatesForBranch(bid);
        _branchHasActiveRates[bid] = rates.isNotEmpty;
      }

      // อัปเดตสถานะของสาขาที่เลือกสำหรับแสดง Helper
      if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty) {
        _selectedBranchHasRates =
            _branchHasActiveRates[_selectedBranchId!] ?? true;
      } else {
        _selectedBranchHasRates = true; // เมื่อไม่ได้เลือกสาขา ไม่แสดง Helper
      }

      if (mounted) setState(() {});
    } catch (e) {
      // หากตรวจสอบไม่ได้ ให้ไม่บล็อกการใช้งานปุ่มออกบิล
      if (mounted) setState(() => _selectedBranchHasRates = true);
    }
  }

  // ฟังก์ชันจัดรูปแบบวันที่
  String _formatDate(DateTime date) {
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} น.';
  }

  String _getMonthName(int month) {
    const monthNames = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return monthNames[month - 1];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'billed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'draft':
        return 'ร่าง';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'billed':
        return 'ออกบิลแล้ว';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWeb = screenSize.width > 1200;
    final isTablet = screenSize.width > 768 && screenSize.width <= 1200;
    final isMobile = screenSize.width <= 768;

    final canCreateReading = _currentUser?.hasAnyPermission([
          DetailedPermission.all,
          DetailedPermission.manageMeterReadings,
        ]) ??
        false;

    final canFilterByBranch = _currentUser?.hasAnyPermission([
          DetailedPermission.all,
          DetailedPermission.manageBranches,
        ]) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการบันทึกค่ามิเตอร์'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'ตัวกรอง',
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: null,
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.calendar_month,
                        size: 20, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text('เดือน/ปี',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ...List.generate(12, (index) {
                return PopupMenuItem<String>(
                  value: 'month_${index + 1}',
                  child: Text(_getMonthName(index + 1)),
                );
              }),
              const PopupMenuDivider(),
              ...List.generate(5, (index) {
                final year = DateTime.now().year - index;
                return PopupMenuItem<String>(
                  value: 'year_$year',
                  child: Text('$year'),
                );
              }),
            ],
            onSelected: (String? value) {
              if (value != null) {
                if (value.startsWith('month_')) {
                  setState(() {
                    _selectedMonth =
                        int.parse(value.replaceFirst('month_', ''));
                  });
                } else if (value.startsWith('year_')) {
                  setState(() {
                    _selectedYear = int.parse(value.replaceFirst('year_', ''));
                  });
                }
                _loadMeterReadings();
                _loadStats();
              }
            },
          ),
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with search and filters
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาเลขที่บันทึก, หมายเลขห้อง, ชื่อผู้เช่า...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _applyFilters();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _applyFilters();
                  },
                ),

                // Branch and Room filters for responsive layout
                if (canFilterByBranch && _branches.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  if (isWeb || isTablet)
                    Row(
                      children: [
                        Expanded(child: _buildBranchDropdown()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildRoomDropdown()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildBranchDropdown(),
                        const SizedBox(height: 8),
                        _buildRoomDropdown(),
                      ],
                    ),
                ],

                const SizedBox(height: 12),

                // Statistics tracking bar
                if (_stats != null) _buildTrackingBar(),

                const SizedBox(height: 12),

                // Tab bar
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  onTap: (index) => _applyFilters(),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: 'ทั้งหมด (${_getReadingCountByStatus('all')})'),
                    Tab(text: 'ร่าง (${_getReadingCountByStatus('draft')})'),
                    Tab(
                        text:
                            'ยืนยันแล้ว (${_getReadingCountByStatus('confirmed')})'),
                    Tab(
                        text:
                            'ออกบิลแล้ว (${_getReadingCountByStatus('billed')})'),
                    Tab(
                        text:
                            'ยกเลิก (${_getReadingCountByStatus('cancelled')})'),
                  ],
                ),

                // Helper: ยังไม่ตั้งค่าอัตราค่าบริการสำหรับสาขาที่เลือก
                if (_selectedBranchId != null && !_selectedBranchHasRates) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.amber.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      title: const Text(
                        'ยังไม่สามารถออกบิลได้ เนื่องจากสาขานี้ยังไม่ได้กำหนดอัตราค่าบริการค่าน้ำและค่าไฟ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.settings),
                        label: const Text('ไปตั้งค่าอัตราค่าบริการ'),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UtilityRatesManagementUi(),
                            ),
                          );
                          // กลับมาจากหน้าตั้งค่าแล้ว รีเช็คสถานะอีกครั้ง
                          await _updateBranchRatesCache();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Meter readings list
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'กำลังโหลดข้อมูล...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _filteredReadings.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        color: AppTheme.primary,
                        child: _buildMeterReadingsList(screenSize),
                      ),
          ),
        ],
      ),
      floatingActionButton: canCreateReading
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MeterReadingFormPage()),
                ).then((_) => _refreshData());
              },
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: 'เพิ่มบันทึกค่ามิเตอร์',
            )
          : null,
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildBranchDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedBranchId,
          hint: const Text('เลือกสาขา (ทั้งหมด)'),
          icon: const Icon(Icons.arrow_drop_down),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('ทุกสาขา'),
            ),
            ..._branches.map((branch) {
              return DropdownMenuItem<String>(
                value: branch['branch_id'],
                child: Text(branch['branch_name'] ?? ''),
              );
            }).toList(),
          ],
          onChanged: (String? value) async {
            setState(() {
              _selectedBranchId = value;
              _selectedRoomId = null;
              _rooms.clear();
            });
            if (value != null) await _loadRooms();
            await _loadMeterReadings();
            await _loadStats();
          },
        ),
      ),
    );
  }

  Widget _buildRoomDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedRoomId,
          hint: const Text('เลือกห้อง (ทั้งหมด)'),
          icon: const Icon(Icons.arrow_drop_down),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('ทุกห้อง'),
            ),
            ..._rooms.map((room) {
              return DropdownMenuItem<String>(
                value: room['room_id'],
                child: Text('ห้อง ${room['room_number']}'),
              );
            }).toList(),
          ],
          onChanged: (String? value) {
            setState(() => _selectedRoomId = value);
            _loadMeterReadings();
            _loadStats();
          },
        ),
      ),
    );
  }

  Widget _buildTrackingBar() {
    final total = _getReadingCountByStatus('all');
    final draft = _getReadingCountByStatus('draft');
    final confirmed = _getReadingCountByStatus('confirmed');
    final billed = _getReadingCountByStatus('billed');

    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'สถิติการบันทึกค่ามิเตอร์',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                'ทั้งหมด $total รายการ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (draft > 0)
                    Expanded(
                      flex: draft,
                      child: Container(color: Colors.orange),
                    ),
                  if (confirmed > 0)
                    Expanded(
                      flex: confirmed,
                      child: Container(color: Colors.green),
                    ),
                  if (billed > 0)
                    Expanded(
                      flex: billed,
                      child: Container(color: Colors.purple),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.orange, 'ร่าง', draft, total),
              _buildLegendItem(Colors.green, 'ยืนยันแล้ว', confirmed, total),
              _buildLegendItem(Colors.purple, 'ออกบิลแล้ว', billed, total),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int count, int total) {
    final percentage =
        total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.speed_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ไม่มีข้อมูลค่ามิเตอร์ในหมวดนี้',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เมื่อมีการบันทึกค่ามิเตอร์ จะแสดงในที่นี่',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterReadingsList(Size screenSize) {
    final isMobile = screenSize.width <= 768;

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _filteredReadings.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredReadings.length) {
          return _buildLoadMoreButton();
        }

        final reading = _filteredReadings[index];
        return _buildMeterReadingCard(reading, screenSize);
      },
    );
  }

  Widget _buildLoadMoreButton() {
    if (!_hasMoreData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      child: _isLoadingMore
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : ElevatedButton.icon(
              onPressed: () => _loadMeterReadings(isLoadMore: true),
              icon: const Icon(Icons.expand_more),
              label: const Text('โหลดเพิ่มเติม'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );
  }

  Widget _buildMeterReadingCard(Map<String, dynamic> reading, Size screenSize) {
    final isMobile = screenSize.width <= 768;
    final isTablet = screenSize.width > 768 && screenSize.width <= 1200;

    final readingId = reading['reading_id'];
    final status = reading['reading_status'] ?? 'draft';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final readingNumber = reading['reading_number'] ?? '';
    final roomNumber = reading['room_number'] ?? '';
    final tenantName = reading['tenant_name'] ?? '';
    final branchName = reading['branch_name'] ?? '';
    final readingDate = reading['reading_date'] != null
        ? DateTime.parse(reading['reading_date'])
        : null;

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MeterReadingDetailPage(
                readingId: readingId,
              ),
            ),
          ).then((_) => _refreshData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    readingNumber,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Action buttons
                  _buildActionButtons(reading, screenSize),
                ],
              ),
              const SizedBox(height: 12),

              // Title and room info
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    size: 20,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ห้อง $roomNumber - $tenantName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (branchName.isNotEmpty)
                          Text(
                            branchName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Reading info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildReadingInfoResponsive(reading, isMobile),
              ),
              const SizedBox(height: 12),

              // Date and notes
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    readingDate != null
                        ? _formatDateTime(readingDate)
                        : 'ไม่ระบุ',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'เดือน: ${_getMonthName(reading['reading_month'] ?? 1)} ${reading['reading_year'] ?? DateTime.now().year}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              if (reading['reading_notes'] != null &&
                  reading['reading_notes'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'หมายเหตุ: ${reading['reading_notes']}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingInfoResponsive(
      Map<String, dynamic> reading, bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildReadingInfo('น้ำ', reading),
          const SizedBox(height: 8),
          _buildReadingInfo('ไฟ', reading),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: _buildReadingInfo('น้ำ', reading)),
          const SizedBox(width: 12),
          Expanded(child: _buildReadingInfo('ไฟ', reading)),
        ],
      );
    }
  }

  Widget _buildReadingInfo(String type, Map<String, dynamic> reading) {
    final isWater = type == 'น้ำ';
    final previous = isWater
        ? reading['water_previous_reading']
        : reading['electric_previous_reading'];
    final current = isWater
        ? reading['water_current_reading']
        : reading['electric_current_reading'];
    final usage = isWater ? reading['water_usage'] : reading['electric_usage'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isWater ? Icons.water_drop : Icons.electric_bolt,
              size: 16,
              color: isWater ? Colors.blue : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              type,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'ก่อนหน้า: ${previous?.toStringAsFixed(2) ?? '0.00'}',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          'ปัจจุบัน: ${current?.toStringAsFixed(2) ?? '0.00'} ',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          'ใช้งาน: ${usage?.toStringAsFixed(2) ?? '0.00'} หน่วย',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isWater ? Colors.blue : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> reading, Size screenSize) {
    final status = reading['reading_status'] ?? 'draft';
    final readingId = reading['reading_id'];
    final readingNumber = reading['reading_number'];
    final invoiceId = reading['invoice_id']; // เช็คว่าออกบิลแล้วหรือยัง
    final String? branchId = reading['branch_id'];
    final bool branchHasRates =
        branchId == null ? true : (_branchHasActiveRates[branchId] ?? true);

    final List<PopupMenuEntry<String>> menuItems = [];

    // ปุ่มดูรายละเอียด
    menuItems.add(
      PopupMenuItem<String>(
        value: 'view',
        child: Row(
          children: [
            Icon(Icons.visibility, size: 18, color: Colors.blue[600]),
            const SizedBox(width: 12),
            const Text('ดูรายละเอียด'),
          ],
        ),
      ),
    );

    // ปุ่มแก้ไข (เฉพาะ draft)
    if (status == 'draft') {
      menuItems.add(
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: Colors.orange[600]),
              const SizedBox(width: 12),
              const Text('แก้ไข'),
            ],
          ),
        ),
      );
    }

    // ปุ่มยืนยัน (เฉพาะ draft)
    if (status == 'draft') {
      menuItems.add(
        PopupMenuItem<String>(
          value: 'confirm',
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: Colors.green[600]),
              const SizedBox(width: 12),
              const Text('ยืนยัน'),
            ],
          ),
        ),
      );
    }

    // ปุ่มออกบิล (สำหรับสถานะ confirmed และยังไม่ได้ออกบิล และไม่ใช่ค่าเริ่มต้น/INIT)
    final isInitial = reading['is_initial_reading'] == true;
    final isInitCode = (readingNumber?.toString() ?? '').startsWith('INIT');
    if (status == 'confirmed' &&
        invoiceId == null &&
        !isInitial &&
        !isInitCode) {
      menuItems.add(
        PopupMenuItem<String>(
          value: 'create_invoice',
          child: Row(
            children: [
              Icon(Icons.receipt_long, size: 18, color: Colors.purple[600]),
              const SizedBox(width: 12),
              const Text('ออกบิล',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // ปุ่มดูบิล ถูกย้ายไปหน้า "รายละเอียด" เป็นแท็บใบแจ้งหนี้

    // ปุ่มยกเลิก (เฉพาะ draft)
    if (status == 'draft') {
      menuItems.add(const PopupMenuDivider());
      menuItems.add(
        PopupMenuItem<String>(
          value: 'cancel',
          child: Row(
            children: [
              Icon(Icons.cancel, size: 18, color: Colors.red[600]),
              const SizedBox(width: 12),
              const Text('ยกเลิก', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    // ปุ่มลบ (เฉพาะ Super Admin และสถานะ draft หรือ cancelled)
    if (_currentUser?.userRole == UserRole.superAdmin &&
        (status == 'draft' || status == 'cancelled')) {
      if (menuItems.last is! PopupMenuDivider) {
        menuItems.add(const PopupMenuDivider());
      }
      menuItems.add(
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_forever, size: 18, color: Colors.red[700]),
              const SizedBox(width: 12),
              const Text('ลบ', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => menuItems,
      onSelected: (String value) {
        switch (value) {
          case 'view':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MeterReadingDetailPage(
                  readingId: readingId,
                ),
              ),
            ).then((_) => _refreshData());
            break;

          case 'edit':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MeterReadingEditPage(
                  readingId: readingId,
                ),
              ),
            ).then((_) => _refreshData());
            break;

          case 'confirm':
            _confirmReading(readingId, readingNumber);
            break;

          case 'create_invoice':
            _createInvoice(reading);
            break;

          // case 'view_invoice':
          //   break; // ย้ายไปดูในหน้า MeterReadingDetailPage (แท็บ ใบแจ้งหนี้)

          case 'cancel':
            _cancelReading(readingId, readingNumber);
            break;

          case 'delete':
            _deleteReading(readingId, readingNumber);
            break;
        }
      },
    );
  }

  // โหลดข้อมูลเริ่มต้น
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      _currentUser = await AuthService.getCurrentUser();
      if (_currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      await Future.wait([
        _loadBranches(),
        _loadMeterReadings(),
        _loadStats(),
      ]);
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // โหลดสาขา
  Future<void> _loadBranches() async {
    try {
      if (_currentUser?.userRole == UserRole.superAdmin) {
        _branches = await BranchService.getAllBranches();
      } else {
        _branches = await BranchService.getBranchesByUser();
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error loading branches: $e');
    }
  }

  // โหลดห้องตามสาขาที่เลือก
  Future<void> _loadRooms() async {
    if (_selectedBranchId == null) return;

    try {
      final rooms = await RoomService.getAllRooms(branchId: _selectedBranchId);
      setState(() => _rooms = rooms);
    } catch (e) {
      debugPrint('Error loading rooms: $e');
    }
  }

  // โหลดข้อมูลค่ามิเตอร์
  Future<void> _loadMeterReadings({bool isLoadMore = false}) async {
    if (isLoadMore) {
      setState(() => _isLoadingMore = true);
    }

    try {
      final offset = isLoadMore ? _meterReadings.length : 0;

      final readings = await MeterReadingService.getMeterReadingsByUser(
        offset: offset,
        limit: _pageSize,
        searchQuery:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        branchId: _selectedBranchId,
        roomId: _selectedRoomId,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        readingMonth: _selectedMonth,
        readingYear: _selectedYear,
      );

      for (var reading in readings) {
        if (reading['branch_id'] == null) {
          debugPrint(
              '⚠️ Warning: Reading ${reading['reading_id']} missing branch_id');
        }
      }

      setState(() {
        if (isLoadMore) {
          _meterReadings.addAll(readings);
        } else {
          _meterReadings = readings;
          _currentPage = 0;
        }
        _hasMoreData = readings.length == _pageSize;
      });

      _applyFilters();
      await _updateBranchRatesCache();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      if (isLoadMore) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  // ใช้ตัวกรอง
  void _applyFilters() {
    if (!mounted || _meterReadings.isEmpty) {
      setState(() => _filteredReadings = []);
      return;
    }

    List<Map<String, dynamic>> filtered = List.from(_meterReadings);

    // Filter by tab status
    String tabStatus = _getStatusFromTab(_tabController.index);
    if (tabStatus != 'all') {
      filtered = filtered
          .where((reading) => reading['reading_status'] == tabStatus)
          .toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((reading) {
        final readingNumber =
            reading['reading_number']?.toString().toLowerCase() ?? '';
        final roomNumber =
            reading['room_number']?.toString().toLowerCase() ?? '';
        final tenantName =
            reading['tenant_name']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return readingNumber.contains(query) ||
            roomNumber.contains(query) ||
            tenantName.contains(query);
      }).toList();
    }

    setState(() => _filteredReadings = filtered);
  }

  String _getStatusFromTab(int index) {
    switch (index) {
      case 0:
        return 'all';
      case 1:
        return 'draft';
      case 2:
        return 'confirmed';
      case 3:
        return 'billed';
      case 4:
        return 'cancelled';
      default:
        return 'all';
    }
  }

  int _getReadingCountByStatus(String status) {
    if (_stats == null) return 0;
    if (status == 'all') return _stats!['total'] ?? 0;
    return _stats![status] ?? 0;
  }

  // โหลดสถิติ
  Future<void> _loadStats() async {
    try {
      // Admin ไม่เลือกสาขา → คำนวณจากรายการที่โหลดไว้แล้ว (ซึ่งถูกจำกัดสิทธิ์)
      if (_currentUser?.userRole == UserRole.admin &&
          (_selectedBranchId == null || _selectedBranchId!.isEmpty)) {
        _stats = _computeStatsFromReadings(_meterReadings);
        setState(() {});
        return;
      }

      final stats = await MeterReadingService.getMeterReadingStats(
        branchId: _selectedBranchId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      setState(() => _stats = stats);
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Map<String, dynamic> _computeStatsFromReadings(
      List<Map<String, dynamic>> readings) {
    int total = readings.length;
    int initial = readings.where((r) => r['is_initial_reading'] == true).length;
    int draft = readings
        .where((r) =>
            r['is_initial_reading'] != true && r['reading_status'] == 'draft')
        .length;
    int confirmed = readings
        .where((r) =>
            r['is_initial_reading'] != true &&
            r['reading_status'] == 'confirmed')
        .length;
    int billed = readings.where((r) => r['reading_status'] == 'billed').length;
    int cancelled =
        readings.where((r) => r['reading_status'] == 'cancelled').length;

    return {
      'total': total,
      'initial': initial,
      'draft': draft,
      'confirmed': confirmed,
      'billed': billed,
      'cancelled': cancelled,
    };
  }

  // รีเฟรชข้อมูล
  Future<void> _refreshData() async {
    await Future.wait([
      _loadMeterReadings(),
      _loadStats(),
    ]);
    await _updateBranchRatesCache();
  }

  // ยืนยันค่ามิเตอร์
  Future<void> _confirmReading(String readingId, String readingNumber) async {
    final currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) {
      _showErrorSnackBar('กรุณาเข้าสู่ระบบใหม่');
      return;
    }

    final canManage = currentUser.hasAnyPermission([
      DetailedPermission.all,
      DetailedPermission.manageMeterReadings,
    ]);

    if (!canManage) {
      _showErrorSnackBar('ไม่มีสิทธิ์ในการยืนยันค่ามิเตอร์');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันค่ามิเตอร์'),
        content: Text('ต้องการยืนยันค่ามิเตอร์ $readingNumber หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await MeterReadingService.confirmMeterReading(readingId);
        if (result['success']) {
          _showSuccessSnackBar('ยืนยันค่ามิเตอร์สำเร็จ');
          _refreshData();
        } else {
          _showErrorSnackBar(result['message']);
        }
      } catch (e) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  // ยกเลิกค่ามิเตอร์
  Future<void> _cancelReading(String readingId, String readingNumber) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกค่ามิเตอร์'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ต้องการยกเลิกค่ามิเตอร์ $readingNumber หรือไม่?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'เหตุผลในการยกเลิก',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await MeterReadingService.cancelMeterReading(
          readingId,
          reasonController.text,
        );
        if (result['success']) {
          _showSuccessSnackBar('ยกเลิกค่ามิเตอร์สำเร็จ');
          _refreshData();
        } else {
          _showErrorSnackBar(result['message']);
        }
      } catch (e) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  // ลบค่ามิเตอร์
  Future<void> _deleteReading(String readingId, String readingNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบค่ามิเตอร์'),
        content: Text(
            'ต้องการลบค่ามิเตอร์ $readingNumber หรือไม่?\n\nการดำเนินการนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await MeterReadingService.deleteMeterReading(readingId);
        if (result['success']) {
          _showSuccessSnackBar('ลบค่ามิเตอร์สำเร็จ');
          _refreshData();
        } else {
          _showErrorSnackBar(result['message']);
        }
      } catch (e) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  // ออกบิล - นำไปที่หน้าสร้างบิลใหม่
  Future<void> _createInvoice(Map<String, dynamic> reading) async {
    final currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) {
      _showErrorSnackBar('กรุณาเข้าสู่ระบบใหม่');
      return;
    }

    final canManage = currentUser.hasAnyPermission([
      DetailedPermission.all,
      DetailedPermission.manageInvoices,
    ]);

    if (!canManage) {
      _showErrorSnackBar('ไม่มีสิทธิ์ในการออกบิล');
      return;
    }

    // ตรวจสอบว่าค่ามิเตอร์นี้ยืนยันแล้วหรือยัง
    if (reading['reading_status'] != 'confirmed') {
      _showErrorSnackBar('กรุณายืนยันค่ามิเตอร์ก่อนออกบิล');
      return;
    }

    if (reading['branch_id'] == null) {
      _showErrorSnackBar('ไม่พบข้อมูลสาขา');
      return;
    }

    try {
      String? branchId = reading['branch_id'];
      if (branchId == null && reading['room_id'] != null) {
        final room = await RoomService.getRoomById(reading['room_id']);
        branchId = room?['branch_id'];
      }

      if (branchId == null) {
        _showErrorSnackBar('ไม่พบข้อมูลสาขา กรุณาตรวจสอบข้อมูลห้องพัก');
        return;
      }

      // ตรวจสอบว่ามีอัตราค่าบริการที่เปิดใช้งานในสาขานี้หรือไม่
      final hasRates = _branchHasActiveRates[branchId] ??
          (await UtilityRatesService.getActiveRatesForBranch(branchId))
              .isNotEmpty;
      if (!hasRates) {
        _showDetailedErrorDialog(
          'ยังไม่สามารถออกบิลได้',
          'ยังไม่สามารถออกบิลได้ เนื่องจากสาขานี้ยังไม่ได้กำหนดอัตราค่าบริการค่าน้ำและค่าไฟ',
        );
        return;
      }
      // นำทางไปหน้าสร้างบิลใหม่พร้อมข้อมูลจากการอ่านมิเตอร์
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceAddPage(
            // ส่งข้อมูลที่จำเป็นไปยังหน้าสร้างบิล
            initialData: {
              'room_id': reading['room_id'],
              'branch_id': reading['branch_id'],
              'tenant_id': reading['tenant_id'],
              'contract_id': reading['contract_id'],
              'reading_id': reading['reading_id'],
              'invoice_month': reading['reading_month'],
              'invoice_year': reading['reading_year'],
              'room_number': reading['room_number'],
              'tenant_name': reading['tenant_name'],
              'branch_name': reading['branch_name'],
              // ข้อมูลค่าน้ำ-ไฟ
              'water_usage': reading['water_usage'],
              'electric_usage': reading['electric_usage'],
              'water_previous': reading['water_previous_reading'],
              'water_current': reading['water_current_reading'],
              'electric_previous': reading['electric_previous_reading'],
              'electric_current': reading['electric_current_reading'],
            },
          ),
        ),
      );

      // ถ้าสร้างบิลสำเร็จ ให้รีเฟรชข้อมูล
      if (result != null && result['success'] == true) {
        _showSuccessSnackBar('สร้างใบแจ้งหนี้สำเร็จ');

        // สร้างร่างบันทึกค่ามิเตอร์ของเดือนถัดไป โดยตั้งค่า "ก่อนหน้า" = "ปัจจุบัน" ของเดือนนี้
        try {
          await _ensureNextMonthDraftReading(reading);
        } catch (e) {
          // ไม่ขัดขวาง flow หลัก หากสร้างร่างไม่สำเร็จเพียงแจ้งเตือนเบาๆ
          _showErrorSnackBar('ไม่สามารถเตรียมร่างค่ามิเตอร์เดือนถัดไป: $e');
        }

        _refreshData();
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    }
  }

  // เตรียมร่างค่ามิเตอร์เดือนถัดไป โดยดึงค่า "ก่อนหน้า" จากค่า "ปัจจุบัน" ของรายการที่เพิ่งออกบิล
  Future<void> _ensureNextMonthDraftReading(
      Map<String, dynamic> currentReading) async {
    final String? roomId = currentReading['room_id'];
    final String? tenantId = currentReading['tenant_id'];
    final String? contractId = currentReading['contract_id'];

    if (roomId == null || tenantId == null || contractId == null) {
      return; // ข้อมูลไม่ครบ ข้ามไป
    }

    final int? month = currentReading['reading_month'];
    final int? year = currentReading['reading_year'];

    if (month == null || year == null) {
      return; // ไม่มีเดือน/ปี (เช่น initial) ไม่ต้องสร้าง
    }

    // คำนวณเดือน/ปี ถัดไป
    int nextMonth = month + 1;
    int nextYear = year;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear += 1;
    }

    // เช็คว่ามีรอบเดือนถัดไปอยู่แล้วหรือไม่
    final exists =
        await MeterReadingService.hasReadingForMonth(roomId, nextMonth, nextYear);
    if (exists) return;

    final double waterCurrent =
        (currentReading['water_current_reading'] ?? 0.0).toDouble();
    final double electricCurrent =
        (currentReading['electric_current_reading'] ?? 0.0).toDouble();

    final payload = {
      'room_id': roomId,
      'tenant_id': tenantId,
      'contract_id': contractId,
      'is_initial_reading': false,
      'reading_month': nextMonth,
      'reading_year': nextYear,
      // ตั้งค่าก่อนหน้า = ค่าปัจจุบันของเดือนที่เพิ่งออกบิล
      'water_previous_reading': waterCurrent,
      'electric_previous_reading': electricCurrent,
      // สร้างเป็นร่าง โดยตั้งค่าปัจจุบันเท่ากับก่อนหน้า (usage = 0) ให้แก้ไขภายหลังได้
      'water_current_reading': waterCurrent,
      'electric_current_reading': electricCurrent,
      'reading_date': DateTime.now().toIso8601String().split('T')[0],
      'reading_notes': 'เตรียมร่างอัตโนมัติจากการออกบิลเดือน $month/$year',
    };

    final res = await MeterReadingService.createMeterReading(payload);
    if (res['success'] == true) {
      _showSuccessSnackBar('เตรียมร่างค่ามิเตอร์เดือนถัดไปสำเร็จ');
    }
  }

  // แสดง SnackBar สำเร็จ
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // แสดง SnackBar ข้อผิดพลาด
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showDetailedErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 28),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(color: Colors.red[900]),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'แนะนำ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              _buildSuggestionItem('• ตรวจสอบการตั้งค่าอัตราค่าน้ำ-ไฟ'),
              _buildSuggestionItem('• ตรวจสอบสถานะสัญญาเช่า'),
              _buildSuggestionItem('• ตรวจสอบว่ายืนยันค่ามิเตอร์แล้ว'),
              _buildSuggestionItem('• ติดต่อผู้ดูแลระบบหากยังพบปัญหา'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: เปิดหน้าการตั้งค่าหรือคู่มือ
            },
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('คู่มือ'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
