import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/face_registration_models.dart';

class EnhancedFacePainter extends CustomPainter {
  final Face face;
  final Size imageSize;
  final Color primaryColor;
  final double animationValue;
  final String currentStep;
  final FaceQualityAnalysis? qualityAnalysis;
  final bool showLandmarks;
  final bool showContours;
  final bool showQualityIndicators;
  final bool showGuidelines;

  EnhancedFacePainter({
    required this.face,
    required this.imageSize,
    this.primaryColor = const Color(0xFF00FFFF),
    this.animationValue = 1.0,
    this.currentStep = 'center',
    this.qualityAnalysis,
    this.showLandmarks = true,
    this.showContours = true,
    this.showQualityIndicators = true,
    this.showGuidelines = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw guidelines first (behind face detection)
    if (showGuidelines) {
      _drawGuidelines(canvas, size);
    }

    // Draw main face detection with quality-based colors
    _drawFaceDetection(canvas, size);

    // Draw detailed landmarks with different colors and sizes
    if (showLandmarks) {
      _drawEnhancedLandmarks(canvas, size);
    }

    // Draw face contours with step-specific emphasis
    if (showContours) {
      _drawStepSpecificContours(canvas, size);
    }

    // Draw quality indicators
    if (showQualityIndicators && qualityAnalysis != null) {
      _drawQualityIndicators(canvas, size);
    }

    // Draw step-specific guides
    _drawStepGuides(canvas, size);
  }

  void _drawGuidelines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2 * animationValue)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw center cross
    canvas.drawLine(
      Offset(centerX - 50, centerY),
      Offset(centerX + 50, centerY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - 50),
      Offset(centerX, centerY + 50),
      paint,
    );

