import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class EnhancedFaceGuidePainter extends CustomPainter {
  final String currentStep;
  final Color stepColor;
  final Face? detectedFace;
  final double animationValue;

  EnhancedFaceGuidePainter({
    required this.currentStep,
    required this.stepColor,
    this.detectedFace,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw main face guide frame
    _drawFaceGuideFrame(canvas, size);
    
    // Draw step-specific guidance
    _drawStepGuidance(canvas, size);
    
    // Draw positioning grid
    _drawPositioningGrid(canvas, size);
    
    // Draw face detection feedback
    if (detectedFace != null) {
      _drawFaceDetectionFeedback(canvas, size);
    }
  }

  void _drawFaceGuideFrame(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stepColor.withValues(alpha: 0.6 * animationValue)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Calculate ideal face position (centered, taking up ~40% of height)
    final faceHeight = size.height * 0.4;
    final faceWidth = faceHeight * 0.75; // Face aspect ratio
    final left = (size.width - faceWidth) / 2;
    final top = (size.height - faceHeight) / 2 - size.height * 0.05; // Slightly higher

    final rect = Rect.fromLTWH(left, top, faceWidth, faceHeight);

    // Draw oval face guide
    canvas.drawOval(rect, paint);

    // Draw corner indicators
    _drawCornerIndicators(canvas, rect, stepColor);

    // Draw center alignment guides
    _drawAlignmentGuides(canvas, size, stepColor);
  }

  void _drawCornerIndicators(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8 * animationValue)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerSize = 20.0 * animationValue;

    // Top-left
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerSize),
      Offset(rect.left, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerSize, rect.top),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(rect.right - cornerSize, rect.top),
      Offset(rect.right, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerSize),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerSize),
      Offset(rect.left, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerSize, rect.bottom),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(rect.right - cornerSize, rect.bottom),
      Offset(rect.right, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerSize),
      paint,
    );
  }

  void _drawAlignmentGuides(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3 * animationValue)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Vertical center line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Horizontal center line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Rule of thirds grid
    for (int i = 1; i < 3; i++) {
      // Vertical lines
      final x = size.width * i / 3;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );

      // Horizontal lines
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawStepGuidance(Canvas canvas, Size size) {
    switch (currentStep) {
      case 'up':
        _drawUpArrow(canvas, size);
        break;
      case 'down':
        _drawDownArrow(canvas, size);
        break;
      case 'left':
        _drawLeftArrow(canvas, size);
        break;
      case 'right':
        _drawRightArrow(canvas, size);
        break;
      case 'center':
      default:
        _drawCenterIndicator(canvas, size);
        break;
    }
  }

  void _drawCenterIndicator(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stepColor.withValues(alpha: 0.8 * animationValue)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 8.0 * animationValue, paint);

    // Concentric circles
    final strokePaint = Paint()
      ..color = stepColor.withValues(alpha: 0.4 * animationValue)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, 8.0 * i * 2 * animationValue, strokePaint);
    }
  }

  void _drawUpArrow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stepColor.withValues(alpha: 0.8 * animationValue)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height * 0.3);
    final arrowSize = 30.0 * animationValue;

    // Arrow shaft
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy + arrowSize),
      paint,
    );

    // Arrow head
    canvas.drawLine(
      Offset(center.dx - arrowSize / 3, center.dy + arrowSize / 3),
      center,
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + arrowSize / 3, center.dy + arrowSize / 3),
      center,
      paint,
    );
  }

  void _drawDownArrow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stepColor.withValues(alpha: 0.8 * animationValue)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height * 0.7);
    final arrowSize = 30.0 * animationValue;

    // Arrow shaft
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - arrowSize),
      paint,
    );

    // Arrow head
    canvas.drawLine(
      Offset(center.dx - arrowSize / 3, center.dy - arrowSize / 3),
      center,
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + arrowSize / 3, center.dy - arrowSize / 3),
      center,
      paint,
    );
  }

  void _drawLeftArrow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stepColor.withValues(alpha: 0.8 * animationValue)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.25, size.height / 2);
    final arrowSize = 30.0 * animationValue;

    // Arrow shaft
    canvas.drawLine(
      center,
      Offset(center.dx + arrowSize, center.dy),
      paint,
    );

    // Arrow head
    canvas.drawLine(
      Offset(center.dx + arrowSize / 3, center.dy - arrowSize / 3),
      center,
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + arrowSize / 3, center.dy + arrowSize / 3),
      center,
      paint,
    );
  }

  void _drawRightArrow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stepColor.withValues(alpha: 0.8 * animationValue)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.75, size.height / 2);
    final arrowSize = 30.0 * animationValue;

    // Arrow shaft
    canvas.drawLine(
      center,
      Offset(center.dx - arrowSize, center.dy),
      paint,
    );

    // Arrow head
    canvas.drawLine(
      Offset(center.dx - arrowSize / 3, center.dy - arrowSize / 3),
      center,
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - arrowSize / 3, center.dy + arrowSize / 3),
      center,
      paint,
    );
  }

  void _drawPositioningGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1 * animationValue)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Fine grid for precise positioning
    const gridSize = 20;
    for (int i = 0; i <= gridSize; i++) {
      final x = size.width * i / gridSize;
      final y = size.height * i / gridSize;

      // Vertical lines
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );

      // Horizontal lines
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawFaceDetectionFeedback(Canvas canvas, Size size) {
    final box = detectedFace!.boundingBox;
    
    // Transform face coordinates to screen coordinates
    final scaleX = size.width / 640; // Assuming input image width
    final scaleY = size.height / 480; // Assuming input image height
    
    final faceRect = Rect.fromLTWH(
      box.left * scaleX,
      box.top * scaleY,
      box.width * scaleX,
      box.height * scaleY,
    );

    // Feedback based on face position
    final centerX = faceRect.center.dx / size.width;
    final centerY = faceRect.center.dy / size.height;
    
    Color feedbackColor = stepColor;
    if ((centerX - 0.5).abs() > 0.15 || (centerY - 0.5).abs() > 0.15) {
      feedbackColor = Colors.orange; // Face not centered
    } else if (faceRect.width < size.width * 0.2 || faceRect.width > size.width * 0.6) {
      feedbackColor = Colors.red; // Face too small or too large
    } else {
      feedbackColor = Colors.green; // Good positioning
    }

    // Draw feedback indicator
    final feedbackPaint = Paint()
      ..color = feedbackColor.withValues(alpha: 0.8 * animationValue)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(faceRect, feedbackPaint);

    // Draw positioning arrows if needed
    if ((centerX - 0.5).abs() > 0.1) {
      _drawPositioningArrows(canvas, size, centerX < 0.5 ? 'move-right' : 'move-left');
    }
    if ((centerY - 0.5).abs() > 0.1) {
      _drawPositioningArrows(canvas, size, centerY < 0.5 ? 'move-down' : 'move-up');
    }
  }

  void _drawPositioningArrows(Canvas canvas, Size size, String direction) {
    final paint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.8 * animationValue)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arrowSize = 20.0;
    final center = Offset(size.width / 2, size.height / 2);

    switch (direction) {
      case 'move-right':
        canvas.drawLine(
          Offset(center.dx + 50, center.dy),
          Offset(center.dx + 80, center.dy),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx + 70, center.dy - 10),
          Offset(center.dx + 80, center.dy),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx + 70, center.dy + 10),
          Offset(center.dx + 80, center.dy),
          paint,
        );
        break;
      case 'move-left':
        canvas.drawLine(
          Offset(center.dx - 50, center.dy),
          Offset(center.dx - 80, center.dy),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx - 70, center.dy - 10),
          Offset(center.dx - 80, center.dy),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx - 70, center.dy + 10),
          Offset(center.dx - 80, center.dy),
          paint,
        );
        break;
      case 'move-up':
        canvas.drawLine(
          Offset(center.dx, center.dy - 50),
          Offset(center.dx, center.dy - 80),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx - 10, center.dy - 70),
          Offset(center.dx, center.dy - 80),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx + 10, center.dy - 70),
          Offset(center.dx, center.dy - 80),
          paint,
        );
        break;
      case 'move-down':
        canvas.drawLine(
          Offset(center.dx, center.dy + 50),
          Offset(center.dx, center.dy + 80),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx - 10, center.dy + 70),
          Offset(center.dx, center.dy + 80),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx + 10, center.dy + 70),
          Offset(center.dx, center.dy + 80),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(EnhancedFaceGuidePainter oldDelegate) {
    return currentStep != oldDelegate.currentStep ||
        stepColor != oldDelegate.stepColor ||
        detectedFace != oldDelegate.detectedFace ||
        animationValue != oldDelegate.animationValue;
  }
}
