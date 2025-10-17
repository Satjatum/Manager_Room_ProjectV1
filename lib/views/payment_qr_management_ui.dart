import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_models.dart';
import '../services/auth_service.dart';
import '../services/branch_service.dart';
import '../services/branch_payment_qr_service.dart';
import '../services/image_service.dart';

class PaymentQrManagementUi extends StatefulWidget {
  const PaymentQrManagementUi({super.key});

  @override
  State<PaymentQrManagementUi> createState() => _PaymentQrManagementUiState();
}

class _PaymentQrManagementUiState extends State<PaymentQrManagementUi> {
  UserModel? _user;
  bool _loading = true;
  String? _selectedBranchId;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _qrs = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      _user = await AuthService.getCurrentUser();
      _branches = await BranchService.getBranchesByUser();
      if (_branches.isNotEmpty) {
        _selectedBranchId = _branches.first['branch_id'];
        await _loadQrs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadQrs() async {
    if (_selectedBranchId == null) return;
    setState(() => _busy = true);
    try {
      _qrs = await BranchPaymentQrService.getByBranch(_selectedBranchId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('โหลดบัญชี/QR ล้มเหลว: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? record}) async {
    if (_selectedBranchId == null) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _QrEditorSheet(
        branchId: _selectedBranchId!,
        record: record,
      ),
    );
    if (result == true) {
      await _loadQrs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าบัญชี/QR รับชำระ'),
      ),
      floatingActionButton: _selectedBranchId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มบัญชี/QR'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('สาขา: ',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedBranchId,
                          items: _branches
                              .map((b) => DropdownMenuItem<String>(
                                    value: b['branch_id'],
                                    child: Text(
                                        '${b['branch_name']} (${b['branch_code'] ?? '-'})'),
                                  ))
                              .toList(),
                          onChanged: (v) async {
                            setState(() => _selectedBranchId = v);
                            await _loadQrs();
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _busy
                        ? const Center(child: CircularProgressIndicator())
                        : _qrs.isEmpty
                            ? const Center(
                                child: Text('ยังไม่มีบัญชี/QR ในสาขานี้'))
                            : ListView.separated(
                                itemCount: _qrs.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final q = _qrs[i];
                                  final isActive =
                                      (q['is_active'] ?? true) == true;
                                  final isPrimary =
                                      (q['is_primary'] ?? false) == true;
                                  final scheme = Theme.of(ctx).colorScheme;
                                  return Card(
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(12),
                                      leading: q['qr_code_image'] != null &&
                                              q['qr_code_image']
                                                  .toString()
                                                  .isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                q['qr_code_image'],
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : const Icon(Icons.qr_code, size: 36),
                                      title: Text(
                                          '${q['bank_name'] ?? '-'}  ${q['account_number'] ?? ''}'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(q['account_name'] ?? ''),
                                          const SizedBox(height: 4),
                                          Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                _Chip(
                                                  text: isActive
                                                      ? 'เปิดใช้งาน'
                                                      : 'ปิดใช้งาน',
                                                  color: isActive
                                                      ? scheme.primary
                                                      : scheme.onSurface,
                                                ),
                                                if (isPrimary)
                                                  _Chip(
                                                    text: 'บัญชีหลัก',
                                                    color: scheme.secondary,
                                                  ),
                                              ]),
                                        ],
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (val) async {
                                          if (val == 'edit') {
                                            _openEditor(record: q);
                                          } else if (val == 'primary') {
                                            final res =
                                                await BranchPaymentQrService
                                                    .setPrimary(
                                              qrId: q['qr_id'].toString(),
                                              branchId: _selectedBranchId!,
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(res[
                                                                'success'] ==
                                                            true
                                                        ? 'ตั้งเป็นบัญชีหลักแล้ว'
                                                        : (res['message'] ??
                                                            'ทำรายการไม่สำเร็จ'))),
                                              );
                                              await _loadQrs();
                                            }
                                          } else if (val == 'toggle') {
                                            final res =
                                                await BranchPaymentQrService
                                                    .toggleActive(
                                              q['qr_id'].toString(),
                                              !isActive,
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(res[
                                                                'success'] ==
                                                            true
                                                        ? (isActive
                                                            ? 'ปิดใช้งานแล้ว'
                                                            : 'เปิดใช้งานแล้ว')
                                                        : (res['message'] ??
                                                            'ทำรายการไม่สำเร็จ'))),
                                              );
                                              await _loadQrs();
                                            }
                                          } else if (val == 'delete') {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title:
                                                    const Text('ยืนยันการลบ'),
                                                content: const Text(
                                                    'คุณต้องการลบบัญชี/QR นี้หรือไม่?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: const Text('ยกเลิก'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: const Text('ลบ'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (ok == true) {
                                              final res =
                                                  await BranchPaymentQrService
                                                      .delete(q['qr_id']
                                                          .toString());
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(res[
                                                                  'success'] ==
                                                              true
                                                          ? 'ลบสำเร็จ'
                                                          : (res['message'] ??
                                                              'ลบไม่สำเร็จ'))),
                                                );
                                                await _loadQrs();
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('แก้ไข')),
                                          if (!isPrimary)
                                            const PopupMenuItem(
                                                value: 'primary',
                                                child:
                                                    Text('ตั้งเป็นบัญชีหลัก')),
                                          PopupMenuItem(
                                            value: 'toggle',
                                            child: Text(isActive
                                                ? 'ปิดใช้งาน'
                                                : 'เปิดใช้งาน'),
                                          ),
                                          const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('ลบ')),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _QrEditorSheet extends StatefulWidget {
  final String branchId;
  final Map<String, dynamic>? record;
  const _QrEditorSheet({required this.branchId, this.record});

  @override
  State<_QrEditorSheet> createState() => _QrEditorSheetState();
}

class _QrEditorSheetState extends State<_QrEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _bankCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();
  bool _isActive = true;
  bool _isPrimary = false;
  XFile? _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      _bankCtrl.text = (r['bank_name'] ?? '').toString();
      _accNameCtrl.text = (r['account_name'] ?? '').toString();
      _accNumCtrl.text = (r['account_number'] ?? '').toString();
      _orderCtrl.text = (r['display_order'] ?? '').toString();
      _isActive = (r['is_active'] ?? true) == true;
      _isPrimary = (r['is_primary'] ?? false) == true;
    }
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _accNameCtrl.dispose();
    _accNumCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null) setState(() => _image = img);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? imageUrl = widget.record?['qr_code_image'];
      if (_image != null) {
        Map<String, dynamic> upload;
        if (kIsWeb) {
          final bytes = await _image!.readAsBytes();
          upload = await ImageService.uploadImageFromBytes(
            bytes,
            _image!.name,
            'branch-payment-qr',
            folder: widget.branchId,
            prefix: 'qr',
            context: 'branch_${widget.branchId}',
          );
        } else {
          upload = await ImageService.uploadImage(
            File(_image!.path),
            'branch-payment-qr',
            folder: widget.branchId,
            prefix: 'qr',
            context: 'branch_${widget.branchId}',
          );
        }

        if (upload['success'] != true) {
          throw upload['message'] ?? 'อัปโหลดรูป QR ไม่สำเร็จ';
        }
        imageUrl = upload['url'];
      }

      final payload = {
        'branch_id': widget.branchId,
        'bank_name': _bankCtrl.text.trim(),
        'account_name': _accNameCtrl.text.trim(),
        'account_number': _accNumCtrl.text.trim(),
        'qr_code_image': imageUrl,
        'is_active': _isActive,
        'is_primary': _isPrimary,
        'display_order': int.tryParse(_orderCtrl.text.trim()),
      };

      Map<String, dynamic> res;
      if (widget.record == null) {
        res = await BranchPaymentQrService.create(payload);
      } else {
        res = await BranchPaymentQrService.update(
          widget.record!['qr_id'].toString(),
          payload,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['success'] == true
                ? 'บันทึกสำเร็จ'
                : (res['message'] ?? 'บันทึกไม่สำเร็จ'))),
      );
      if (res['success'] == true) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.record == null ? 'เพิ่มบัญชี/QR' : 'แก้ไขบัญชี/QR',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ธนาคาร',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'กรอกธนาคาร' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อบัญชี',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'กรอกชื่อบัญชี' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accNumCtrl,
                  decoration: const InputDecoration(
                    labelText: 'เลขบัญชี',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'กรอกเลขบัญชี' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _orderCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ลำดับแสดง',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              value: _isActive,
                              onChanged: (v) =>
                                  setState(() => _isActive = v ?? true),
                              title: const Text('เปิดใช้งาน'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: _isPrimary,
                  onChanged: (v) => setState(() => _isPrimary = v ?? false),
                  title: const Text('ตั้งเป็นบัญชีหลักของสาขานี้'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: Text(_image == null
                          ? (widget.record?['qr_code_image'] != null
                              ? 'เปลี่ยนรูป QR'
                              : 'เลือกรูป QR')
                          : 'เปลี่ยนรูป QR'),
                    ),
                    const SizedBox(width: 8),
                    if (widget.record?['qr_code_image'] != null)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              widget.record!['qr_code_image'],
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('บันทึก'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