    // Draw rule of thirds grid
    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    for (int i = 1; i < 3; i++) {
      // Vertical lines
      canvas.drawLine(
        Offset(thirdWidth * i, 0),
        Offset(thirdWidth * i, size.height),
        paint,
      );
      // Horizontal lines
      canvas.drawLine(
        Offset(0, thirdHeight * i),
        Offset(size.width, thirdHeight * i),
        paint,
      );
    }
  }

  void _drawFaceDetection(Canvas canvas, Size size) {
    final boundingBox = face.boundingBox;
    
    // Get quality-based color
    Color faceColor = primaryColor;
    if (qualityAnalysis != null) {
      if (qualityAnalysis!.overall >= 0.8) {
        faceColor = Colors.green;
      } else if (qualityAnalysis!.overall >= 0.6) {
        faceColor = Colors.orange;
      } else {
        faceColor = Colors.red;
      }
    }

    // Transform bounding box coordinates
    final topLeft = _transformPoint(
      math.Point(boundingBox.left.toInt(), boundingBox.top.toInt()),
      size,
    );
    final bottomRight = _transformPoint(
      math.Point(boundingBox.right.toInt(), boundingBox.bottom.toInt()),
      size,
    );

    final rect = Rect.fromPoints(topLeft, bottomRight);

    // Draw main bounding box with animated thickness
    final boxPaint = Paint()
      ..color = faceColor.withValues(alpha: 0.8 * animationValue)
      ..strokeWidth = 3.0 + (2.0 * animationValue)
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, boxPaint);

    // Draw corner markers for better visibility
    _drawCornerMarkers(canvas, rect, faceColor);

    // Draw center point
    final centerPaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;

    final centerX = (rect.left + rect.right) / 2;
    final centerY = (rect.top + rect.bottom) / 2;
    canvas.drawCircle(Offset(centerX, centerY), 4.0, centerPaint);
  }

  void _drawCornerMarkers(Canvas canvas, Rect rect, Color color) {
    final cornerPaint = Paint()
      ..color = color.withValues(alpha: 0.9 * animationValue)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0 * animationValue;

    // Animated corner markers
    final corners = [
      // Top-left
      [Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top)],
      [Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLength)],
      // Top-right
      [Offset(rect.right, rect.top), Offset(rect.right - cornerLength, rect.top)],
      [Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength)],
      // Bottom-left
      [Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom)],
      [Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLength)],
      // Bottom-right
      [Offset(rect.right, rect.bottom), Offset(rect.right - cornerLength, rect.bottom)],
      [Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength)],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], cornerPaint);
    }
  }

  void _drawEnhancedLandmarks(Canvas canvas, Size size) {
    final landmarks = face.landmarks;

    // Enhanced landmark styles with categories
    final landmarkCategories = {
      'eyes': {
        'landmarks': [FaceLandmarkType.leftEye, FaceLandmarkType.rightEye],
        'color': Colors.lightBlue,
        'size': 6.0,
        'importance': 'high',
      },
      'nose': {
        'landmarks': [FaceLandmarkType.noseBase],
        'color': Colors.lightGreen,
        'size': 5.0,
        'importance': 'high',
      },
      'mouth': {
        'landmarks': [
          FaceLandmarkType.leftMouth,
          FaceLandmarkType.rightMouth,
          FaceLandmarkType.bottomMouth
        ],
        'color': Colors.redAccent,
        'size': 5.0,
        'importance': 'high',
      },
      'face': {
        'landmarks': [
          FaceLandmarkType.leftCheek,
          FaceLandmarkType.rightCheek,
          FaceLandmarkType.leftEar,
          FaceLandmarkType.rightEar
        ],
        'color': Colors.deepOrange,
        'size': 4.0,
        'importance': 'medium',
      },
    };

    landmarkCategories.forEach((category, config) {
      final landmarkTypes = config['landmarks'] as List<FaceLandmarkType>;
      final color = config['color'] as Color;
      final landmarkSize = config['size'] as double;
      final importance = config['importance'] as String;

      for (final type in landmarkTypes) {
        final landmark = landmarks[type];
        if (landmark != null) {
          final point = _transformPoint(landmark.position, size);
          
          // Draw landmark with glow effect
          _drawLandmarkWithGlow(canvas, point, color, landmarkSize, importance);
          
          // Add landmark label for high importance ones
          if (importance == 'high') {
            _drawLandmarkLabel(canvas, point, _getLandmarkLabel(type), color);
          }
        }
      }
    });
  }

  void _drawLandmarkWithGlow(
    Canvas canvas,
    Offset point,
    Color color,
    double size,
    String importance,
  ) {
    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * animationValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(point, size * 2.0 * animationValue, glowPaint);

    // Middle ring
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.6 * animationValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(point, size * 1.2, ringPaint);

    // Inner dot
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.9 * animationValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, size, dotPaint);

    // Center highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8 * animationValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, size * 0.3, highlightPaint);
  }

  void _drawLandmarkLabel(Canvas canvas, Offset point, String label, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Draw label with background
    final labelOffset = Offset(
      point.dx - textPainter.width / 2,
      point.dy - 20,
    );
    
    // Background
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - 4,
          labelOffset.dy - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
      ),
      bgPaint,
    );
    
    textPainter.paint(canvas, labelOffset);
  }

  void _drawStepSpecificContours(Canvas canvas, Size size) {
    final contours = face.contours;

    // Step-specific contour emphasis
    final emphasizedContours = _getStepContours(currentStep);

    contours.forEach((type, contour) {
      if (contour != null && contour.points.isNotEmpty) {
        final isEmphasized = emphasizedContours.contains(type);
        final color = isEmphasized ? Colors.yellow : primaryColor;
        final strokeWidth = isEmphasized ? 3.0 : 2.0;
        final opacity = isEmphasized ? 0.9 : 0.6;

        final paint = Paint()
          ..color = color.withValues(alpha: opacity * animationValue)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final path = Path();
        final firstPoint = _transformPoint(contour.points.first, size);
        path.moveTo(firstPoint.dx, firstPoint.dy);

        for (int i = 1; i < contour.points.length; i++) {
          final point = _transformPoint(contour.points[i], size);
          path.lineTo(point.dx, point.dy);
        }

        // Close certain contours
        if (_shouldCloseContour(type)) {
          path.close();
        }

        canvas.drawPath(path, paint);
      }
    });
  }

  void _drawQualityIndicators(Canvas canvas, Size size) {
    if (qualityAnalysis == null) return;

    final quality = qualityAnalysis!;
    final indicatorSize = 60.0;
    final margin = 20.0;

    // Overall quality indicator (top-right)
    _drawQualityMeter(
      canvas,
      Offset(size.width - indicatorSize - margin, margin),
      indicatorSize,
      quality.overall,
      'Overall',
      _getQualityColor(quality.overall),
    );

    // Individual quality metrics (right side) - Enhanced with new metrics
    final metrics = [
      ('Light', quality.lighting),
      ('Sharp', quality.sharpness),
      ('Pose', quality.pose),
      ('Eyes', quality.eyeOpenness),
      ('Landmarks', quality.landmarkQuality),
      ('Contours', quality.contourCompleteness),
    ];

    for (int i = 0; i < metrics.length; i++) {
      final (label, value) = metrics[i];
      final y = margin + 80 + (i * 50.0);
      
      _drawQualityBar(
        canvas,
        Offset(size.width - 120, y),
        100.0,
        20.0,
        value,
        label,
        _getQualityColor(value),
      );
    }
  }

  void _drawQualityMeter(
    Canvas canvas,
    Offset center,
    double size,
    double value,
    String label,
    Color color,
  ) {
    // Background circle
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2, bgPaint);

    // Quality arc
    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(center: center, width: size - 10, height: size - 10);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, arcPaint);

    // Percentage text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(value * 100).toInt()}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    // Label
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy + 15,
      ),
    );
  }

  void _drawQualityBar(
    Canvas canvas,
    Offset position,
    double width,
    double height,
    double value,
    String label,
    Color color,
  ) {
    // Background
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(position.dx, position.dy, width, height),
      bgPaint,
    );

    // Progress bar
    final progressPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(position.dx, position.dy, width * value, height),
      progressPaint,
    );

    // Label
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    
    labelPainter.layout();
    labelPainter.paint(canvas, Offset(position.dx - 45, position.dy + 5));
  }

  void _drawStepGuides(Canvas canvas, Size size) {
    // Draw step-specific guides and instructions
    switch (currentStep) {
      case 'up':
        _drawDirectionalArrow(canvas, size, Offset(size.width / 2, 50), 0, Colors.green);
        break;
      case 'down':
        _drawDirectionalArrow(canvas, size, Offset(size.width / 2, size.height - 50), math.pi, Colors.orange);
        break;
      case 'left':
        _drawDirectionalArrow(canvas, size, Offset(50, size.height / 2), -math.pi / 2, Colors.purple);
        break;
      case 'right':
        _drawDirectionalArrow(canvas, size, Offset(size.width - 50, size.height / 2), math.pi / 2, Colors.teal);
        break;
    }
  }

  void _drawDirectionalArrow(
    Canvas canvas,
    Size size,
    Offset position,
    double rotation,
    Color color,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7 * animationValue)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);

    // Arrow shape
    final path = Path();
    path.moveTo(0, -20);
    path.lineTo(0, 20);
    path.moveTo(-10, 10);
    path.lineTo(0, 20);
    path.lineTo(10, 10);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  Offset _transformPoint(math.Point<int> point, Size canvasSize) {
    final double scaleX = canvasSize.width / imageSize.width;
    final double scaleY = canvasSize.height / imageSize.height;
    
    final double scaledX = point.x * scaleX;
    final double scaledY = point.y * scaleY;
    
    // Mirror horizontally for front camera
    final double mirroredX = canvasSize.width - scaledX;
    
    return Offset(mirroredX, scaledY);
  }

  String _getLandmarkLabel(FaceLandmarkType type) {
    switch (type) {
      case FaceLandmarkType.leftEye:
        return 'L Eye';
      case FaceLandmarkType.rightEye:
        return 'R Eye';
      case FaceLandmarkType.noseBase:
        return 'Nose';
      case FaceLandmarkType.leftMouth:
        return 'L Mouth';
      case FaceLandmarkType.rightMouth:
        return 'R Mouth';
      case FaceLandmarkType.bottomMouth:
        return 'B Mouth';
      default:
        return '';
    }
  }

  List<FaceContourType> _getStepContours(String step) {
    switch (step) {
      case 'blink':
        return [FaceContourType.leftEye, FaceContourType.rightEye];
      case 'smile':
        return [
          FaceContourType.upperLipTop,
          FaceContourType.upperLipBottom,
          FaceContourType.lowerLipTop,
          FaceContourType.lowerLipBottom,
        ];
      default:
        return [FaceContourType.face];
    }
  }

  bool _shouldCloseContour(FaceContourType type) {
    return [
      FaceContourType.face,
      FaceContourType.leftEye,
      FaceContourType.rightEye,
    ].contains(type);
  }

  Color _getQualityColor(double quality) {
    if (quality >= 0.8) return Colors.green;
    if (quality >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  bool shouldRepaint(EnhancedFacePainter oldDelegate) {
    return face != oldDelegate.face ||
        animationValue != oldDelegate.animationValue ||
        currentStep != oldDelegate.currentStep ||
        qualityAnalysis != oldDelegate.qualityAnalysis;
  }
}
