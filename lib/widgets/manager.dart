import 'package:flutter/material.dart';
import '../widgets/colors.dart';

// สร้าง class ใหม่สำหรับ Dialog
class _ManagerManagementDialog extends StatefulWidget {
  final List<Map<String, dynamic>> adminUsers;
  final List<Map<String, dynamic>> currentManagers;
  final Future<bool> Function(List<String>, String?) onSave;

  const _ManagerManagementDialog({
    required this.adminUsers,
    required this.currentManagers,
    required this.onSave,
  });

  @override
  State<_ManagerManagementDialog> createState() =>
      _ManagerManagementDialogState();
}

class _ManagerManagementDialogState extends State<_ManagerManagementDialog> {
  late List<String> _selectedManagerIds;
  late String? _primaryManagerId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedManagerIds = widget.currentManagers
        .map((m) => m['users']['user_id'] as String)
        .toList();

    final primary = widget.currentManagers.firstWhere(
      (m) => m['is_primary'] == true,
      orElse: () => {},
    );
    _primaryManagerId = primary.isNotEmpty ? primary['users']['user_id'] : null;
  }

  void _toggleManagerSelection(String userId) {
    setState(() {
      if (_selectedManagerIds.contains(userId)) {
        _selectedManagerIds.remove(userId);
        if (_primaryManagerId == userId) {
          // หาคนใหม่เป็น primary ถ้ายังมีคนอยู่
          if (_selectedManagerIds.isNotEmpty) {
            _primaryManagerId = _selectedManagerIds.first;
          } else {
            _primaryManagerId = null;
          }
        }
      } else {
        _selectedManagerIds.add(userId);
        // ถ้าเป็นคนแรก ให้เป็น primary
        if (_selectedManagerIds.length == 1) {
          _primaryManagerId = userId;
        }
      }
    });
  }

  void _setPrimaryManager(String userId) {
    setState(() {
      _primaryManagerId = userId;
    });
  }

  Future<void> _handleSave() async {
    if (_selectedManagerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกผู้ดูแลอย่างน้อย 1 คน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.onSave(_selectedManagerIds, _primaryManagerId);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกการเปลี่ยนแปลงสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_alt, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'จัดการผู้ดูแลสาขา',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'เลือกผู้ดูแลอย่างน้อย 1 คน',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // Selection Summary
            if (_selectedManagerIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.green.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'เลือกแล้ว ${_selectedManagerIds.length} คน',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Manager List
            Expanded(
              child: widget.adminUsers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'ไม่พบรายการผู้ดูแล',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ต้องมี Admin หรือ SuperAdmin\nในระบบก่อนจึงจะจัดการได้',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.adminUsers.length,
                      itemBuilder: (context, index) {
                        final user = widget.adminUsers[index];
                        final userId = user['user_id'];
                        final isSelected = _selectedManagerIds.contains(userId);
                        final isPrimary = _primaryManagerId == userId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isSelected ? 3 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: _isSaving
                                ? null
                                : () => _toggleManagerSelection(userId),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Checkbox
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: _isSaving
                                        ? null
                                        : (value) =>
                                            _toggleManagerSelection(userId),
                                    activeColor: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  // User Avatar
                                  CircleAvatar(
                                    backgroundColor: isSelected
                                        ? AppTheme.primary.withOpacity(0.1)
                                        : Colors.grey.shade200,
                                    child: Icon(
                                      Icons.person,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // User info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                user['user_name'] ??
                                                    'ไม่มีชื่อ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: isSelected
                                                      ? AppTheme.primary
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (isPrimary)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star,
                                                        size: 14,
                                                        color: Colors
                                                            .amber.shade700),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'หลัก',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .amber.shade700,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${user['role'] == 'superadmin' ? 'SuperAdmin' : 'Admin'} • ${user['user_email'] ?? 'ไม่มีอีเมล'}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Primary button
                                  if (isSelected && !isPrimary)
                                    IconButton(
                                      icon: Icon(Icons.star_border,
                                          color: Colors.grey.shade400),
                                      onPressed: _isSaving
                                          ? null
                                          : () => _setPrimaryManager(userId),
                                      tooltip: 'ตั้งเป็นผู้ดูแลหลัก',
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _isSaving ? 'กำลังบันทึก...' : 'บันทึกการเปลี่ยนแปลง',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
