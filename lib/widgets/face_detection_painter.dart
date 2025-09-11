import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Enhanced face detection painter compatible with your registration screen
class FaceDetectionPainter extends CustomPainter {
  final List<Face> faces;
  final Face? face; // Single face support for your registration screen
  final Size imageSize;
  final Size previewSize;
  final InputImageRotation rotation;
  final Color primaryColor;
  final Color? color; // Alternative color for your registration screen
  final double animationValue;
  final bool showLandmarks;
  final bool showContours;

  // Constructor for multiple faces (verification screen)
  FaceDetectionPainter({
    required this.faces,
    this.face,
    this.imageSize = const Size(1280, 720),
    this.previewSize = const Size(1280, 720),
    this.rotation = InputImageRotation.rotation0deg,
    this.primaryColor = const Color(0xFF00FFFF),
    this.color,
    this.animationValue = 1.0,
    this.showLandmarks = true,
    this.showContours = false,
  });

  // Constructor for single face (registration screen compatibility)
  FaceDetectionPainter.single(Face this.face, Color this.color)
    : faces = [face],
      primaryColor = color,
      imageSize = const Size(1280, 720),
      previewSize = const Size(1280, 720),
      rotation = InputImageRotation.rotation0deg,
      animationValue = 1.0,
      showLandmarks = true,
      showContours = false;

  @override
  void paint(Canvas canvas, Size size) {
    // Handle both single face and multiple faces
    final facesToDraw = face != null ? [face!] : faces;
    if (facesToDraw.isEmpty) return;

    // Use the appropriate color
    final activeColor = color ?? primaryColor;

    // For registration screen compatibility - simple drawing
    if (face != null) {
      _drawSimpleFaceDetection(canvas, size, face!, activeColor);
    } else {
      // For verification screen - enhanced drawing with landmarks
      _drawEnhancedFaceDetection(canvas, size, faces, activeColor);
    }
  }

  // Enhanced face detection with detailed landmarks for registration screen
  void _drawSimpleFaceDetection(
    Canvas canvas,
    Size size,
    Face detectedFace,
    Color faceColor,
  ) {
    // Main face bounding box with proper coordinate transformation
    final boxPaint = Paint()
      ..color = faceColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Transform bounding box coordinates to match camera preview using the final method
    final topLeft = _transformPointFinal(
      math.Point(
        detectedFace.boundingBox.left.toInt(),
        detectedFace.boundingBox.top.toInt(),
      ),
      size,
    );
    final bottomRight = _transformPointFinal(
      math.Point(
        detectedFace.boundingBox.right.toInt(),
        detectedFace.boundingBox.bottom.toInt(),
      ),
      size,
    );

    final rect = Rect.fromPoints(topLeft, bottomRight);
    canvas.drawRect(rect, boxPaint);

    // Draw corner markers for better face alignment
    _drawCornerMarkers(canvas, rect, faceColor);

    // Draw detailed landmarks with different colors
    _drawDetailedLandmarks(canvas, detectedFace, faceColor, size);

    // Draw face contours (eyebrows, mouth, nose, jawlines)
    _drawDetailedContours(canvas, detectedFace, faceColor, size);
  }

  // Draw corner markers for better face positioning
  void _drawCornerMarkers(Canvas canvas, Rect rect, Color color) {
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final cornerLength = 25.0;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.top + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right - cornerLength, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.bottom - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - cornerLength, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      cornerPaint,
    );

    // Center crosshair for perfect alignment
    final centerX = (rect.left + rect.right) / 2;
    final centerY = (rect.top + rect.bottom) / 2;
    final crossSize = 15.0;

