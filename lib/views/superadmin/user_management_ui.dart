import 'package:flutter/material.dart';
import '../../models/user_models.dart';
import '../../services/user_service.dart';

class UserManagementUi extends StatefulWidget {
  const UserManagementUi({Key? key}) : super(key: key);

  @override
  State<UserManagementUi> createState() => _UserManagementUiState();
}

class _UserManagementUiState extends State<UserManagementUi> {
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  String? roleFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await UserService.getAllUsers(
        searchQuery: searchQuery.isEmpty ? null : searchQuery,
        roleFilter: roleFilter,
      );

      if (mounted) {
        setState(() {
          users = result;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddUserDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddUserDialog(),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _deactivateUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการปิดใช้งาน'),
        content: Text('คุณต้องการปิดใช้งานผู้ใช้ "$userName" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ปิดใช้งาน'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await UserService.deactivateUser(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );

        if (result['success']) {
          _loadUsers();
        }
      }
    }
  }

  // Helper method to parse role from string
  UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'user':
        return UserRole.user;
      case 'tenant':
        return UserRole.tenant;
      default:
        return UserRole.user;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการผู้ใช้งาน'),
        backgroundColor: const Color(0xff10B981),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อผู้ใช้หรืออีเมล',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => searchQuery = value);
                    _loadUsers();
                  },
                ),
                const SizedBox(height: 12),
                // Role Filter
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'กรองตามบทบาท',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        value: roleFilter,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                          DropdownMenuItem(
                              value: 'superadmin',
                              child: Text('ผู้ดูแลระบบหลัก')),
                          DropdownMenuItem(
                              value: 'admin', child: Text('ผู้ดูแลระบบ')),
                          DropdownMenuItem(
                              value: 'user', child: Text('ผู้ใช้งาน')),
                          DropdownMenuItem(
                              value: 'tenant', child: Text('ผู้เช่า')),
                        ],
                        onChanged: (value) {
                          setState(() => roleFilter = value);
                          _loadUsers();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadUsers,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(errorMessage!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadUsers,
                              child: const Text('ลองใหม่'),
                            ),
                          ],
                        ),
                      )
                    : users.isEmpty
                        ? const Center(child: Text('ไม่พบข้อมูลผู้ใช้'))
                        : ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return _buildUserCard(user);
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('เพิ่มผู้ใช้'),
        backgroundColor: const Color(0xff10B981),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = _parseRole(user['role']);
    final roleDisplay = _getRoleDisplay(role);
    final isActive = user['is_active'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? const Color(0xff10B981) : Colors.grey,
          child: Text(
            user['user_name'].toString().substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          user['user_name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['user_email']),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(role).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roleDisplay,
                style: TextStyle(
                  fontSize: 12,
                  color: _getRoleColor(role),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditUserDialog(user);
            } else if (value == 'deactivate') {
              _deactivateUser(user['user_id'], user['user_name']);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('แก้ไข'),
                ],
              ),
            ),
            if (isActive)
              const PopupMenuItem(
                value: 'deactivate',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ปิดใช้งาน', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplay(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'ผู้ดูแลระบบหลัก';
      case UserRole.admin:
        return 'ผู้ดูแลระบบ';
      case UserRole.user:
        return 'ผู้ใช้งาน';
      case UserRole.tenant:
        return 'ผู้เช่า';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.admin:
        return Colors.blue;
      case UserRole.user:
        return Colors.green;
      case UserRole.tenant:
        return Colors.orange;
    }
  }
}

// Add User Dialog
class AddUserDialog extends StatefulWidget {
  const AddUserDialog({Key? key}) : super(key: key);

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'user';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await UserService.createUser({
      'user_name': _userNameController.text.trim(),
      'user_email': _emailController.text.trim(),
      'user_pass': _passwordController.text,
      'role': _selectedRole,
    });

    if (mounted) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มผู้ใช้ใหม่'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _userNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อผู้ใช้',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อผู้ใช้';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'อีเมล',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกอีเมล';
                  }
                  if (!value.contains('@')) {
                    return 'รูปแบบอีเมลไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกรหัสผ่าน';
                  }
                  if (value.length < 6) {
                    return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'บทบาท',
                  prefixIcon: Icon(Icons.shield),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('ผู้ดูแลระบบ')),
                  DropdownMenuItem(value: 'user', child: Text('ผู้ใช้งาน')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff10B981),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('เพิ่มผู้ใช้'),
        ),
      ],
    );
  }
}

// Edit User Dialog
class EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditUserDialog({Key? key, required this.user}) : super(key: key);

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _userNameController;
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  late String _selectedRole;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: widget.user['user_name']);
    _emailController = TextEditingController(text: widget.user['user_email']);
    _selectedRole = widget.user['role'];
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final updateData = {
      'user_name': _userNameController.text.trim(),
      'user_email': _emailController.text.trim(),
      'role': _selectedRole,
    };

    if (_passwordController.text.isNotEmpty) {
      updateData['user_pass'] = _passwordController.text;
    }

    final result =
        await UserService.updateUser(widget.user['user_id'], updateData);

    if (mounted) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('แก้ไขข้อมูลผู้ใช้'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _userNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อผู้ใช้',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อผู้ใช้';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'อีเมล',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกอีเมล';
                  }
                  if (!value.contains('@')) {
                    return 'รูปแบบอีเมลไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านใหม่ (ไม่บังคับ)',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  helperText: 'เว้นว่างไว้หากไม่ต้องการเปลี่ยน',
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'บทบาท',
                  prefixIcon: Icon(Icons.shield),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('ผู้ดูแลระบบ')),
                  DropdownMenuItem(value: 'user', child: Text('ผู้ใช้งาน')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff10B981),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('บันทึก'),
        ),
      ],
    );
  }
}
