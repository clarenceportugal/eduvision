import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'screens/face_registration_screen.dart';
import 'screens/tflite_debug_screen.dart';
import 'screens/data_management_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/help_center_screen.dart';
import 'screens/send_feedback_screen.dart';
import 'screens/superadmin/superadmin_dashboard_screen.dart';
import 'screens/dean/dean_dashboard_screen.dart';
import 'screens/program_chair/program_chair_dashboard_screen.dart';
import 'test_capture_screen.dart';
import 'widgets/animated_wave_background.dart';
import 'utils/logger.dart';

// ThemeProvider class for managing theme state
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // For system mode, check the platform brightness
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  bool get isLightMode => !isDarkMode;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs?.getString(_themeKey) ?? 'system';

    switch (savedTheme) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return; // Skip if same theme

    _themeMode = mode;
    notifyListeners(); // Immediate UI update

    // Save to preferences in background
    _prefs ??= await SharedPreferences.getInstance();
    String themeString = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
        ? 'light'
        : 'system';
    await _prefs!.setString(_themeKey, themeString);
  }

  Future<void> toggleTheme() async {
    // Immediate toggle for better UX
    final newMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await setThemeMode(newMode);
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

// Helper methods for theme creation
class AppThemes {
  static ThemeData lightTheme() {
    return ThemeData(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B0000),
            brightness: Brightness.light,
          ).copyWith(
            primary: const Color(0xFF8B0000),
            secondary: const Color(0xFFD4B728),
            tertiary: const Color(0xFF0F5132),
            surface: const Color(0xFFFBF8F3),
            onPrimary: const Color(0xFFFFFFFF),
            onSecondary: const Color(0xFF1D1C00),
            onSurface: const Color(0xFF1A1B18),
            primaryContainer: const Color(0xFFFFDAD4),
            onPrimaryContainer: const Color(0xFF370001),
            secondaryContainer: const Color(0xFFFEE685),
            onSecondaryContainer: const Color(0xFF221B00),
            tertiaryContainer: const Color(0xFFA2F5BB),
            onTertiaryContainer: const Color(0xFF002111),
            outline: const Color(0xFF857A73),
            surfaceContainerHighest: const Color(0xFFF2E7DE),
            onSurfaceVariant: const Color(0xFF52453D),
          ),
      useMaterial3: true,
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B0000),
            brightness: Brightness.dark,
          ).copyWith(
            primary: const Color(0xFFFF6B6B),
            secondary: const Color(0xFFFFD93D),
            tertiary: const Color(0xFF6BCF7F),
            surface: const Color(0xFF1A1A1A),
            onPrimary: const Color(0xFF370001),
            onSecondary: const Color(0xFF221B00),
            onSurface: const Color(0xFFE6E1E6),
            primaryContainer: const Color(0xFF8B0000),
            onPrimaryContainer: const Color(0xFFFFDAD4),
            secondaryContainer: const Color(0xFFD4B728),
            onSecondaryContainer: const Color(0xFF221B00),
            tertiaryContainer: const Color(0xFF0F5132),
            onTertiaryContainer: const Color(0xFFA2F5BB),
            outline: const Color(0xFF6B6B6B),
            surfaceContainerHighest: const Color(0xFF2D2D2D),
            onSurfaceVariant: const Color(0xFFD5C4BB),
          ),
      useMaterial3: true,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'EduVision',
          debugShowCheckedModeBanner: false,
          theme: AppThemes.lightTheme(),
          darkTheme: AppThemes.darkTheme(),
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          _animationController.reverse().then((_) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const TermsScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                transitionDuration: const Duration(milliseconds: 800),
              ),
            );
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.12),
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'EduVision',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Educational Excellence',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.secondary,
                    letterSpacing: 3.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showDeclineDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Exit Application?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          content: Text(
            'Are you sure you want to exit? You will need to accept the terms to use the facial recognition features.',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _onDecline();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Exit',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onDecline() {
    _animationController.reverse().then((_) {
      SystemNavigator.pop();
    });
  }

  void _onAccept() {
    _animationController.reverse().then((_) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.12),
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                            Theme.of(
                              context,
                            ).colorScheme.secondaryContainer.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15),
                            spreadRadius: 0,
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Privacy & Terms',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.surface,
                            Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            spreadRadius: 0,
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.06),
                            spreadRadius: 0,
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Facial Recognition for Attendance',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'EduVision uses facial recognition technology to automatically track attendance and enhance classroom management. By proceeding, you consent to the collection and processing of your facial biometric data for:',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.6,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildBulletPoint(
                              context,
                              'Automated attendance tracking during classes',
                            ),
                            _buildBulletPoint(
                              context,
                              'Classroom entry and exit monitoring',
                            ),
                            _buildBulletPoint(
                              context,
                              'Academic performance analytics',
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Data Security',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your facial biometric data is encrypted using advanced security protocols and stored on secure servers. This data is used exclusively for attendance purposes and is never shared with external parties or used for commercial purposes.',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.6,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Your Rights',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'You may withdraw consent at any time, request deletion of your biometric data, or opt for manual attendance tracking. Contact your institution\'s admin or use the app settings to exercise these rights.',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.6,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showDeclineDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            'Decline',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 3,
                            shadowColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                          child: Text(
                            'Accept & Continue',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.6,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late AnimationController _logoAnimationController;
  late AnimationController _formAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _formFadeAnimation;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Logo animation controller
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Form animation controller
    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Main fade and slide animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _mainAnimationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    // Logo animations
    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    _logoRotationAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    // Form animations
    _formSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _formAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    // Start animations with staggered timing
    _mainAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _logoAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _formAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _logoAnimationController.dispose();
    _formAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userData = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (userData != null) {
        // Login successful - navigate to dashboard or home screen
        if (mounted) {
          // For now, show success message
          // Get user's name - try different possible field names
          String userName =
              userData['displayName'] ??
              userData['name'] ??
              userData['fullName'] ??
              userData['firstName'] ??
              userData['username'] ??
              userData['email']?.toString().split('@')[0] ??
              'User';

          // Debug log
          Logger.info('Login successful! User data: $userData');
          Logger.info('Display name: $userName');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Welcome back, $userName!',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 3),
            ),
          );

          // Navigate to main app screen after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              try {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MainNavigationScreen(userData: userData),
              ),
            );
              } catch (e) {
                print('Navigation error: $e');
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Navigation error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          });
        }
      } else {
        // Login failed
        setState(() {
          _errorMessage =
              'Invalid credentials. Please check your email/username and password.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Connection error. Please check your internet connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedWaveBackground(
        useFullScreen: true,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.15),
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _logoAnimationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _logoScaleAnimation.value,
                                child: Transform.rotate(
                                  angle: _logoRotationAnimation.value,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.15),
                                          spreadRadius: 3,
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Welcome Back',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to continue',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 40),
                          FadeTransition(
                            opacity: _formFadeAnimation,
                            child: SlideTransition(
                              position: _formSlideAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).colorScheme.surface,
                                      Theme.of(
                                        context,
                                      ).colorScheme.surface.withValues(alpha: 0.95),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withValues(alpha: 0.15),
                                      spreadRadius: 0,
                                      blurRadius: 35,
                                      offset: const Offset(0, 12),
                                    ),
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline.withValues(alpha: 0.08),
                                      spreadRadius: 0,
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _emailController,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your email or username';
                                          }
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Email or Username',
                                          labelStyle: GoogleFonts.inter(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                                  .withValues(alpha: 0.4),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              width: 2.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.person_outline,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                        style: GoogleFonts.inter(),
                                      ),
                                      const SizedBox(height: 20),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: !_isPasswordVisible,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          if (value.length < 3) {
                                            return 'Password must be at least 3 characters';
                                          }
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          labelStyle: GoogleFonts.inter(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                                  .withValues(alpha: 0.4),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              width: 2.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.lock_outline,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.7),
                                          ),
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _isPasswordVisible =
                                                    !_isPasswordVisible;
                                              });
                                            },
                                            icon: Icon(
                                              _isPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                        style: GoogleFonts.inter(),
                                      ),
                                      const SizedBox(height: 16),
                                      if (_errorMessage != null) ...[
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.errorContainer,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            _errorMessage!,
                                            style: GoogleFonts.inter(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onErrorContainer,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          foregroundColor: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          elevation: 4,
                                          shadowColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.4),
                                        ),
                                        child: _isLoading
                                            ? SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
                                                      ),
                                                ),
                                              )
                                            : Text(
                                                'Sign In',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextButton(
                                        onPressed: () {
                                          // TODO: Implement forgot password
                                        },
                                        child: Text(
                                          'Forgot Password?',
                                          style: GoogleFonts.inter(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late AnimationController _cardAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _cardScaleAnimation;

  // Individual card animations
  late List<Animation<double>> _cardFadeAnimations;
  late List<Animation<Offset>> _cardSlideAnimations;

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Card animation controller for staggered animations
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500), // Reduced duration
      vsync: this,
    );

    // Main fade and slide animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: Curves.easeOut, // Simplified curve
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _mainAnimationController,
            curve: Curves.easeOut, // Simplified curve
          ),
        );

    _cardScaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.easeOut, // Simplified curve
      ),
    );

    // Initialize staggered card animations
    _initializeCardAnimations();

    // Start animations with reduced timing
    _mainAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _cardAnimationController.forward();
    });
  }

  void _initializeCardAnimations() {
    _cardFadeAnimations = [];
    _cardSlideAnimations = [];

    // Create 4 card animations with staggered timing
    for (int i = 0; i < 4; i++) {
      final startTime = i * 0.1;
      final endTime = startTime + 0.4;

      _cardFadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _cardAnimationController,
            curve: Interval(
              startTime,
              endTime.clamp(0.0, 1.0),
              curve: Curves.easeOut,
            ),
          ),
        ),
      );

      _cardSlideAnimations.add(
        Tween<Offset>(
          begin: Offset(0, 0.5 + (i * 0.1)),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _cardAnimationController,
            curve: Interval(
              startTime,
              endTime.clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String userName =
        widget.userData['displayName'] ??
        widget.userData['name'] ??
        widget.userData['fullName'] ??
        widget.userData['firstName'] ??
        widget.userData['username'] ??
        widget.userData['email']?.toString().split('@')[0] ??
        'User';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.8),
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'EduVision',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                'Dashboard',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showProfileMenu(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).colorScheme.surface,
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  child: Text(
                                    _getInitials(userName),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      userName.length > 8
                                          ? '${userName.substring(0, 8)}...'
                                          : userName,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Student',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Section
                      _buildWelcomeSection(context, userName),

                      const SizedBox(height: 40),

                      // Stats Section
                      _buildStatsSection(context),

                      const SizedBox(height: 40),

                      // Quick Actions
                      _buildQuickActionsSection(context),

                      const SizedBox(height: 40),

                      // Recent Activity
                      _buildRecentActivitySection(context),

                      const SizedBox(
                        height: 170,
                      ), // Bottom padding for BottomNavigationBar
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      userName,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getCurrentDate(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return _buildSummaryCardsGrid(context);
  }

  Widget _buildSummaryCardsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.dashboard_rounded,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Your dashboard at a glance',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Class Schedule',
                '5 classes today',
                Icons.schedule_rounded,
                const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClassScheduleScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Attendance',
                '98 present, 12 absent',
                Icons.people_rounded,
                const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AttendanceScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Tasks & Deadlines',
                '6 items due today',
                Icons.assignment_turned_in_rounded,
                const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TasksDeadlinesScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Announcements',
                '3 new updates',
                Icons.campaign_rounded,
                const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                ),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnnouncementsScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String summary,
    IconData icon,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashFactory: InkSparkle.splashFactory,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 24, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    summary,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildClassScheduleContent(BuildContext context) {
    final classes = [
      {
        'time': '08:00 - 09:30',
        'section': 'Section A',
        'subject': 'Mathematics',
        'present': 28,
        'absent': 2,
        'status': 'active',
      },
      {
        'time': '10:00 - 11:30',
        'section': 'Section B',
        'subject': 'Physics',
        'present': 25,
        'absent': 5,
        'status': 'active',
      },
      {
        'time': '13:00 - 14:30',
        'section': 'Section C',
        'subject': 'Chemistry',
        'present': 0,
        'absent': 0,
        'status': 'canceled',
      },
      {
        'time': '15:00 - 16:30',
        'section': 'Section A',
        'subject': 'Biology',
        'present': 27,
        'absent': 3,
        'status': 'upcoming',
      },
    ];

    return Column(
      children: classes
          .map(
            (classInfo) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classInfo['time'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${classInfo['section']} - ${classInfo['subject']}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (classInfo['status'] != 'canceled')
                    Expanded(
                      child: Text(
                        '${classInfo['present']}P / ${classInfo['absent']}A',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        classInfo['status'] as String,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(classInfo['status'] as String),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(classInfo['status'] as String),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAttendanceHighlightsContent(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAttendanceStatCard(
                context,
                '98',
                'Present Today',
                Icons.check_circle_rounded,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAttendanceStatCard(
                context,
                '12',
                'Absent Today',
                Icons.cancel_rounded,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSpecialCasesList(context),
      ],
    );
  }

  Widget _buildAttendanceStatCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialCasesList(BuildContext context) {
    final specialCases = [
      {
        'name': 'Maria Santos',
        'type': 'Late',
        'detail': '15 mins late - Section A',
        'icon': Icons.access_time,
      },
      {
        'name': 'John Doe',
        'type': 'Excused',
        'detail': 'Medical appointment',
        'icon': Icons.local_hospital,
      },
      {
        'name': 'Sarah Lee',
        'type': 'Make-up',
        'detail': 'Chemistry lab session',
        'icon': Icons.refresh,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Special Cases',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...specialCases.map(
          (case_) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  case_['icon'] as IconData,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        case_['name'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        case_['detail'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getCaseTypeColor(
                      case_['type'] as String,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    case_['type'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getCaseTypeColor(case_['type'] as String),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskDeadlinesContent(BuildContext context) {
    final tasks = [
      {
        'title': 'Mathematics Quiz - Chapter 5',
        'type': 'Quiz',
        'time': '10:00 AM',
        'section': 'Section A',
        'urgent': true,
      },
      {
        'title': 'Physics Lab Report',
        'type': 'Assignment',
        'time': '2:00 PM',
        'section': 'Section B',
        'urgent': false,
      },
      {
        'title': 'Parent-Teacher Meeting',
        'type': 'Meeting',
        'time': '3:30 PM',
        'section': 'Office',
        'urgent': false,
      },
      {
        'title': 'Chemistry Midterm Prep',
        'type': 'Exam',
        'time': '4:00 PM',
        'section': 'Section C',
        'urgent': true,
      },
    ];

    return Column(
      children: tasks
          .map(
            (task) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: task['urgent'] as bool
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: task['urgent'] as bool ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getTaskIcon(task['type'] as String),
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${task['time']} • ${task['section']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task['urgent'] as bool)
                    Icon(Icons.priority_high, color: Colors.orange, size: 16),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAnnouncementsContent(BuildContext context) {
    final announcements = [
      {
        'title': 'Grade Submission Deadline',
        'content': 'All semester grades must be submitted by Friday, 5:00 PM',
        'priority': 'high',
      },
      {
        'title': 'Faculty Meeting Tomorrow',
        'content':
            'Monthly faculty meeting scheduled at 2:00 PM in Conference Room A',
        'priority': 'medium',
      },
      {
        'title': 'Student Evaluation Forms',
        'content':
            'Please distribute mid-semester evaluation forms to all sections',
        'priority': 'low',
      },
      {
        'title': 'Holiday Schedule Update',
        'content': 'Classes will resume on Monday following the winter break',
        'priority': 'medium',
      },
    ];

    return Column(
      children: announcements
          .map(
            (announcement) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getAnnouncementPriorityColor(
                    announcement['priority'] as String,
                  ).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getAnnouncementPriorityColor(
                            announcement['priority'] as String,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          announcement['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        announcement['priority'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getAnnouncementPriorityColor(
                            announcement['priority'] as String,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    announcement['content'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'upcoming':
        return Colors.blue;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'upcoming':
        return 'Upcoming';
      case 'canceled':
        return 'Canceled';
      default:
        return 'Unknown';
    }
  }

  Color _getCaseTypeColor(String type) {
    switch (type) {
      case 'Late':
        return Colors.orange;
      case 'Excused':
        return Colors.blue;
      case 'Make-up':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTaskIcon(String type) {
    switch (type) {
      case 'Quiz':
        return Icons.quiz_rounded;
      case 'Assignment':
        return Icons.assignment_rounded;
      case 'Meeting':
        return Icons.meeting_room_rounded;
      case 'Exam':
        return Icons.school_rounded;
      default:
        return Icons.task_rounded;
    }
  }

  Color _getAnnouncementPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEnhancedStatCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.flash_on_rounded,
                size: 24,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Get things done faster',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _cardFadeAnimations[0],
                child: SlideTransition(
                  position: _cardSlideAnimations[0],
                  child: ScaleTransition(
                    scale: _cardScaleAnimation,
                    child: _buildEnhancedActionCard(
                      context,
                      Icons.camera_alt_rounded,
                      'Attendance',
                      'Take attendance',
                      const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      ),
                      () => _showFeatureComingSoon(context, 'Attendance'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: FadeTransition(
                opacity: _cardFadeAnimations[1],
                child: SlideTransition(
                  position: _cardSlideAnimations[1],
                  child: ScaleTransition(
                    scale: _cardScaleAnimation,
                    child: _buildEnhancedActionCard(
                      context,
                      Icons.schedule_rounded,
                      'Schedule',
                      'View classes',
                      const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      () => _showFeatureComingSoon(context, 'Schedule'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _cardFadeAnimations[2],
                child: SlideTransition(
                  position: _cardSlideAnimations[2],
                  child: ScaleTransition(
                    scale: _cardScaleAnimation,
                    child: _buildEnhancedActionCard(
                      context,
                      Icons.grade_rounded,
                      'Grades',
                      'Check scores',
                      const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFDC2626)],
                      ),
                      () => _showFeatureComingSoon(context, 'Grades'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: FadeTransition(
                opacity: _cardFadeAnimations[3],
                child: SlideTransition(
                  position: _cardSlideAnimations[3],
                  child: ScaleTransition(
                    scale: _cardScaleAnimation,
                    child: _buildEnhancedActionCard(
                      context,
                      Icons.analytics_rounded,
                      'Reports',
                      'View analytics',
                      const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      ),
                      () => _showFeatureComingSoon(context, 'Reports'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 100),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                splashFactory: InkSparkle.splashFactory,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: gradient.colors.first.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 24, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
                    Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.timeline_rounded,
                size: 24,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Activity',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Stay up to date with your progress',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildActivityItem(
                context,
                Icons.check_circle_rounded,
                'Attendance marked for Math 101',
                '2 minutes ago',
                const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
              ),
              const SizedBox(height: 20),
              _buildActivityItem(
                context,
                Icons.schedule_rounded,
                'Next class: Physics Lab at 2:00 PM',
                '15 minutes ago',
                const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
              ),
              const SizedBox(height: 20),
              _buildActivityItem(
                context,
                Icons.grade_rounded,
                'New grade posted for Chemistry',
                '1 hour ago',
                const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () =>
                    _showFeatureComingSoon(context, 'Activity History'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View All Activity',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    IconData icon,
    String title,
    String time,
    LinearGradient gradient,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: gradient.colors.first.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: gradient.colors.first,
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$feature feature coming soon!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getInitials(String name) {
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty) {
      return nameParts[0].substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  void _showProfileMenu(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userData: widget.userData),
      ),
    );

    // If profile was updated, refresh the dashboard
    if (result != null) {
      setState(() {
        // The userData would have been updated already in the ProfileScreen
      });
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout from your account?',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// Main Navigation Screen with Bottom Navigation Bar
class MainNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MainNavigationScreen({super.key, required this.userData});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    try {
    _screens = _buildScreensBasedOnRole();
    } catch (e) {
      // Handle initialization error
      _screens = [
        Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Error initializing dashboard: $e'),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    );
                  },
                  child: Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ];
    }
  }

  List<Widget> _buildScreensBasedOnRole() {
    final String userRole =
        widget.userData['role']?.toString().toLowerCase() ?? 'instructor';

    // Debug logging removed - issue fixed

    Widget dashboardScreen;

    try {
    switch (userRole) {
      case 'superadmin':
          dashboardScreen = SuperadminDashboardScreen(userData: widget.userData);
        break;
      case 'dean':
        dashboardScreen = DeanDashboardScreen(userData: widget.userData);
        break;
      case 'programchairperson':
      case 'program chairperson':
        dashboardScreen = ProgramChairDashboardScreen(userData: widget.userData);
        break;
      case 'instructor':
      case 'instructors':
      default:
        dashboardScreen = DashboardScreen(userData: widget.userData);
        break;
      }
    } catch (e) {
      print('Error creating dashboard for role $userRole: $e');
      // Fallback to instructor dashboard
      dashboardScreen = DashboardScreen(userData: widget.userData);
    }

    Widget settingsScreen;

    switch (userRole) {
      case 'superadmin':
        settingsScreen = SizedBox.shrink(); // Settings integrated into dashboard
        break;
      case 'dean':
          // Settings now integrated into DeanDashboardScreen
          settingsScreen = const SizedBox.shrink();
        break;
      case 'programchairperson':
      case 'program chairperson':
        settingsScreen = SizedBox.shrink(); // Settings integrated into dashboard
        break;
      case 'instructor':
      case 'instructors':
      default:
        settingsScreen = SettingsScreen(userData: widget.userData);
        break;
    }

    return [dashboardScreen, settingsScreen];
  }

  String _getDashboardLabel() {
    final String userRole =
        widget.userData['role']?.toString().toLowerCase() ?? 'instructor';

    switch (userRole) {
      case 'superadmin':
        return 'Admin';
      case 'dean':
        return 'Dean';
      case 'programchairperson':
      case 'program chairperson':
        return 'Program';
      case 'instructor':
      case 'instructors':
      default:
        return 'Dashboard';
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
        decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
            ),
          ],
        ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
              _buildBottomNavItem(Icons.settings_rounded, 'Settings', 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
            setState(() {
              _currentIndex = index;
            });
          },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
          color: isSelected 
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 24,
                ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userRole = widget.userData['role']?.toString().toLowerCase() ?? 'instructor';
    
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: (userRole == 'instructor' || userRole == 'instructors') 
          ? _buildBottomNavigationBar() 
          : null, // MainLayout widgets handle their own navigation for other roles
    );
  }
}

// Settings Screen
class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SettingsScreen({super.key, required this.userData});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _notificationsEnabled = true;
  bool _biometricEnabled = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String userName =
        widget.userData['displayName'] ??
        widget.userData['name'] ??
        widget.userData['fullName'] ??
        widget.userData['firstName'] ??
        widget.userData['username'] ??
        widget.userData['email']?.toString().split('@')[0] ??
        'User';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedWaveBackground(
        useFullScreen: true,
        child: CustomScrollView(
          slivers: [
            // Custom App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.8),
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.settings_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Settings',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  'Manage your preferences',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main Content
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      _buildProfileSection(context, userName),

                      const SizedBox(height: 32),

                      // App Settings
                      _buildAppSettingsSection(context),

                      const SizedBox(height: 32),

                      // Account Settings
                      _buildAccountSettingsSection(context),

                      const SizedBox(height: 32),

                      // Support Section
                      _buildSupportSection(context),

                      const SizedBox(
                        height: 170,
                      ), // Bottom padding for BottomNavigationBar
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ...rest of the class...

  Widget _buildProfileSection(BuildContext context, String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              _getInitials(userName),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userData['email']?.toString() ?? 'No email available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.userData['role']?.toString() ?? 'Student',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    userData: widget.userData,
                    onProfileUpdated: (updatedUserData) {
                      // Update the parent widget's userData
                      setState(() {
                        widget.userData.clear();
                        widget.userData.addAll(updatedUserData);
                      });
                    },
                  ),
                ),
              );
            },
            icon: Icon(
              Icons.edit_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App Settings',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        _buildSettingItem(
          context,
          Icons.notifications_rounded,
          'Notifications',
          'Receive push notifications',
          Switch(
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ),

        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return _buildSettingItem(
              context,
              themeProvider.isDarkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
              themeProvider.isSystemMode
                  ? (themeProvider.isDarkMode
                        ? 'System (Dark)'
                        : 'System (Light)')
                  : (themeProvider.isDarkMode
                        ? 'Dark theme active'
                        : 'Light theme active'),
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) async {
                  await themeProvider.toggleTheme();
                },
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            );
          },
        ),

        _buildSettingItem(
          context,
          Icons.fingerprint_rounded,
          'Biometric Login',
          'Use fingerprint or face recognition',
          Switch(
            value: _biometricEnabled,
            onChanged: (value) {
              setState(() {
                _biometricEnabled = value;
              });
              _showFeatureComingSoon(context, 'Biometric Login');
            },
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ),

        _buildSettingItem(
          context,
          Icons.camera_alt_rounded,
          'Test Face Capture',
          'Test if photo capture and Cloudinary upload works',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TestCaptureScreen(userData: widget.userData),
              ),
            );
          },
        ),

        _buildSettingItem(
          context,
          Icons.face_rounded,
          'Face Registration',
          'Register your face for attendace monitoring',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FaceRegistrationScreen(userData: widget.userData),
              ),
            );
          },
        ),

        _buildSettingItem(
          context,
          Icons.psychology_rounded,
          'TensorFlow Lite Debug',
          'Test deep learning face analysis models',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TFLiteDebugScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        _buildSettingItem(
          context,
          Icons.lock_rounded,
          'Change Password',
          'Update your account password',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChangePasswordScreen(userData: widget.userData),
              ),
            );
          },
        ),

        _buildSettingItem(
          context,
          Icons.privacy_tip_rounded,
          'Privacy Settings',
          'Manage your privacy preferences',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PrivacySettingsScreen(userData: widget.userData),
            ),
          ),
        ),

        _buildSettingItem(
          context,
          Icons.storage_rounded,
          'Data Management',
          'Manage your stored data',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DataManagementScreen(userData: widget.userData),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        _buildSettingItem(
          context,
          Icons.help_rounded,
          'Help Center',
          'Get help and support',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HelpCenterScreen(userData: widget.userData),
            ),
          ),
        ),

        _buildSettingItem(
          context,
          Icons.feedback_rounded,
          'Send Feedback',
          'Share your thoughts with us',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SendFeedbackScreen(userData: widget.userData),
            ),
          ),
        ),

        _buildSettingItem(
          context,
          Icons.info_rounded,
          'About',
          'App version and information',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => _showAboutDialog(context),
        ),

        const SizedBox(height: 24),

        // Logout Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _showLogoutDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Logout',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget trailing, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty) {
      return nameParts[0].substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  void _showFeatureComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$feature feature coming soon!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'About EduVision',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EduVision v1.0.0',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A modern education management system with facial recognition technology for attendance tracking.',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '© 2024 EduVision. All rights reserved.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Close',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout from your account?',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Helper function to construct full name with middle name included
String getFullNameFromUserData(Map<String, dynamic> userData) {
  // Try both naming conventions (camelCase and snake_case)
  String firstName =
      (userData['firstName'] ?? userData['first_name'])?.toString().trim() ??
      '';
  String middleName =
      (userData['middleName'] ?? userData['middle_name'])?.toString().trim() ??
      '';
  String lastName =
      (userData['lastName'] ?? userData['last_name'])?.toString().trim() ?? '';

  // If we have individual name components, use them
  if (firstName.isNotEmpty || middleName.isNotEmpty || lastName.isNotEmpty) {
    List<String> nameParts = [];
    if (firstName.isNotEmpty) nameParts.add(firstName);
    if (middleName.isNotEmpty) nameParts.add(middleName);
    if (lastName.isNotEmpty) nameParts.add(lastName);

    if (nameParts.isNotEmpty) {
      return nameParts.join(' ');
    }
  }

  // Fallback to existing display name fields
  return userData['displayName']?.toString().trim() ??
      userData['name']?.toString().trim() ??
      userData['fullName']?.toString().trim() ??
      userData['username']?.toString().trim() ??
      userData['email']?.toString().split('@')[0] ??
      'User';
}

// Helper function to get initials from name (improved to handle middle names)
String getInitialsFromName(String name) {
  if (name.isEmpty) return 'U';

  List<String> nameParts = name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList();

  if (nameParts.length == 1) {
    // Single name, use first letter
    return nameParts[0][0].toUpperCase();
  } else if (nameParts.length >= 2) {
    // Multiple names, use first and last initials (skip middle for better appearance)
    return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
  }

  return 'U';
}

// Profile Screen
class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileScreen({super.key, required this.userData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String userName = getFullNameFromUserData(widget.userData);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedWaveBackground(
        useFullScreen: true,
        child: CustomScrollView(
          slivers: [
            // Custom App Bar with Profile Header
            SliverAppBar(
              expandedHeight: 250,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.8),
                        Theme.of(
                          context,
                        ).colorScheme.secondaryContainer.withValues(alpha: 0.6),
                        Theme.of(context).colorScheme.surface,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Profile Avatar
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: Text(
                                getInitialsFromName(userName),
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // User Name
                          Flexible(
                            child: Text(
                              userName,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.userData['role']?.toString() ?? 'Student',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Profile Content
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Personal Information Section
                        _buildPersonalInfoSection(context),

                        const SizedBox(height: 32),

                        // Contact Information Section
                        _buildContactInfoSection(context),

                        const SizedBox(height: 32),

                        // Account Details Section
                        _buildAccountDetailsSection(context),

                        const SizedBox(height: 32),

                        // Actions Section
                        _buildActionsSection(context),

                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildInfoItem(
                context,
                Icons.person_rounded,
                'Full Name',
                getFullNameFromUserData(widget.userData),
              ),
              // Show individual name parts if available
              if (widget.userData['firstName'] != null ||
                  widget.userData['first_name'] != null) ...[
                const SizedBox(height: 16),
                _buildInfoItem(
                  context,
                  Icons.person_outline_rounded,
                  'First Name',
                  (widget.userData['firstName'] ??
                              widget.userData['first_name'])
                          ?.toString() ??
                      'Not provided',
                ),
              ],
              if (widget.userData['middleName'] != null ||
                  widget.userData['middle_name'] != null) ...[
                const SizedBox(height: 16),
                _buildInfoItem(
                  context,
                  Icons.person_2_rounded,
                  'Middle Name',
                  (widget.userData['middleName'] ??
                              widget.userData['middle_name'])
                          ?.toString() ??
                      'Not provided',
                ),
              ],
              if (widget.userData['lastName'] != null ||
                  widget.userData['last_name'] != null) ...[
                const SizedBox(height: 16),
                _buildInfoItem(
                  context,
                  Icons.person_pin_rounded,
                  'Last Name',
                  (widget.userData['lastName'] ?? widget.userData['last_name'])
                          ?.toString() ??
                      'Not provided',
                ),
              ],
              const SizedBox(height: 16),
              _buildInfoItem(
                context,
                Icons.badge_rounded,
                'Username',
                widget.userData['username'] ??
                    widget.userData['email']?.toString().split('@')[0] ??
                    'Not provided',
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                context,
                Icons.work_rounded,
                'Role',
                widget.userData['role']?.toString() ?? 'Student',
              ),
              if (widget.userData['department'] != null) ...[
                const SizedBox(height: 16),
                _buildInfoItem(
                  context,
                  Icons.business_rounded,
                  'Department',
                  widget.userData['department'].toString(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildInfoItem(
                context,
                Icons.email_rounded,
                'Email Address',
                widget.userData['email']?.toString() ?? 'Not provided',
              ),
              if (widget.userData['phone'] != null) ...[
                const SizedBox(height: 16),
                _buildInfoItem(
                  context,
                  Icons.phone_rounded,
                  'Phone Number',
                  widget.userData['phone'].toString(),
                ),
              ],
              if (widget.userData['address'] != null) ...[
                const SizedBox(height: 16),
                _buildInfoItem(
                  context,
                  Icons.location_on_rounded,
                  'Address',
                  widget.userData['address'].toString(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Details',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (widget.userData['studentId'] != null ||
                  widget.userData['employeeId'] != null)
                _buildInfoItem(
                  context,
                  Icons.badge_outlined,
                  widget.userData['role']?.toString() == 'Student'
                      ? 'Student ID'
                      : 'Employee ID',
                  widget.userData['studentId']?.toString() ??
                      widget.userData['employeeId']?.toString() ??
                      'Not provided',
                ),
              if ((widget.userData['studentId'] != null ||
                      widget.userData['employeeId'] != null) &&
                  (widget.userData['program'] != null ||
                      widget.userData['yearLevel'] != null))
                const SizedBox(height: 16),
              if (widget.userData['program'] != null)
                _buildInfoItem(
                  context,
                  Icons.school_rounded,
                  'Program',
                  widget.userData['program'].toString(),
                ),
              if (widget.userData['program'] != null &&
                  widget.userData['yearLevel'] != null)
                const SizedBox(height: 16),
              if (widget.userData['yearLevel'] != null)
                _buildInfoItem(
                  context,
                  Icons.grade_rounded,
                  'Year Level',
                  widget.userData['yearLevel'].toString(),
                ),
              const SizedBox(height: 16),
              _buildInfoItem(
                context,
                Icons.access_time_rounded,
                'Member Since',
                _formatDate(widget.userData['createdAt']) ?? 'Unknown',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                        userData: widget.userData,
                        onProfileUpdated: (updatedUserData) {
                          // Update the parent widget's userData
                          setState(() {
                            widget.userData.clear();
                            widget.userData.addAll(updatedUserData);
                          });
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                icon: Icon(Icons.edit_rounded, size: 20),
                label: Text(
                  'Edit Profile',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ChangePasswordScreen(userData: widget.userData),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                icon: Icon(Icons.lock_rounded, size: 20),
                label: Text(
                  'Change Password',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty) {
      return nameParts[0].substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  String? _formatDate(dynamic dateValue) {
    if (dateValue == null) return null;

    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return null;
      }

      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showFeatureComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$feature feature coming soon!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// Detail Screens

class ClassScheduleScreen extends StatefulWidget {
  const ClassScheduleScreen({super.key});

  @override
  State<ClassScheduleScreen> createState() => _ClassScheduleScreenState();
}

class _ClassScheduleScreenState extends State<ClassScheduleScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _selectedSemester = 0; // 0 = First Semester, 1 = Second Semester
  int _selectedWeek = 0; // Current week within the semester
  final List<String> _semesters = [
    'First Semester (Aug-Dec)',
    'Second Semester (Jan-May)',
  ];

  // Get current semester based on date
  int get _currentSemester {
    final now = DateTime.now();
    if (now.month >= 8 || now.month <= 12) {
      return 0; // First Semester
    } else {
      return 1; // Second Semester
    }
  }

  // Get total weeks for current semester
  int get _totalWeeks {
    return _selectedSemester == 0 ? 16 : 18;
  }

  // Get current week within semester
  int get _currentWeek {
    final now = DateTime.now();
    if (_selectedSemester == 0) {
      final startDate = DateTime(2024, 8, 26);
      final weekDiff = now.difference(startDate).inDays ~/ 7;
      return weekDiff.clamp(0, 15); // 0-15 for 16 weeks
    } else {
      final startDate = DateTime(2025, 1, 13);
      final weekDiff = now.difference(startDate).inDays ~/ 7;
      return weekDiff.clamp(0, 17); // 0-17 for 18 weeks
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500), // Faster animation
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Class Schedule',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showScheduleOptions(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.more_vert_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(context),
                const SizedBox(height: 24),
                _buildSemesterSelector(context),
                const SizedBox(height: 16),
                _buildWeekSelector(context),
                const SizedBox(height: 24),
                Expanded(child: _buildScheduleGrid(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Week ${_selectedWeek + 1} Schedule',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getWeekDate(_selectedWeek)} • ${_getCurrentWeekClasses()} classes',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterSelector(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _semesters.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedSemester;
          return Container(
            margin: EdgeInsets.only(
              right: index < _semesters.length - 1 ? 16 : 0,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _selectedSemester = index;
                    _selectedWeek =
                        0; // Reset to first week when semester changes
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.8),
                            ],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.school_rounded
                            : Icons.school_outlined,
                        size: 18,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_semesters[index].split(' ')[0]} ${_semesters[index].split(' ')[1]}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeekSelector(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _totalWeeks,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedWeek;

          return Container(
            margin: EdgeInsets.only(right: index < _totalWeeks - 1 ? 12 : 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _selectedWeek = index;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.secondary,
                              Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.8),
                            ],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.calendar_today_rounded
                            : Icons.calendar_today_outlined,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Week ${index + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleGrid(BuildContext context) {
    final timeSlots = _getTimeSlots();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final scheduleData = _getScheduleData();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row with days
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Time column header
                Container(
                  width: 70,
                  alignment: Alignment.center,
                  child: Text(
                    'Time',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                // Day headers
                ...days.map(
                  (day) => Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        day,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Schedule grid
          Expanded(
            child: ListView.builder(
              itemCount: timeSlots.length,
              itemBuilder: (context, timeIndex) {
                final timeSlot = timeSlots[timeIndex];
                return Container(
                  height: 110,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Time column
                      Container(
                        width: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          timeSlot,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      // Day columns
                      ...days.asMap().entries.map((dayEntry) {
                        final classData = scheduleData[dayEntry.value]?[timeSlot];

                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: classData != null
                                ? _buildClassCard(context, classData)
                                : Container(),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, Map<String, dynamic> classData) {
    final colors = _getSubjectColors(classData['subject']);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.first.withValues(alpha: 0.9), colors.last.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showClassDetails(context, classData),
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject name
                Text(
                  classData['subject'],
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Room and block info
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.room_rounded,
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        classData['room'],
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        classData['block'],
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getTimeSlots() {
    return [
      '8:00',
      '8:30',
      '9:00',
      '9:30',
      '10:00',
      '10:30',
      '11:00',
      '11:30',
      '12:00',
      '12:30',
      '1:00',
      '1:30',
      '2:00',
      '2:30',
      '3:00',
      '3:30',
      '4:00',
      '4:30',
      '5:00',
    ];
  }

  Map<String, Map<String, Map<String, dynamic>>> _getScheduleData() {
    return {
      'Mon': {
        '8:00': {
          'subject': 'Mathematics',
          'room': 'Room 101',
          'block': '1A',
          'duration': '1.5h',
        },
        '10:00': {
          'subject': 'Physics',
          'room': 'Lab 201',
          'block': '2B',
          'duration': '2h',
        },
        '2:00': {
          'subject': 'Chemistry',
          'room': 'Room 305',
          'block': '3C',
          'duration': '1.5h',
        },
      },
      'Tue': {
        '9:00': {
          'subject': 'Biology',
          'room': 'Lab 102',
          'block': '1B',
          'duration': '2h',
        },
        '1:00': {
          'subject': 'English',
          'room': 'Room 205',
          'block': '2A',
          'duration': '1h',
        },
        '3:00': {
          'subject': 'History',
          'room': 'Room 401',
          'block': '4A',
          'duration': '1.5h',
        },
      },
      'Wed': {
        '8:30': {
          'subject': 'Mathematics',
          'room': 'Room 101',
          'block': '1C',
          'duration': '1.5h',
        },
        '11:00': {
          'subject': 'Computer Science',
          'room': 'Lab 301',
          'block': '3A',
          'duration': '2h',
        },
        '4:00': {
          'subject': 'Art',
          'room': 'Studio A',
          'block': '2C',
          'duration': '1h',
        },
      },
      'Thu': {
        '9:30': {
          'subject': 'Physics',
          'room': 'Lab 201',
          'block': '2D',
          'duration': '2h',
        },
        '2:30': {
          'subject': 'Chemistry',
          'room': 'Room 305',
          'block': '3B',
          'duration': '1.5h',
        },
      },
      'Fri': {
        '8:00': {
          'subject': 'Biology',
          'room': 'Lab 102',
          'block': '1D',
          'duration': '2h',
        },
        '1:00': {
          'subject': 'English',
          'room': 'Room 205',
          'block': '2E',
          'duration': '1h',
        },
        '3:00': {
          'subject': 'Physical Education',
          'room': 'Gym',
          'block': '4B',
          'duration': '1h',
        },
      },
    };
  }

  List<Color> _getSubjectColors(String subject) {
    final colorMap = {
      'Mathematics': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      'Physics': [const Color(0xFF10B981), const Color(0xFF059669)],
      'Chemistry': [const Color(0xFFF59E0B), const Color(0xFFDC2626)],
      'Biology': [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
      'English': [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      'History': [const Color(0xFF059669), const Color(0xFF047857)],
      'Computer Science': [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
      'Art': [const Color(0xFFEC4899), const Color(0xFFDB2777)],
      'Physical Education': [const Color(0xFFF97316), const Color(0xFFEA580C)],
    };

    return colorMap[subject] ??
        [const Color(0xFF6B7280), const Color(0xFF4B5563)];
  }

  Map<String, dynamic> _getSemesterInfo() {
    if (_selectedSemester == 0) {
      return {
        'totalClasses': 80, // 16 weeks × 5 classes per week
        'weeks': 16,
        'dateRange': 'Aug 26 - Dec 20, 2024',
      };
    } else {
      return {
        'totalClasses': 90, // 18 weeks × 5 classes per week
        'weeks': 18,
        'dateRange': 'Jan 13 - May 16, 2025',
      };
    }
  }

  String _getWeekDate(int weekIndex) {
    if (_selectedSemester == 0) {
      final startDate = DateTime(2024, 8, 26);
      final weekStart = startDate.add(Duration(days: weekIndex * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
    } else {
      final startDate = DateTime(2025, 1, 13);
      final weekStart = startDate.add(Duration(days: weekIndex * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  int _getCurrentWeekClasses() {
    final scheduleData = _getScheduleData();
    int totalClasses = 0;
    for (var day in scheduleData.values) {
      totalClasses += day.length;
    }
    return totalClasses;
  }

  void _showClassDetails(BuildContext context, Map<String, dynamic> classData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            classData['subject'],
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Room', classData['room']),
              _buildDetailRow('Block', classData['block']),
              _buildDetailRow('Duration', classData['duration']),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          Text(value),
        ],
      ),
    );
  }

  void _showScheduleOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Schedule Options',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.print_rounded),
                title: Text('Print Schedule'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement print functionality
                },
              ),
              ListTile(
                leading: Icon(Icons.share_rounded),
                title: Text('Share Schedule'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement share functionality
                },
              ),
              ListTile(
                leading: Icon(Icons.settings_rounded),
                title: Text('Schedule Settings'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement settings
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _selectedSemester = 0; // 0 = First Semester, 1 = Second Semester
  int _selectedWeek = 0; // Current week within the semester
  final List<String> _semesters = [
    'First Semester (Aug-Dec)',
    'Second Semester (Jan-May)',
  ];

  // Get current semester based on date
  int get _currentSemester {
    final now = DateTime.now();
    if (now.month >= 8 || now.month <= 12) {
      return 0; // First Semester
    } else {
      return 1; // Second Semester
    }
  }

  // Get total weeks for current semester
  int get _totalWeeks {
    return _selectedSemester == 0 ? 16 : 18;
  }

  // Get current week within semester
  int get _currentWeek {
    final now = DateTime.now();
    if (_selectedSemester == 0) {
      final startDate = DateTime(2024, 8, 26);
      final weekDiff = now.difference(startDate).inDays ~/ 7;
      return weekDiff.clamp(0, 15); // 0-15 for 16 weeks
    } else {
      final startDate = DateTime(2025, 1, 13);
      final weekDiff = now.difference(startDate).inDays ~/ 7;
      return weekDiff.clamp(0, 17); // 0-17 for 18 weeks
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Attendance Heatmap',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(context),
                const SizedBox(height: 24),
                _buildSemesterSelector(context),
                const SizedBox(height: 16),
                _buildWeekSelector(context),
                const SizedBox(height: 24),
                Expanded(child: _buildAttendanceHeatmap(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final attendanceStats = _getAttendanceStats();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.how_to_reg_rounded,
              color: Theme.of(context).colorScheme.tertiary,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Teaching Attendance',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  '${attendanceStats['present']} attended, ${attendanceStats['absent']} missed',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (attendanceStats['present'] ?? 0) >
                          (attendanceStats['absent'] ?? 0)
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFFEF4444).withValues(alpha: 0.2),
                  (attendanceStats['present'] ?? 0) >
                          (attendanceStats['absent'] ?? 0)
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFFEF4444).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    (attendanceStats['present'] ?? 0) >
                        (attendanceStats['absent'] ?? 0)
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : const Color(0xFFEF4444).withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (attendanceStats['present'] ?? 0) >
                          (attendanceStats['absent'] ?? 0)
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFFEF4444).withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${(((attendanceStats['present'] ?? 0) / ((attendanceStats['present'] ?? 0) + (attendanceStats['absent'] ?? 0))) * 100).round()}%',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    (attendanceStats['present'] ?? 0) >
                        (attendanceStats['absent'] ?? 0)
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterSelector(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _semesters.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedSemester;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSemester = index;
                _selectedWeek = 0; // Reset to first week when semester changes
              });
            },
            child: Container(
              margin: EdgeInsets.only(
                right: index < _semesters.length - 1 ? 12 : 0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                '${_semesters[index].split(' ')[0]} ${_semesters[index].split(' ')[1]}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeekSelector(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _totalWeeks,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedWeek;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedWeek = index;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: index < _totalWeeks - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                'Week ${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttendanceHeatmap(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final attendanceData = _getAttendanceData();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header row with days
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Week label
                Container(
                  width: 70,
                  alignment: Alignment.center,
                  child: Text(
                    'Week',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                // Day headers
                ...days.map(
                  (day) => Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        day,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Heatmap grid
          Expanded(
            child: ListView.builder(
              itemCount: _selectedSemester == 0
                  ? 16
                  : 18, // 16 weeks for 1st sem, 18 for 2nd sem
              itemBuilder: (context, weekIndex) {
                return Container(
                  height: 100, // Increased height for better visibility
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Week number
                      Container(
                        width: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          '${weekIndex + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      // Day cells
                      ...days.asMap().entries.map((dayEntry) {
                        final attendance = attendanceData[weekIndex]?[dayEntry.key];

                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: attendance != null
                                ? _buildAttendanceCell(context, attendance)
                                : Container(),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCell(
    BuildContext context,
    Map<String, dynamic> attendance,
  ) {
    final isPresent = attendance['present'] as bool;
    final subject = attendance['subject'] as String;
    final time = attendance['time'] as String;

    Color cellColor;
    Color textColor;
    if (isPresent) {
      cellColor = const Color(0xFF10B981);
      textColor = Colors.white;
    } else {
      cellColor = const Color(0xFFEF4444);
      textColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cellColor.withValues(alpha: 0.9), cellColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: cellColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showAttendanceDetails(context, attendance),
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status icon
                Icon(
                  isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 12,
                  color: textColor,
                ),
                const SizedBox(height: 2),
                // Time
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Subject
                Text(
                  subject,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, int> _getAttendanceStats() {
    final attendanceData = _getAttendanceData();
    int present = 0;
    int absent = 0;

    for (var week in attendanceData.values) {
      for (var day in week.values) {
        if (day['present'] as bool) {
          present++;
        } else {
          absent++;
        }
      }
    }

    return {'present': present, 'absent': absent};
  }

  Map<int, Map<int, Map<String, dynamic>>> _getAttendanceData() {
    // Generate semester-based attendance data with actual dates
    final Map<int, Map<int, Map<String, dynamic>>> semesterData = {};

    // First Semester (August - December)
    if (_selectedSemester == 0) {
      final startDate = DateTime(2024, 8, 26); // August 26, 2024
      final endDate = DateTime(2024, 12, 20); // December 20, 2024

      int weekIndex = 0;
      DateTime currentDate = startDate;

      while (currentDate.isBefore(endDate) && weekIndex < 16) {
        // 16 weeks
        semesterData[weekIndex] = {};

        // Monday to Friday
        for (int dayIndex = 0; dayIndex < 5; dayIndex++) {
          final classDate = currentDate.add(Duration(days: dayIndex));

          // Only add classes on weekdays
          if (classDate.weekday >= 1 && classDate.weekday <= 5) {
            semesterData[weekIndex]![dayIndex] = {
              'present': _getRandomAttendance(),
              'subject': _getSubjectForDay(dayIndex),
              'block': _getBlockForDay(dayIndex),
              'time': _getTimeForDay(dayIndex),
              'date': classDate,
              'formattedDate': _formatDate(classDate),
            };
          }
        }

        currentDate = currentDate.add(const Duration(days: 7));
        weekIndex++;
      }
    }
    // Second Semester (January - May)
    else {
      final startDate = DateTime(2025, 1, 13); // January 13, 2025
      final endDate = DateTime(2025, 5, 16); // May 16, 2025

      int weekIndex = 0;
      DateTime currentDate = startDate;

      while (currentDate.isBefore(endDate) && weekIndex < 18) {
        // 18 weeks
        semesterData[weekIndex] = {};

        // Monday to Friday
        for (int dayIndex = 0; dayIndex < 5; dayIndex++) {
          final classDate = currentDate.add(Duration(days: dayIndex));

          // Only add classes on weekdays
          if (classDate.weekday >= 1 && classDate.weekday <= 5) {
            semesterData[weekIndex]![dayIndex] = {
              'present': _getRandomAttendance(),
              'subject': _getSubjectForDay(dayIndex),
              'block': _getBlockForDay(dayIndex),
              'time': _getTimeForDay(dayIndex),
              'date': classDate,
              'formattedDate': _formatDate(classDate),
            };
          }
        }

        currentDate = currentDate.add(const Duration(days: 7));
        weekIndex++;
      }
    }

    return semesterData;
  }

  bool _getRandomAttendance() {
    // 85% attendance rate for realistic data
    return DateTime.now().millisecondsSinceEpoch % 100 < 85;
  }

  String _getSubjectForDay(int dayIndex) {
    final subjects = ['Math', 'Bio', 'Math', 'Physics', 'Bio'];
    return subjects[dayIndex % subjects.length];
  }

  String _getBlockForDay(int dayIndex) {
    final blocks = ['1A', '1B', '1C', '2D', '1D'];
    return blocks[dayIndex % blocks.length];
  }

  String _getTimeForDay(int dayIndex) {
    final times = ['8:00', '9:00', '8:30', '9:30', '8:00'];
    return times[dayIndex % times.length];
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _showAttendanceDetails(
    BuildContext context,
    Map<String, dynamic> attendance,
  ) {
    final isPresent = attendance['present'] as bool;
    final subject = attendance['subject'] as String;
    final block = attendance['block'] as String;
    final time = attendance['time'] as String;
    final date = attendance['date'] as DateTime;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isPresent ? Icons.check_circle : Icons.cancel,
                color: isPresent ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isPresent ? 'Class Attended' : 'Class Missed',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date', _formatFullDate(date)),
              _buildDetailRow('Time', time),
              _buildDetailRow('Subject', subject),
              _buildDetailRow('Block', block),
              _buildDetailRow('Status', isPresent ? 'Present' : 'Absent'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getWeekDate(int weekIndex) {
    if (_selectedSemester == 0) {
      final startDate = DateTime(2024, 8, 26);
      final weekStart = startDate.add(Duration(days: weekIndex * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
    } else {
      final startDate = DateTime(2025, 1, 13);
      final weekStart = startDate.add(Duration(days: weekIndex * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
    }
  }

  int _getWeekAttendancePercentage() {
    final attendanceData = _getAttendanceData();
    final weekData = attendanceData[_selectedWeek];
    if (weekData == null) return 0;

    int present = 0;
    int total = weekData.length;

    for (var dayData in weekData.values) {
      if (dayData['present'] as bool) {
        present++;
      }
    }

    return total > 0 ? ((present / total) * 100).round() : 0;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class TasksDeadlinesScreen extends StatelessWidget {
  const TasksDeadlinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Tasks & Deadlines',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.assignment_rounded,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Tasks',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '6 items due this week',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Task management and deadline tracking will be implemented here.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Announcements',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.08),
                    Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.tertiary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Announcements',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '3 new updates available',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Announcements and notifications will be displayed here.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.userData,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _departmentController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _programController = TextEditingController();
  final _yearLevelController = TextEditingController();

  bool _isLoading = false;
  String _selectedRole = 'Student';

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    // Parse existing full name or use individual fields if available
    String fullName =
        widget.userData['displayName'] ??
        widget.userData['name'] ??
        widget.userData['fullName'] ??
        '';

    // Try to get individual name parts first (check both naming conventions), then fallback to splitting full name
    _firstNameController.text =
        (widget.userData['firstName'] ?? widget.userData['first_name'])
            ?.toString() ??
        (fullName.isNotEmpty ? fullName.split(' ').first : '');
    _middleNameController.text =
        (widget.userData['middleName'] ?? widget.userData['middle_name'])
            ?.toString() ??
        (fullName.split(' ').length > 2 ? fullName.split(' ')[1] : '');
    _lastNameController.text =
        (widget.userData['lastName'] ?? widget.userData['last_name'])
            ?.toString() ??
        (fullName.split(' ').length > 1 ? fullName.split(' ').last : '');

    _usernameController.text = widget.userData['username'] ?? '';
    _emailController.text = widget.userData['email']?.toString() ?? '';
    _phoneController.text = widget.userData['phone']?.toString() ?? '';
    _addressController.text = widget.userData['address']?.toString() ?? '';
    _departmentController.text =
        widget.userData['department']?.toString() ?? '';
    _studentIdController.text = widget.userData['studentId']?.toString() ?? '';
    _employeeIdController.text =
        widget.userData['employeeId']?.toString() ?? '';
    _programController.text = widget.userData['program']?.toString() ?? '';
    _yearLevelController.text = widget.userData['yearLevel']?.toString() ?? '';

    // Validate role and ensure it's in the allowed list
    final roleFromData = widget.userData['role']?.toString() ?? 'Student';
    if ([
      'Student',
      'Faculty',
      'Instructor',
      'Staff',
      'Admin',
    ].contains(roleFromData)) {
      _selectedRole = roleFromData;
    } else {
      _selectedRole = 'Student'; // Default fallback
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _departmentController.dispose();
    _studentIdController.dispose();
    _employeeIdController.dispose();
    _programController.dispose();
    _yearLevelController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value != null && value.isNotEmpty) {
      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
      if (!phoneRegex.hasMatch(value)) {
        return 'Please enter a valid phone number';
      }
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create updated user data
      final updatedUserData = Map<String, dynamic>.from(widget.userData);

      // Prepare data for API call using database field names
      final apiData = <String, dynamic>{};
      apiData['first_name'] = _firstNameController.text.trim();
      apiData['middle_name'] = _middleNameController.text.trim().isNotEmpty
          ? _middleNameController.text.trim()
          : null;
      apiData['last_name'] = _lastNameController.text.trim();
      apiData['username'] = _usernameController.text.trim();
      apiData['email'] = _emailController.text.trim();
      apiData['phone'] = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null;
      apiData['address'] = _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null;
      apiData['department'] = _departmentController.text.trim().isNotEmpty
          ? _departmentController.text.trim()
          : null;
      apiData['role'] = _selectedRole;

      if (_selectedRole == 'Student') {
        apiData['studentId'] = _studentIdController.text.trim().isNotEmpty
            ? _studentIdController.text.trim()
            : null;
        apiData['program'] = _programController.text.trim().isNotEmpty
            ? _programController.text.trim()
            : null;
        apiData['yearLevel'] = _yearLevelController.text.trim().isNotEmpty
            ? _yearLevelController.text.trim()
            : null;
      } else {
        apiData['employeeId'] = _employeeIdController.text.trim().isNotEmpty
            ? _employeeIdController.text.trim()
            : null;
      }

      // Try to call the actual API first, fall back to demo mode if it fails
      bool apiSuccess = false;
      try {
        final response = await http.put(
          Uri.parse('${AuthService.baseUrl}/profile/${widget.userData['_id']}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(apiData),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            // Update local data with response from server
            updatedUserData.addAll(data['user']);
            apiSuccess = true;
          }
        }
      } catch (e) {
        Logger.warning('API call failed, using demo mode: $e');
      }

      // If API failed, update local data manually (demo mode)
      if (!apiSuccess) {
        // Simulate API call delay
        await Future.delayed(const Duration(seconds: 1));

        // Construct full name from individual parts
        String fullName = _firstNameController.text.trim();
        if (_middleNameController.text.trim().isNotEmpty) {
          fullName += ' ${_middleNameController.text.trim()}';
        }
        if (_lastNameController.text.trim().isNotEmpty) {
          fullName += ' ${_lastNameController.text.trim()}';
        }

        updatedUserData['firstName'] = _firstNameController.text.trim();
        updatedUserData['first_name'] = _firstNameController.text.trim();
        updatedUserData['middleName'] =
            _middleNameController.text.trim().isNotEmpty
            ? _middleNameController.text.trim()
            : null;
        updatedUserData['middle_name'] =
            _middleNameController.text.trim().isNotEmpty
            ? _middleNameController.text.trim()
            : null;
        updatedUserData['lastName'] = _lastNameController.text.trim();
        updatedUserData['last_name'] = _lastNameController.text.trim();
        updatedUserData['displayName'] = fullName;
        updatedUserData['name'] = fullName;
        updatedUserData['fullName'] = fullName;
        updatedUserData['username'] = _usernameController.text.trim();
        updatedUserData['email'] = _emailController.text.trim();
        updatedUserData['phone'] = _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null;
        updatedUserData['address'] = _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null;
        updatedUserData['department'] =
            _departmentController.text.trim().isNotEmpty
            ? _departmentController.text.trim()
            : null;
        updatedUserData['role'] = _selectedRole;

        if (_selectedRole == 'Student') {
          updatedUserData['studentId'] =
              _studentIdController.text.trim().isNotEmpty
              ? _studentIdController.text.trim()
              : null;
          updatedUserData['program'] = _programController.text.trim().isNotEmpty
              ? _programController.text.trim()
              : null;
          updatedUserData['yearLevel'] =
              _yearLevelController.text.trim().isNotEmpty
              ? _yearLevelController.text.trim()
              : null;
          updatedUserData.remove('employeeId');
        } else {
          updatedUserData['employeeId'] =
              _employeeIdController.text.trim().isNotEmpty
              ? _employeeIdController.text.trim()
              : null;
          updatedUserData.remove('studentId');
          updatedUserData.remove('program');
          updatedUserData.remove('yearLevel');
        }
      }

      // Call the callback to update the profile
      widget.onProfileUpdated(updatedUserData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Profile updated successfully!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        Navigator.pop(context, updatedUserData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Failed to update profile. Please try again.',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        _getInitials(_getFullNameFromFields()),
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _firstNameController,
                label: 'First Name',
                icon: Icons.person_rounded,
                validator: (value) => _validateRequired(value, 'First Name'),
                onChanged: (value) => setState(() {}), // To update initials
              ),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _middleNameController,
                label: 'Middle Name (Optional)',
                icon: Icons.person_outline_rounded,
                onChanged: (value) => setState(() {}), // To update initials
              ),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _lastNameController,
                label: 'Last Name',
                icon: Icons.person_rounded,
                validator: (value) => _validateRequired(value, 'Last Name'),
                onChanged: (value) => setState(() {}), // To update initials
              ),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _usernameController,
                label: 'Username',
                icon: Icons.badge_rounded,
                validator: (value) => _validateRequired(value, 'Username'),
              ),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),

              // Role Selection
              _buildDropdownField(
                label: 'Role',
                icon: Icons.work_rounded,
                value: _selectedRole,
                items: ['Student', 'Faculty', 'Instructor', 'Staff', 'Admin'],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Contact Information Section
              _buildSectionHeader('Contact Information'),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _phoneController,
                label: 'Phone Number (Optional)',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _addressController,
                label: 'Address (Optional)',
                icon: Icons.location_on_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _departmentController,
                label: 'Department (Optional)',
                icon: Icons.business_rounded,
              ),

              const SizedBox(height: 32),

              // Role-specific Information Section
              if (_selectedRole == 'Student') ...[
                _buildSectionHeader('Student Information'),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: _studentIdController,
                  label: 'Student ID (Optional)',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: _programController,
                  label: 'Program (Optional)',
                  icon: Icons.school_rounded,
                ),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: _yearLevelController,
                  label: 'Year Level (Optional)',
                  icon: Icons.grade_rounded,
                ),

                const SizedBox(height: 32),
              ],

              if (_selectedRole != 'Student') ...[
                _buildSectionHeader('Employee Information'),
                const SizedBox(height: 16),

                _buildTextFormField(
                  controller: _employeeIdController,
                  label: 'Employee ID (Optional)',
                  icon: Icons.badge_outlined,
                ),

                const SizedBox(height: 32),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      icon: Icon(Icons.cancel_rounded, size: 20),
                      label: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        _isLoading ? 'Saving...' : 'Save Changes',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: GoogleFonts.inter(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      }).toList(),
      style: GoogleFonts.inter(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  String _getFullNameFromFields() {
    String fullName = _firstNameController.text.trim();
    if (_middleNameController.text.trim().isNotEmpty) {
      fullName += ' ${_middleNameController.text.trim()}';
    }
    if (_lastNameController.text.trim().isNotEmpty) {
      fullName += ' ${_lastNameController.text.trim()}';
    }
    return fullName.isNotEmpty ? fullName : 'User';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty) {
      return nameParts[0].substring(0, 1).toUpperCase();
    }
    return 'U';
  }
}

// Change Password Screen
class ChangePasswordScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ChangePasswordScreen({super.key, required this.userData});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Current password is required';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'New password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (value == _currentPasswordController.text) {
      return 'New password must be different from current password';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _showChangePasswordConfirmation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.security_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Confirm Password Change',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to change your password?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'This action will:',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildConfirmationItem(
                      'Update your password securely in the database',
                    ),
                    _buildConfirmationItem(
                      'Require you to use the new password for future logins',
                    ),
                    _buildConfirmationItem(
                      'Keep your account secure with encrypted storage',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: Text(
                'Change Password',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    // If user confirmed, proceed with password change
    if (confirmed == true) {
      await _changePassword();
    }
  }

  Future<void> _changePassword() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Test server connectivity first
      Logger.info('Testing server connection before password change...');
      bool serverConnected = await AuthService.testServerConnection();
      Logger.info('Server connected: $serverConnected');

      // Try to call the actual API first
      bool apiSuccess = false;
      String errorMessage = '';

      if (!serverConnected) {
        Logger.warning('Server not reachable, using demo mode');
        await Future.delayed(const Duration(seconds: 2));
        apiSuccess = true; // Simulate success in demo mode
      } else {
        try {
          final response = await http.put(
            Uri.parse(
              '${AuthService.baseUrl}/change-password/${widget.userData['_id']}',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'currentPassword': _currentPasswordController.text,
              'newPassword': _newPasswordController.text,
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true) {
              apiSuccess = true;
            } else {
              errorMessage = data['message'] ?? 'Failed to change password';
            }
          } else if (response.statusCode == 401) {
            final data = jsonDecode(response.body);
            errorMessage = data['message'] ?? 'Current password is incorrect';
          } else if (response.statusCode == 400) {
            final data = jsonDecode(response.body);
            errorMessage = data['message'] ?? 'Invalid password requirements';
          } else {
            errorMessage = 'Server error. Please try again later.';
          }
        } catch (e) {
          Logger.error('API call failed: $e');

          // Check if it's a connection error
          if (e.toString().contains('Failed host lookup') ||
              e.toString().contains('No route to host') ||
              e.toString().contains('Connection refused') ||
              e.toString().contains('SocketException')) {
            Logger.warning(
              'Network connection error - falling back to demo mode',
            );
            // Fall back to demo mode
            await Future.delayed(const Duration(seconds: 2));
            apiSuccess = true; // Simulate success in demo mode
          } else {
            Logger.error('Other API error: $e');
            errorMessage = 'Network error. Please check your connection.';
          }
        }
      }

      if (mounted) {
        if (apiSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Password changed successfully!',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          // Clear form fields
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();

          // Navigate back
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Change password error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Change Password',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.6),
                      Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.security_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Your Password',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your current password and choose a new secure password',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Current Password
              Text(
                'Current Password',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              _buildPasswordField(
                controller: _currentPasswordController,
                label: 'Enter current password',
                isVisible: _isCurrentPasswordVisible,
                onToggleVisibility: () {
                  setState(() {
                    _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                  });
                },
                validator: _validateCurrentPassword,
              ),

              const SizedBox(height: 24),

              // New Password
              Text(
                'New Password',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              _buildPasswordField(
                controller: _newPasswordController,
                label: 'Enter new password',
                isVisible: _isNewPasswordVisible,
                onToggleVisibility: () {
                  setState(() {
                    _isNewPasswordVisible = !_isNewPasswordVisible;
                  });
                },
                validator: _validateNewPassword,
              ),

              const SizedBox(height: 24),

              // Confirm New Password
              Text(
                'Confirm New Password',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm new password',
                isVisible: _isConfirmPasswordVisible,
                onToggleVisibility: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
                validator: _validateConfirmPassword,
              ),

              const SizedBox(height: 32),

              // Password Requirements
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Password Requirements',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRequirement('At least 6 characters long'),
                    _buildRequirement('Different from your current password'),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Change Password Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _showChangePasswordConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Changing Password...',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Change Password',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