    canvas.drawLine(
      Offset(centerX - crossSize, centerY),
      Offset(centerX + crossSize, centerY),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - crossSize),
      Offset(centerX, centerY + crossSize),
      cornerPaint,
    );
  }

  // Draw detailed landmarks with color coding
  void _drawDetailedLandmarks(
    Canvas canvas,
    Face detectedFace,
    Color faceColor,
    Size canvasSize,
  ) {
    final landmarks = detectedFace.landmarks;

    // Enhanced landmark styles with better colors and visibility
    final Map<FaceLandmarkType, LandmarkStyle> landmarkStyles = {
      FaceLandmarkType.leftEye: LandmarkStyle(Colors.lightBlue, 5.0),
      FaceLandmarkType.rightEye: LandmarkStyle(Colors.lightBlue, 5.0),
      FaceLandmarkType.noseBase: LandmarkStyle(Colors.lightGreen, 4.5),
      FaceLandmarkType.leftMouth: LandmarkStyle(Colors.redAccent, 4.0),
      FaceLandmarkType.rightMouth: LandmarkStyle(Colors.redAccent, 4.0),
      FaceLandmarkType.bottomMouth: LandmarkStyle(Colors.red, 4.0),
      FaceLandmarkType.leftCheek: LandmarkStyle(Colors.deepOrange, 3.5),
      FaceLandmarkType.rightCheek: LandmarkStyle(Colors.deepOrange, 3.5),
      FaceLandmarkType.leftEar: LandmarkStyle(Colors.deepPurple, 3.0),
      FaceLandmarkType.rightEar: LandmarkStyle(Colors.deepPurple, 3.0),
    };

    landmarks.forEach((type, landmark) {
      if (landmark != null) {
        final style = landmarkStyles[type] ?? LandmarkStyle(faceColor, 4.0);

        // Main landmark point using the final transformation
        final paint = Paint()
          ..color = style.color
          ..style = PaintingStyle.fill;

        final point = _transformPointFinal(landmark.position, canvasSize);

        canvas.drawCircle(point, style.size, paint);

        // Add glow effect for better visibility
        final glowPaint = Paint()
          ..color = style.color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawCircle(point, style.size * 1.5, glowPaint);

        // Add small white center dot for precision
        final centerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, 1.5, centerPaint);
      }
    });
  }

  // Draw detailed face contours (eyebrows, mouth outline, nose, jawlines)
  void _drawDetailedContours(
    Canvas canvas,
    Face detectedFace,
    Color faceColor,
    Size canvasSize,
  ) {
    final contours = detectedFace.contours;

    // Enhanced contour styles with better visibility
    final Map<FaceContourType, ContourStyle> contourStyles = {
      FaceContourType.face: ContourStyle(faceColor, 3.0, true),
      FaceContourType.leftEyebrowTop: ContourStyle(Colors.blue, 2.5, false),
      FaceContourType.leftEyebrowBottom: ContourStyle(Colors.blue, 2.5, false),
      FaceContourType.rightEyebrowTop: ContourStyle(Colors.blue, 2.5, false),
      FaceContourType.rightEyebrowBottom: ContourStyle(Colors.blue, 2.5, false),
      FaceContourType.leftEye: ContourStyle(Colors.lightBlue, 2.0, true),
      FaceContourType.rightEye: ContourStyle(Colors.lightBlue, 2.0, true),
      FaceContourType.upperLipTop: ContourStyle(Colors.red, 2.5, false),
      FaceContourType.upperLipBottom: ContourStyle(Colors.red, 2.5, false),
      FaceContourType.lowerLipTop: ContourStyle(Colors.red, 2.5, false),
      FaceContourType.lowerLipBottom: ContourStyle(Colors.red, 2.5, false),
      FaceContourType.noseBridge: ContourStyle(Colors.green, 2.0, false),
      FaceContourType.noseBottom: ContourStyle(Colors.green, 2.0, false),
    };

    contours.forEach((type, contour) {
      if (contour != null && contour.points.isNotEmpty) {
        final style =
            contourStyles[type] ?? ContourStyle(faceColor, 2.0, false);

        final paint = Paint()
          ..color = style.color.withOpacity(0.8)
          ..strokeWidth = style.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final path = Path();
        final firstPoint = _transformPointFinal(
          contour.points.first,
          canvasSize,
        );
        path.moveTo(firstPoint.dx, firstPoint.dy);

        // Create smooth, accurate contour lines
        for (int i = 1; i < contour.points.length; i++) {
          final point = _transformPointFinal(contour.points[i], canvasSize);
          path.lineTo(point.dx, point.dy);
        }

        // Close enclosed contours
        if (style.shouldClose) {
          path.close();
        }

        canvas.drawPath(path, paint);

        // Add glow effect for thicker contours
        if (style.strokeWidth >= 2.0) {
          final glowPaint = Paint()
            ..color = style.color.withOpacity(0.2)
            ..strokeWidth = style.strokeWidth + 2.0
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
          canvas.drawPath(path, glowPaint);
        }
      }
    });
  }

  // Enhanced face detection for verification screen with accurate transformation
  void _drawEnhancedFaceDetection(
    Canvas canvas,
    Size size,
    List<Face> detectedFaces,
    Color faceColor,
  ) {
    // Calculate accurate transformation parameters for camera preview
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    final bool shouldFlip = true; // Front camera mirror effect

    // Draw each detected face with enhanced details
    for (final detectedFace in detectedFaces) {
      // Draw main face rectangle with corner markers
      _drawAccurateFaceRect(
        canvas,
        detectedFace,
        scaleX,
        scaleY,
        size.width,
        shouldFlip,
        faceColor,
        size,
      );

      if (showLandmarks) {
        _drawAccurateLandmarks(
          canvas,
          detectedFace,
          scaleX,
          scaleY,
          size.width,
          shouldFlip,
          faceColor,
          size,
        );
      }

      if (showContours) {
        _drawAccurateContours(
          canvas,
          detectedFace,
          scaleX,
          scaleY,
          size.width,
          shouldFlip,
          faceColor,
          size,
        );
      }
    }
  }

  // Draw accurate face rectangle with proper coordinate transformation
  void _drawAccurateFaceRect(
    Canvas canvas,
    Face face,
    double scaleX,
    double scaleY,
    double canvasWidth,
    bool flipX,
    Color color,
    Size canvasSize,
  ) {
    final boundingBox = face.boundingBox;

    // Transform coordinates with proper centering using the accurate method
    final topLeft = _transformPointAccurate(
      math.Point(boundingBox.left.toInt(), boundingBox.top.toInt()),
      canvasSize,
    );
    final bottomRight = _transformPointAccurate(
      math.Point(boundingBox.right.toInt(), boundingBox.bottom.toInt()),
      canvasSize,
    );

    final paint = Paint()
      ..color = color.withOpacity(0.8 * animationValue)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromPoints(topLeft, bottomRight);
    canvas.drawRect(rect, paint);

    // Draw enhanced corner markers
    _drawCornerMarkers(canvas, rect, color);
  }

  // Draw accurate landmarks with proper coordinate transformation
  void _drawAccurateLandmarks(
    Canvas canvas,
    Face face,
    double scaleX,
    double scaleY,
    double canvasWidth,
    bool flipX,
    Color baseColor,
    Size canvasSize,
  ) {
    final landmarks = face.landmarks;

    // Enhanced landmark styles with better colors
    final Map<FaceLandmarkType, LandmarkStyle> landmarkStyles = {
      FaceLandmarkType.leftEye: LandmarkStyle(Colors.lightBlue, 5.0),
      FaceLandmarkType.rightEye: LandmarkStyle(Colors.lightBlue, 5.0),
      FaceLandmarkType.noseBase: LandmarkStyle(Colors.lightGreen, 4.5),
      FaceLandmarkType.leftMouth: LandmarkStyle(Colors.redAccent, 4.0),
      FaceLandmarkType.rightMouth: LandmarkStyle(Colors.redAccent, 4.0),
      FaceLandmarkType.bottomMouth: LandmarkStyle(Colors.red, 4.0),
      FaceLandmarkType.leftCheek: LandmarkStyle(Colors.deepOrange, 3.5),
      FaceLandmarkType.rightCheek: LandmarkStyle(Colors.deepOrange, 3.5),
      FaceLandmarkType.leftEar: LandmarkStyle(Colors.deepPurple, 3.0),
      FaceLandmarkType.rightEar: LandmarkStyle(Colors.deepPurple, 3.0),
    };

    landmarks.forEach((type, landmark) {
      if (landmark != null) {
        final style = landmarkStyles[type] ?? LandmarkStyle(baseColor, 3.0);

        // Transform landmark coordinates accurately with the new method
        final point = _transformPointAccurate(landmark.position, canvasSize);

        // Draw main landmark with enhanced visibility
        final paint = Paint()
          ..color = style.color.withOpacity(0.9 * animationValue)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(point, style.size, paint);

        // Enhanced glow effect
        final glowPaint = Paint()
          ..color = style.color.withOpacity(0.4 * animationValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(point, style.size * 1.8, glowPaint);

        // Precise center dot
        final centerPaint = Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, 1.2, centerPaint);
      }
    });
  }

  // Draw accurate face contours with coordinate transformation
  void _drawAccurateContours(
    Canvas canvas,
    Face face,
    double scaleX,
    double scaleY,
    double canvasWidth,
    bool flipX,
    Color baseColor,
    Size canvasSize,
  ) {
    final contours = face.contours;

    // Enhanced contour styles with better visibility
    final Map<FaceContourType, ContourStyle> contourStyles = {
      FaceContourType.face: ContourStyle(baseColor, 3.0, true),
      FaceContourType.leftEyebrowTop: ContourStyle(Colors.blue, 2.5, false),
      FaceContourType.leftEyebrowBottom: ContourStyle(Colors.blue, 2.5, false),
      FaceContourType.rightEyebrowTop: ContourStyle(Colors.blue, 2.5, false),
      FaceContourType.rightEyebrowBottom: ContourStyle(Colors.blue, 2.5, false),
      FaceContourType.leftEye: ContourStyle(Colors.lightBlue, 2.0, true),
      FaceContourType.rightEye: ContourStyle(Colors.lightBlue, 2.0, true),
      FaceContourType.upperLipTop: ContourStyle(Colors.red, 2.5, false),
      FaceContourType.upperLipBottom: ContourStyle(Colors.red, 2.5, false),
      FaceContourType.lowerLipTop: ContourStyle(Colors.red, 2.5, false),
      FaceContourType.lowerLipBottom: ContourStyle(Colors.red, 2.5, false),
      FaceContourType.noseBridge: ContourStyle(Colors.green, 2.0, false),
      FaceContourType.noseBottom: ContourStyle(Colors.green, 2.0, false),
    };

    contours.forEach((type, contour) {
      if (contour != null && contour.points.isNotEmpty) {
        final style =
            contourStyles[type] ?? ContourStyle(baseColor, 2.0, false);

        final paint = Paint()
          ..color = style.color.withOpacity(0.7 * animationValue)
          ..strokeWidth = style.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final path = Path();
        final firstPoint = _transformPointAccurate(
          contour.points.first,
          canvasSize,
        );
        path.moveTo(firstPoint.dx, firstPoint.dy);

        // Create smooth, accurate contour lines
        for (int i = 1; i < contour.points.length; i++) {
          final point = _transformPointAccurate(contour.points[i], canvasSize);
          path.lineTo(point.dx, point.dy);
        }

        // Close enclosed contours
        if (style.shouldClose) {
          path.close();
        }

        canvas.drawPath(path, paint);
      }
    });
  }

  void _drawFaceRect(
    Canvas canvas,
    Face face,
    double scaleX,
    double scaleY,
    double canvasWidth,
    bool flipX,
    Paint paint,
  ) {
    final boundingBox = face.boundingBox;

    // Transform bounding box
    final left = flipX
        ? canvasWidth - (boundingBox.right * scaleX)
        : boundingBox.left * scaleX;
    final top = boundingBox.top * scaleY;
    final right = flipX
        ? canvasWidth - (boundingBox.left * scaleX)
        : boundingBox.right * scaleX;
    final bottom = boundingBox.bottom * scaleY;

    // Draw main face rectangle
    final rect = Rect.fromLTRB(left, top, right, bottom);
    canvas.drawRect(rect, paint);

    // Draw corner markers for better visibility
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = primaryColor.withOpacity(animationValue)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    // Top-left corner
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(right, top),
      Offset(right - cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLength, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left, bottom - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - cornerLength, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLength),
      cornerPaint,
    );

    // Draw center crosshair
    final centerX = (left + right) / 2;
    final centerY = (top + bottom) / 2;
    final crossSize = 15.0;

    canvas.drawLine(
      Offset(centerX - crossSize, centerY),
      Offset(centerX + crossSize, centerY),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - crossSize),
      Offset(centerX, centerY + crossSize),
      cornerPaint,
    );
  }

  void _drawLandmarks(
    Canvas canvas,
    Face face,
    double scaleX,
    double scaleY,
    double canvasWidth,
    bool flipX,
    Paint landmarkPaint,
  ) {
    final landmarks = face.landmarks;

    // Define landmark colors for different facial features
    final Map<FaceLandmarkType, Color> landmarkColors = {
      FaceLandmarkType.leftEye: Colors.blue,
      FaceLandmarkType.rightEye: Colors.blue,
      FaceLandmarkType.noseBase: Colors.green,
      FaceLandmarkType.leftMouth: Colors.red,
      FaceLandmarkType.rightMouth: Colors.red,
      FaceLandmarkType.bottomMouth: Colors.red,
      FaceLandmarkType.leftCheek: Colors.orange,
      FaceLandmarkType.rightCheek: Colors.orange,
      FaceLandmarkType.leftEar: Colors.purple,
      FaceLandmarkType.rightEar: Colors.purple,
    };

    landmarks.forEach((type, landmark) {
      if (landmark != null) {
        final color = landmarkColors[type] ?? primaryColor;
        final paint = Paint()
          ..color = color.withOpacity(0.8 * animationValue)
          ..style = PaintingStyle.fill;

        final point = _transformPoint(
          landmark.position,
          scaleX,
          scaleY,
          canvasWidth,
          flipX,
        );

        // Draw landmark point
        canvas.drawCircle(point, 4.0, paint);

        // Add subtle glow effect
        final glowPaint = Paint()
          ..color = color.withOpacity(0.3 * animationValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawCircle(point, 6.0, glowPaint);
      }
    });
  }

  void _drawContours(
    Canvas canvas,
    Face face,
    double scaleX,
    double scaleY,
    double canvasWidth,
    bool flipX,
  ) {
    final contours = face.contours;

    contours.forEach((type, contour) {
      if (contour != null && contour.points.isNotEmpty) {
        final paint = Paint()
          ..color = primaryColor.withOpacity(0.6 * animationValue)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

        final path = Path();
        final firstPoint = _transformPoint(
          contour.points.first,
          scaleX,
          scaleY,
          canvasWidth,
          flipX,
        );
        path.moveTo(firstPoint.dx, firstPoint.dy);

        for (int i = 1; i < contour.points.length; i++) {
          final point = _transformPoint(
            contour.points[i],
            scaleX,
            scaleY,
            canvasWidth,
            flipX,
          );
          path.lineTo(point.dx, point.dy);
        }

        canvas.drawPath(path, paint);
      }
    });
  }

  Offset _transformPoint(
    math.Point<int> point,
    double scaleX,
    double scaleY,
    double canvasWidth,
    bool flipX,
  ) {
    final x = flipX ? canvasWidth - (point.x * scaleX) : point.x * scaleX;
    final y = point.y * scaleY;
    return Offset(x, y);
  }

  // OPTIMIZED: Center-aligned face detection coordinate transformation
  Offset _transformPointAccurate(math.Point<int> point, Size canvasSize) {
    // Use the same optimized transformation logic as _transformPointFinal
    return _transformPointFinal(point, canvasSize);
  }

  // NEW: Direct coordinate mapping for perfect alignment
  Offset _transformPointDirect(math.Point<int> point, Size canvasSize) {
    // Get the actual camera preview size
    final Size previewSize = this.previewSize;
    final Size imageSize = this.imageSize;

    // Calculate the actual scaling factors
    final double scaleX = canvasSize.width / imageSize.width;
    final double scaleY = canvasSize.height / imageSize.height;

    // Apply scaling directly
    final double scaledX = point.x * scaleX;
    final double scaledY = point.y * scaleY;

    // Apply front camera mirroring (flip horizontally)
    final double mirroredX = canvasSize.width - scaledX;

    return Offset(mirroredX, scaledY);
  }

  // NEW: Simple and accurate coordinate transformation
  Offset _transformPointSimple(math.Point<int> point, Size canvasSize) {
    // Get the actual camera preview size
    final Size imageSize = this.imageSize;

    // Calculate scaling factors based on the canvas size vs image size
    final double scaleX = canvasSize.width / imageSize.width;
    final double scaleY = canvasSize.height / imageSize.height;

    // Apply scaling
    final double scaledX = point.x * scaleX;
    final double scaledY = point.y * scaleY;

    // Apply front camera mirroring (flip horizontally)
    final double mirroredX = canvasSize.width - scaledX;

    return Offset(mirroredX, scaledY);
  }

  // NEW: Most accurate coordinate transformation for AspectRatio camera preview
  Offset _transformPointForAspectRatio(math.Point<int> point, Size canvasSize) {
    // Get the actual camera preview size and image size
    final Size imageSize = this.imageSize;
    final Size previewSize = this.previewSize;

    // Calculate the aspect ratios
    final double imageAspectRatio = imageSize.width / imageSize.height;
    final double canvasAspectRatio = canvasSize.width / canvasSize.height;

    // Determine the actual display size that maintains aspect ratio (like AspectRatio widget)
    double displayWidth, displayHeight;
    double offsetX = 0, offsetY = 0;

    if (canvasAspectRatio > imageAspectRatio) {
      // Canvas is wider than image - scale by height (like AspectRatio widget)
      displayHeight = canvasSize.height;
      displayWidth = canvasSize.height * imageAspectRatio;
      offsetX = (canvasSize.width - displayWidth) / 2;
    } else {
      // Canvas is taller than image - scale by width (like AspectRatio widget)
      displayWidth = canvasSize.width;
      displayHeight = canvasSize.width / imageAspectRatio;
      offsetY = (canvasSize.height - displayHeight) / 2;
    }

    // Calculate scaling factors based on the actual display size
    final double scaleX = displayWidth / imageSize.width;
    final double scaleY = displayHeight / imageSize.height;

    // Apply scaling and centering
    final double scaledX = point.x * scaleX + offsetX;
    final double scaledY = point.y * scaleY + offsetY;

    // Apply front camera mirroring (flip horizontally)
    final double mirroredX = canvasSize.width - scaledX;

    return Offset(mirroredX, scaledY);
  }

  // OPTIMIZED: Perfect center-aligned face detection transformation
  Offset _transformPointFinal(math.Point<int> point, Size canvasSize) {
    // Get the actual camera preview size and image size
    final Size imageSize = this.imageSize;

    // Calculate the aspect ratios
    final double imageAspectRatio = imageSize.width / imageSize.height;
    final double canvasAspectRatio = canvasSize.width / canvasSize.height;

    // Determine the actual display size that maintains aspect ratio and centers the image
    double displayWidth, displayHeight;
    double offsetX = 0, offsetY = 0;

    if (canvasAspectRatio > imageAspectRatio) {
      // Canvas is wider than image - scale by height and center horizontally
      displayHeight = canvasSize.height;
      displayWidth = canvasSize.height * imageAspectRatio;
      offsetX = (canvasSize.width - displayWidth) / 2;
    } else {
      // Canvas is taller than image - scale by width and center vertically  
      displayWidth = canvasSize.width;
      displayHeight = canvasSize.width / imageAspectRatio;
      offsetY = (canvasSize.height - displayHeight) / 2;
    }

    // Calculate precise scaling factors for perfect alignment
    final double scaleX = displayWidth / imageSize.width;
    final double scaleY = displayHeight / imageSize.height;

    // Apply scaling with perfect centering
    final double scaledX = point.x * scaleX + offsetX;
    final double scaledY = point.y * scaleY + offsetY;

    // Apply front camera mirroring for natural user experience
    final double mirroredX = canvasSize.width - scaledX;

    return Offset(mirroredX, scaledY);
  }

  @override
  bool shouldRepaint(FaceDetectionPainter oldDelegate) {
    return faces != oldDelegate.faces ||
        animationValue != oldDelegate.animationValue;
  }
}

