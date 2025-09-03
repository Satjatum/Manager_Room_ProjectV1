import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/views/superadmin/roomdetail_ui.dart';

class EditRoomUI extends StatefulWidget {
  final Map<String, dynamic> room; // รับข้อมูลห้องจากหน้าเดิม
  const EditRoomUI({Key? key, required this.room}) : super(key: key);

  @override
  State<EditRoomUI> createState() => _EditRoomUIState();
}

class _RoomImage {
  // รองรับทั้ง bytes และ url
  final Uint8List? bytes;
  final String? url;
  const _RoomImage.bytes(this.bytes) : url = null;
  const _RoomImage.url(this.url) : bytes = null;
}

class _OptionItem {
  // ใช้กับ Category/Type/Status/Facility
  final String id; // UUID
  final String code; // *_code
  final String name; // *_name
  final String? color; // เฉพาะบางตาราง
  final String? icon;
  _OptionItem(
      {required this.id,
      required this.code,
      required this.name,
      this.color,
      this.icon});
}

class _EditRoomUIState extends State<EditRoomUI> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoadingOptions = false;
  bool _hasChanges = false;

  // Controllers
  final _roomNumberController = TextEditingController();
  final _roomNameController = TextEditingController();
  final _roomRateController = TextEditingController();
  final _roomDepositController = TextEditingController();
  final _roomSizeController = TextEditingController();
  final _roomDescriptionController = TextEditingController();

  // Master options
  List<_OptionItem> _categories = [];
  List<_OptionItem> _types = [];
  List<_OptionItem> _statuses = [];
  List<_OptionItem> _facilities = [];

  // Selected values
  String? _selectedCategoryId;
  String? _selectedTypeId;
  String? _selectedStatusId;
  final Set<String> _selectedFacilityCodes = {}; // เก็บเป็น facility_code

  // Images
  final ImagePicker _picker = ImagePicker();
  final List<_RoomImage> _images = [];

  @override
  void initState() {
    super.initState();
    // Prefill fields จากข้อมูลเดิม
    _roomNumberController.text = (widget.room['room_number'] ?? '').toString();
    _roomNameController.text = (widget.room['room_name'] ?? '').toString();
    _roomRateController.text = (widget.room['room_rate'] ?? '').toString();
    _roomDepositController.text =
        (widget.room['room_deposit'] ?? '').toString();
    _roomSizeController.text = (widget.room['room_size'] ?? '').toString();
    _roomDescriptionController.text =
        (widget.room['room_des'] ?? '').toString();

    // รองรับทั้ง id และ code เดิม
    _selectedCategoryId = widget.room['category_id']?.toString();
    _selectedTypeId = widget.room['type_id']?.toString();
    _selectedStatusId = widget.room['status_id']?.toString();

    _initFacilitiesFromRoom();
    _initImagesFromRoom();

    _loadMasterOptions();
  }

  // ---------------- Loaders ----------------
  Future<void> _loadMasterOptions() async {
    setState(() => _isLoadingOptions = true);
    try {
      // ป้องกัน null supabase: คุณต้องแน่ใจว่ามี Supabase client
      final catRows = await supabase
          .from('room_categories')
          .select(
              'category_id, category_code, category_name, category_color, category_icon, is_active, display_order')
          .eq('is_active', true)
          .order('display_order');
      final typeRows = await supabase
          .from('room_types')
          .select(
              'type_id, type_code, type_name, type_icon, default_max_occupants, is_active, display_order')
          .eq('is_active', true)
          .order('display_order');
      final statusRows = await supabase
          .from('room_status_types')
          .select(
              'status_id, status_code, status_name, status_color, status_icon, can_book, is_active, display_order')
          .eq('is_active', true)
          .order('display_order');
      final facRows = await supabase
          .from('room_facilities')
          .select(
              'facility_id, facility_code, facility_name, facility_icon, facility_category, is_active, display_order')
          .eq('is_active', true)
          .order('display_order');

      _categories = (catRows as List)
          .map((e) => _OptionItem(
                id: e['category_id'].toString(),
                code: e['category_code'].toString(),
                name: e['category_name'].toString(),
                color: e['category_color']?.toString(),
                icon: e['category_icon']?.toString(),
              ))
          .toList();
      _types = (typeRows as List)
          .map((e) => _OptionItem(
                id: e['type_id'].toString(),
                code: e['type_code'].toString(),
                name: e['type_name'].toString(),
                icon: e['type_icon']?.toString(),
              ))
          .toList();
      _statuses = (statusRows as List)
          .map((e) => _OptionItem(
                id: e['status_id'].toString(),
                code: e['status_code'].toString(),
                name: e['status_name'].toString(),
                color: e['status_color']?.toString(),
                icon: e['status_icon']?.toString(),
              ))
          .toList();
      _facilities = (facRows as List)
          .map((e) => _OptionItem(
                id: e['facility_id'].toString(),
                code: e['facility_code'].toString(),
                name: e['facility_name'].toString(),
                icon: e['facility_icon']?.toString(),
              ))
          .toList();

      // ถ้ายังไม่มี *_id ในข้อมูลเดิม ลอง mapping จาก code เดิม (room_cate, room_type, room_status)
      _selectedCategoryId ??=
          _matchIdByCode(_categories, widget.room['room_cate']?.toString());
      _selectedTypeId ??=
          _matchIdByCode(_types, widget.room['room_type']?.toString());
      _selectedStatusId ??=
          _matchIdByCode(_statuses, widget.room['room_status']?.toString());

      setState(() {});
    } catch (e) {
      // ถ้าดึง options ไม่ได้ ให้แสดงแบบข้อความแจ้งเตือนอ่อน ๆ แต่ยังใช้งานฟอร์มได้
      debugPrint('Load master options error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ไม่สามารถโหลดตัวเลือกจากฐานข้อมูลได้'),
              backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  String? _matchIdByCode(List<_OptionItem> items, String? code) {
    if (code == null) return null;
    try {
      return items.firstWhere((x) => x.code == code).id;
    } catch (_) {
      return null;
    }
  }

  void _initFacilitiesFromRoom() {
    try {
      final fac = widget.room['room_fac'];
      if (fac is List) {
        // รับได้ทั้ง facility_code หรือ facility_name
        _selectedFacilityCodes.addAll(fac.map((e) => e.toString()));
      } else if (fac is String && fac.isNotEmpty) {
        final parsed = jsonDecode(fac);
        if (parsed is List) {
          _selectedFacilityCodes.addAll(parsed.map((e) => e.toString()));
        }
      }
    } catch (_) {}
  }

  void _initImagesFromRoom() {
    final imgs = widget.room['room_images'];
    if (imgs == null) return;
    try {
      if (imgs is List) {
        for (final it in imgs) {
          _addImageFromDynamic(it);
        }
      } else if (imgs is String) {
        final parsed = _tryJsonDecode(imgs);
        if (parsed is List) {
          for (final it in parsed) {
            _addImageFromDynamic(it);
          }
        } else {
          _addImageFromDynamic(imgs);
        }
      }
      setState(() {});
    } catch (_) {}
  }

  dynamic _tryJsonDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  bool _isHttpUrl(String s) =>
      s.startsWith('http://') || s.startsWith('https://');
  String _stripDataUriPrefix(String s) =>
      s.contains(',') && s.startsWith('data:') ? s.split(',').last : s;

  void _addImageFromDynamic(dynamic it) {
    if (it == null) return;
    if (it is Uint8List) {
      _images.add(_RoomImage.bytes(it));
      return;
    }
    if (it is Map && it['url'] != null) {
      final u = it['url'].toString();
      if (_isHttpUrl(u)) _images.add(_RoomImage.url(u));
      return;
    }
    final s = it.toString();
    if (_isHttpUrl(s)) {
      _images.add(_RoomImage.url(s));
      return;
    }
    final b64 = _stripDataUriPrefix(s);
    try {
      _images.add(_RoomImage.bytes(base64Decode(b64)));
    } catch (_) {}
  }

  // ---------------- UI ----------------
  InputDecoration _decor({required String label, required IconData icon}) {
    return InputDecoration(
      prefixIcon: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      labelText: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลห้อง',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
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
              _buildImageSection(),
              const SizedBox(height: 24),
              _labeled(
                  'หมายเลขห้อง *',
                  TextFormField(
                    controller: _roomNumberController,
                    decoration: _decor(
                        label: 'หมายเลขห้อง', icon: Icons.confirmation_number),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณาใส่หมายเลขห้อง'
                        : null,
                    onChanged: (_) => _markChanged(),
                  )),
              const SizedBox(height: 16),
              _labeled(
                  'ชื่อห้อง (ถ้ามี)',
                  TextFormField(
                    controller: _roomNameController,
                    decoration: _decor(label: 'ชื่อห้อง', icon: Icons.label),
                    onChanged: (_) => _markChanged(),
                  )),
              const SizedBox(height: 16),
              _labeled(
                  'ค่าเช่า *',
                  TextFormField(
                    controller: _roomRateController,
                    decoration: _decor(
                        label: 'ค่าเช่า (บาท/เดือน)', icon: Icons.payments),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณาใส่ค่าเช่า'
                        : null,
                    onChanged: (_) => _markChanged(),
                  )),
              const SizedBox(height: 16),
              _labeled(
                  'เงินมัดจำ *',
                  TextFormField(
                    controller: _roomDepositController,
                    decoration:
                        _decor(label: 'เงินมัดจำ (บาท)', icon: Icons.savings),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณาใส่มัดจำ'
                        : null,
                    onChanged: (_) => _markChanged(),
                  )),
              const SizedBox(height: 16),
              _labeled(
                  'ขนาดห้อง (ตร.ม.)',
                  TextFormField(
                    controller: _roomSizeController,
                    decoration: _decor(
                        label: 'ขนาดห้อง (ตร.ม.)', icon: Icons.square_foot),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^[0-9]*\.?[0-9]*'))
                    ],
                    onChanged: (_) => _markChanged(),
                  )),
              const SizedBox(height: 16),
              _buildMasterDropdowns(),
              const SizedBox(height: 16),
              _buildFacilitiesSection(),
              const SizedBox(height: 16),
              _labeled(
                  'คำอธิบายเพิ่มเติม',
                  TextFormField(
                    controller: _roomDescriptionController,
                    maxLines: 4,
                    decoration: _decor(
                        label: 'รายละเอียดอื่น ๆ', icon: Icons.description),
                    onChanged: (_) => _markChanged(),
                  )),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving || !_hasChanges ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _hasChanges ? AppColors.primary : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('บันทึกการเปลี่ยนแปลง',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterDropdowns() {
    final ddStyle = (String label, IconData icon, String? value,
        List<_OptionItem> items, ValueChanged<String?> onChanged) {
      if (_isLoadingOptions) {
        return InputDecorator(
          decoration: _decor(label: label, icon: icon),
          child: const SizedBox(
              height: 20,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )),
        );
      }
      return DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        menuMaxHeight: 320,
        decoration: _decor(label: label, icon: icon),
        items: items
            .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
            .toList(),
        onChanged: onChanged,
        validator: (v) => (v == null || v.isEmpty) ? 'กรุณาเลือก$label' : null,
      );
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeled(
            'หมวดหมู่ห้อง *',
            ddStyle(
                'หมวดหมู่ห้อง', Icons.layers, _selectedCategoryId, _categories,
                (v) {
              setState(() {
                _selectedCategoryId = v;
                _markChanged();
              });
            })),
        const SizedBox(height: 16),
        _labeled(
            'ประเภทห้อง *',
            ddStyle('ประเภทห้อง', Icons.apartment, _selectedTypeId, _types,
                (v) {
              setState(() {
                _selectedTypeId = v;
                _markChanged();
              });
            })),
        const SizedBox(height: 16),
        _labeled(
            'สถานะห้อง *',
            ddStyle(
                'สถานะห้อง', Icons.info_outline, _selectedStatusId, _statuses,
                (v) {
              setState(() {
                _selectedStatusId = v;
                _markChanged();
              });
            })),
      ],
    );
  }

  Widget _buildFacilitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [
          Text('สิ่งอำนวยความสะดวก',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        if (_facilities.isEmpty && !_isLoadingOptions)
          Text('ไม่มีรายการสิ่งอำนวยความสะดวก',
              style: TextStyle(color: Colors.grey[500]))
        else if (_isLoadingOptions)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _facilities.map((f) {
              final selected = _isFacilitySelected(f);
              return FilterChip(
                label: Text(f.name, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    v ? _selectFacility(f) : _unselectFacility(f);
                    _markChanged();
                  });
                },
                selectedColor: AppColors.primary.withOpacity(0.15),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
        if (_selectedFacilityCodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('เลือกแล้ว ${_selectedFacilityCodes.length} รายการ',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  bool _isFacilitySelected(_OptionItem f) {
    // รองรับทั้งกรณีเก่าที่เก็บเป็นชื่อ และกรณีใหม่ที่เก็บเป็น code
    return _selectedFacilityCodes.contains(f.code) ||
        _selectedFacilityCodes.contains(f.name);
  }

  void _selectFacility(_OptionItem f) {
    _selectedFacilityCodes
      ..remove(f.name)
      ..add(f.code);
  }

  void _unselectFacility(_OptionItem f) {
    _selectedFacilityCodes
      ..remove(f.code)
      ..remove(f.name);
  }

  Widget _labeled(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800])),
          const SizedBox(height: 8),
          child
        ],
      );

  // ---------------- Images UI ----------------
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('รูปภาพห้อง',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            _imageButton(icon: Icons.add_a_photo, onTap: _pickImages),
          ],
        ),
        const SizedBox(height: 8),
        Text('รองรับ URL / Base64 / Data URI',
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 12),
        if (_images.isEmpty)
          Container(
            height: 110,
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.image, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text('ยังไม่มีรูปภาพ', style: TextStyle(color: Colors.grey[500]))
            ])),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImageTile(_images[i]),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: _roundIcon(
                        icon: Icons.close,
                        color: Colors.red,
                        onTap: () {
                          setState(() {
                            _images.removeAt(i);
                            _markChanged();
                          });
                        }),
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageTile(_RoomImage img) {
    const w = 140.0;
    const h = 120.0;
    if (img.bytes != null) {
      return Image.memory(
        img.bytes!,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageErrorBox(w, h),
      );
    }
    if (img.url != null && _isHttpUrl(img.url!)) {
      return Image.network(
        img.url!,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageErrorBox(w, h),
        loadingBuilder: (c, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
              width: w,
              height: h,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        },
      );
    }
    return _imageErrorBox(w, h);
  }

  Widget _imageErrorBox(double w, double h) {
    return Container(
        width: w,
        height: h,
        color: Colors.grey[200],
        child: Icon(Icons.broken_image, color: Colors.grey[500]));
  }

  Widget _imageButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]),
      child: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.add_a_photo, color: Colors.white, size: 18),
          padding: EdgeInsets.zero),
    );
  }

  Widget _roundIcon(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          width: 28,
          height: 28,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]),
          child: Icon(icon, color: Colors.white, size: 16)),
    );
  }

  // ---------------- Actions ----------------
  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    for (final f in files) {
      _images.add(_RoomImage.bytes(await f.readAsBytes()));
    }
    _markChanged();
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      // รวมรูป: bytes -> base64, URL คงเดิม
      final imageList = _images
          .map((e) {
            if (e.bytes != null) return base64Encode(e.bytes!);
            if (e.url != null) return e.url!;
            return null;
          })
          .whereType<String>()
          .toList();

      final payload = {
        'room_number': _roomNumberController.text.trim(),
        'room_name': _roomNameController.text.trim(),
        'room_rate': double.tryParse(_roomRateController.text.trim()),
        'room_deposit': double.tryParse(_roomDepositController.text.trim()),
        'room_size': _roomSizeController.text.trim().isEmpty
            ? null
            : double.tryParse(_roomSizeController.text.trim()),
        'room_des': _roomDescriptionController.text.trim().isEmpty
            ? null
            : _roomDescriptionController.text.trim(),
        // คีย์ใหม่ตาม schema
        'category_id': _selectedCategoryId,
        'type_id': _selectedTypeId,
        'status_id': _selectedStatusId,
        // คีย์เดิม (optional) เพื่อ backward compatibility
        'room_cate': _codeById(_categories, _selectedCategoryId),
        'room_type': _codeById(_types, _selectedTypeId),
        'room_status': _codeById(_statuses, _selectedStatusId),
        // facilities เก็บเป็น code array
        'room_fac': _selectedFacilityCodes.toList(),
        // images
        'room_images': imageList,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // TODO: เรียกอัปเดตจริง
      // await supabase.from('rooms').update(payload).eq('room_id', widget.room['room_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('บันทึกสำเร็จ'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _codeById(List<_OptionItem> list, String? id) {
    if (id == null) return null;
    try {
      return list.firstWhere((e) => e.id == id).code;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _roomNameController.dispose();
    _roomRateController.dispose();
    _roomDepositController.dispose();
    _roomSizeController.dispose();
    _roomDescriptionController.dispose();
    super.dispose();
  }
}
