import 'package:flutter/material.dart';
import 'package:manager_room_project/views/admin/admindash_ui.dart';
import 'package:manager_room_project/views/superadmin/superadmindash_ui.dart';
import 'package:manager_room_project/views/login_ui.dart';
import 'package:manager_room_project/views/tenant/tenantdash_ui.dart';
import 'package:manager_room_project/views/user/userdash_ui.dart';
import '../services/auth_service.dart';
import '../model/user_model.dart';

class SplashUi extends StatefulWidget {
  const SplashUi({super.key});

  @override
  State<SplashUi> createState() => _SplashUiState();
}

class _SplashUiState extends State<SplashUi>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    // Start animation
    _animationController.forward();

    // Check authentication after animation starts
    _checkAuthenticationStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  _checkAuthenticationStatus() async {
    try {
      // Show splash screen for at least 3 seconds
      await Future.delayed(Duration(seconds: 3));

      if (!mounted) return;

      print('Checking authentication status...');

      // Initialize and check session
      await AuthService.initializeSession();

      // Check if user is logged in
      if (AuthService.isLoggedIn()) {
        final currentUser = AuthService.getCurrentUser();
        print('Current user found: ${currentUser?.displayName}');
        print('User role: ${currentUser?.userRole}');

        if (currentUser != null) {
          // Verify session validity with database
          final isValid = await AuthService.isSessionValid();
          print('Session valid: $isValid');

          if (isValid) {
            // Session is valid, navigate to appropriate dashboard
            print('Navigating to dashboard...');
            _navigateToDashboard(currentUser);
          } else {
            // Session is invalid, clear and go to login
            print('Session invalid, clearing and going to login');
            await AuthService.signOut();
            _navigateToLogin();
          }
        } else {
          // No current user, go to login
          print('No current user, going to login');
          _navigateToLogin();
        }
      } else {
        // Not logged in, go to login
        print('Not logged in, going to login');
        _navigateToLogin();
      }
    } catch (e) {
      print('Error checking authentication status: $e');
      // On error, clear session and go to login
      await AuthService.signOut();
      _navigateToLogin();
    }
  }

  _navigateToDashboard(UserModel user) {
    if (!mounted) return;

    Widget targetPage;
    String pageName;

    switch (user.userRole) {
      case UserRole.superAdmin:
        targetPage = SuperadmindashUi();
        pageName = 'Admin Dashboard (Super Admin)';
        break;
      case UserRole.admin:
        targetPage = AdmindashUi();
        pageName = 'Admin Dashboard';
        break;
      case UserRole.user:
        targetPage = UserdashUi();
        pageName = 'User Dashboard';
        break;
      case UserRole.tenant:
        targetPage = TenantdashUi();
        pageName = 'Tenant Dashboard';
        break;
    }

    print('Navigating to: $pageName');

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  _navigateToLogin() {
    if (!mounted) return;

    print('Navigating to Login');

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginUi(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff10B981).withOpacity(0.1),
              Colors.white,
              Color(0xff10B981).withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon/Logo
                      Container(
                        width: 100,
                        height: 100,
                        margin: EdgeInsets.only(bottom: 30),
                        decoration: BoxDecoration(
                          color: Color(0xff10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Color(0xff10B981).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.apartment,
                          size: 50,
                          color: Color(0xff10B981),
                        ),
                      ),

                      // App Title
                      Text(
                        'ระบบจัดการห้องเช่า',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.1),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 8),

                      // App Subtitle
                      Text(
                        'Room Management System',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          color: Colors.black.withOpacity(0.7),
                          letterSpacing: 1.2,
                        ),
                      ),

                      SizedBox(height: 60),

                      // Loading Indicator
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xff10B981),
                          ),
                          strokeWidth: 3,
                        ),
                      ),

                      SizedBox(height: 20),

                      // Loading Text
                      Text(
                        'กำลังตรวจสอบการเข้าสู่ระบบ...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black.withOpacity(0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      SizedBox(height: 40),

                      // Version or additional info
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.4),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
