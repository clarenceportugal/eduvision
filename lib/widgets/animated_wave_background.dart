import 'package:flutter/material.dart';
import 'dart:math';

// Animated Wave Background Widget
class AnimatedWaveBackground extends StatefulWidget {
  final Widget child;
  final double height;
  final bool useFullScreen;

  const AnimatedWaveBackground({
    super.key,
    required this.child,
    this.height = 300,
    this.useFullScreen = false,
  });

  @override
  State<AnimatedWaveBackground> createState() => _AnimatedWaveBackgroundState();
}

class _AnimatedWaveBackgroundState extends State<AnimatedWaveBackground>
    with TickerProviderStateMixin {
  late AnimationController _waveController1;
  late AnimationController _waveController2;
  late AnimationController _waveController3;
  late AnimationController _colorController;

  late Animation<double> _waveAnimation1;
  late Animation<double> _waveAnimation2;
  late Animation<double> _waveAnimation3;
  late Animation<double> _colorAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize wave animation controllers with optimized speeds
    _waveController1 = AnimationController(
      duration: const Duration(seconds: 12), // Slower for better performance
      vsync: this,
    );

    _waveController2 = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _waveController3 = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );

    _colorController = AnimationController(
      duration: const Duration(seconds: 20), // Much slower
      vsync: this,
    );

    // Create wave animations
    _waveAnimation1 = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159, // 2π for full wave cycle
    ).animate(CurvedAnimation(parent: _waveController1, curve: Curves.linear));

    _waveAnimation2 = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(parent: _waveController2, curve: Curves.linear));

    _waveAnimation3 = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(parent: _waveController3, curve: Curves.linear));

    _colorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
    );

    // Start all animations
    _waveController1.repeat();
    _waveController2.repeat();
    _waveController3.repeat();
    _colorController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController1.dispose();
    _waveController2.dispose();
    _waveController3.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Animated Wave Background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _waveController1,
              _waveController2,
              _waveController3,
              _colorController,
            ]),
            builder: (context, child) {
              return CustomPaint(
                painter: WavePainter(
                  waveAnimation1: _waveAnimation1.value,
                  waveAnimation2: _waveAnimation2.value,
                  waveAnimation3: _waveAnimation3.value,
                  colorAnimation: _colorAnimation.value,
                  isDarkMode: isDark,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
        // Content on top of waves
        widget.child,
      ],
    );
  }
}

// Custom Wave Painter
class WavePainter extends CustomPainter {
  final double waveAnimation1;
  final double waveAnimation2;
  final double waveAnimation3;
  final double colorAnimation;
  final bool isDarkMode;

  WavePainter({
    required this.waveAnimation1,
    required this.waveAnimation2,
    required this.waveAnimation3,
    required this.colorAnimation,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Define color palettes for light and dark modes - ultra subtle
    final List<Color> lightColors = [
      Color(0xFF667EEA).withValues(alpha: 0.01),
      Color(0xFF764BA2).withValues(alpha: 0.015),
      Color(0xFF6B73FF).withValues(alpha: 0.008),
      Color(0xFF9FACE6).withValues(alpha: 0.012),
      Color(0xFF74EBD5).withValues(alpha: 0.01),
    ];

    final List<Color> darkColors = [
      Color(0xFF667EEA).withValues(alpha: 0.008),
      Color(0xFF764BA2).withValues(alpha: 0.012),
      Color(0xFF6B73FF).withValues(alpha: 0.006),
      Color(0xFF9FACE6).withValues(alpha: 0.01),
      Color(0xFF74EBD5).withValues(alpha: 0.008),
    ];

    final colors = isDarkMode ? darkColors : lightColors;

    // Wave 1 - Bottom layer (largest)
    _drawWave(
      canvas,
      size,
      waveAnimation1,
      25, // amplitude (reduced from 80)
      0.8, // frequency
      size.height * 0.8, // base height (moved down)
      [colors[0], colors[1]],
    );

    // Wave 2 - Middle layer
    _drawWave(
      canvas,
      size,
      waveAnimation2 + 1.0, // phase offset
      20, // amplitude (reduced from 60)
      1.2, // frequency
      size.height * 0.6, // base height (moved down)
      [colors[2], colors[3]],
    );

    // Wave 3 - Top layer (smallest)
    _drawWave(
      canvas,
      size,
      waveAnimation3 + 2.0, // phase offset
      15, // amplitude (reduced from 40)
      1.5, // frequency
      size.height * 0.4, // base height (moved down)
      [colors[4], colors[0]],
    );

    // Additional floating particles/bubbles
    _drawFloatingElements(canvas, size, colorAnimation, colors);
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    double animation,
    double amplitude,
    double frequency,
    double baseHeight,
    List<Color> gradientColors,
  ) {
    final path = Path();
    final paint = Paint();

    // Create gradient
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: gradientColors,
      stops: [0.0, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Start path at bottom left
    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);

    // Create wave using sine function
    for (double x = 0; x <= size.width; x += 2) {
      double y =
          baseHeight +
          amplitude *
              sin(frequency * (x / size.width) * 2 * 3.14159 + animation);
      path.lineTo(x, y);
    }

    // Complete the path
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawFloatingElements(
    Canvas canvas,
    Size size,
    double animation,
    List<Color> colors,
  ) {
    final paint = Paint();
    final random = Random(42); // Fixed seed for consistent positioning

    // Draw floating circles/bubbles
    for (int i = 0; i < 8; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height * 0.6) + (size.height * 0.2);
      final radius = 2 + (random.nextDouble() * 3);
      final opacity = 0.1 + (random.nextDouble() * 0.2);

      paint.color = colors[i % colors.length].withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