// Center guide painter to help users position their face perfectly
class CenterGuidePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  CenterGuidePainter({
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw simple center rectangle guide for face positioning
    final rectWidth = size.width * 0.7;
    final rectHeight = size.height * 0.9;
    final guideRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: rectWidth,
      height: rectHeight,
    );
    canvas.drawRect(guideRect, paint);

    // Draw center crosshair
    final crossSize = 30.0;
    canvas.drawLine(
      Offset(centerX - crossSize, centerY),
      Offset(centerX + crossSize, centerY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - crossSize),
      Offset(centerX, centerY + crossSize),
      paint,
    );

    // Draw text guide
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'CENTER YOUR FACE HERE',
        style: TextStyle(
          color: color,
          fontSize: 16,
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
        centerX - textPainter.width / 2,
        centerY + rectHeight / 2 + 20,
      ),
    );

    // Draw corner guides
    final cornerLength = 30.0;
    final margin = size.width * 0.15;

    // Top-left corner
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin + cornerLength, margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin, margin + cornerLength),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin - cornerLength, margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin, margin + cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + cornerLength, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin, size.height - margin - cornerLength),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin - cornerLength, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin, size.height - margin - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// Helper classes for enhanced face detection
class LandmarkStyle {
  final Color color;
  final double size;

  LandmarkStyle(this.color, this.size);
}

class ContourStyle {
  final Color color;
  final double strokeWidth;
  final bool shouldClose;

  ContourStyle(this.color, this.strokeWidth, this.shouldClose);
}
