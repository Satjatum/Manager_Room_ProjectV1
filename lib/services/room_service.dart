import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

class RoomService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all rooms with pagination and filtering
  static Future<List<Map<String, dynamic>>> getAllRooms({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    String? branchId,
    bool? isActive,
    String? roomStatus,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      // Build query with joins
      var query = _supabase.from('rooms').select('''
        *,
        branches!inner(branch_id, branch_name, branch_code),
        room_types(roomtype_id, roomtype_name),
        room_categories(roomcate_id, roomcate_name)
      ''');

      // Add filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('room_number.ilike.%$searchQuery%');
      }

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId);
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (roomStatus != null && roomStatus.isNotEmpty) {
        query = query.eq('room_status', roomStatus);
      }

      // Add ordering and pagination
      final result = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      // Format the response
      return List<Map<String, dynamic>>.from(result).map((room) {
        return {
          ...room,
          'branch_name': room['branches']?['branch_name'],
          'branch_code': room['branches']?['branch_code'],
          'room_type_name': room['room_types']?['roomtype_name'],
          'room_category_name': room['room_categories']?['roomcate_name'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลห้องพัก: $e');
    }
  }

  /// Get rooms by user role and permissions
  static Future<List<Map<String, dynamic>>> getRoomsByUser({
    String? branchId,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();

      // Allow anonymous access - return active rooms only
      if (currentUser == null) {
        return await getActiveRooms(branchId: branchId);
      }

      // If user has manage rooms permission, return all rooms
      if (currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageRooms,
      ])) {
        return getAllRooms(branchId: branchId, isActive: true);
      }

      // For other users, return rooms they have access to
      var query = _supabase.from('rooms').select('''
        *,
        branches!inner(branch_id, branch_name, branch_code),
        room_types(roomtype_id, roomtype_name),
        room_categories(roomcate_id, roomcate_name)
      ''').eq('is_active', true);

      // If user is assigned to specific branch, filter by that
      if (currentUser.branchId != null) {
        query = query.eq('branch_id', currentUser.branchId!);
      }

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId);
      }

      final result = await query.order('room_number');

      return List<Map<String, dynamic>>.from(result).map((room) {
        return {
          ...room,
          'branch_name': room['branches']?['branch_name'],
          'branch_code': room['branches']?['branch_code'],
          'room_type_name': room['room_types']?['roomtype_name'],
          'room_category_name': room['room_categories']?['roomcate_name'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลห้องพัก: $e');
    }
  }

  /// Get room by ID
  static Future<Map<String, dynamic>?> getRoomById(String roomId) async {
    try {
      final result = await _supabase.from('rooms').select('''
        *,
        branches!inner(branch_id, branch_name, branch_code, branch_address),
        room_types(roomtype_id, roomtype_name, roomtype_desc),
        room_categories(roomcate_id, roomcate_name, roomcate_desc)
      ''').eq('room_id', roomId).maybeSingle();

      if (result == null) return null;

      // Format the response
      return {
        ...result,
        'branch_name': result['branches']?['branch_name'],
        'branch_code': result['branches']?['branch_code'],
        'branch_address': result['branches']?['branch_address'],
        'room_type_name': result['room_types']?['roomtype_name'],
        'room_type_desc': result['room_types']?['roomtype_desc'],
        'room_category_name': result['room_categories']?['roomcate_name'],
        'room_category_desc': result['room_categories']?['roomcate_desc'],
      };
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลห้องพัก: $e');
    }
  }

  /// Create new room
  static Future<Map<String, dynamic>> createRoom(
      Map<String, dynamic> roomData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Check permissions: allow superadmin/manageRooms OR admin who manages selected branch
      bool allowed = currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageRooms,
      ]);

      // If not globally allowed, check admin branch manager for the target branch
      if (!allowed && currentUser.userRole == UserRole.admin) {
        final String? branchId = roomData['branch_id']?.toString();
        if (branchId != null && branchId.isNotEmpty) {
          allowed = await isUserManagerOfBranch(currentUser.userId, branchId);
        }
      }

      if (!allowed) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการสร้างห้องพักใหม่',
        };
      }

      // Validate required fields
      if (roomData['branch_id'] == null ||
          roomData['branch_id'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณาเลือกสาขา',
        };
      }

      if (roomData['room_number'] == null ||
          roomData['room_number'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกหมายเลขห้อง',
        };
      }

      if (roomData['room_price'] == null) {
        return {
          'success': false,
          'message': 'กรุณากรอกราคาเช่า',
        };
      }

      if (roomData['room_deposit'] == null) {
        return {
          'success': false,
          'message': 'กรุณากรอกค่าประกัน',
        };
      }

      // Check for duplicate room number in same branch
      final existingRoom = await _supabase
          .from('rooms')
          .select('room_id')
          .eq('branch_id', roomData['branch_id'])
          .eq('room_number', roomData['room_number'].toString().trim())
          .maybeSingle();

      if (existingRoom != null) {
        return {
          'success': false,
          'message': 'หมายเลขห้องนี้มีอยู่แล้วในสาขานี้',
        };
      }

      // Prepare data for insertion
      final insertData = {
        'branch_id': roomData['branch_id'],
        'room_number': roomData['room_number'].toString().trim(),
        'room_type_id': roomData['room_type_id'],
        'room_category_id': roomData['room_category_id'],
        'room_size': roomData['room_size'],
        'room_price': roomData['room_price'],
        'room_deposit': roomData['room_deposit'],
        'room_status': roomData['room_status'] ?? 'available',
        'room_desc': roomData['room_desc'],
        'is_active': roomData['is_active'] ?? true,
        'created_by': currentUser.userId,
      };

      final result =
          await _supabase.from('rooms').insert(insertData).select().single();

      return {
        'success': true,
        'message': 'สร้างห้องพักสำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        message = 'หมายเลขห้องนี้มีอยู่แล้วในสาขานี้';
      } else if (e.code == '23503') {
        if (e.message.contains('branch_id')) {
          message = 'ไม่พบสาขาที่ระบุ';
        } else if (e.message.contains('room_type_id')) {
          message = 'ไม่พบประเภทห้องที่ระบุ';
        } else if (e.message.contains('room_category_id')) {
          message = 'ไม่พบหมวดหมู่ห้องที่ระบุ';
        }
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการสร้างห้องพัก: $e',
      };
    }
  }

  /// Update room
  static Future<Map<String, dynamic>> updateRoom(
    String roomId,
    Map<String, dynamic> roomData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Check permissions
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageRooms,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขห้องพัก',
        };
      }

      // Validate required fields
      if (roomData['room_number'] == null ||
          roomData['room_number'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกหมายเลขห้อง',
        };
      }

      // Check for duplicate room number in same branch (exclude current room)
      if (roomData['branch_id'] != null) {
        final existingRoom = await _supabase
            .from('rooms')
            .select('room_id')
            .eq('branch_id', roomData['branch_id'])
            .eq('room_number', roomData['room_number'].toString().trim())
            .neq('room_id', roomId)
            .maybeSingle();

        if (existingRoom != null) {
          return {
            'success': false,
            'message': 'หมายเลขห้องนี้มีอยู่แล้วในสาขานี้',
          };
        }
      }

      // Prepare data for update
      final updateData = {
        'room_number': roomData['room_number'].toString().trim(),
        'room_type_id': roomData['room_type_id'],
        'room_category_id': roomData['room_category_id'],
        'room_size': roomData['room_size'],
        'room_price': roomData['room_price'],
        'room_deposit': roomData['room_deposit'],
        'room_status': roomData['room_status'],
        'room_desc': roomData['room_desc'],
        'is_active': roomData['is_active'],
      };

      // Remove null values
      updateData.removeWhere((key, value) => value == null);

      final result = await _supabase
          .from('rooms')
          .update(updateData)
          .eq('room_id', roomId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'อัปเดตห้องพักสำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        message = 'หมายเลขห้องนี้มีอยู่แล้วในสาขานี้';
      } else if (e.code == 'PGRST116') {
        message = 'ไม่พบห้องพักที่ต้องการแก้ไข';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตห้องพัก: $e',
      };
    }
  }

  /// Toggle room status (active/inactive)
  static Future<Map<String, dynamic>> toggleRoomStatus(String roomId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      if (roomId.isEmpty) {
        return {
          'success': false,
          'message': 'ไม่พบรหัสห้องพัก',
        };
      }

      // Check permissions
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageRooms,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการเปลี่ยนสถานะห้องพัก',
        };
      }

      // Get current status
      final existingRoom = await _supabase
          .from('rooms')
          .select('room_id, room_number, is_active')
          .eq('room_id', roomId)
          .maybeSingle();

      if (existingRoom == null) {
        return {
          'success': false,
          'message': 'ไม่พบห้องพักที่ต้องการ',
        };
      }

      final currentStatus = existingRoom['is_active'] ?? false;
      final newStatus = !currentStatus;

      // Update status
      final result = await _supabase
          .from('rooms')
          .update({
            'is_active': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId)
          .select()
          .single();

      return {
        'success': true,
        'message': newStatus
            ? 'เปิดใช้งานห้อง "${existingRoom['room_number']}" สำเร็จ'
            : 'ปิดใช้งานห้อง "${existingRoom['room_number']}" สำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        message = 'ไม่พบห้องพักที่ต้องการ';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเปลี่ยนสถานะห้องพัก: $e',
      };
    }
  }

  /// Delete room permanently (SuperAdmin only)
  static Future<Map<String, dynamic>> deleteRoom(String roomId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      if (roomId.isEmpty) {
        return {
          'success': false,
          'message': 'ไม่พบรหัสห้องพัก',
        };
      }

      // Only superadmin can delete permanently
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการลบห้องพักถาวร',
        };
      }

      // Check if room exists
      final existingRoom = await _supabase
          .from('rooms')
          .select('room_id, room_number')
          .eq('room_id', roomId)
          .maybeSingle();

      if (existingRoom == null) {
        return {
          'success': false,
          'message': 'ไม่พบห้องพักที่ต้องการลบ',
        };
      }

      // Check for active contracts
      final activeContracts = await _supabase
          .from('rental_contracts')
          .select('contract_id')
          .eq('room_id', roomId)
          .inFilter('contract_status', ['active', 'pending']);

      if (activeContracts.isNotEmpty) {
        return {
          'success': false,
          'message':
              'ไม่สามารถลบห้องพักได้ เนื่องจากยังมีสัญญาเช่าที่ใช้งานอยู่ ${activeContracts.length} สัญญา',
        };
      }

      // Delete permanently
      await _supabase.from('rooms').delete().eq('room_id', roomId);

      return {
        'success': true,
        'message': 'ลบห้อง "${existingRoom['room_number']}" ถาวรสำเร็จ',
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        message = 'ไม่พบห้องพักที่ต้องการลบ';
      } else if (e.code == '23503') {
        message = 'ไม่สามารถลบห้องพักได้ เนื่องจากยังมีข้อมูลที่เกี่ยวข้อง';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบห้องพัก: $e',
      };
    }
  }

  /// Get active rooms for public access
  static Future<List<Map<String, dynamic>>> getActiveRooms({
    String? branchId,
  }) async {
    try {
      var query = _supabase.from('rooms').select('''
        *,
        branches!inner(branch_id, branch_name, branch_code),
        room_types(roomtype_id, roomtype_name),
        room_categories(roomcate_id, roomcate_name)
      ''').eq('is_active', true).eq('room_status', 'available');

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId);
      }

      final result = await query.order('room_number');

      return List<Map<String, dynamic>>.from(result).map((room) {
        return {
          ...room,
          'branch_name': room['branches']?['branch_name'],
          'branch_code': room['branches']?['branch_code'],
          'room_type_name': room['room_types']?['roomtype_name'],
          'room_category_name': room['room_categories']?['roomcate_name'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลห้องพัก: $e');
    }
  }

  /// Get branches for room filter
  static Future<List<Map<String, dynamic>>> getBranchesForRoomFilter() async {
    try {
      final currentUser = await AuthService.getCurrentUser();

      var query = _supabase
          .from('branches')
          .select('branch_id, branch_name, branch_code')
          .eq('is_active', true);

      // If user has specific branch, show only that branch
      if (currentUser != null && currentUser.branchId != null) {
        query = query.eq('branch_id', currentUser.branchId!);
      }

      final result = await query.order('branch_name');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
    }
  }

  /// Check if a user is a manager of the given branch
  static Future<bool> isUserManagerOfBranch(
      String userId, String branchId) async {
    try {
      final row = await _supabase
          .from('branch_managers')
          .select('id')
          .eq('user_id', userId)
          .eq('branch_id', branchId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      return false;
    }
  }

  /// Get room types
  static Future<List<Map<String, dynamic>>> getRoomTypes() async {
    try {
      final result =
          await _supabase.from('room_types').select('*').order('roomtype_name');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดประเภทห้อง: $e');
    }
  }

  /// Get room categories
  static Future<List<Map<String, dynamic>>> getRoomCategories() async {
    try {
      final result = await _supabase
          .from('room_categories')
          .select('*')
          .order('roomcate_name');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดหมวดหมู่ห้อง: $e');
    }
  }

  /// Get amenities
  static Future<List<Map<String, dynamic>>> getAmenities() async {
    try {
      final result =
          await _supabase.from('amenities').select('*').order('amenities_name');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสิ่งอำนวยความสะดวก: $e');
    }
  }

  /// Get room amenities
  static Future<List<Map<String, dynamic>>> getRoomAmenities(
      String roomId) async {
    try {
      final result = await _supabase.from('room_amenities').select('''
        *,
        amenities!inner(amenities_id, amenities_name, amenities_icon, amenities_desc)
      ''').eq('room_id', roomId);

      return List<Map<String, dynamic>>.from(result).map((item) {
        return {
          'amenities_id': item['amenities']?['amenities_id'],
          'amenities_name': item['amenities']?['amenities_name'],
          'amenities_icon': item['amenities']?['amenities_icon'],
          'amenities_desc': item['amenities']?['amenities_desc'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสิ่งอำนวยความสะดวก: $e');
    }
  }

  /// Get room images
  static Future<List<Map<String, dynamic>>> getRoomImages(String roomId) async {
    try {
      final result = await _supabase
          .from('room_images')
          .select('*')
          .eq('room_id', roomId)
          .order('display_order');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดรูปภาพห้อง: $e');
    }
  }

  /// Search rooms
  static Future<List<Map<String, dynamic>>> searchRooms(
      String searchQuery) async {
    try {
      if (searchQuery.trim().isEmpty) {
        return [];
      }

      final result = await _supabase
          .from('rooms')
          .select('''
        *,
        branches!inner(branch_id, branch_name),
        room_types(roomtype_name),
        room_categories(roomcate_name)
      ''')
          .or('room_number.ilike.%$searchQuery%')
          .eq('is_active', true)
          .order('room_number')
          .limit(20);

      return List<Map<String, dynamic>>.from(result).map((room) {
        return {
          ...room,
          'branch_name': room['branches']?['branch_name'],
          'room_type_name': room['room_types']?['roomtype_name'],
          'room_category_name': room['room_categories']?['roomcate_name'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการค้นหาห้องพัก: $e');
    }
  }

  /// Get room statistics
  /// Get room statistics
  static Future<Map<String, dynamic>> getRoomStatistics(String roomId) async {
    try {
      final room = await getRoomById(roomId);
      if (room == null) {
        return {};
      }

      final contractHistory = await _supabase
          .from('rental_contracts')
          .select('contract_id')
          .eq('room_id', roomId);

      final activeContract = await _supabase
          .from('rental_contracts')
          .select('*, tenants!inner(*)')
          .eq('room_id', roomId)
          .eq('contract_status', 'active')
          .maybeSingle();

      final pendingIssues = await _supabase
          .from('issue_reports')
          .select('issue_id')
          .eq('room_id', roomId)
          .inFilter('issue_status', ['pending', 'in_progress']);

      return {
        'room_status': room['room_status'],
        'contract_count': contractHistory.length,
        'active_contract': activeContract,
        'pending_issues_count': pendingIssues.length,
        'current_tenant': activeContract != null
            ? activeContract['tenants']
            : ['tenant_fullname']
      };
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสถิติห้องพัก: $e');
    }
  }

  // ============================================
  // ROOM TYPES CRUD
  // ============================================

  /// Create room type
  static Future<Map<String, dynamic>> createRoomType(
      Map<String, dynamic> data) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการสร้างประเภทห้อง'};
      }

      final result =
          await _supabase.from('room_types').insert(data).select().single();

      return {
        'success': true,
        'message': 'เพิ่มประเภทห้องสำเร็จ',
        'data': result,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเพิ่มประเภทห้อง: $e',
      };
    }
  }

  /// Update room type
  static Future<Map<String, dynamic>> updateRoomType(
      String id, Map<String, dynamic> data) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการแก้ไขประเภทห้อง'};
      }

      final result = await _supabase
          .from('room_types')
          .update(data)
          .eq('roomtype_id', id)
          .select()
          .single();

      return {
        'success': true,
        'message': 'แก้ไขประเภทห้องสำเร็จ',
        'data': result,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการแก้ไขประเภทห้อง: $e',
      };
    }
  }

  /// Delete room type
  static Future<Map<String, dynamic>> deleteRoomType(String id) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการลบประเภทห้อง'};
      }

      // Check if any rooms use this type
      final roomsUsingType = await _supabase
          .from('rooms')
          .select('room_id')
          .eq('room_type_id', id)
          .limit(1);

      if (roomsUsingType.isNotEmpty) {
        return {
          'success': false,
          'message': 'ไม่สามารถลบได้ เนื่องจากมีห้องที่ใช้ประเภทนี้อยู่',
        };
      }

      await _supabase.from('room_types').delete().eq('roomtype_id', id);

      return {
        'success': true,
        'message': 'ลบประเภทห้องสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบประเภทห้อง: $e',
      };
    }
  }

  // ============================================
  // ROOM CATEGORIES CRUD
  // ============================================

  /// Create room category
  static Future<Map<String, dynamic>> createRoomCategory(
      Map<String, dynamic> data) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการสร้างหมวดหมู่ห้อง'
        };
      }

      final result = await _supabase
          .from('room_categories')
          .insert(data)
          .select()
          .single();

      return {
        'success': true,
        'message': 'เพิ่มหมวดหมู่ห้องสำเร็จ',
        'data': result,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเพิ่มหมวดหมู่ห้อง: $e',
      };
    }
  }

  /// Update room category
  static Future<Map<String, dynamic>> updateRoomCategory(
      String id, Map<String, dynamic> data) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขหมวดหมู่ห้อง'
        };
      }

      final result = await _supabase
          .from('room_categories')
          .update(data)
          .eq('roomcate_id', id)
          .select()
          .single();

      return {
        'success': true,
        'message': 'แก้ไขหมวดหมู่ห้องสำเร็จ',
        'data': result,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการแก้ไขหมวดหมู่ห้อง: $e',
      };
    }
  }

  /// Delete room category
  static Future<Map<String, dynamic>> deleteRoomCategory(String id) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการลบหมวดหมู่ห้อง'};
      }

      // Check if any rooms use this category
      final roomsUsingCategory = await _supabase
          .from('rooms')
          .select('room_id')
          .eq('room_category_id', id)
          .limit(1);

      if (roomsUsingCategory.isNotEmpty) {
        return {
          'success': false,
          'message': 'ไม่สามารถลบได้ เนื่องจากมีห้องที่ใช้หมวดหมู่นี้อยู่',
        };
      }

      await _supabase.from('room_categories').delete().eq('roomcate_id', id);

      return {
        'success': true,
        'message': 'ลบหมวดหมู่ห้องสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบหมวดหมู่ห้อง: $e',
      };
    }
  }

  // ============================================
  // AMENITIES CRUD
  // ============================================

  /// Create amenity
  static Future<Map<String, dynamic>> createAmenity(
      Map<String, dynamic> data) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการสร้างสิ่งอำนวยความสะดวก'
        };
      }

      final result =
          await _supabase.from('amenities').insert(data).select().single();

      return {
        'success': true,
        'message': 'เพิ่มสิ่งอำนวยความสะดวกสำเร็จ',
        'data': result,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเพิ่มสิ่งอำนวยความสะดวก: $e',
      };
    }
  }

  /// Update amenity
  static Future<Map<String, dynamic>> updateAmenity(
      String id, Map<String, dynamic> data) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขสิ่งอำนวยความสะดวก'
        };
      }

      final result = await _supabase
          .from('amenities')
          .update(data)
          .eq('amenities_id', id)
          .select()
          .single();

      return {
        'success': true,
        'message': 'แก้ไขสิ่งอำนวยความสะดวกสำเร็จ',
        'data': result,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการแก้ไขสิ่งอำนวยความสะดวก: $e',
      };
    }
  }

  /// Delete amenity
  static Future<Map<String, dynamic>> deleteAmenity(String id) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการลบสิ่งอำนวยความสะดวก'
        };
      }

      // Check if any rooms use this amenity
      final roomsUsingAmenity = await _supabase
          .from('room_amenities')
          .select('room_id')
          .eq('amenity_id', id)
          .limit(1);

      if (roomsUsingAmenity.isNotEmpty) {
        return {
          'success': false,
          'message':
              'ไม่สามารถลบได้ เนื่องจากมีห้องที่ใช้สิ่งอำนวยความสะดวกนี้อยู่',
        };
      }

      await _supabase.from('amenities').delete().eq('amenities_id', id);

      return {
        'success': true,
        'message': 'ลบสิ่งอำนวยความสะดวกสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบสิ่งอำนวยความสะดวก: $e',
      };
    }
  }
}
