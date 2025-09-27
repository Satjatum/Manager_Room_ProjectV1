import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../middleware/auth_middleware.dart';
import '../models/user_models.dart';
import 'login_ui.dart';
import 'superadmin/superadmindash_ui.dart';

class SplashUi extends StatefulWidget {
  const SplashUi({Key? key}) : super(key: key);

  @override
  State<SplashUi> createState() => _SplashUiState();
}

class _SplashUiState extends State<SplashUi> with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _progressAnimationController;
  late AnimationController _textAnimationController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  String _statusMessage = 'กำลังเริ่มต้นระบบ...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Logo animations
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _logoRotationAnimation = Tween<double>(
      begin: -0.2,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    ));

    // Progress animation
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    // Text animations
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeIn,
    ));

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeOut,
    ));

    // Start logo animation
    _logoAnimationController.forward();
    _textAnimationController.forward();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _progressAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Show splash for minimum 2 seconds
      await Future.delayed(const Duration(seconds: 1));
      await _updateProgress(0.1, 'เชื่อมต่อฐานข้อมูล...');

      // Initialize AuthService
      await AuthService.initializeSession();
      await _updateProgress(0.3, 'ตรวจสอบการเข้าสู่ระบบ...');

      // Clean expired sessions
      await AuthService.cleanExpiredSessions();
      await _updateProgress(0.4, 'ทำความสะอาดเซสชันเก่า...');

      // Check authentication
      final isAuthenticated = await AuthMiddleware.isAuthenticated();
      await _updateProgress(0.6, 'กำลังตรวจสอบสิทธิ์...');

      if (isAuthenticated) {
        final currentUser = await AuthMiddleware.getCurrentUser();

        if (currentUser != null && currentUser.isActive) {
          await _updateProgress(0.8, 'พบผู้ใช้: ${currentUser.displayName}');

          // Validate session
          final isValid = await AuthService.validateSession();
          await _updateProgress(0.9, 'ตรวจสอบ session...');

          if (isValid) {
            await _updateProgress(1.0, 'เข้าสู่ระบบสำเร็จ');

            // Show welcome message with last login info
            await _updateProgress(
                1.0,
                'ยินดีต้อนรับ ${currentUser.displayName}!\n'
                'เข้าสู่ระบบล่าสุด: ${currentUser.lastLoginDisplay}');

            await Future.delayed(const Duration(milliseconds: 800));

            if (mounted) {
              _navigateToDashboard(currentUser);
            }
          } else {
            await _updateProgress(0.8, 'Session หมดอายุ');
            await AuthService.signOut();
            await Future.delayed(const Duration(milliseconds: 800));

            if (mounted) {
              _navigateToLogin();
            }
          }
        } else {
          await _updateProgress(0.6, 'ข้อมูลผู้ใช้ไม่ถูกต้อง');
          await AuthService.signOut();
          await Future.delayed(const Duration(milliseconds: 800));

          if (mounted) {
            _navigateToLogin();
          }
        }
      } else {
        await _updateProgress(0.5, 'ไม่พบการเข้าสู่ระบบ');
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          _navigateToLogin();
        }
      }
    } catch (e) {
      print('Error during initialization: $e');

      if (mounted) {
        await _updateProgress(0.0, 'เกิดข้อผิดพลาด กำลังรีเซ็ต...');
        await AuthService.clearUserSession();
        await Future.delayed(const Duration(seconds: 1));
        _navigateToLogin();
      }
    }
  }

  Future<void> _updateProgress(double progress, String message) async {
    if (mounted) {
      setState(() {
        _progress = progress;
        _statusMessage = message;
      });

      _progressAnimationController.reset();
      _progressAnimationController.forward();

      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  void _navigateToDashboard(UserModel user) {
    if (!mounted) return;

    // Navigate to appropriate dashboard based on role and permissions
    Widget targetPage =
        const SuperadmindashUi(); // Default dashboard for all roles now

    // Wrap with AuthWrapper to ensure proper access control
    targetPage = AuthWrapper(
      requiredPermissions: [DetailedPermission.viewOwnData],
      child: targetPage,
      fallback: const LoginUi(),
    );

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _navigateToLogin() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginUi(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xff10B981).withOpacity(0.05),
              Colors.white,
              const Color(0xff10B981).withOpacity(0.08),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 64 : 32,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWeb ? 500 : double.infinity,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo with advanced animations
                    AnimatedBuilder(
                      animation: _logoAnimationController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _logoOpacityAnimation,
                          child: Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Transform.rotate(
                              angle: _logoRotationAnimation.value,
                              child: Container(
                                width: isTablet ? 140 : 120,
                                height: isTablet ? 140 : 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xff10B981),
                                      const Color(0xff059669),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xff10B981)
                                          .withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.8),
                                      blurRadius: 20,
                                      offset: const Offset(0, -5),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.apartment_rounded,
                                  size: isTablet ? 70 : 60,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: isTablet ? 50 : 40),

                    // App Title with slide animation
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: FadeTransition(
                        opacity: _textFadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              'ระบบจัดการห้องเช่า',
                              style: TextStyle(
                                fontSize: isTablet ? 36 : 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isTablet ? 12 : 8),
                            Text(
                              'Room Management System',
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.w300,
                                color: Colors.black.withOpacity(0.7),
                                letterSpacing: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: isTablet ? 80 : 60),

                    // Progress Section
                    Container(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: Column(
                        children: [
                          // Custom Progress Bar
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, child) {
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor:
                                      _progress * _progressAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xff10B981),
                                          Color(0xff059669),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xff10B981)
                                              .withOpacity(0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Status Text with animation
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.2),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _statusMessage,
                              key: ValueKey(_statusMessage),
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 15,
                                color: Colors.black.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Progress Percentage
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xff10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 60 : 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
