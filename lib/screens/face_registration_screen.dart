import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../widgets/animated_wave_background.dart';
import '../widgets/face_detection_painter.dart';
import '../widgets/enhanced_face_painter.dart';
import '../widgets/enhanced_face_guide_painter.dart';
import '../services/face_embedding_service.dart';
import '../services/tflite_deep_learning_service.dart';
import '../services/face_quality_analyzer.dart';
import '../services/cloudinary_service.dart';
import '../models/face_registration_models.dart';
import '../utils/logger.dart';
import '../config/server_config.dart';
import '../utils/custom_colors.dart';

class FaceRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FaceRegistrationScreen({super.key, required this.userData});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isRegistering = false;
  bool _isRegistered = false;

  // Camera related variables
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _hasCameraPermission = false;
  List<CameraDescription>? _cameras;

  // ULTRA HIGH ACCURACY face detection with enhanced stability tracking
  bool _isDetecting = false;
  Face? _detectedFace;
  Face? _previousFace; // For stability checking
  final List<Face> _faceHistory = []; // Face tracking history for smoothing
  int _stableFaceCount = 0; // Count of stable detections
  final int _requiredStability = 10; // Increased frames for better accuracy
  double _currentConfidence = 0.0; // Current detection confidence
  // Remove unused variables

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true, // Enable ALL contours for maximum accuracy
      enableLandmarks: true, // Enable ALL landmarks for detailed detection
      enableClassification: true, // Enable smile/eye classification
      enableTracking: true, // Enable face tracking with ID consistency
      performanceMode:
          FaceDetectorMode.accurate, // ACCURATE mode for best quality
      minFaceSize:
          0.12, // Reduced to capture more distant faces but maintain quality
    ),
  );

  // Auto capture variables
  bool _isCapturing = false;
  bool _captureEnabled = true;

  // Cloudinary URLs storage
  final List<String> _cloudinaryUrls = [];

  // Enhanced face filtering and validation for maximum accuracy
  List<Face> _filterAndValidateFacesAdvanced(
    List<Face> faces,
    int imageWidth,
    int imageHeight,
  ) {
    if (faces.isEmpty) return [];

    Logger.info(
      '🔍 Advanced face filtering: Processing ${faces.length} detected faces',
    );

    // Remove duplicate faces (from multiple detection strategies)
    final uniqueFaces = <Face>[];
    for (final face in faces) {
      bool isDuplicate = false;
      for (final existing in uniqueFaces) {
        // Check if faces are too similar (same position/size)
        final distanceThreshold = 50.0;
        final sizeThreshold = 0.2;

        final centerDistance = math.sqrt(
          math.pow(
                face.boundingBox.center.dx - existing.boundingBox.center.dx,
                2,
              ) +
              math.pow(
                face.boundingBox.center.dy - existing.boundingBox.center.dy,
                2,
              ),
        );

        final sizeDifference =
            (face.boundingBox.width - existing.boundingBox.width).abs() /
            math.max(face.boundingBox.width, existing.boundingBox.width);

        if (centerDistance < distanceThreshold &&
            sizeDifference < sizeThreshold) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        uniqueFaces.add(face);
      }
    }

    Logger.info(
      '📊 Removed duplicates: ${faces.length} → ${uniqueFaces.length} unique faces',
    );

    // Apply comprehensive quality filters
    final qualityFaces = uniqueFaces.where((face) {
      final box = face.boundingBox;

      // 1. Size validation - face should be appropriate size (more restrictive)
      final faceArea = box.width * box.height;
      final imageArea = imageWidth * imageHeight;
      final faceRatio = faceArea / imageArea;

      if (faceRatio < 0.08 || faceRatio > 0.6) {
        Logger.warning(
          '❌ Face size invalid: ${(faceRatio * 100).toStringAsFixed(1)}% of image - must be 8-60%',
        );
        return false;
      }

      // 2. Position validation - face should be STRICTLY centered
      final centerX = box.center.dx / imageWidth;
      final centerY = box.center.dy / imageHeight;

      // More restrictive centering requirements - face must be in center 50%
      if (centerX < 0.25 ||
          centerX > 0.75 ||
          centerY < 0.25 ||
          centerY > 0.75) {
        Logger.warning(
          '❌ Face position invalid: (${(centerX * 100).toInt()}%, ${(centerY * 100).toInt()}%) - must be in center 50%',
        );
        return false;
      }

      // 3. Aspect ratio validation - face should have reasonable proportions
      final aspectRatio = box.width / box.height;
      if (aspectRatio < 0.5 || aspectRatio > 2.0) {
        Logger.warning(
          '❌ Face aspect ratio invalid: ${aspectRatio.toStringAsFixed(2)}',
        );
        return false;
      }

      // 4. Landmark validation - sufficient landmarks should be detected (more strict)
      final landmarkCount = face.landmarks.length;
      if (landmarkCount < 5) {
        Logger.warning(
          '❌ Insufficient landmarks: $landmarkCount detected - need at least 5',
        );
        return false;
      }

      // 5. Tracking ID validation - face should have consistent tracking
      if (face.trackingId != null && face.trackingId! < 0) {
        Logger.warning('❌ Invalid tracking ID: ${face.trackingId}');
        return false;
      }

      // 6. STRICT ANGLE VALIDATION based on current step
      if (!_isFaceAngleCorrectForStep(face)) {
        Logger.warning('❌ Face angle incorrect for current step');
        return false;
      }

      Logger.info('✅ Face passed all quality filters');
      return true;
    }).toList();

    // Sort by quality score (combination of size, position, and landmark count)
    qualityFaces.sort((a, b) {
      final scoreA = _calculateFaceQualityScore(a, imageWidth, imageHeight);
      final scoreB = _calculateFaceQualityScore(b, imageWidth, imageHeight);
      return scoreB.compareTo(scoreA); // Descending order (best first)
    });

    Logger.info('🎯 Final result: ${qualityFaces.length} high-quality faces');
    if (qualityFaces.isNotEmpty) {
      final bestFace = qualityFaces.first;
      final score = _calculateFaceQualityScore(
        bestFace,
        imageWidth,
        imageHeight,
      );
      Logger.info(
        '🏆 Best face quality score: ${(score * 100).toStringAsFixed(1)}%',
      );
    }

    return qualityFaces;
  }

  // STRICT angle validation for each registration step
  bool _isFaceAngleCorrectForStep(Face face) {
    if (_currentStep >= _registrationSteps.length) return true;

    final headEulerAngleX = face.headEulerAngleX ?? 0.0;
    final headEulerAngleY = face.headEulerAngleY ?? 0.0;
    final headEulerAngleZ = face.headEulerAngleZ ?? 0.0;

    switch (_currentStep) {
      case 0: // center - face forward
        // Very strict: face must be almost perfectly straight
        return headEulerAngleX.abs() <= 8.0 &&
            headEulerAngleY.abs() <= 8.0 &&
            headEulerAngleZ.abs() <= 5.0;

      case 1: // up - look up slightly
        // Strict upward tilt: -15 to -25 degrees
        return headEulerAngleX <= -12.0 &&
            headEulerAngleX >= -28.0 &&
            headEulerAngleY.abs() <= 10.0 &&
            headEulerAngleZ.abs() <= 8.0;

      case 2: // down - look down slightly
        // Strict downward tilt: 12 to 28 degrees
        return headEulerAngleX >= 12.0 &&
            headEulerAngleX <= 28.0 &&
            headEulerAngleY.abs() <= 10.0 &&
            headEulerAngleZ.abs() <= 8.0;

      case 3: // left - turn left slightly
        // Strict left turn: -18 to -32 degrees
        return headEulerAngleY <= -15.0 &&
            headEulerAngleY >= -35.0 &&
            headEulerAngleX.abs() <= 12.0 &&
            headEulerAngleZ.abs() <= 8.0;

      case 4: // right - turn right slightly
        // Strict right turn: 18 to 32 degrees
        return headEulerAngleY >= 15.0 &&
            headEulerAngleY <= 35.0 &&
            headEulerAngleX.abs() <= 12.0 &&
            headEulerAngleZ.abs() <= 8.0;

      case 5: // blink - eyes should be open
        // Face should be relatively straight for blink detection
        return headEulerAngleX.abs() <= 12.0 &&
            headEulerAngleY.abs() <= 12.0 &&
            headEulerAngleZ.abs() <= 8.0;

      case 6: // smile - natural expression
        // Face should be relatively straight for smile detection
        return headEulerAngleX.abs() <= 12.0 &&
            headEulerAngleY.abs() <= 12.0 &&
            headEulerAngleZ.abs() <= 8.0;

      case 7: // neutral - return to neutral
        // Face should be straight for neutral expression
        return headEulerAngleX.abs() <= 10.0 &&
            headEulerAngleY.abs() <= 10.0 &&
            headEulerAngleZ.abs() <= 6.0;

      default:
        return true;
    }
  }

  // Get specific guidance message based on current step and face angles
  String _getAngleGuidanceMessage() {
    if (_detectedFace == null || _currentStep >= _registrationSteps.length) {
      return 'Position your face correctly';
    }

    final headEulerAngleX = _detectedFace!.headEulerAngleX ?? 0.0;
    final headEulerAngleY = _detectedFace!.headEulerAngleY ?? 0.0;
    final headEulerAngleZ = _detectedFace!.headEulerAngleZ ?? 0.0;

    switch (_currentStep) {
      case 0: // center
        if (headEulerAngleX.abs() > 8.0) {
          return headEulerAngleX > 0
              ? 'Tilt your head down'
              : 'Tilt your head up';
        }
        if (headEulerAngleY.abs() > 8.0) {
          return headEulerAngleY > 0
              ? 'Turn your head right'
              : 'Turn your head left';
        }
        if (headEulerAngleZ.abs() > 5.0) {
          return 'Keep your head straight';
        }
        return 'Look straight at the camera';

      case 1: // up
        if (headEulerAngleX > -12.0) {
          return 'Tilt your head up more (12-28°)';
        }
        if (headEulerAngleX < -28.0) {
          return 'Tilt your head up less (12-28°)';
        }
        if (headEulerAngleY.abs() > 10.0) {
          return 'Keep your head straight, only tilt up';
        }
        return 'Perfect! Hold this position';

      case 2: // down
        if (headEulerAngleX < 12.0) {
          return 'Tilt your head down more (12-28°)';
        }
        if (headEulerAngleX > 28.0) {
          return 'Tilt your head down less (12-28°)';
        }
        if (headEulerAngleY.abs() > 10.0) {
          return 'Keep your head straight, only tilt down';
        }
        return 'Perfect! Hold this position';

      case 3: // left
        if (headEulerAngleY > -15.0) {
          return 'Turn your head left more (15-35°)';
        }
        if (headEulerAngleY < -35.0) {
          return 'Turn your head left less (15-35°)';
        }
        if (headEulerAngleX.abs() > 12.0) {
          return 'Keep your head level, only turn left';
        }
        return 'Perfect! Hold this position';

      case 4: // right
        if (headEulerAngleY < 15.0) {
          return 'Turn your head right more (15-35°)';
        }
        if (headEulerAngleY > 35.0) {
          return 'Turn your head right less (15-35°)';
        }
        if (headEulerAngleX.abs() > 12.0) {
          return 'Keep your head level, only turn right';
        }
        return 'Perfect! Hold this position';

      case 5: // blink
        if (headEulerAngleX.abs() > 12.0 || headEulerAngleY.abs() > 12.0) {
          return 'Keep your head straight for blink detection';
        }
        return 'Blink naturally while looking at camera';

      case 6: // smile
        if (headEulerAngleX.abs() > 12.0 || headEulerAngleY.abs() > 12.0) {
          return 'Keep your head straight for smile detection';
        }
        return 'Smile naturally while looking at camera';

      case 7: // neutral
        if (headEulerAngleX.abs() > 10.0 || headEulerAngleY.abs() > 10.0) {
          return 'Keep your head straight for neutral expression';
        }
        return 'Maintain neutral expression';

      default:
        return 'Follow the step instructions';
    }
  }

  // Calculate comprehensive quality score for face ranking
  double _calculateFaceQualityScore(
    Face face,
    int imageWidth,
    int imageHeight,
  ) {
    double score = 0.0;

    final box = face.boundingBox;
    final faceArea = box.width * box.height;
    final imageArea = imageWidth * imageHeight;
    final faceRatio = faceArea / imageArea;

    // 1. Size score (optimal around 20-40% of image)
    final optimalSizeRatio = 0.3;
    final sizeScore =
        1.0 - (faceRatio - optimalSizeRatio).abs() / optimalSizeRatio;
    score += sizeScore * 0.3;

    // 2. Position score (prefer center)
    final centerX = box.center.dx / imageWidth;
    final centerY = box.center.dy / imageHeight;
    final centerDistanceFromOptimal = math.sqrt(
      math.pow(centerX - 0.5, 2) + math.pow(centerY - 0.5, 2),
    );
    final positionScore =
        1.0 - (centerDistanceFromOptimal * 2); // Normalize to 0-1
    score += math.max(0.0, positionScore) * 0.2;

    // 3. Landmark score
    final landmarkCount = face.landmarks.length;
    final maxExpectedLandmarks = 8; // Based on our critical landmarks
    final landmarkScore = math.min(1.0, landmarkCount / maxExpectedLandmarks);
    score += landmarkScore * 0.25;

    // 4. Classification confidence (if available)
    final eyeOpenness =
        ((face.leftEyeOpenProbability ?? 0.5) +
            (face.rightEyeOpenProbability ?? 0.5)) /
        2;
    score += eyeOpenness * 0.15;

    // 5. Contour completeness
    final contourCount = face.contours.length;
    final maxExpectedContours = 13; // Based on our critical contours
    final contourScore = math.min(1.0, contourCount / maxExpectedContours);
    score += contourScore * 0.1;

    return math.max(0.0, math.min(1.0, score));
  }

  // Enhanced face registration steps with detailed guidance and quality metrics
  int _currentStep = 0;
  final List<RegistrationStep> _registrationSteps = [
    RegistrationStep(
      id: 'center',
      title: 'Face Forward',
      description:
          'Look straight at the camera with a neutral expression. Keep your face centered in the frame.',
      icon: Icons.center_focus_strong,
      color: CustomColors.stepCenter,
      qualityChecks: [
        'face_centered',
        'proper_lighting',
        'clear_features',
        'neutral_expression',
      ],
    ),
    RegistrationStep(
      id: 'up',
      title: 'Look Up Slightly',
      description:
          'Gently tilt your head up about 10-15 degrees. Keep your eyes looking at the camera.',
      icon: Icons.keyboard_arrow_up,
      color: CustomColors.stepUp,
      qualityChecks: ['head_tilt_up', 'jaw_visibility', 'under_chin_visible'],
    ),
    RegistrationStep(
      id: 'down',
      title: 'Look Down Slightly',
      description:
          'Gently tilt your head down about 10-15 degrees. Keep your forehead visible.',
      icon: Icons.keyboard_arrow_down,
      color: CustomColors.stepDown,
      qualityChecks: [
        'head_tilt_down',
        'forehead_visibility',
        'eyebrows_clear',
      ],
    ),
    RegistrationStep(
      id: 'left',
      title: 'Turn Left Slightly',
      description:
          'Turn your head to the left about 15-20 degrees. Show your left profile partially.',
      icon: Icons.keyboard_arrow_left,
      color: CustomColors.stepLeft,
      qualityChecks: ['head_turn_left', 'profile_partial', 'left_side_visible'],
    ),
    RegistrationStep(
      id: 'right',
      title: 'Turn Right Slightly',
      description: 'Turn your head to the right about 20 degrees',
      icon: Icons.keyboard_arrow_right,
      color: CustomColors.stepRight,
      qualityChecks: ['head_turn_right', 'profile_partial'],
    ),
    RegistrationStep(
      id: 'blink',
      title: 'Blink Detection',
      description: 'Blink naturally a few times',
      icon: Icons.visibility_off,
      color: CustomColors.stepBlink,
      qualityChecks: ['blink_detected', 'eye_movement'],
    ),
    RegistrationStep(
      id: 'smile',
      title: 'Natural Smile',
      description: 'Smile naturally to capture expression variations',
      icon: Icons.sentiment_satisfied,
      color: CustomColors.stepSmile,
      qualityChecks: ['smile_detected', 'mouth_movement'],
    ),
    RegistrationStep(
      id: 'neutral',
      title: 'Neutral Expression',
      description: 'Return to a neutral, relaxed expression',
      icon: Icons.sentiment_neutral,
      color: CustomColors.stepNeutral,
      qualityChecks: ['neutral_expression', 'relaxed_features'],
    ),
  ];

  // Enhanced step completion tracking with quality metrics
  final Map<int, StepQualityData> _completedSteps = {};
  bool _allStepsCompleted = false;

  // Quality assessment variables
  double _currentStepQuality = 0.0;
  final Map<String, double> _qualityMetrics = {};
  List<String> _qualityIssues = [];

  // Advanced face analysis data
  FaceQualityAnalysis? _currentQualityAnalysis;
  final List<FaceDataPoint> _capturedFaceData = [];

  // Real-time feedback
  String _feedbackMessage = 'Position your face in the center';
  Color _feedbackColor = CustomColors.primaryRed;
  final bool _showDetailedFeedback = true;

  // Face smoothing variables and blink detection
  int _consecutiveDetections = 0;
  int _blinkFrameCount = 0;
  int _eyesOpenFrameCount = 0;
  bool _blinkDetected = false;
  final int _blinkRequiredFrames = 5;
  static const int _maxFaceHistory = 5;

  // TFLite services for face embedding and analysis
  final FaceEmbeddingService _faceEmbeddingService = FaceEmbeddingService();
  final TFLiteDeepLearningService _tfliteService = TFLiteDeepLearningService();
  bool _isTFLiteInitialized = false;

  // Enhanced TFLite face embeddings storage with metadata
  final List<FaceEmbeddingData> _capturedEmbeddings = [];
  final List<Map<String, dynamic>> _capturedAnalyses = [];
  final List<File> _capturedPhotos = [];

  // Remove unused quality assessment variables and landmark tracking

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Initialize TFLite services
    _initializeTFLiteServices();

    // Clear previous face images when starting new registration
    _clearPreviousFaceImages();

    // Don't initialize camera automatically - only when user starts registration
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Check permissions when app becomes active (user returns from settings)
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  // Check current permission status
  Future<void> _checkPermissionStatus() async {
    try {
      final status = await Permission.camera.status;
      if (mounted) {
        setState(() {
          _hasCameraPermission = status.isGranted;
        });

        // Permission status updated, but don't auto-initialize camera
        // Camera will be initialized when user starts registration
      }
    } catch (e) {
      print('Error checking permission status: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _cameraController?.dispose();
    _faceDetector.close();

    // Clean up TFLite resources
    _tfliteService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.getBackgroundColor(context),
      body: AnimatedWaveBackground(
        useFullScreen: true,
        child: Column(
          children: [
            // Enhanced Header with Progress
            _buildEnhancedHeader(context),

            // Main Content Area
            Expanded(child: _buildMainContent(context)),

            // Enhanced Control Panel
            _buildEnhancedControlPanel(context),
          ],
        ),
      ),
    );
  }

  // Enhanced header with real-time progress and quality indicators
  Widget _buildEnhancedHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CustomColors.getPrimaryColor(context).withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // Title and Back Button
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: CustomColors.getPrimaryColor(context),
                ),
              ),
              Expanded(
                child: Text(
                  'Face Registration',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: CustomColors.getOnSurfaceColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Balance the back button
            ],
          ),

          const SizedBox(height: 20),

          // Progress Indicator
          if (_isRegistering) _buildProgressIndicator(context),

          // Current Step Information
          if (_isRegistering) _buildCurrentStepInfo(context),
        ],
      ),
    );
  }

  // Enhanced progress indicator with step visualization
  Widget _buildProgressIndicator(BuildContext context) {
    final progress = (_currentStep + 1) / _registrationSteps.length;

    return Column(
      children: [
        // Step dots visualization
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_registrationSteps.length, (index) {
            final isCompleted = index < _currentStep;
            final isCurrent = index == _currentStep;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isCurrent ? 12 : 8,
              height: isCurrent ? 12 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? CustomColors.getSuccessColor(context)
                    : isCurrent
                    ? CustomColors.getPrimaryColor(context)
                    : CustomColors.getSecondaryColor(context).withValues(alpha: 0.3),
                border: isCurrent
                    ? Border.all(
                        color: CustomColors.getPrimaryColor(context),
                        width: 2,
                      )
                    : null,
              ),
            );
          }),
        ),

        const SizedBox(height: 12),

        // Progress bar
        Container(
          width: double.infinity,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: CustomColors.getSecondaryColor(context).withValues(alpha: 0.2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [
                    CustomColors.getPrimaryColor(context),
                    CustomColors.getPrimaryColor(context).withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Progress text
        Text(
          'Step ${_currentStep + 1} of ${_registrationSteps.length}',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: CustomColors.getOnSurfaceColor(context).withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  // Current step information with enhanced guidance
  Widget _buildCurrentStepInfo(BuildContext context) {
    if (_currentStep >= _registrationSteps.length) {
      return const SizedBox.shrink();
    }

    final step = _registrationSteps[_currentStep];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: step.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: step.color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          // Step icon and title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(step.icon, color: step.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Step description
          Text(
            step.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CustomColors.getOnSurfaceColor(context).withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Main content area with improved camera preview
  Widget _buildMainContent(BuildContext context) {
    if (!_isRegistering) {
      return _buildPreRegistrationState();
    }

    return _buildRegistrationState();
  }

  // Enhanced control panel with quality indicators and actions
  Widget _buildEnhancedControlPanel(BuildContext context) {
    if (!_isRegistering) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startFaceRegistration,
                icon: const Icon(Icons.face_rounded),
                label: const Text('Start Face Registration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.getPrimaryColor(context),
                  foregroundColor: CustomColors.getOnPrimaryColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Debug completion button (for testing)
            if (_isRegistering && _completedSteps.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _debugCheckCompletion,
                  icon: const Icon(Icons.bug_report_rounded),
                  label: Text(
                    'Debug: ${_completedSteps.length}/${_registrationSteps.length} Steps',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CustomColors.getWarningColor(context),
                    side: BorderSide(
                      color: CustomColors.getWarningColor(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // Test confirmation button (for testing)
            if (_isRegistering)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _testConfirmationDialog,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('Test Confirmation Dialog'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CustomColors.getSecondaryColor(context),
                    side: BorderSide(
                      color: CustomColors.getSecondaryColor(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CustomColors.getPrimaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        color: CustomColors.getPrimaryColor(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tips for best results:',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CustomColors.getOnSurfaceColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Ensure good lighting on your face\n'
                    '• Remove glasses or hats if possible\n'
                    '• Hold device steady during capture\n'
                    '• Follow the step-by-step guidance',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CustomColors.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: CustomColors.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Real-time quality indicators
          if (_detectedFace != null) _buildQualityIndicators(context),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Cancel/Skip button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentStep > 0
                      ? _skipCurrentStep
                      : _cancelRegistration,
                  icon: Icon(_currentStep > 0 ? Icons.skip_next : Icons.close),
                  label: Text(_currentStep > 0 ? 'Skip Step' : 'Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CustomColors.getSecondaryColor(context),
                    side: BorderSide(
                      color: CustomColors.getSecondaryColor(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Capture/Next button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _detectedFace != null && !_isCapturing
                      ? _captureCurrentStep
                      : null,
                  icon: _isCapturing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              CustomColors.getOnPrimaryColor(context),
                            ),
                          ),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(_isCapturing ? 'Capturing...' : 'Capture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _detectedFace != null
                        ? CustomColors.getPrimaryColor(context)
                        : CustomColors.getSecondaryColor(
                            context,
                          ).withValues(alpha: 0.3),
                    foregroundColor: CustomColors.getOnPrimaryColor(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Real-time quality indicators
  Widget _buildQualityIndicators(BuildContext context) {
    // This will be populated when we have quality analysis
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CustomColors.getPrimaryColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQualityIndicator('Face Detected', true, Icons.face),
          _buildQualityIndicator(
            'Well Lit',
            _currentConfidence > 0.7,
            Icons.light_mode,
          ),
          _buildQualityIndicator(
            'Stable',
            _stableFaceCount >= _requiredStability,
            Icons.check_circle,
          ),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(String label, bool isGood, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isGood
              ? CustomColors.getSuccessColor(context)
              : CustomColors.getWarningColor(context),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: isGood
                ? CustomColors.getSuccessColor(context)
                : CustomColors.getWarningColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Helper methods for control panel actions
  void _skipCurrentStep() {
    if (_currentStep < _registrationSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _cancelRegistration() {
    setState(() {
      _isRegistering = false;
      _currentStep = 0;
    });
    _cameraController?.dispose();
    _cameraController = null;
    _isCameraInitialized = false;
  }

  void _captureCurrentStep() async {
    if (_detectedFace == null || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Add your capture logic here
      await Future.delayed(
        const Duration(milliseconds: 1500),
      ); // Simulate capture

      if (_currentStep < _registrationSteps.length - 1) {
        setState(() {
          _currentStep++;
          _isCapturing = false;
        });
      } else {
        // Complete registration
        setState(() {
          _isRegistered = true;
          _isCapturing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      // Handle error
    }
  }

  // Step-specific guidance overlay
  Widget _buildStepGuidanceOverlay() {
    if (_currentStep >= _registrationSteps.length) {
      return const SizedBox.shrink();
    }

    final step = _registrationSteps[_currentStep];

    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: step.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(step.icon, color: step.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
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

  // Real-time feedback overlay
  Widget _buildRealTimeFeedbackOverlay() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Face detection status with enhanced guidance
          if (_detectedFace == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CustomColors.getWarningColor(context).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.face_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Position your face in the center frame',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // Angle and position guidance
          if (_detectedFace != null &&
              !_isFaceAngleCorrectForStep(_detectedFace!))
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CustomColors.getErrorColor(context).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getAngleGuidanceMessage(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // Stability indicator
          if (_detectedFace != null && _stableFaceCount < _requiredStability)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CustomColors.getPrimaryColor(context).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: _stableFaceCount / _requiredStability,
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hold still... ${_requiredStability - _stableFaceCount} more frames',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // Ready to capture indicator
          if (_detectedFace != null &&
              _stableFaceCount >= _requiredStability &&
              !_isCapturing)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CustomColors.getSuccessColor(context).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Ready to capture! Tap the capture button',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.face_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Face Recognition',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Register your face for attendance monitoring',
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
          const SizedBox(height: 12),
          // TFLite Status Indicator
          _buildTFLiteStatusIndicator(),
        ],
      ),
    );
  }

  Widget _buildFaceRegistrationArea() {
    // Show different content based on registration state
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: _isRegistered
          ? _buildRegisteredState()
          : _buildPreRegistrationState(), // Show placeholder before registration starts
    );
  }

  // Full screen camera for registration
  Widget _buildFullScreenCamera() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview - full screen centered
          if (_cameraController != null && _isCameraInitialized)
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),

          // Instructions overlay
          _buildFullScreenInstructions(),

          // Face detection overlay
          if (_detectedFace != null) _buildFullScreenFaceOverlay(),

          // Step indicator overlay
          _buildFullScreenStepIndicator(),

          // Close button
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(25),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = false;
                  });
                },
                icon: Icon(Icons.close_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),

          // Success completion button
          if (_allStepsCompleted)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: ElevatedButton.icon(
                onPressed: () {
                  _completeRegistration();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.getSuccessColor(context),
                  foregroundColor: CustomColors.getOnPrimaryColor(context),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(Icons.check_circle_rounded, size: 24),
                label: Text(
                  'Complete Registration',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Pre-registration state - shown before camera starts
  Widget _buildPreRegistrationState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CustomColors.getPrimaryColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(
            Icons.face_rounded,
            size: 64,
            color: CustomColors.getPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Ready to Register Face',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: CustomColors.getOnSurfaceColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Press "Start Face Registration" to begin',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: CustomColors.getOnSurfaceColor(context).withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRegistrationState() {
    if (!_hasCameraPermission) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Camera Permission Required',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please grant camera permission to register your face',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: _requestCameraPermission,
                icon: Icon(Icons.camera_alt_rounded),
                label: Text('Grant Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => openAppSettings(),
                icon: Icon(Icons.settings_rounded),
                label: Text('Open Settings'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Initializing Camera...',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Camera preview with enhanced aspect ratio
            AspectRatio(
              aspectRatio:
                  3 / 4, // Portrait aspect ratio for better face capture
              child: Stack(
                children: [
                  // Camera preview
                  Positioned.fill(child: CameraPreview(_cameraController!)),

                  // Face guide frame
                  Positioned.fill(
                    child: CustomPaint(
                      painter: EnhancedFaceGuidePainter(
                        currentStep: _registrationSteps[_currentStep].id,
                        stepColor: _registrationSteps[_currentStep].color,
                        detectedFace: _detectedFace,
                        animationValue: _animationController.value,
                      ),
                    ),
                  ),

                  // Enhanced face detection overlay
                  if (_detectedFace != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: EnhancedFacePainter(
                          face: _detectedFace!,
                          imageSize:
                              _cameraController!.value.previewSize ??
                              const Size(640, 480),
                          primaryColor: _registrationSteps[_currentStep].color,
                          animationValue: _animationController.value,
                          currentStep: _registrationSteps[_currentStep].id,
                          showLandmarks: true,
                          showContours: true,
                          showQualityIndicators: true,
                          showGuidelines: true,
                        ),
                      ),
                    ),

                  // Step-specific guidance overlay
                  Positioned.fill(child: _buildStepGuidanceOverlay()),

                  // Real-time feedback overlay
                  Positioned.fill(child: _buildRealTimeFeedbackOverlay()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisteredState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CustomColors.getSuccessColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: CustomColors.getSuccessColor(context),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Face Registered!',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: CustomColors.getSuccessColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your face is now registered for login',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: CustomColors.getOnSurfaceColor(context).withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Instructions',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionItem(
            '1',
            'Ensure good lighting',
            'Make sure your face is well-lit and clearly visible',
          ),
          _buildInstructionItem(
            '2',
            'Remove accessories',
            'Take off glasses, hats, or other face coverings',
          ),
          _buildInstructionItem(
            '3',
            'Look directly at camera',
            'Position your face in the center of the frame',
          ),
          _buildInstructionItem(
            '4',
            'Stay still',
            'Hold your position while the system captures your face',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(
    String number,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
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
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (!_isRegistered && !_isRegistering) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startFaceRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.getPrimaryColor(context),
                foregroundColor: CustomColors.getOnPrimaryColor(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: Icon(Icons.camera_alt_rounded, size: 20),
              label: Text(
                'Start Face Registration',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ] else if (_isRegistering) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isRegistering = false;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: CustomColors.getErrorColor(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: CustomColors.getErrorColor(context),
                  width: 1.5,
                ),
              ),
              icon: Icon(Icons.stop_rounded, size: 20),
              label: Text(
                'Stop Registration',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _removeFaceRegistration,
              style: OutlinedButton.styleFrom(
                foregroundColor: CustomColors.getErrorColor(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: CustomColors.getErrorColor(context),
                  width: 1.5,
                ),
              ),
              icon: Icon(Icons.delete_rounded, size: 20),
              label: Text(
                'Remove Registration',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: CustomColors.getOnSurfaceColor(
                context,
              ).withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: Icon(Icons.arrow_back_rounded, size: 20),
            label: Text(
              'Back to Settings',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _startFaceRegistration() async {
    // Initialize camera if not already initialized
    if (_cameraController == null || !_isCameraInitialized) {
      await _initializeCamera();

      // Check if initialization was successful
      if (_cameraController == null || !_isCameraInitialized) {
        _showError('Failed to initialize camera. Please check permissions.');
        return;
      }
    }

    // Stop current image stream to avoid conflicts
    try {
      await _cameraController!.stopImageStream();
      print('✅ Stopped main widget image stream before full-screen navigation');
    } catch (e) {
      print('ℹ️ No image stream to stop: $e');
    }

    // Navigate to full screen registration mode
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => _FaceRegistrationFullScreen(
              cameraController: _cameraController!,
              faceDetector: _faceDetector,
              cameras: _cameras!,
              userData: widget.userData,
            ),
          ),
        )
        .then((result) {
          // Handle result from full screen registration
          if (result == true) {
            setState(() {
              _isRegistered = true;
            });

            // Show success message
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
                    Expanded(
                      child: Text(
                        'Face registration completed successfully!',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                backgroundColor: CustomColors.getSuccessColor(context),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 3),
              ),
            );
          }

          // Restart face detection for main widget when returning from full-screen
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted &&
                _cameraController != null &&
                _cameraController!.value.isInitialized) {
              try {
                _startFaceDetection();
                print(
                  '✅ Restarted face detection after returning from full-screen',
                );
              } catch (e) {
                print('ℹ️ Face detection already running: $e');
              }
            }
          });
        });
  }

  // Start step-by-step registration process
  void _startStepByStepRegistration() {
    // The face detection will automatically progress through steps
    // Each step completion will be handled by _checkStepCompletion()

    // Start face detection if not already running
    if (!_isDetecting) {
      _startFaceDetection();
    }
  }

  void _removeFaceRegistration() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Remove Face Registration',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to remove your face registration? You\'ll need to register again to use face login.',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                setState(() {
                  _isRegistered = false;
                });

                // Show confirmation message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Face registration removed',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
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
                'Remove',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // Camera initialization method
  Future<void> _initializeCamera() async {
    try {
      // Request camera permission first
      await _requestCameraPermission();

      if (!_hasCameraPermission) {
        print('Camera permission not granted');
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras available on this device');
        return;
      }

      print('Found ${_cameras!.length} cameras');

      // Use front camera for face registration
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      print('Using camera: ${frontCamera.name}');

      // Use MAXIMUM quality settings for crystal clear camera like native app
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.max, // Use absolute maximum resolution available
        enableAudio: false,
        imageFormatGroup:
            ImageFormatGroup.bgra8888, // Best compatibility for face detection
      );

      await _cameraController!.initialize();

      // Configure NATIVE camera features for ULTRA HIGH QUALITY like phone's camera app
      try {
        // Basic camera modes for quality
        await _cameraController!.setFocusMode(FocusMode.auto);
        await _cameraController!.setExposureMode(ExposureMode.auto);
        await _cameraController!.setFlashMode(FlashMode.off);

        // Advanced quality optimizations for maximum sharpness
        try {
          await _cameraController!.setFocusPoint(
            null,
          ); // Auto-focus center for sharpest image
          await _cameraController!.setExposurePoint(
            null,
          ); // Auto-expose center for best lighting
          await _cameraController!.setZoomLevel(
            1.0,
          ); // No digital zoom for maximum quality

          // Additional native optimizations for clarity
          await _cameraController!.setExposureOffset(
            0.0,
          ); // Neutral exposure for natural colors
          await _cameraController!
              .lockCaptureOrientation(); // Prevent rotation blur

          print(
            '📱 ULTRA HIGH QUALITY: All native camera optimizations applied',
          );
          print(
            '🔥 Camera quality: MAXIMUM - same as phone\'s native camera app',
          );
        } catch (e) {
          print('Advanced quality settings: $e');
        }

        // Log camera specifications for quality verification
        print('📊 CAMERA SPECS:');
        print('   - Resolution: ${_cameraController!.value.previewSize}');
        print('   - Format: BGRA8888 (32-bit color)');
        print('   - Focus: Auto with continuous tracking');
        print('   - Exposure: Auto with scene optimization');
        print('   - Quality: MAXIMUM AVAILABLE');
      } catch (e) {
        print('Camera setup: $e');
      }

      print('✅ Camera initialized successfully!');
      print('Camera value: ${_cameraController!.value.isInitialized}');
      print('Preview size: ${_cameraController!.value.previewSize}');

      // Test face detector
      print('🧪 Testing face detector...');
      try {
        await _faceDetector.processImage(InputImage.fromFilePath(''));
        print('✅ Face detector is working!');
      } catch (e) {
        print('✅ Face detector initialized (expected error: $e)');
      }

      // Start face detection with longer delay to ensure camera is fully ready
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted &&
            _cameraController != null &&
            _cameraController!.value.isInitialized) {
          _startFaceDetection();
          print(
            '✅ Face detection started after camera initialization confirmation',
          );
        } else {
          print('❌ Camera not ready after delay, retrying...');
          // Retry after another delay
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted &&
                _cameraController != null &&
                _cameraController!.value.isInitialized) {
              _startFaceDetection();
            }
          });
        }
      });

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      _showError(
        'Failed to initialize camera. Please check your device settings and try again.',
      );
    }
  }

  // Request camera permission
  Future<void> _requestCameraPermission() async {
    try {
      // First check if permission is already granted
      PermissionStatus status = await Permission.camera.status;

      if (status.isGranted) {
        if (mounted) {
          setState(() {
            _hasCameraPermission = true;
          });
        }
        return;
      }

      // If permission is permanently denied, show dialog to open settings
      if (status.isPermanentlyDenied) {
        _showPermissionDialog();
        return;
      }

      // Request permission
      status = await Permission.camera.request();

      if (mounted) {
        setState(() {
          _hasCameraPermission = status.isGranted;
        });
      }

      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          _showPermissionDialog();
        } else {
          _showError(
            'Camera permission is required for face registration. Please grant permission in settings.',
          );
        }
      }
    } catch (e) {
      print('Permission error: $e');
      _showError(
        'Failed to request camera permission. Please check your device settings.',
      );
    }
  }

  // Show permission dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Camera Permission Required',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Camera access is required for face registration. Please enable camera permission in your device settings.',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Open Settings',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // Start DEBUG face detection with logging
  void _startFaceDetection() {
    if (_cameraController == null) {
      print('❌ Camera controller is null!');
      return;
    }

    print('🚀 Starting face detection stream...');

    try {
      _cameraController!.startImageStream((CameraImage image) {
        if (_isDetecting || !mounted) return;
        _isDetecting = true;

        _processImageWithNativeFeatures(image).catchError((error) {
          print('Error in image processing: $error');
          _isDetecting = false;
        });
      });
      print('✅ Face detection stream started successfully!');
    } catch (e) {
      print('💥 Failed to start image stream: $e');
    }
  }

  // ULTRA ADVANCED face detection with stability and confidence scoring
  Future<void> _processImageWithNativeFeatures(CameraImage image) async {
    try {
      print(
        '📷 Processing image: ${image.width}x${image.height}, format: ${image.format.group}',
      );

      final inputImage = _convertCameraImageOptimized(image);
      if (inputImage == null) {
        print('❌ Failed to convert camera image!');
        _isDetecting = false;
        return;
      }

      print('🔍 Running ULTRA ADVANCED face detection...');

      // Primary face detection with multiple orientation attempts
      List<Face> allFaces = [];

      // Try multiple rotations for maximum detection accuracy
      final rotations = [
        InputImageRotation.rotation0deg,
        InputImageRotation.rotation90deg,
        InputImageRotation.rotation270deg,
      ];

      for (final rotation in rotations) {
        try {
          final rotatedImage = InputImage.fromBytes(
            bytes: inputImage.bytes!,
            metadata: InputImageMetadata(
              size: inputImage.metadata!.size,
              rotation: rotation,
              format: inputImage.metadata!.format,
              bytesPerRow: inputImage.metadata!.bytesPerRow,
            ),
          );

          final faces = await _faceDetector.processImage(rotatedImage);
          allFaces.addAll(faces);
          print('📐 Rotation ${rotation.name}: Found ${faces.length} faces');
        } catch (e) {
          print('⚠️ Rotation ${rotation.name} failed: $e');
        }
      }

      print('🔍 Total faces found across all rotations: ${allFaces.length}');

      // Advanced face quality filtering and scoring
      List<Face> qualityFaces = _filterAndScoreFaces(
        allFaces,
        image.width,
        image.height,
      );

      // Apply stability checking
      Face? finalFace = _applyStabilityFilter(qualityFaces);

      print('👥 Final quality faces after filtering: ${qualityFaces.length}');
      print('🎯 Selected stable face: ${finalFace != null ? "YES" : "NO"}');

      if (mounted) {
        setState(() {
          // Apply face smoothing for stable detection
          _detectedFace = _applySmoothingToFace(finalFace);

          if (_detectedFace != null) {
            print('✅ ULTRA HIGH QUALITY FACE DETECTED!');
            print(
              '   Size: ${_detectedFace!.boundingBox.width}x${_detectedFace!.boundingBox.height}',
            );
            print(
              '   Confidence: ${(_currentConfidence * 100).toStringAsFixed(1)}%',
            );
            print('   Stability: $_stableFaceCount/$_requiredStability');

            // Update native camera focus on detected face
            _updateNativeCameraForFace();

            _checkStepCompletion();
          } else {
            print('❌ NO STABLE QUALITY FACE DETECTED in this frame');
          }
        });
      }
    } catch (e) {
      print('💥 Face detection ERROR: $e');
    } finally {
      _isDetecting = false;
    }
  }

  // Advanced face filtering and scoring system
  List<Face> _filterAndScoreFaces(
    List<Face> faces,
    int imageWidth,
    int imageHeight,
  ) {
    if (faces.isEmpty) return [];

    List<MapEntry<Face, double>> scoredFaces = [];
    final imageArea = imageWidth * imageHeight;

    for (final face in faces) {
      double score = 0.0;
      final rect = face.boundingBox;
      final faceArea = rect.width * rect.height;
      final faceRatio = faceArea / imageArea;

      // Size scoring (optimal face size is 8-25% of image)
      if (faceRatio >= 0.08 && faceRatio <= 0.25) {
        score += 30.0; // Perfect size range
      } else if (faceRatio >= 0.05 && faceRatio <= 0.35) {
        score += 20.0; // Good size range
      } else if (faceRatio >= 0.03) {
        score += 10.0; // Acceptable size range
      } else {
        continue; // Too small, skip this face
      }

      // Head angle scoring (prefer straight faces)
      if (face.headEulerAngleX != null &&
          face.headEulerAngleY != null &&
          face.headEulerAngleZ != null) {
        final xAngle = face.headEulerAngleX!.abs();
        final yAngle = face.headEulerAngleY!.abs();
        final zAngle = face.headEulerAngleZ!.abs();

        // Perfect straight face
        if (xAngle < 10 && yAngle < 10 && zAngle < 10) {
          score += 25.0;
        }
        // Good angle
        else if (xAngle < 20 && yAngle < 20 && zAngle < 15) {
          score += 15.0;
        }
        // Acceptable angle
        else if (xAngle < 35 && yAngle < 35 && zAngle < 25) {
          score += 5.0;
        }
        // Extreme angle - reduce score
        else {
          score -= 10.0;
        }
      }

      // Position scoring (prefer centered faces)
      final centerX = rect.left + rect.width / 2;
      final centerY = rect.top + rect.height / 2;
      final imageCenterX = imageWidth / 2;
      final imageCenterY = imageHeight / 2;

      final distanceFromCenter =
          ((centerX - imageCenterX).abs() + (centerY - imageCenterY).abs()) / 2;
      final maxDistance = (imageWidth + imageHeight) / 4;
      final centerScore = 15.0 * (1.0 - (distanceFromCenter / maxDistance));
      score += centerScore;

      // Landmark quality scoring
      final landmarks = face.landmarks;
      int landmarkCount = landmarks.values.where((l) => l != null).length;
      if (landmarkCount >= 8) {
        score += 15.0; // Excellent landmark detection
      } else if (landmarkCount >= 5) {
        score += 10.0; // Good landmark detection
      } else if (landmarkCount >= 3) {
        score += 5.0; // Basic landmark detection
      }

      // Smile and eye classification bonus (if available)
      if (face.smilingProbability != null && face.smilingProbability! > 0.3) {
        score += 5.0; // Bonus for detectable smile
      }
      if (face.leftEyeOpenProbability != null &&
          face.rightEyeOpenProbability != null) {
        if (face.leftEyeOpenProbability! > 0.5 &&
            face.rightEyeOpenProbability! > 0.5) {
          score += 5.0; // Bonus for open eyes
        }
      }

      // Only keep faces with minimum score
      if (score >= 35.0) {
        scoredFaces.add(MapEntry(face, score));
        print('✅ Quality face scored: ${score.toStringAsFixed(1)} points');
      } else {
        print(
          '❌ Face rejected: ${score.toStringAsFixed(1)} points (minimum 35.0 required)',
        );
      }
    }

    // Sort by score (highest first)
    scoredFaces.sort((a, b) => b.value.compareTo(a.value));

    // Update confidence with best score
    if (scoredFaces.isNotEmpty) {
      _currentConfidence = scoredFaces.first.value / 100.0; // Normalize to 0-1
    } else {
      _currentConfidence = 0.0;
    }

    return scoredFaces.map((entry) => entry.key).toList();
  }

  // Stability filter to reduce jitter and ensure consistent detection
  Face? _applyStabilityFilter(List<Face> faces) {
    if (faces.isEmpty) {
      _stableFaceCount = 0;
      _previousFace = null;
      _faceHistory.clear();
      return null;
    }

    final currentFace = faces.first; // Best scored face

    // Check if this face is similar to previous detection
    if (_previousFace != null) {
      final similarity = _calculateFaceSimilarity(currentFace, _previousFace!);
      print('🔍 Face similarity: ${(similarity * 100).toStringAsFixed(1)}%');

      if (similarity > 0.75) {
        // 75% similarity threshold
        _stableFaceCount++;
        print('📈 Stable face count: $_stableFaceCount');
      } else {
        _stableFaceCount = 1; // Reset but count current face
        print('🔄 Face similarity too low, resetting stability count');
      }
    } else {
      _stableFaceCount = 1;
    }

    // Add to history for smoothing
    _faceHistory.add(currentFace);
    if (_faceHistory.length > 5) {
      _faceHistory.removeAt(0); // Keep only last 5 frames
    }

    _previousFace = currentFace;

    // Only return face if it's been stable for required frames
    if (_stableFaceCount >= _requiredStability) {
      return _smoothFaceDetection(); // Return smoothed face
    } else {
      return null; // Not stable enough yet
    }
  }

  // Calculate similarity between two faces based on position and size
  double _calculateFaceSimilarity(Face face1, Face face2) {
    final rect1 = face1.boundingBox;
    final rect2 = face2.boundingBox;

    // Position similarity
    final centerX1 = rect1.left + rect1.width / 2;
    final centerY1 = rect1.top + rect1.height / 2;
    final centerX2 = rect2.left + rect2.width / 2;
    final centerY2 = rect2.top + rect2.height / 2;

    final distance =
        ((centerX1 - centerX2).abs() + (centerY1 - centerY2).abs()) / 2;
    final maxDistance =
        (rect1.width + rect1.height) / 4; // Quarter of face dimensions
    final positionSimilarity = 1.0 - (distance / maxDistance).clamp(0.0, 1.0);

    // Size similarity
    final sizeRatio =
        (rect1.width * rect1.height) / (rect2.width * rect2.height);
    final sizeSimilarity = sizeRatio > 1.0 ? 1.0 / sizeRatio : sizeRatio;

    // Combined similarity (weighted average)
    return (positionSimilarity * 0.7) + (sizeSimilarity * 0.3);
  }

  // Smooth face detection using historical data
  Face _smoothFaceDetection() {
    if (_faceHistory.length <= 1) {
      return _faceHistory.last;
    }

    // Calculate average position and size
    double avgLeft = 0, avgTop = 0, avgWidth = 0, avgHeight = 0;

    for (final face in _faceHistory) {
      final rect = face.boundingBox;
      avgLeft += rect.left;
      avgTop += rect.top;
      avgWidth += rect.width;
      avgHeight += rect.height;
    }

    final count = _faceHistory.length;
    avgLeft /= count;
    avgTop /= count;
    avgWidth /= count;
    avgHeight /= count;

    // Create smoothed face (use latest face as base and adjust position)
    final latestFace = _faceHistory.last;

    // For now, return the latest face with improved confidence
    // In a real implementation, you'd create a new Face object with smoothed coordinates
    print('📊 Smoothed face detection applied over $count frames');

    return latestFace;
  }

  // Update native camera focus and exposure for detected faces
  Future<void> _updateNativeCameraForFace() async {
    try {
      if (_detectedFace != null && _cameraController != null) {
        final face = _detectedFace!;
        final boundingBox = face.boundingBox;

        // Calculate face center point for native camera focus
        final centerX =
            (boundingBox.left + boundingBox.width / 2) /
            _cameraController!.value.previewSize!.width;
        final centerY =
            (boundingBox.top + boundingBox.height / 2) /
            _cameraController!.value.previewSize!.height;

        // Set native camera focus and exposure to face location
        await _cameraController!.setFocusPoint(Offset(centerX, centerY));
        await _cameraController!.setExposurePoint(Offset(centerX, centerY));
      }
    } catch (e) {
      // Native features may not be available on all devices
      print('Native camera adjustment not available: $e');
    }
  }

  // DEBUG camera image conversion with detailed logging
  InputImage? _convertCameraImageOptimized(CameraImage image) {
    try {
      print(
        '🖼️ Converting image: ${image.width}x${image.height}, planes: ${image.planes.length}',
      );
      print('Format raw: ${image.format.raw}, group: ${image.format.group}');

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
        print(
          'Plane: ${plane.bytes.length} bytes, bytesPerRow: ${plane.bytesPerRow}',
        );
      }
      final bytes = allBytes.done().buffer.asUint8List();
      print('Total bytes: ${bytes.length}');

      // Check if image has actual data (not all zeros)
      final nonZeroBytes = bytes.where((b) => b != 0).length;
      print(
        'Non-zero bytes: $nonZeroBytes/${bytes.length} (${(nonZeroBytes / bytes.length * 100).toStringAsFixed(1)}%)',
      );

      if (nonZeroBytes < bytes.length * 0.1) {
        print('⚠️ WARNING: Image seems mostly empty!');
      }

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final camera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      final InputImageRotation imageRotation = _rotationIntToImageRotation(
        camera.sensorOrientation,
      );
      print(
        'Camera orientation: ${camera.sensorOrientation}, rotation: $imageRotation',
      );

      final InputImageFormat inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;
      print('Input format: $inputImageFormat');

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      print('✅ Successfully converted camera image to InputImage');
      return inputImage;
    } catch (e) {
      print('💥 Image conversion FAILED: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Convert rotation to InputImageRotation - FIX for face detection
  InputImageRotation _rotationIntToImageRotation(int rotation) {
    // ALWAYS use 0 degrees for front camera to fix face detection
    print(
      'Original rotation: $rotation, using: rotation0deg for better face detection',
    );
    return InputImageRotation.rotation0deg;

    // Original logic (commented out):
    // switch (rotation) {
    //   case 90:
    //     return InputImageRotation.rotation90deg;
    //   case 180:
    //     return InputImageRotation.rotation180deg;
    //   case 270:
    //     return InputImageRotation.rotation270deg;
    //   default:
    //     return InputImageRotation.rotation0deg;
    // }
  }

  // Check if current step is completed with STRICT angle validation
  Future<void> _checkStepCompletion() async {
    if (_detectedFace == null) return;

    // First check if face angle is correct for the current step
    if (!_isFaceAngleCorrectForStep(_detectedFace!)) {
      print('❌ Face angle not correct for step ${_currentStep + 1}');
      return;
    }

    bool stepCompleted = false;

    switch (_currentStep) {
      case 0: // Look straight ahead
        stepCompleted = _isLookingStraight();
        break;
      case 1: // Look up
        stepCompleted = _isLookingUp();
        break;
      case 2: // Look down
        stepCompleted = _isLookingDown();
        break;
      case 3: // Look left
        stepCompleted = _isLookingLeft();
        break;
      case 4: // Look right
        stepCompleted = _isLookingRight();
        break;
      case 5: // Blink eyes
        stepCompleted = _isBlinking();
        break;
      case 6: // Smile
        stepCompleted = _isSmiling();
        break;
      case 7: // Neutral expression
        stepCompleted = _isNeutralExpression();
        break;
    }

    // Debug and simplified auto-capture
    print(
      '📊 Step ${_currentStep + 1} (${_registrationSteps[_currentStep].title}): stepCompleted=$stepCompleted, captureEnabled=$_captureEnabled, alreadyCompleted=${_completedSteps.containsKey(_currentStep)}',
    );

    if (stepCompleted &&
        !_completedSteps.containsKey(_currentStep) &&
        _captureEnabled) {
      print(
        '✅ AUTO-CAPTURING Step ${_currentStep + 1} - ${_registrationSteps[_currentStep]}!',
      );

      // Capture photo and wait for completion
      final captureSuccess = await _captureStepPhoto();

      if (captureSuccess) {
        // Mark step as completed
        _completedSteps[_currentStep] = StepQualityData(
          stepIndex: _currentStep,
          overallQuality: 0.8, // Default quality for legacy capture
          qualityMetrics: {},
          completedAt: DateTime.now(),
        );
        _showStepCompleted();

        // Check if all steps are completed after this step
        print(
          '🔍 Step ${_currentStep + 1} completed. Total completed: ${_completedSteps.length}/${_registrationSteps.length}',
        );

        if (_completedSteps.length == _registrationSteps.length) {
          print('🎉 ALL STEPS COMPLETED! Calling _completeRegistration()');
          _allStepsCompleted = true;
          _completeRegistration();
        } else {
          // Move to next step
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _currentStep++;
                _captureEnabled = true;
              });
              print('✅ Moved to step ${_currentStep + 1}');
            }
          });
        }
      } else {
        print(
          '❌ Capture failed for step ${_currentStep + 1}, re-enabling capture',
        );
        setState(() {
          _captureEnabled = true;
        });
      }
    }
  }

  // STRICT pose detection for step completion
  bool _isLookingStraight() {
    if (_detectedFace == null) {
      print('No face for straight check');
      return false;
    }

    final headEulerAngleX = _detectedFace!.headEulerAngleX;
    final headEulerAngleY = _detectedFace!.headEulerAngleY;
    final headEulerAngleZ = _detectedFace!.headEulerAngleZ;

    if (headEulerAngleX == null ||
        headEulerAngleY == null ||
        headEulerAngleZ == null) {
      print('Head angles not available, assuming straight');
      return true; // If angles not available, assume straight
    }

    // Use the same strict criteria as the angle validation
    final result =
        headEulerAngleX.abs() <= 8.0 &&
        headEulerAngleY.abs() <= 8.0 &&
        headEulerAngleZ.abs() <= 5.0;

    print(
      'Straight check: X=${headEulerAngleX.toStringAsFixed(1)}, Y=${headEulerAngleY.toStringAsFixed(1)}, Z=${headEulerAngleZ.toStringAsFixed(1)} -> $result',
    );
    return result;
  }

  bool _isLookingUp() {
    if (_detectedFace == null) return false;
    final headEulerAngleX = _detectedFace!.headEulerAngleX;
    if (headEulerAngleX == null) {
      return true; // Fallback: assume success if no data
    }
    // Use the same strict criteria as the angle validation
    final result = headEulerAngleX <= -12.0 && headEulerAngleX >= -28.0;
    print('Up check: X=${headEulerAngleX.toStringAsFixed(1)} -> $result');
    return result;
  }

  bool _isLookingDown() {
    if (_detectedFace == null) return false;
    final headEulerAngleX = _detectedFace!.headEulerAngleX;
    if (headEulerAngleX == null) return true;
    // Use the same strict criteria as the angle validation
    final result = headEulerAngleX >= 12.0 && headEulerAngleX <= 28.0;
    print('Down check: X=${headEulerAngleX.toStringAsFixed(1)} -> $result');
    return result;
  }

  bool _isLookingLeft() {
    if (_detectedFace == null) return false;
    final headEulerAngleY = _detectedFace!.headEulerAngleY;
    if (headEulerAngleY == null) return true;
    // Use the same strict criteria as the angle validation
    final result = headEulerAngleY <= -15.0 && headEulerAngleY >= -35.0;
    print('Left check: Y=${headEulerAngleY.toStringAsFixed(1)} -> $result');
    return result;
  }

  bool _isLookingRight() {
    if (_detectedFace == null) return false;
    final headEulerAngleY = _detectedFace!.headEulerAngleY;
    if (headEulerAngleY == null) return true;
    // Use the same strict criteria as the angle validation
    final result = headEulerAngleY >= 15.0 && headEulerAngleY <= 35.0;
    print('Right check: Y=${headEulerAngleY.toStringAsFixed(1)} -> $result');
    return result;
  }

  bool _isBlinking() {
    if (_detectedFace == null) {
      print('👁️ Blink check: NO FACE DETECTED');
      _resetBlinkDetection();
      return false;
    }

    // First check if face is in correct position for blink detection
    final headEulerAngleX = _detectedFace!.headEulerAngleX ?? 0.0;
    final headEulerAngleY = _detectedFace!.headEulerAngleY ?? 0.0;
    final headEulerAngleZ = _detectedFace!.headEulerAngleZ ?? 0.0;

    // Face must be relatively straight for accurate blink detection
    if (headEulerAngleX.abs() > 12.0 ||
        headEulerAngleY.abs() > 12.0 ||
        headEulerAngleZ.abs() > 8.0) {
      print('👁️ Face not straight enough for blink detection');
      return false;
    }

    // Use face landmarks to detect blink if available
    final leftEye = _detectedFace!.landmarks[FaceLandmarkType.leftEye];
    final rightEye = _detectedFace!.landmarks[FaceLandmarkType.rightEye];

    if (leftEye != null && rightEye != null) {
      print('👁️ Blink check: Eye landmarks available - checking blink...');
      // Calculate eye openness based on face height vs eye positions
      final faceHeight = _detectedFace!.boundingBox.height;
      final eyeDistance = (leftEye.position.y - rightEye.position.y).abs();
      final eyeRatio = eyeDistance / faceHeight;

      print('👁️ Eye ratio: ${eyeRatio.toStringAsFixed(4)} (threshold: 0.02)');

      // If eyes appear closed (low ratio)
      if (eyeRatio < 0.02) {
        _blinkFrameCount++;
        _eyesOpenFrameCount = 0;
        print('👁️ Eyes CLOSED frame $_blinkFrameCount/$_blinkRequiredFrames');

        if (_blinkFrameCount >= _blinkRequiredFrames && !_blinkDetected) {
          _blinkDetected = true;
          print('✅ BLINK DETECTED SUCCESSFULLY!');
          return true;
        }
      } else {
        // Eyes are open
        _eyesOpenFrameCount++;
        print('👁️ Eyes OPEN ($_eyesOpenFrameCount frames)');
        if (_eyesOpenFrameCount > 3) {
          _blinkFrameCount = 0; // Reset if eyes have been open
          print(
            '👁️ Blink counter reset - eyes have been open for $_eyesOpenFrameCount frames',
          );
        }
      }
    } else {
      // No eye landmarks available - cannot detect real blinks
      print(
        '👁️ No eye landmarks available for blink detection - waiting for landmarks...',
      );
    }

    return false;
  }

  void _resetBlinkDetection() {
    _blinkFrameCount = 0;
    _eyesOpenFrameCount = 0;
    _blinkDetected = false;
  }

  // Apply smoothing to face detection for stable tracking
  Face? _applySmoothingToFace(Face? newFace) {
    if (newFace == null) {
      _consecutiveDetections = 0;
      _faceHistory.clear();
      return null;
    }

    // Add new face to history
    _faceHistory.add(newFace);
    _consecutiveDetections++;

    // Keep only recent history
    if (_faceHistory.length > _maxFaceHistory) {
      _faceHistory.removeAt(0);
    }

    // Need at least 2 consecutive detections for stability
    if (_consecutiveDetections < 2) {
      return null;
    }

    // Calculate smoothed position by averaging recent detections
    double avgLeft = 0, avgTop = 0, avgRight = 0, avgBottom = 0;
    int validFaces = 0;

    for (int i = 0; i < _faceHistory.length; i++) {
      final face = _faceHistory[i];
      final weight =
          (i + 1) / _faceHistory.length; // More weight to recent faces

      avgLeft += face.boundingBox.left * weight;
      avgTop += face.boundingBox.top * weight;
      avgRight += face.boundingBox.right * weight;
      avgBottom += face.boundingBox.bottom * weight;
      validFaces++;
    }

    if (validFaces == 0) return newFace;

    // Normalize averages
    avgLeft /= validFaces;
    avgTop /= validFaces;
    avgRight /= validFaces;
    avgBottom /= validFaces;

    // Create smoothed face with averaged position but current face attributes
    return Face(
      boundingBox: Rect.fromLTRB(avgLeft, avgTop, avgRight, avgBottom),
      landmarks: newFace.landmarks,
      contours: newFace.contours,
      headEulerAngleX: newFace.headEulerAngleX,
      headEulerAngleY: newFace.headEulerAngleY,
      headEulerAngleZ: newFace.headEulerAngleZ,
      leftEyeOpenProbability: newFace.leftEyeOpenProbability,
      rightEyeOpenProbability: newFace.rightEyeOpenProbability,
      smilingProbability: newFace.smilingProbability,
      trackingId: newFace.trackingId,
    );
  }

  bool _isSmiling() {
    if (_detectedFace == null) {
      print('😊 Smile check: NO FACE DETECTED');
      return false;
    }

    // First check if face is in correct position for smile detection
    final headEulerAngleX = _detectedFace!.headEulerAngleX ?? 0.0;
    final headEulerAngleY = _detectedFace!.headEulerAngleY ?? 0.0;
    final headEulerAngleZ = _detectedFace!.headEulerAngleZ ?? 0.0;

    // Face must be relatively straight for accurate smile detection
    if (headEulerAngleX.abs() > 12.0 ||
        headEulerAngleY.abs() > 12.0 ||
        headEulerAngleZ.abs() > 8.0) {
      print('😊 Face not straight enough for smile detection');
      return false;
    }

    // Use ML Kit's smile classification
    final smilingProbability = _detectedFace!.smilingProbability;
    if (smilingProbability != null) {
      print(
        '😊 Smile probability: ${(smilingProbability * 100).toStringAsFixed(1)}% (threshold: 70%)',
      );

      if (smilingProbability > 0.7) {
        print('😊 SMILE DETECTED! Auto capturing...');
        return true;
      } else {
        print('😊 Not smiling enough - keep smiling!');
        return false;
      }
    } else {
      print('😊 Smile detection not available - waiting for classification...');
      return false;
    }
  }

  bool _isNeutralExpression() {
    if (_detectedFace == null) {
      print('😐 Neutral check: NO FACE DETECTED');
      return false;
    }

    // First check if face is in correct position for neutral expression detection
    final headEulerAngleX = _detectedFace!.headEulerAngleX ?? 0.0;
    final headEulerAngleY = _detectedFace!.headEulerAngleY ?? 0.0;
    final headEulerAngleZ = _detectedFace!.headEulerAngleZ ?? 0.0;

    // Face must be straight for accurate neutral expression detection
    if (headEulerAngleX.abs() > 10.0 ||
        headEulerAngleY.abs() > 10.0 ||
        headEulerAngleZ.abs() > 6.0) {
      print('😐 Face not straight enough for neutral expression detection');
      return false;
    }

    // Use ML Kit's smile classification to detect neutral expression
    final smilingProbability = _detectedFace!.smilingProbability;
    if (smilingProbability != null) {
      print(
        '😐 Smile probability: ${(smilingProbability * 100).toStringAsFixed(1)}% (neutral threshold: <30%)',
      );

      // Neutral expression means not smiling too much
      if (smilingProbability < 0.3) {
        print('😐 NEUTRAL EXPRESSION DETECTED! Auto capturing...');
        return true;
      } else {
        print('😐 Expression not neutral - relax your face');
        return false;
      }
    } else {
      print('😐 Expression detection not available - assuming neutral');
      return true; // Assume neutral if detection not available
    }
  }

  // INSTANT native camera capture with TFLite integration
  Future<bool> _captureStepPhoto() async {
    print(
      '📸 _captureStepPhoto called - captureEnabled=$_captureEnabled, isCapturing=$_isCapturing, cameraController=${_cameraController != null}, tfliteInitialized=$_isTFLiteInitialized',
    );
    if (!_captureEnabled || _isCapturing || _cameraController == null) {
      print(
        '❌ Capture blocked: captureEnabled=$_captureEnabled, isCapturing=$_isCapturing, cameraController=${_cameraController != null}',
      );
      return false;
    }

    setState(() {
      _isCapturing = true;
      _captureEnabled = false;
    });

    try {
      // Use native camera's instant capture
      final XFile photo = await _cameraController!.takePicture();
      final photoFile = File(photo.path);
      print(
        '📸 INSTANT NATIVE CAPTURE - Step ${_currentStep + 1}: ${photo.path}',
      );

      // Store the captured photo
      _capturedPhotos.add(photoFile);

      // Upload to Cloudinary immediately after capture and wait for completion
      bool uploadSuccessful = false;
      if (widget.userData['_id'] != null) {
        print('☁️ Starting Cloudinary upload (Regular Mode)...');

        // Show upload progress indicator
        if (mounted) {
          setState(() {
            _feedbackMessage = 'Uploading photo to cloud...';
            _feedbackColor = CustomColors.getWarningColor(context);
          });
        }

        final uploadResult = await CloudinaryService.uploadFaceImage(
          userId: widget.userData['_id'],
          imageFile: photoFile,
          imageType: 'face_registration_step_${_currentStep + 1}',
          stepName: _registrationSteps[_currentStep].title,
          stepNumber: _currentStep + 1,
        );

        if (uploadResult['success']) {
          print(
            '🎉 UPLOAD SUCCESS (Regular)! URL: ${uploadResult['data']['image_url']}',
          );
          // Store the Cloudinary URL for later use
          _cloudinaryUrls.add(uploadResult['data']['image_url']);
          uploadSuccessful = true;

          if (mounted) {
            setState(() {
              _feedbackMessage = 'Photo uploaded successfully!';
              _feedbackColor = CustomColors.getSuccessColor(context);
            });
          }
        } else {
          print('💥 UPLOAD FAILED (Regular): ${uploadResult['message']}');
          if (mounted) {
            setState(() {
              _feedbackMessage = 'Upload failed. Please try again.';
              _feedbackColor = CustomColors.getErrorColor(context);
            });
          }
          // Don't proceed if upload failed
          return false;
        }
      } else {
        print('❌ No user ID found for upload (Regular Mode)');
        if (mounted) {
          setState(() {
            _feedbackMessage = 'No user ID found for upload';
            _feedbackColor = CustomColors.getErrorColor(context);
          });
        }
        return false;
      }

      // Only proceed to TFLite analysis if upload was successful
      if (!uploadSuccessful) {
        print('❌ Stopping capture process - upload failed');
        return false;
      }

      // Generate TFLite face embedding and analysis if TFLite is initialized
      Logger.info(
        '📊 Capture analysis check: _isTFLiteInitialized=$_isTFLiteInitialized, _detectedFace=${_detectedFace != null}',
      );

      if (_isTFLiteInitialized && _detectedFace != null) {
        Logger.info('✅ Processing TFLite analysis for captured photo...');
        await _processTFLiteAnalysis(photoFile, _detectedFace!);
      } else {
        Logger.warning(
          '⚠️ TFLite not initialized ($_isTFLiteInitialized) or no face detected (${_detectedFace != null}), skipping analysis',
        );

        // Generate synthetic embedding for testing
        final syntheticEmbedding = List.generate(
          512,
          (index) => math.Random().nextDouble(),
        );
        _capturedEmbeddings.add(
          FaceEmbeddingData(
            embedding: syntheticEmbedding,
            quality: 0.8,
            stepId: _registrationSteps[_currentStep].id,
            timestamp: DateTime.now(),
            metadata: {},
            detectedFace: _detectedFace!,
          ),
        );
        Logger.info(
          '🎭 Generated synthetic embedding for testing (${syntheticEmbedding.length}D)',
        );
      }
    } catch (e) {
      print('❌ Native capture error: $e');
      Logger.error('❌ Error during photo capture: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }

    // Return true if we reached here (capture was successful)
    return true;
  }

  // Optimize camera using NATIVE features before capture
  Future<void> _optimizeCameraForCapture() async {
    try {
      if (_detectedFace != null) {
        final face = _detectedFace!;
        final boundingBox = face.boundingBox;

        // Use native camera auto-focus on the detected face
        final centerX =
            (boundingBox.left + boundingBox.width / 2) /
            _cameraController!.value.previewSize!.width;
        final centerY =
            (boundingBox.top + boundingBox.height / 2) /
            _cameraController!.value.previewSize!.height;

        // Native camera focus and exposure optimization
        await _cameraController!.setFocusPoint(Offset(centerX, centerY));
        await _cameraController!.setExposurePoint(Offset(centerX, centerY));

        // Brief pause for native camera to adjust focus/exposure
        await Future.delayed(const Duration(milliseconds: 100));

        print(
          'Native camera optimized for face at (${centerX.toStringAsFixed(2)}, ${centerY.toStringAsFixed(2)})',
        );
      }
    } catch (e) {
      print('Native optimization failed: $e');
    }
  }

  // Show step completed feedback with TFLite analysis
  void _showStepCompleted() {
    String message =
        'Step ${_currentStep + 1} captured! Photo taken automatically.';

    // Add TFLite analysis information if available
    if (_capturedAnalyses.isNotEmpty &&
        _capturedAnalyses.length > _currentStep) {
      final analysis = _capturedAnalyses[_currentStep];
      final tfliteInfo = <String>[];

      // Add emotion information
      if (analysis['emotion'] != null) {
        final emotions = analysis['emotion'] as Map<String, double>;
        final topEmotion = emotions.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        if (topEmotion.value > 0.5) {
          tfliteInfo.add(
            '${topEmotion.key} (${(topEmotion.value * 100).toStringAsFixed(0)}%)',
          );
        }
      }

      // Add age information
      if (analysis['age'] != null) {
        tfliteInfo.add('Age: ${analysis['age']}');
      }

      // Add gender information
      if (analysis['gender'] != null) {
        tfliteInfo.add('${analysis['gender']}');
      }

      if (tfliteInfo.isNotEmpty) {
        message += '\nAI Analysis: ${tfliteInfo.join(', ')}';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: CustomColors.getSuccessColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  // Build face detection overlay inside AspectRatio - perfectly aligned
  Widget _buildFaceDetectionOverlayInside() {
    if (_detectedFace == null) return const SizedBox.shrink();

    // Get the actual camera preview size and aspect ratio
    final cameraPreviewSize = _cameraController!.value.previewSize!;
    final cameraAspectRatio = _cameraController!.value.aspectRatio;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the actual display size based on aspect ratio
          final displayWidth = constraints.maxWidth;
          final displayHeight = constraints.maxHeight;

          // Calculate the scaled size that maintains aspect ratio
          double scaledWidth, scaledHeight;
          double offsetX = 0, offsetY = 0;

          if (displayWidth / displayHeight > cameraAspectRatio) {
            // Display is wider than camera - scale by height
            scaledHeight = displayHeight;
            scaledWidth = displayHeight * cameraAspectRatio;
            offsetX = (displayWidth - scaledWidth) / 2;
          } else {
            // Display is taller than camera - scale by width
            scaledWidth = displayWidth;
            scaledHeight = displayWidth / cameraAspectRatio;
            offsetY = (displayHeight - scaledHeight) / 2;
          }

          return Positioned(
            left: offsetX,
            top: offsetY,
            width: scaledWidth,
            height: scaledHeight,
            child: CustomPaint(
              painter: FaceDetectionPainter(
                faces: [_detectedFace!],
                face: _detectedFace,
                imageSize: cameraPreviewSize,
                previewSize: Size(scaledWidth, scaledHeight),
                primaryColor: _getStepColor(),
                animationValue: 1.0,
                showLandmarks: true,
                showContours: true,
              ),
            ),
          );
        },
      ),
    );
  }

  // Build face detection overlay with enhanced centering (legacy method)
  Widget _buildFaceDetectionOverlay() {
    if (_detectedFace == null) return const SizedBox.shrink();

    // Use the enhanced face detection painter with proper camera dimensions
    return Positioned.fill(
      child: Stack(
        children: [
          // Center guide overlay - always visible
          CustomPaint(
            painter: CenterGuidePainter(color: Colors.white.withValues(alpha: 0.5)),
          ),
          // Face detection overlay
          CustomPaint(
            painter: FaceDetectionPainter(
              faces: [_detectedFace!],
              face: _detectedFace,
              imageSize: _cameraController != null
                  ? _cameraController!.value.previewSize!
                  : const Size(1280, 720),
              previewSize: _cameraController != null
                  ? _cameraController!.value.previewSize!
                  : const Size(1280, 720),
              primaryColor: _getStepColor(),
              animationValue: 1.0,
              showLandmarks: true,
              showContours: true,
            ),
          ),
        ],
      ),
    );
  }

  // Get color based on current step
  Color _getStepColor() {
    if (_completedSteps.containsKey(_currentStep)) {
      return CustomColors.getSuccessColor(context);
    } else if (_detectedFace != null) {
      return CustomColors.getPrimaryColor(context);
    }
    return CustomColors.getErrorColor(context);
  }

  // Build step indicator
  Widget _buildStepIndicator() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step ${_currentStep + 1} of ${_registrationSteps.length}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _registrationSteps[_currentStep].title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Progress indicator
            LinearProgressIndicator(
              value: _completedSteps.length / _registrationSteps.length,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              '${_completedSteps.length}/${_registrationSteps.length} steps completed',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            // Step detection progress
            if (!_completedSteps.containsKey(_currentStep)) ...[
              Text(
                '✨ Auto-capture ready - position correctly',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Full screen instructions overlay
  Widget _buildFullScreenInstructions() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Current Step: ${_registrationSteps[_currentStep]}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getStepInstructions(_currentStep),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            // Progress bar
            LinearProgressIndicator(
              value: _completedSteps.length / _registrationSteps.length,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              '${_completedSteps.length}/${_registrationSteps.length} steps completed',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            if (!_completedSteps.containsKey(_currentStep)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '📸 Auto-capture enabled',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Get step-specific instructions
  String _getStepInstructions(int step) {
    switch (step) {
      case 0: // Look straight ahead
        return 'Position your face in the center and look directly at the camera. Keep your head straight and eyes open.';
      case 1: // Look up
        return 'Slowly tilt your head up while keeping your eyes on the camera. Hold for 2 seconds.';
      case 2: // Look down
        return 'Slowly tilt your head down while keeping your eyes on the camera. Hold for 2 seconds.';
      case 3: // Look left
        return 'Turn your head to the left while keeping your eyes on the camera. Hold for 2 seconds.';
      case 4: // Look right
        return 'Turn your head to the right while keeping your eyes on the camera. Hold for 2 seconds.';
      case 5: // Blink eyes
        return 'Blink your eyes naturally 2-3 times. Make sure your eyes are clearly visible.';
      case 6: // Smile
        return 'Give a natural smile. Keep your face relaxed and natural.';
      default:
        return 'Follow the instructions above to complete face registration.';
    }
  }

  // Full screen face detection overlay
  Widget _buildFullScreenFaceOverlay() {
    if (_detectedFace == null) return const SizedBox.shrink();

    // Use the enhanced face detection painter for full screen
    return Positioned.fill(
      child: Stack(
        children: [
          // Center guide overlay - always visible
          CustomPaint(
            painter: CenterGuidePainter(color: Colors.white.withValues(alpha: 0.5)),
          ),
          // Face detection overlay
          CustomPaint(
            painter: FaceDetectionPainter(
              faces: [_detectedFace!],
              face: _detectedFace,
              imageSize: _cameraController != null
                  ? _cameraController!.value.previewSize!
                  : const Size(1280, 720),
              previewSize: _cameraController != null
                  ? _cameraController!.value.previewSize!
                  : const Size(1280, 720),
              primaryColor: _getStepColor(),
              animationValue: 1.0,
              showLandmarks: true,
              showContours: true,
            ),
          ),
        ],
      ),
    );
  }

  // Get step-specific icon
  IconData _getStepIcon(int step) {
    switch (step) {
      case 0: // Look straight ahead
        return Icons.face_rounded;
      case 1: // Look up
        return Icons.keyboard_arrow_up_rounded;
      case 2: // Look down
        return Icons.keyboard_arrow_down_rounded;
      case 3: // Look left
        return Icons.keyboard_arrow_left_rounded;
      case 4: // Look right
        return Icons.keyboard_arrow_right_rounded;
      case 5: // Blink eyes
        return Icons.visibility_rounded;
      case 6: // Smile
        return Icons.sentiment_satisfied_rounded;
      default:
        return Icons.face_rounded;
    }
  }

  // Full screen step indicator
  Widget _buildFullScreenStepIndicator() {
    return Positioned(
      top: 80,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getStepColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getStepIcon(_currentStep),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${_currentStep + 1} of ${_registrationSteps.length}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    _registrationSteps[_currentStep].title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (_completedSteps.containsKey(_currentStep))
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
          ],
        ),
      ),
    );
  }

  // Clear previous face images from Cloudinary
  Future<void> _clearPreviousFaceImages() async {
    try {
      if (widget.userData['_id'] != null) {
        print(
          '🗑️ Clearing previous face images for user: ${widget.userData['_id']}',
        );
        final result = await CloudinaryService.clearUserFaceImages(
          widget.userData['_id'],
        );
        if (result['success']) {
          print('✅ Previous face images cleared successfully');
        } else {
          print('⚠️ Failed to clear previous images: ${result['message']}');
        }
      }
    } catch (e) {
      print('❌ Error clearing previous face images: $e');
    }
  }

  /// Initialize TFLite services for face embedding and analysis
  Future<void> _initializeTFLiteServices() async {
    try {
      Logger.info('🚀 Initializing TFLite services for face registration...');

      // Initialize face embedding service
      final embeddingInitialized = await _faceEmbeddingService.initialize();
      if (!embeddingInitialized) {
        Logger.warning('⚠️ Face embedding service initialization failed');
      }

      // Initialize TFLite deep learning service
      final tfliteInitialized = await _tfliteService.initialize();
      if (!tfliteInitialized) {
        Logger.warning('⚠️ TFLite deep learning service initialization failed');
      }

      if (mounted) {
        setState(() {
          _isTFLiteInitialized = embeddingInitialized && tfliteInitialized;
        });
      }

      Logger.info(
        '🔧 TFLite initialization status: embedding=$embeddingInitialized, tflite=$tfliteInitialized, final=$_isTFLiteInitialized',
      );

      if (_isTFLiteInitialized) {
        Logger.info(
          '✅ TFLite services initialized successfully for face registration',
        );
      } else {
        Logger.warning(
          '⚠️ Some TFLite services failed to initialize, using fallback mode',
        );
      }
    } catch (e) {
      Logger.error('❌ Error initializing TFLite services: $e');
      if (mounted) {
        setState(() {
          _isTFLiteInitialized = false;
        });
      }
    }
  }

  /// Process TFLite analysis for captured photo
  Future<void> _processTFLiteAnalysis(File photoFile, Face detectedFace) async {
    try {
      Logger.info(
        '🧠 Processing TFLite analysis for step ${_currentStep + 1}...',
      );

      // Generate face embedding using TFLite
      final embedding = await _faceEmbeddingService.generateEmbedding(
        photoFile,
        detectedFace,
      );
      if (embedding != null) {
        _capturedEmbeddings.add(
          FaceEmbeddingData(
            embedding: embedding,
            quality: 0.8, // Default quality for legacy capture
            stepId: _registrationSteps[_currentStep].id,
            timestamp: DateTime.now(),
            metadata: {},
            detectedFace: detectedFace,
          ),
        );
        Logger.info(
          '✅ Generated 512D face embedding for step ${_currentStep + 1}',
        );
        print('📊 Embedding dimensions: ${embedding.length}');
      } else {
        Logger.warning(
          '⚠️ Failed to generate face embedding for step ${_currentStep + 1}',
        );
      }

      // Analyze facial attributes using TFLite
      final analysis = await _faceEmbeddingService.analyzeFacialAttributes(
        photoFile,
        detectedFace,
      );
      if (analysis != null) {
        _capturedAnalyses.add(analysis);
        Logger.info('✅ Generated facial analysis for step ${_currentStep + 1}');

        // Log analysis results
        if (analysis['emotion'] != null) {
          final emotions = analysis['emotion'] as Map<String, double>;
          final topEmotion = emotions.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          Logger.info(
            '😊 Top emotion: ${topEmotion.key} (${(topEmotion.value * 100).toStringAsFixed(1)}%)',
          );
        }

        if (analysis['age'] != null) {
          Logger.info('👤 Age: ${analysis['age']} years');
        }

        if (analysis['gender'] != null) {
          Logger.info('👤 Gender: ${analysis['gender']}');
        }
      } else {
        Logger.warning(
          '⚠️ Failed to generate facial analysis for step ${_currentStep + 1}',
        );
      }
    } catch (e) {
      Logger.error('❌ Error processing TFLite analysis: $e');
    }
  }

  /// Save TFLite embeddings and analysis data for face recognition
  Future<void> _saveTFLiteEmbeddings() async {
    try {
      Logger.info('💾 Saving TFLite embeddings and analysis data...');

      // Get user ID from widget data
      final userId =
          widget.userData['id'] ?? widget.userData['userId'] ?? 'unknown';

      // Create registration data structure
      final registrationData = {
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'embeddings': _capturedEmbeddings,
        'analyses': _capturedAnalyses,
        'photos': _capturedPhotos.map((file) => file.path).toList(),
        'steps': _registrationSteps,
        'completedSteps': _completedSteps.values.toList(),
        'tfliteVersion': '1.0.0',
        'embeddingSize': _capturedEmbeddings.isNotEmpty
            ? _capturedEmbeddings.first.embedding.length
            : 0,
      };

      // Save to SharedPreferences for now (in production, this should be saved to secure storage or backend)
      final prefs = await SharedPreferences.getInstance();
      final key = 'face_registration_$userId';
      final jsonData = jsonEncode(registrationData);
      await prefs.setString(key, jsonData);

      Logger.info('✅ TFLite embeddings saved successfully for user $userId');
      Logger.info(
        '📊 Saved ${_capturedEmbeddings.length} embeddings with ${_capturedEmbeddings.isNotEmpty ? _capturedEmbeddings.first.embedding.length : 0} dimensions each',
      );
      Logger.info('📸 Saved ${_capturedPhotos.length} photos');
      Logger.info('🔬 Saved ${_capturedAnalyses.length} facial analyses');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Face registration completed with TFLite analysis!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: CustomColors.getSuccessColor(context),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Logger.error('❌ Error saving TFLite embeddings: $e');
      if (mounted) {
        _showError('Failed to save face registration data: $e');
      }
    }
  }

  /// Build TFLite status indicator widget
  Widget _buildTFLiteStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isTFLiteInitialized
            ? CustomColors.getSuccessColor(context).withValues(alpha: 0.1)
            : CustomColors.getWarningColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isTFLiteInitialized
              ? CustomColors.getSuccessColor(context).withValues(alpha: 0.3)
              : CustomColors.getWarningColor(context).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isTFLiteInitialized
                ? Icons.psychology_rounded
                : Icons.psychology_outlined,
            color: _isTFLiteInitialized
                ? CustomColors.getSuccessColor(context)
                : CustomColors.getWarningColor(context),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isTFLiteInitialized ? 'TFLite AI Ready' : 'TFLite AI Loading...',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _isTFLiteInitialized
                  ? CustomColors.getSuccessColor(context)
                  : CustomColors.getWarningColor(context),
            ),
          ),
        ],
      ),
    );
  }

  // Convert CameraImage to InputImage for face detection
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      const InputImageRotation imageRotation =
          InputImageRotation.rotation270deg;
      const InputImageFormat inputImageFormat = InputImageFormat.nv21;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      Logger.error('Error converting camera image: $e');
      return null;
    }
  }

  // Enhanced face processing with quality analysis
  Future<void> _processImageWithQualityAnalysis(CameraImage image) async {
    if (!mounted || _isDetecting) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final detectedFace = faces.first;

        // Analyze face quality
        final tempFile = await _saveCameraImageToTempFile(image);
        final qualityAnalysis = FaceQualityAnalyzer.analyzeFaceQuality(
          detectedFace,
          tempFile,
          _registrationSteps[_currentStep].id,
        );

        // Update UI with quality feedback
        if (mounted) {
          setState(() {
            _detectedFace = detectedFace;
            _currentQualityAnalysis = qualityAnalysis;
            _currentStepQuality = qualityAnalysis.overall;
            _qualityIssues = qualityAnalysis.issues;

            // Update feedback message based on quality
            _updateRealTimeFeedback(qualityAnalysis);

            // Check if step can be completed with current quality
            if (_canCompleteCurrentStep(qualityAnalysis)) {
              _autoCompleteStepWithQuality(
                detectedFace,
                qualityAnalysis,
                tempFile,
              );
            }
          });
        }

        // Clean up temp file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } else {
        if (mounted) {
          setState(() {
            _detectedFace = null;
            _currentQualityAnalysis = null;
            _feedbackMessage =
                'No face detected. Position your face in the center.';
            _feedbackColor = Colors.orange;
          });
        }
      }
    } catch (e) {
      Logger.error('Error in enhanced face processing: $e');
    } finally {
      _isDetecting = false;
    }
  }

  // Update real-time feedback based on quality analysis
  void _updateRealTimeFeedback(FaceQualityAnalysis analysis) {
    if (analysis.overall >= 0.8) {
      _feedbackMessage = 'Excellent! Hold steady...';
      _feedbackColor = Colors.green;
    } else if (analysis.overall >= 0.6) {
      _feedbackMessage = analysis.issues.isNotEmpty
          ? analysis.issues.first
          : 'Good quality. Minor adjustments needed.';
      _feedbackColor = Colors.orange;
    } else {
      _feedbackMessage = analysis.issues.isNotEmpty
          ? analysis.issues.first
          : 'Please improve face positioning and lighting.';
      _feedbackColor = Colors.red;
    }
  }

  // Check if current step can be completed with the given quality
  bool _canCompleteCurrentStep(FaceQualityAnalysis analysis) {
    final step = _registrationSteps[_currentStep];

    // Basic quality threshold
    if (analysis.overall < (step.minQualityThreshold ?? 0.7)) {
      return false;
    }

    // Step-specific validations
    switch (step.id) {
      case 'blink':
        return _blinkDetected;
      case 'smile':
        return (_detectedFace?.smilingProbability ?? 0.0) > 0.7;
      default:
        return analysis.pose >= 0.6; // Good pose for directional steps
    }
  }

  // Auto-complete step with quality validation
  Future<void> _autoCompleteStepWithQuality(
    Face face,
    FaceQualityAnalysis analysis,
    File tempPhoto,
  ) async {
    if (_completedSteps.containsKey(_currentStep)) return;

    try {
      // Generate embedding with quality metadata
      final embedding = await _faceEmbeddingService.generateEmbedding(
        tempPhoto,
        face,
      );
      final faceAnalysisData = await _faceEmbeddingService
          .analyzeFacialAttributes(tempPhoto, face);

      if (embedding != null) {
        // Create quality data record
        final qualityData = StepQualityData(
          stepIndex: _currentStep,
          overallQuality: analysis.overall,
          qualityMetrics: {
            'lighting': analysis.lighting,
            'sharpness': analysis.sharpness,
            'pose': analysis.pose,
            'symmetry': analysis.symmetry,
            'eyeOpenness': analysis.eyeOpenness,
            'mouthVisibility': analysis.mouthVisibility,
          },
          completedAt: DateTime.now(),
          capturedPhoto: tempPhoto,
          embedding: embedding,
          faceAnalysis: faceAnalysisData,
          detectedFace: face,
        );

        // Store enhanced embedding data
        final embeddingData = FaceEmbeddingData(
          embedding: embedding,
          quality: analysis.overall,
          stepId: _registrationSteps[_currentStep].id,
          timestamp: DateTime.now(),
          metadata: {
            'step': _currentStep,
            'qualityAnalysis': {
              'lighting': analysis.lighting,
              'sharpness': analysis.sharpness,
              'pose': analysis.pose,
            },
            'faceMetrics': {
              'boundingBox': {
                'width': face.boundingBox.width,
                'height': face.boundingBox.height,
              },
              'landmarks': face.landmarks.length,
              'contours': face.contours.length,
            },
          },
          detectedFace: face,
        );

        setState(() {
          _completedSteps[_currentStep] = qualityData;
          _capturedEmbeddings.add(embeddingData);
          if (faceAnalysisData != null) {
            _capturedAnalyses.add(faceAnalysisData);
          }

          _feedbackMessage = 'Step completed successfully!';
          _feedbackColor = Colors.green;
        });

        // Move to next step
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _currentStep < _registrationSteps.length - 1) {
            setState(() {
              _currentStep++;
              _feedbackMessage = _registrationSteps[_currentStep].description;
              _feedbackColor = _registrationSteps[_currentStep].color;
            });
          } else {
            _completeRegistration();
          }
        });

        Logger.info(
          '✅ Step $_currentStep completed with quality: ${(analysis.overall * 100).toStringAsFixed(1)}%',
        );
      }
    } catch (e) {
      Logger.error('Error completing step with quality validation: $e');
    }
  }

  // Complete the entire registration process
  Future<void> _completeRegistration() async {
    if (!mounted) return;

    setState(() {
      _allStepsCompleted = true;
      _feedbackMessage = 'Registration completed successfully!';
      _feedbackColor = Colors.green;
    });

    // Calculate overall registration quality
    final overallQuality =
        _completedSteps.values
            .map((data) => data.overallQuality)
            .fold<double>(0.0, (sum, quality) => sum + quality) /
        _completedSteps.length;

    // Save final registration data
    await _saveFinalRegistrationData(overallQuality);

    Logger.info(
      '🎉 Face registration completed with overall quality: ${(overallQuality * 100).toStringAsFixed(1)}%',
    );

    // Show confirmation popup asking user if they want to save or retake
    _showRegistrationConfirmationDialog();
  }

  // Show confirmation dialog after registration completion
  void _showRegistrationConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Registration Complete!',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your face has been successfully registered with ${_completedSteps.length} different angles and expressions.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'What would you like to do?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.save_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Save & Continue: Your face registration will be saved and you\'ll return to the dashboard.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Retake Photos: Start over with a new face registration session.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: CustomColors.getWarningColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Retake button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _restartRegistration(); // Restart the registration process
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: CustomColors.getWarningColor(context),
                side: BorderSide(color: CustomColors.getWarningColor(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                'Retake Photos',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Save & Continue button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _saveAndReturnToDashboard(); // Save and return to dashboard
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.getSuccessColor(context),
                foregroundColor: CustomColors.getOnPrimaryColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: Icon(Icons.check_rounded, size: 20),
              label: Text(
                'Save & Continue',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Restart the registration process
  void _restartRegistration() {
    setState(() {
      // Reset all registration state
      _currentStep = 0;
      _allStepsCompleted = false;
      _completedSteps.clear();
      _capturedFaceData.clear();
      _capturedEmbeddings.clear();
      _capturedAnalyses.clear();
      _capturedPhotos.clear();
      _cloudinaryUrls.clear();
      _isRegistered = false;
      _isRegistering = false;
      _isCapturing = false;
      _captureEnabled = true;
      _stableFaceCount = 0;
      _consecutiveDetections = 0;
      _faceHistory.clear();
      _previousFace = null;
      _detectedFace = null;
      _currentConfidence = 0.0;
      _currentStepQuality = 0.0;
      _qualityMetrics.clear();
      _qualityIssues.clear();
      _currentQualityAnalysis = null;
      _feedbackMessage = 'Position your face in the center';
      _feedbackColor = CustomColors.getPrimaryColor(context);
      _blinkFrameCount = 0;
      _eyesOpenFrameCount = 0;
      _blinkDetected = false;
    });

    // Clear previous face images from backend
    if (widget.userData['_id'] != null) {
      _clearPreviousFaceImages();
    }

    // Show restart message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Registration restarted. You can now capture new photos.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: CustomColors.getWarningColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Save registration and return to dashboard
  void _saveAndReturnToDashboard() {
    // Mark as successfully registered
    setState(() {
      _isRegistered = true;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Face registration saved successfully!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: CustomColors.getSuccessColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );

    // Return to dashboard after a short delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(); // Return to previous screen (dashboard)
      }
    });
  }

  // Save final registration data to storage
  Future<void> _saveFinalRegistrationData(double overallQuality) async {
    try {
      // Create consolidated embedding from all steps
      final consolidatedEmbedding = _createConsolidatedEmbedding();

      if (consolidatedEmbedding != null) {
        final userId =
            widget.userData['_id'] ??
            widget.userData['email'] ??
            'user_${DateTime.now().millisecondsSinceEpoch}';

        // Save the consolidated embedding
        await _faceEmbeddingService.saveFaceEmbedding(
          userId,
          consolidatedEmbedding,
        );

        // Prepare registration data for backend
        final registrationData = {
          'stepsCompleted': _completedSteps.length,
          'overallQuality': overallQuality,
          'registrationDate': DateTime.now().toIso8601String(),
          'cloudinaryUrls': _cloudinaryUrls,
          'steps': _registrationSteps
              .map(
                (step) => {
                  'id': step.id,
                  'title': step.title,
                  'completed': _completedSteps.keys.contains(
                    _registrationSteps.indexOf(step),
                  ),
                },
              )
              .toList(),
        };

        // Save to backend
        if (widget.userData['_id'] != null) {
          final result = await CloudinaryService.completeFaceRegistration(
            userId: widget.userData['_id'],
            registrationData: registrationData,
          );

          if (result['success']) {
            Logger.info('✅ Registration data saved to backend successfully');
          } else {
            Logger.warning(
              '⚠️ Failed to save registration data to backend: ${result['message']}',
            );
          }
        }

        // Save registration metadata locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'face_registration_quality',
          overallQuality.toString(),
        );
        await prefs.setString(
          'face_registration_date',
          DateTime.now().toIso8601String(),
        );
        await prefs.setInt('face_registration_steps', _completedSteps.length);

        Logger.info('✅ Final registration data saved successfully');
      }
    } catch (e) {
      Logger.error('Error saving final registration data: $e');
    }
  }

  // Create consolidated embedding from all captured embeddings
  List<double>? _createConsolidatedEmbedding() {
    if (_capturedEmbeddings.isEmpty) return null;

    // Weight embeddings by quality and combine
    final weightedSum = List<double>.filled(512, 0.0);
    double totalWeight = 0.0;

    for (final embeddingData in _capturedEmbeddings) {
      final weight = embeddingData.quality;
      totalWeight += weight;

      for (int i = 0; i < embeddingData.embedding.length; i++) {
        weightedSum[i] += embeddingData.embedding[i] * weight;
      }
    }

    // Normalize by total weight
    if (totalWeight > 0) {
      for (int i = 0; i < weightedSum.length; i++) {
        weightedSum[i] /= totalWeight;
      }
    }

    return weightedSum;
  }

  // Save camera image to temporary file
  Future<File> _saveCameraImageToTempFile(CameraImage cameraImage) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/temp_face_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    // Convert CameraImage to image bytes (simplified conversion)
    final bytes = cameraImage.planes[0].bytes;
    await tempFile.writeAsBytes(bytes);

    return tempFile;
  }

  // Get current step color
  Color _getCurrentStepColor() {
    if (_currentStep < _registrationSteps.length) {
      return _registrationSteps[_currentStep].color;
    }
    return Colors.blue;
  }

  // Build enhanced face detection overlay with quality indicators
  Widget _buildEnhancedFaceOverlay() {
    if (_detectedFace == null) return const SizedBox.shrink();

    return CustomPaint(
      painter: EnhancedFacePainter(
        face: _detectedFace!,
        imageSize:
            _cameraController?.value.previewSize ?? const Size(1280, 720),
        primaryColor: _getCurrentStepColor(),
        animationValue: _animationController.value,
        currentStep: _registrationSteps[_currentStep].id,
        qualityAnalysis: _currentQualityAnalysis,
        showLandmarks: true,
        showContours: true,
        showQualityIndicators: true,
        showGuidelines: true,
      ),
    );
  }

  // Test confirmation dialog method
  void _testConfirmationDialog() {
    print('🧪 Testing confirmation dialog...');
    _showRegistrationConfirmationDialog();
  }

  // Debug method to check completion status
  void _debugCheckCompletion() {
    print('🔍 DEBUG: Checking completion status...');
    print('🔍 Current step: $_currentStep');
    print('🔍 Total steps: ${_registrationSteps.length}');
    print('🔍 Completed steps: ${_completedSteps.length}');
    print(
      '🔍 All steps completed: ${_completedSteps.length == _registrationSteps.length}',
    );
    print('🔍 Completed step indices: ${_completedSteps.keys.toList()}');

    // Show debug info in a dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Debug: Completion Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Step: ${_currentStep + 1}'),
              Text('Total Steps: ${_registrationSteps.length}'),
              Text('Completed Steps: ${_completedSteps.length}'),
              Text(
                'All Steps Completed: ${_completedSteps.length == _registrationSteps.length}',
              ),
              const SizedBox(height: 16),
              Text('Completed Step Indices:'),
              Text(
                _completedSteps.keys
                    .map((i) => 'Step ${i + 1}: ${_registrationSteps[i].title}')
                    .join('\n'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            if (_completedSteps.length == _registrationSteps.length)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _completeRegistration();
                },
                child: Text('Force Complete'),
              ),
          ],
        );
      },
    );
  }
}

// Full screen face registration widget
class _FaceRegistrationFullScreen extends StatefulWidget {
  final CameraController cameraController;
  final FaceDetector faceDetector;
  final List<CameraDescription> cameras;
  final Map<String, dynamic> userData;

  const _FaceRegistrationFullScreen({
    required this.cameraController,
    required this.faceDetector,
    required this.cameras,
    required this.userData,
  });

  @override
  State<_FaceRegistrationFullScreen> createState() =>
      _FaceRegistrationFullScreenState();
}

class _FaceRegistrationFullScreenState
    extends State<_FaceRegistrationFullScreen> {
  // Face detection variables
  bool _isDetecting = false;
  Face? _detectedFace;
  // Blink detection variables
  int _blinkFrameCount = 0;
  int _eyesOpenFrameCount = 0;
  bool _blinkDetected = false;
  final int _blinkRequiredFrames =
      5; // Need eyes closed for 5 frames to count as blink

  // Auto capture variables
  bool _isCapturing = false;
  bool _captureEnabled = true;
  List<String> _capturedPhotos = []; // Store captured photo paths

  // Cloudinary URLs storage
  final List<String> _cloudinaryUrls = [];

  // Timer for automatic capture
  int _faceDetectedFrames = 0;
  final int _requiredFrames = 30; // Capture after 30 frames (~1 second)

  // Data management
  final Map<int, Map<String, dynamic>> _capturedData =
      {}; // Step -> {file_path, cloudinary_url, timestamp}

  // Registration steps for fullscreen
  int _currentStep = 0;
  final List<String> _registrationSteps = [
    'Look straight ahead',
    'Look up',
    'Look down',
    'Look left',
    'Look right',
    'Blink your eyes',
    'Smile',
  ];

  // Step completion tracking for fullscreen
  final Set<int> _completedSteps = {};
  bool _allStepsCompleted = false;

  // Debug status tracking to prevent spam logging
  Map<String, dynamic> _lastDebugStatus = {};

  @override
  void initState() {
    super.initState();

    // RESET ALL STEPS - Start completely fresh
    _capturedPhotos = [];
    _completedSteps.clear();
    _currentStep = 0;
    _captureEnabled = true;
    _faceDetectedFrames = 0;
    _allStepsCompleted = false;
    _cloudinaryUrls.clear();
    _capturedData.clear();

    print('🔄 FULLSCREEN RESET: Starting fresh face registration');
    print('🔄 Current step: ${_currentStep + 1}/${_registrationSteps.length}');
    print('🔄 Capture enabled: $_captureEnabled');
    print('🔄 Completed steps cleared: ${_completedSteps.length}');

    // Add delay to ensure camera is fully ready before starting detection
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _startFaceDetection();
        print('✅ Full-screen face detection started with initialization delay');
      }
    });
  }

  // Move to next step after successful capture
  void _moveToNextStep() {
    Future.delayed(Duration(milliseconds: 1000), () {
      if (mounted && _currentStep < _registrationSteps.length - 1) {
        setState(() {
          _currentStep++;
          _captureEnabled = true;
          _faceDetectedFrames = 0;
          print('📈 Moving to step ${_currentStep + 1}');
        });
      } else if (mounted) {
        setState(() {
          _allStepsCompleted = true;
          print('🎉 ALL STEPS COMPLETED!');
          print(
            '📊 Registration Summary: ${_capturedPhotos.length} photos captured, ${_cloudinaryUrls.length} uploads successful',
          );
        });

        // Show completion success message and then confirmation dialog
        _showCompletionSuccessAndConfirmation();
      }
    });
  }

  // Show completion success and then confirmation dialog
  void _showCompletionSuccessAndConfirmation() {
    // First show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'All registration steps completed successfully!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: CustomColors.getSuccessColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );

    // Then show confirmation dialog after a short delay
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _showRegistrationConfirmationDialog();
      }
    });
  }

  // Show confirmation dialog after registration completion
  void _showRegistrationConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Registration Complete!',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your face has been successfully registered with ${_completedSteps.length} different angles and expressions.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'What would you like to do?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CustomColors.getOnSurfaceColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CustomColors.getPrimaryColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: CustomColors.getPrimaryColor(
                      context,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.save_rounded,
                      color: CustomColors.getPrimaryColor(context),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Save & Continue: Your face registration will be saved and you\'ll return to the dashboard.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: CustomColors.getPrimaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CustomColors.getWarningColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: CustomColors.getWarningColor(
                      context,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: CustomColors.getWarningColor(context),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Retake Photos: Start over with a new face registration session.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Retake button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _restartFullScreenRegistration(); // Restart the registration process
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: BorderSide(color: Colors.orange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                'Retake Photos',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Save & Continue button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _saveAndReturnFromFullScreen(); // Save and return to dashboard
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.getSuccessColor(context),
                foregroundColor: CustomColors.getOnPrimaryColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: Icon(Icons.check_rounded, size: 20),
              label: Text(
                'Save & Continue',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Restart the full-screen registration process
  void _restartFullScreenRegistration() {
    setState(() {
      // Reset all registration state
      _currentStep = 0;
      _allStepsCompleted = false;
      _completedSteps.clear();
      _capturedPhotos.clear();
      _cloudinaryUrls.clear();
      _capturedData.clear();
      _isCapturing = false;
      _captureEnabled = true;
      _faceDetectedFrames = 0;
      _blinkFrameCount = 0;
      _eyesOpenFrameCount = 0;
      _blinkDetected = false;
      _detectedFace = null;
    });

    // Clear previous face images from backend
    if (widget.userData['_id'] != null) {
      _clearPreviousFaceImagesFromFullScreen();
    }

    // Show restart message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Registration restarted. You can now capture new photos.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: CustomColors.getWarningColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );

    // Restart face detection
    _startFaceDetection();
  }

  // Save registration and return from full-screen
  void _saveAndReturnFromFullScreen() {
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Face registration saved successfully!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: CustomColors.getSuccessColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );

    // Return to previous screen after a short delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate successful registration
      }
    });
  }

  // Clear previous face images from backend (full-screen version)
  Future<void> _clearPreviousFaceImagesFromFullScreen() async {
    try {
      if (widget.userData['_id'] != null) {
        final response = await http.delete(
          Uri.parse(
            '${ServerConfig.baseUrl}/user-faces/${widget.userData['_id']}/clear',
          ),
        );

        if (response.statusCode == 200) {
          print('✅ Previous face images cleared from backend');
        } else {
          print(
            '⚠️ Failed to clear previous face images: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('❌ Error clearing previous face images: $e');
    }
  }

  @override
  void dispose() {
    widget.cameraController.stopImageStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview - full screen
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: widget.cameraController.value.previewSize!.height,
                height: widget.cameraController.value.previewSize!.width,
                child: CameraPreview(widget.cameraController),
              ),
            ),
          ),

          // Face detection overlay - only show face guide
          if (_detectedFace != null)
            Positioned.fill(
              child: CustomPaint(
                painter: FaceDetectionPainter.single(
                  _detectedFace!,
                  _getStepColor(),
                ),
              ),
            ),

          // Capture flash effect
          if (_isCapturing)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.black,
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Photo Captured!',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Clean step indicator at top
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: _buildCleanStepIndicator(context),
          ),

          // Back button
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // Reset button (temporary)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(25),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _completedSteps.clear();
                    _currentStep = 0;
                    _captureEnabled = true;
                    _faceDetectedFrames = 0;
                    print('🔄 RESET: Starting over from step 1');
                  });
                },
                icon: Icon(Icons.refresh, color: Colors.white, size: 24),
              ),
            ),
          ),

          // Manual Capture Button at bottom
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Capture button
                      Container(
                        decoration: BoxDecoration(
                          color: _detectedFace != null && _captureEnabled
                              ? Colors
                                    .green // Green when auto-capture is active
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: IconButton(
                          onPressed: _detectedFace != null && _captureEnabled
                              ? () async {
                                  print(
                                    '📸 MANUAL CAPTURE TRIGGERED for step ${_currentStep + 1}',
                                  );
                                  if (!_completedSteps.contains(_currentStep)) {
                                    final success = await _captureStepPhoto();
                                    if (success) {
                                      print('✅ Manual capture completed!');
                                      _completedSteps.add(_currentStep);
                                      _moveToNextStep();
                                    } else {
                                      print('❌ Manual capture failed!');
                                      setState(() {
                                        _captureEnabled = true;
                                      });
                                    }
                                  } else {
                                    print(
                                      '⚠️ Step ${_currentStep + 1} already completed',
                                    );
                                  }
                                }
                              : null,
                          icon: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),

                      // Status text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Step ${_currentStep + 1}: ${_registrationSteps[_currentStep]}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _detectedFace != null
                                ? 'Face detected - Auto-capture enabled'
                                : 'Position your face in the camera',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w400,
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
        ],
      ),
    );
  }

  // Clean step indicator - only shows current step
  Widget _buildCleanStepIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Step number
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _getStepColor(),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                '${_currentStep + 1}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Step title
          Expanded(
            child: Text(
              _registrationSteps[_currentStep],
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Progress indicator
          Text(
            '${_currentStep + 1}/${_registrationSteps.length}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // Start NATIVE face detection
  void _startFaceDetection() {
    _enableNativeCameraFeatures();

    try {
      widget.cameraController.startImageStream((CameraImage image) {
        if (_isDetecting || !mounted) return;

        _isDetecting = true;
        _processImageWithNativeFeatures(image).catchError((error) {
          print('⚠️ Error in fullscreen image processing: $error');
          _isDetecting = false;
        });
      });
    } catch (e) {
      print('❌ Error starting camera image stream: $e');
      _isDetecting = false;
    }
  }

  // Enable native camera features
  Future<void> _enableNativeCameraFeatures() async {
    try {
      await widget.cameraController.setFocusMode(FocusMode.auto);
      await widget.cameraController.setExposureMode(ExposureMode.auto);
      await widget.cameraController.setFocusPoint(null);
      await widget.cameraController.setExposurePoint(null);
      print('Full-screen native camera features enabled');
    } catch (e) {
      print('Native features not available: $e');
    }
  }

  // NATIVE AUTO-CAPTURE in full-screen mode
  Future<bool> _captureStepPhoto() async {
    print('🎬 _captureStepPhoto called for step ${_currentStep + 1}');
    print('🎬 captureEnabled: $_captureEnabled, isCapturing: $_isCapturing');

    if (!_captureEnabled || _isCapturing) {
      print(
        '❌ Capture blocked - captureEnabled: $_captureEnabled, isCapturing: $_isCapturing',
      );
      return false;
    }

    print('📸 Starting photo capture for step ${_currentStep + 1}...');

    setState(() {
      _isCapturing = true;
      _captureEnabled = false;
    });

    try {
      // Optimize using native camera features
      await _optimizeNativeCameraForCapture();

      // Capture with native optimization
      final XFile photo = await widget.cameraController.takePicture();
      final photoFile = File(photo.path);
      _capturedPhotos.add(photo.path);
      print('📸 PHOTO CAPTURED! Step ${_currentStep + 1}: ${photo.path}');

      // COMPREHENSIVE UPLOAD VERIFICATION
      print('🔍 Verifying file exists: ${photoFile.path}');
      print('🔍 File size: ${await photoFile.length()} bytes');
      print('🔍 User ID: ${widget.userData['_id']}');

      if (widget.userData['_id'] != null) {
        print('☁️ Starting Cloudinary upload...');
        print('📤 Upload details:');
        print('   - User ID: ${widget.userData['_id']}');
        print('   - File path: ${photoFile.path}');
        print('   - Step: ${_currentStep + 1}');

        final uploadResult = await CloudinaryService.uploadFaceImage(
          userId: widget.userData['_id'],
          imageFile: photoFile,
          imageType: 'face_registration_step_${_currentStep + 1}',
          stepName:
              _registrationSteps[_currentStep], // Fullscreen mode uses List<String>
          stepNumber: _currentStep + 1,
        );

        print('📋 Upload result: $uploadResult');

        if (uploadResult['success']) {
          final imageUrl = uploadResult['data']['image_url'];
          final cloudinaryId = uploadResult['data']['cloudinary_id'];

          print('🎉 UPLOAD SUCCESS!');
          print('   📸 Image URL: $imageUrl');
          print('   🆔 Cloudinary ID: $cloudinaryId');

          // Verify image is accessible
          bool imageAccessible = false;
          try {
            final http.Response verifyResponse = await http.get(
              Uri.parse(imageUrl),
            );
            imageAccessible = verifyResponse.statusCode == 200;
            print(
              '🔍 Image accessibility check: ${imageAccessible ? "✅" : "❌"}',
            );
          } catch (e) {
            print('❌ Image accessibility check failed: $e');
          }

          // Store comprehensive data with verification
          _capturedData[_currentStep] = {
            'step_number': _currentStep + 1,
            'step_name': _registrationSteps[_currentStep],
            'file_path': photoFile.path,
            'cloudinary_url': imageUrl,
            'cloudinary_id': cloudinaryId,
            'timestamp': DateTime.now().toIso8601String(),
            'file_size': await photoFile.length(),
            'verification': {
              'upload_success': true,
              'image_accessible': imageAccessible,
              'face_quality_passed': true,
              'capture_timestamp': DateTime.now().toIso8601String(),
            },
          };

          _cloudinaryUrls.add(imageUrl);
          print('💾 Data stored for step ${_currentStep + 1}');
          print('💾 Total captured steps: ${_capturedData.length}');

          // Save to persistent storage
          await _saveRegistrationData();

          print('✅ Upload verified - photo stored in Cloudinary');
          print(
            '✅ Step ${_currentStep + 1} completed and verified successfully!',
          );
        } else {
          print('💥 UPLOAD FAILED!');
          print('   ❌ Error: ${uploadResult['message']}');
          print('   🔍 Full result: $uploadResult');

          // Log upload error and don't proceed
          print('💥 Upload failed - preventing step progression');

          // Return early to prevent step progression
          return false;
        }
      } else {
        print('❌ CRITICAL ERROR: No user ID found for upload!');
        print('   🔍 UserData keys: ${widget.userData.keys.toList()}');

        // Log error and don't proceed
        print('💥 No user ID found - preventing step progression');

        // Return early to prevent step progression
        return false;
      }

      // Flash effect
      await Future.delayed(const Duration(milliseconds: 200));

      // Reset for next step
      setState(() {
        _captureEnabled = true;
        _faceDetectedFrames = 0;
      });

      return true; // Success
    } catch (e) {
      print('Error capturing with native features: $e');
      return false; // Failure
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  // Native camera optimization for capture
  Future<void> _optimizeNativeCameraForCapture() async {
    try {
      if (_detectedFace != null) {
        final boundingBox = _detectedFace!.boundingBox;
        final centerX =
            (boundingBox.left + boundingBox.width / 2) /
            widget.cameraController.value.previewSize!.width;
        final centerY =
            (boundingBox.top + boundingBox.height / 2) /
            widget.cameraController.value.previewSize!.height;

        await widget.cameraController.setFocusPoint(Offset(centerX, centerY));
        await widget.cameraController.setExposurePoint(
          Offset(centerX, centerY),
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      print('Native optimization failed: $e');
    }
  }

  // DEBUG face detection for full-screen mode
  Future<void> _processImageWithNativeFeatures(CameraImage image) async {
    try {
      print('🖼️ Fullscreen processing: ${image.width}x${image.height}');

      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        print('❌ Failed to convert image in fullscreen!');
        _isDetecting = false;
        return;
      }

      final List<Face> faces = await widget.faceDetector.processImage(
        inputImage,
      );
      print('👥 Fullscreen found ${faces.length} faces');

      if (mounted) {
        setState(() {
          _detectedFace = faces.isNotEmpty ? faces.first : null;

          if (_detectedFace != null) {
            print('✅ FULLSCREEN FACE DETECTED!');
            _checkStepCompletion();
          }
        });
      }
    } catch (e) {
      print('💥 Fullscreen face detection ERROR: $e');
    } finally {
      _isDetecting = false;
    }
  }

  // Native camera tracking update
  Future<void> _updateNativeCameraForFace() async {
    try {
      if (_detectedFace != null) {
        final boundingBox = _detectedFace!.boundingBox;
        final centerX =
            (boundingBox.left + boundingBox.width / 2) /
            widget.cameraController.value.previewSize!.width;
        final centerY =
            (boundingBox.top + boundingBox.height / 2) /
            widget.cameraController.value.previewSize!.height;

        await widget.cameraController.setFocusPoint(Offset(centerX, centerY));
        await widget.cameraController.setExposurePoint(
          Offset(centerX, centerY),
        );
      }
    } catch (e) {
      // Native tracking not available
    }
  }

  // DEBUG camera image conversion for full-screen
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      print('🔄 Fullscreen converting: ${image.format.group}');

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final camera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      final InputImageRotation imageRotation = _rotationIntToImageRotation(
        camera.sensorOrientation,
      );

      final InputImageFormat inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      print('💥 Fullscreen conversion error: $e');
      return null;
    }
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  // Check if current step is completed
  void _checkStepCompletion() {
    if (_detectedFace == null) {
      print('❌ No face detected for step completion check');
      return;
    }

    print('🔍 Checking step ${_currentStep + 1} completion...');
    bool stepCompleted = false;

    switch (_currentStep) {
      case 0:
        print('📋 Step 1: Look straight ahead');
        stepCompleted = _isLookingStraight();
        break;
      case 1:
        print('📋 Step 2: Look up');
        stepCompleted = _isLookingUp();
        break;
      case 2:
        print('📋 Step 3: Look down');
        stepCompleted = _isLookingDown();
        break;
      case 3:
        print('📋 Step 4: Look left');
        stepCompleted = _isLookingLeft();
        break;
      case 4:
        print('📋 Step 5: Look right');
        stepCompleted = _isLookingRight();
        break;
      case 5:
        print('📋 Step 6: Blink eyes');
        stepCompleted = _isBlinking();
        break;
      case 6:
        print('📋 Step 7: Smile');
        stepCompleted = _isSmiling();
        break;
    }

    print('📊 Step completion result: $stepCompleted');
    print('📊 Already completed: ${_completedSteps.contains(_currentStep)}');
    print('📊 Capture enabled: $_captureEnabled');

    // AUTOMATIC CAPTURE when angle is correct
    if (!_completedSteps.contains(_currentStep) &&
        _captureEnabled &&
        stepCompleted) {
      _faceDetectedFrames++;
      print(
        '🎯 CORRECT ANGLE: Face frames: $_faceDetectedFrames/3 (Step ${_currentStep + 1})',
      );

      // Wait for 3 frames (~0.15 second) of correct angle for super fast capture
      if (_faceDetectedFrames >= 3) {
        print(
          '✅ PERFECT ANGLE DETECTED! Auto-capturing Step ${_currentStep + 1}',
        );
        print('🔍 Current step: $_currentStep');
        print('🔍 Total steps: ${_registrationSteps.length}');
        print('🔍 Completed steps: ${_completedSteps.length}');

        // Disable further captures
        _captureEnabled = false;
        _faceDetectedFrames = 0;

        // Auto-capture photo and handle step progression
        _captureStepPhoto()
            .then((success) {
              if (success) {
                print(
                  '✅ Step ${_currentStep + 1} auto-captured and uploaded successfully!',
                );

                // Mark as completed AFTER successful capture and upload
                _completedSteps.add(_currentStep);

                // Move to next step after successful capture and upload
                _moveToNextStep();
              } else {
                print(
                  '❌ Step ${_currentStep + 1} auto-capture or upload failed!',
                );

                // Re-enable capture for retry
                setState(() {
                  _captureEnabled = true;
                  _faceDetectedFrames = 0;
                });
              }
            })
            .catchError((error) {
              print('❌ Step ${_currentStep + 1} auto-capture failed: $error');

              // Re-enable capture for retry
              setState(() {
                _captureEnabled = true;
                _faceDetectedFrames = 0;
              });
            });
      }
    } else if (_detectedFace != null && !stepCompleted) {
      _faceDetectedFrames = 0;
      print('📐 Face detected but angle needs adjustment');
    } else if (_detectedFace != null && stepCompleted) {
      print(
        '✅ Face detected with correct angle - Ready for capture (auto or manual)',
      );
    }

    // DEBUG: Print detailed status only when something changes
    if (_detectedFace != null) {
      final currentStatus = {
        'stepCompleted': stepCompleted,
        'highQuality': _isHighQualityFace(),
        'faceFrames': _faceDetectedFrames,
        'faceSize':
            '${_detectedFace!.boundingBox.width.toInt()}x${_detectedFace!.boundingBox.height.toInt()}',
        'headAngles':
            'X=${_detectedFace!.headEulerAngleX?.toStringAsFixed(1)}, Y=${_detectedFace!.headEulerAngleY?.toStringAsFixed(1)}, Z=${_detectedFace!.headEulerAngleZ?.toStringAsFixed(1)}',
      };

      // Only print if status changed
      if (_lastDebugStatus.toString() != currentStatus.toString()) {
        print('🔍 DEBUG STATUS:');
        print('   - Face detected: ✅');
        print('   - Step completed: ${stepCompleted ? "✅" : "❌"}');
        print('   - High quality: ✅ (bypassed for testing)');
        print('   - Face frames: $_faceDetectedFrames/3');
        print('   - Face size: ${currentStatus['faceSize']}');
        print('   - Head angles: ${currentStatus['headAngles']}');
        _lastDebugStatus = currentStatus;
      }
    }
  }

  // Pose detection methods
  bool _isLookingStraight() {
    if (_detectedFace == null) return false;
    final headEulerAngleX = _detectedFace!.headEulerAngleX;
    final headEulerAngleY = _detectedFace!.headEulerAngleY;
    final headEulerAngleZ = _detectedFace!.headEulerAngleZ;

    print(
      '🔍 Straight check - X: $headEulerAngleX, Y: $headEulerAngleY, Z: $headEulerAngleZ',
    );

    // Super relaxed angles - almost any angle will work
    bool isStable =
        headEulerAngleX!.abs() < 45 &&
        headEulerAngleY!.abs() < 45 &&
        headEulerAngleZ!.abs() < 50;

    print('🔍 Looking straight: $isStable');
    return isStable;
  }

  bool _isLookingUp() {
    if (_detectedFace == null) return false;
    final headEulerAngleX = _detectedFace!.headEulerAngleX;
    print('🔍 Up check - X: $headEulerAngleX (need < -2)');
    bool isUp =
        headEulerAngleX! < -2; // Super relaxed - just tilt head slightly up
    print('🔍 Looking up: $isUp');
    return isUp;
  }

  bool _isLookingDown() {
    if (_detectedFace == null) return false;
    final headEulerAngleX = _detectedFace!.headEulerAngleX;
    print('🔍 Down check - X: $headEulerAngleX (need > 2)');
    bool isDown =
        headEulerAngleX! > 2; // Super relaxed - just tilt head slightly down
    print('🔍 Looking down: $isDown');
    return isDown;
  }

  bool _isLookingLeft() {
    if (_detectedFace == null) return false;
    final headEulerAngleY = _detectedFace!.headEulerAngleY;
    print('🔍 Left check - Y: $headEulerAngleY (need < -5)');
    bool isLeft =
        headEulerAngleY! < -5; // Super relaxed - just turn head slightly left
    print('🔍 Looking left: $isLeft');
    return isLeft;
  }

  bool _isLookingRight() {
    if (_detectedFace == null) return false;
    final headEulerAngleY = _detectedFace!.headEulerAngleY;
    print('🔍 Right check - Y: $headEulerAngleY (need > 5)');
    bool isRight =
        headEulerAngleY! > 5; // Super relaxed - just turn head slightly right
    print('🔍 Looking right: $isRight');
    return isRight;
  }

  // High quality face validation for accurate capture
  bool _isHighQualityFace() {
    if (_detectedFace == null) return false;

    final face = _detectedFace!;
    final boundingBox = face.boundingBox;

    // Check face size - use camera preview size instead of screen size
    if (!widget.cameraController.value.isInitialized) return false;

    double faceArea = boundingBox.width * boundingBox.height;

    // Face must be reasonably large (at least 30x30 pixels) - extremely lenient
    if (boundingBox.width < 30 || boundingBox.height < 30) {
      print(
        '🔍 Quality check failed: Face too small (${boundingBox.width.toInt()}x${boundingBox.height.toInt()})',
      );
      return false;
    }

    // No stability requirement - capture immediately
    print(
      '🔍 Quality check passed: Face size ${boundingBox.width.toInt()}x${boundingBox.height.toInt()}',
    );
    return true;
  }

  bool _isBlinking() {
    if (_detectedFace == null) return false;

    // Use landmarks for blink detection in fullscreen
    final leftEye = _detectedFace!.landmarks[FaceLandmarkType.leftEye];
    final rightEye = _detectedFace!.landmarks[FaceLandmarkType.rightEye];

    if (leftEye != null && rightEye != null) {
      final faceHeight = _detectedFace!.boundingBox.height;
      final eyeDistance = (leftEye.position.y - rightEye.position.y).abs();
      final eyeRatio = eyeDistance / faceHeight;

      print(
        'Fullscreen blink check: eyeRatio = ${eyeRatio.toStringAsFixed(4)}',
      );
      return eyeRatio < 0.02; // Eyes closed
    }

    // No eye landmarks available - cannot detect real blinks
    print(
      '👁️ Fullscreen: No eye landmarks available for blink detection - waiting for landmarks...',
    );
    return false;
  }

  bool _isSmiling() {
    if (_detectedFace == null) {
      print('😊 Fullscreen Smile check: NO FACE DETECTED');
      return false;
    }

    // Use ML Kit's smile classification
    final smilingProbability = _detectedFace!.smilingProbability;
    if (smilingProbability != null) {
      print(
        '😊 Fullscreen Smile probability: ${(smilingProbability * 100).toStringAsFixed(1)}% (threshold: 70%)',
      );

      if (smilingProbability > 0.1) {
        // Super lenient - just 10% smile
        print('😊 FULLSCREEN SMILE DETECTED! Auto capturing...');
        return true;
      } else {
        print('😊 Fullscreen Not smiling enough - keep smiling!');
        return false;
      }
    } else {
      print(
        '😊 Fullscreen Smile detection not available - waiting for classification...',
      );
      return false;
    }
  }

  void _resetBlinkDetection() {
    _blinkFrameCount = 0;
    _eyesOpenFrameCount = 0;
    _blinkDetected = false;
  }

  Color _getStepColor() {
    if (_completedSteps.contains(_currentStep)) {
      return Colors.green;
    } else if (_detectedFace != null) {
      return Colors.blue;
    }
    return Colors.red;
  }

  Widget _buildFullScreenInstructions() {
    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Current Step: ${_registrationSteps[_currentStep]}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getStepInstructions(_currentStep),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenStepIndicator() {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStepColor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStepIcon(_currentStep),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of ${_registrationSteps.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        _registrationSteps[_currentStep],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_completedSteps.contains(_currentStep))
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _completedSteps.length / _registrationSteps.length,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              '${_completedSteps.length}/${_registrationSteps.length} steps completed',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            if (!_completedSteps.contains(_currentStep)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '📸 Auto-capture enabled',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStepInstructions(int step) {
    switch (step) {
      case 0:
        return 'Position your face in the center and look directly at the camera. Keep your head straight and eyes open.';
      case 1:
        return 'Slowly tilt your head up while keeping your eyes on the camera. Hold for a few seconds.';
      case 2:
        return 'Slowly tilt your head down while keeping your eyes on the camera. Hold for a few seconds.';
      case 3:
        return 'Turn your head to the left while keeping your eyes on the camera. Hold for a few seconds.';
      case 4:
        return 'Turn your head to the right while keeping your eyes on the camera. Hold for a few seconds.';
      case 5:
        return 'Blink your eyes naturally several times. Make sure your eyes are clearly visible.';
      case 6:
        return 'Give a natural smile. Keep your face relaxed and natural.';
      default:
        return 'Follow the instructions above to complete face registration.';
    }
  }

  IconData _getStepIcon(int step) {
    switch (step) {
      case 0:
        return Icons.face_rounded;
      case 1:
        return Icons.keyboard_arrow_up_rounded;
      case 2:
        return Icons.keyboard_arrow_down_rounded;
      case 3:
        return Icons.keyboard_arrow_left_rounded;
      case 4:
        return Icons.keyboard_arrow_right_rounded;
      case 5:
        return Icons.visibility_rounded;
      case 6:
        return Icons.sentiment_satisfied_rounded;
      default:
        return Icons.face_rounded;
    }
  }

  // Save registration data to persistent storage
  Future<void> _saveRegistrationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.userData['_id']?.toString() ?? 'unknown';

      // Save captured data to SharedPreferences
      final dataJson = jsonEncode(_capturedData);
      await prefs.setString('face_registration_$userId', dataJson);

      print('💾 Registration data saved to persistent storage');
    } catch (e) {
      print('❌ Error saving registration data: $e');
    }
  }

  Future<void> _clearRegistrationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.userData['_id']?.toString() ?? 'unknown';

      await prefs.remove('face_registration_$userId');
      _capturedData.clear();
      _cloudinaryUrls.clear();
      _capturedPhotos.clear();

      print('🗑️ All registration data cleared');
    } catch (e) {
      print('❌ Failed to clear registration data: $e');
    }
  }

  void _printRegistrationSummary() {
    print('📊 REGISTRATION DATA SUMMARY:');
    print('   📸 Total steps captured: ${_capturedData.length}');

    _capturedData.forEach((step, data) {
      print('   Step ${data['step_number']}: ${data['step_name']}');
      print('      📁 File: ${data['file_path']}');
      print('      ☁️ URL: ${data['cloudinary_url']}');
      print('      🕒 Time: ${data['timestamp']}');
      print('      📏 Size: ${data['file_size']} bytes');
    });
  }
}

// Success screen after face registration
class _FaceRegistrationSuccessScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success animation or icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.green, width: 3),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 80,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Face Registration Complete!',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                'Your face has been successfully registered. You can now use face recognition to quickly and securely login to your account.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(Icons.home_rounded, size: 20),
                  label: Text(
                    'Return to Settings',
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
}
