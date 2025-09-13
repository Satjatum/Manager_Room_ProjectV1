import 'package:flutter/material.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/views/admin/admindash_ui.dart';
import 'package:manager_room_project/views/superadmin/superadmindash_ui.dart';
import 'package:manager_room_project/views/tenant/tenantdash_ui.dart';
import 'package:manager_room_project/views/user/userdash_ui.dart';
import 'package:manager_room_project/widget/appcolors.dart';
import 'package:manager_room_project/widget/hashpass.dart';
import '../model/user_model.dart';

class LoginUi extends StatefulWidget {
  const LoginUi({Key? key}) : super(key: key);

  @override
  State<LoginUi> createState() => _LoginUiState();
}

class _LoginUiState extends State<LoginUi> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  // bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
  }

  _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await AuthService.signIn(
          emailOrUsername: _emailOrUsernameController.text.trim(),
          password: _passwordController.text,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (result['success']) {
            final UserModel user = result['user'];

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('ยินดีต้อนรับ, ${user.displayName}!'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            // Navigate to appropriate dashboard
            _navigateToDashboard(user);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text(result['message'])),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  _navigateToDashboard(UserModel user) {
    Widget targetPage;

    switch (user.userRole) {
      case UserRole.superAdmin:
        targetPage = SuperadmindashUi();
        break;
      case UserRole.admin:
        targetPage = AdmindashUi();
        break;
      case UserRole.user:
        targetPage = UserdashUi();
        break;
      case UserRole.tenant:
        targetPage = TenantdashUi(); // หน้าสำหรับผู้เช่า
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildLoginForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Text(
            'ระบบจัดการห้องเช่า',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'เข้าสู่ระบบเพื่อดำเนินการต่อ',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),

          // Email or Username Field
          TextFormField(
            controller: _emailOrUsernameController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'อีเมลหรือชื่อผู้ใช้',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอก email หรือ username';
              }
              return null;
            },
          ),

          SizedBox(height: 20),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'รหัสผ่าน',
              prefixIcon: Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'กรุณากรอกรหัสผ่าน';
              }
              return null;
            },
          ),

          SizedBox(height: 20),

          // Login Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'เข้าสู่ระบบ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 20),
          const HashGeneratorCard(),
          SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ยังไม่มีบัญชี?',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              TextButton(
                onPressed: () {
                  // สามารถเพิ่มหน้าสำหรับติดต่อ admin ได้
                },
                child: Text(
                  'ติดต่อผู้ดูแลระบบ',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
