import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../widgets/animated_wave_background.dart';
import '../widgets/face_detection_painter.dart';
import '../services/face_embedding_service.dart';
import '../utils/logger.dart';
import '../utils/custom_colors.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String userId;

  const FaceVerificationScreen({super.key, required this.userId});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  // Camera related
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _hasCameraPermission = false;
  List<CameraDescription>? _cameras;

  // Face detection
  bool _isDetecting = false;
  Face? _detectedFace;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true, // Enable for better face detection
      enableLandmarks: true, // Enable landmarks for more accurate detection
      enableClassification: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  // Face verification
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();
  bool _isVerifying = false;
  bool _isVerified = false;
  String? _verificationMessage;
  double? _similarityScore;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Pulse animation for face detection
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
    _pulseAnimationController.repeat(reverse: true);

    _initializeServices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseAnimationController.dispose();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await _embeddingService.initialize();
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      setState(() {
        _hasCameraPermission = status.isGranted;
      });

      if (!_hasCameraPermission) return;

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      // Configure camera for optimal face detection
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });

        // Start face detection after camera is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _startFaceDetection();
        });
      }
    } catch (e) {
      Logger.error('Camera initialization error: $e');
    }
  }

  void _startFaceDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      _cameraController!.startImageStream((CameraImage image) {
        // Enhanced null and state checks
        if (_isDetecting || _isVerifying || !mounted) return;

        // Double check camera controller is still valid
        if (_cameraController == null ||
            !_cameraController!.value.isInitialized) {
          Logger.warning('⚠️ Camera controller became null during stream');
          return;
        }

        try {
          _isDetecting = true;
          _processImage(image);
        } catch (e) {
          Logger.error('Error in image stream handler: $e');
          _isDetecting = false;
        }
      });
    } catch (e) {
      Logger.error('Failed to start face detection stream: $e');
    }
  }

  Future<void> _stopFaceDetection() async {
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        await _cameraController!.stopImageStream();
        Logger.info('🛑 Stopped face detection stream');
      }
    } catch (e) {
      Logger.error('Error stopping face detection: $e');
    }
    _isDetecting = false;
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      if (!mounted ||
          _cameraController == null ||
          !_cameraController!.value.isInitialized) {
        _isDetecting = false;
        return;
      }

      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector
          .processImage(inputImage)
          .timeout(const Duration(seconds: 2), onTimeout: () => <Face>[]);

      if (mounted && _cameraController != null) {
        setState(() {
          _detectedFace = faces.isNotEmpty ? faces.first : null;
          if (_detectedFace != null) {
            print('🔍 Face detected at: ${_detectedFace!.boundingBox}');
          }
        });
      }
    } catch (e) {
      Logger.error('Face detection error: $e');
    } finally {
      if (mounted) {
        _isDetecting = false;
      }
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      if (_cameras == null || _cameras!.isEmpty) {
        Logger.error('No cameras available for image conversion');
        return null;
      }

      final bytes = image.planes.fold<List<int>>(
        <int>[],
        (List<int> previousValue, Plane plane) =>
            previousValue..addAll(plane.bytes),
      );

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

      final InputImageFormat inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      return InputImage.fromBytes(
        bytes: Uint8List.fromList(bytes),
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      Logger.error('Image conversion error: $e');
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

  Future<void> _verifyFace() async {
    if (_isVerifying || _detectedFace == null || _cameraController == null) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationMessage = null;
      _similarityScore = null;
      _isVerified = false;
    });

    try {
      // Stop camera stream temporarily
      await _cameraController!.stopImageStream();

      // Take a picture for verification
      final XFile photo = await _cameraController!.takePicture();
      final photoFile = File(photo.path);

      // Perform verification
      final isMatch = await _embeddingService.verifyFace(
        widget.userId,
        photoFile,
        _detectedFace!,
      );

      // Load registered embedding to calculate similarity score
      final registeredEmbedding = await _embeddingService.loadFaceEmbedding(
        widget.userId,
      );
      final currentEmbedding = await _embeddingService.generateEmbedding(
        photoFile,
        _detectedFace!,
      );

      double? similarity;
      if (registeredEmbedding != null && currentEmbedding != null) {
        similarity = _embeddingService.calculateSimilarity(
          registeredEmbedding,
          currentEmbedding,
        );
      }

      // Clean up photo
      await photoFile.delete();

      if (mounted) {
        setState(() {
          _isVerified = isMatch;
          _similarityScore = similarity;
          _verificationMessage = isMatch
              ? '✅ Face verification successful!'
              : '❌ Face verification failed. Try again.';
        });

        _showVerificationResult(isMatch, similarity);
      }

      // Restart camera stream
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _cameraController != null) {
          _startFaceDetection();
        }
      });
    } catch (e) {
      Logger.error('Verification error: $e');

      if (mounted) {
        setState(() {
          _verificationMessage = '❌ Verification error: Please try again';
        });
      }

      // Restart camera stream
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _cameraController != null) {
          _startFaceDetection();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _showVerificationResult(bool isMatch, double? similarity) {
    final similarityPercent = similarity != null
        ? (similarity * 100).toStringAsFixed(1)
        : 'N/A';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isMatch
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMatch
                        ? 'Verification Successful!'
                        : 'Verification Failed',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Similarity: $similarityPercent%',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isMatch ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.getBackgroundColor(context),
      body: AnimatedWaveBackground(
        useFullScreen: true,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: CustomColors.getSurfaceColor(context),
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CustomColors.getSurfaceColor(
                      context,
                    ).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: CustomColors.getOnSurfaceColor(context),
                    size: 20,
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Face Verification',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: CustomColors.getOnSurfaceColor(context),
                  ),
                ),
                centerTitle: true,
              ),
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 32),
                      _buildCameraSection(),
                      const SizedBox(height: 32),
                      _buildVerificationSection(),
                      const SizedBox(height: 32),
                      _buildActionButtons(),
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

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CustomColors.getPrimaryColor(context).withValues(alpha: 0.1),
            CustomColors.getPrimaryColor(context).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CustomColors.getPrimaryColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.face_retouching_natural_rounded,
              color: CustomColors.getOnPrimaryColor(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Face Verification',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CustomColors.getOnSurfaceColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verify your identity using face recognition',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: CustomColors.getOnSurfaceColor(
                      context,
                    ).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: CustomColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _detectedFace != null
              ? CustomColors.getSuccessColor(context)
              : CustomColors.getSecondaryColor(context).withValues(alpha: 0.2),
          width: _detectedFace != null ? 3 : 2,
        ),
      ),
      child: _buildCameraPreview(),
    );
  }

  Widget _buildCameraPreview() {
    if (!_hasCameraPermission) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_rounded,
            size: 64,
            color: CustomColors.getOnSurfaceColor(context).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Camera Permission Required',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CustomColors.getOnSurfaceColor(context),
            ),
          ),
        ],
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Initializing Camera...',
            style: GoogleFonts.inter(fontSize: 16),
          ),
        ],
      );
    }

    return Stack(
      children: [
        // Camera preview with rounded corners
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
        ),

        // Simple center guide overlay - always visible on top
        Positioned.fill(
          child: CustomPaint(
            painter: CenterGuidePainter(color: Colors.yellow, strokeWidth: 4.0),
          ),
        ),

        // Face detection overlay - simple positioning
        if (_detectedFace != null)
          Positioned.fill(
            child: CustomPaint(
              painter: FaceDetectionPainter(
                faces: [_detectedFace!],
                primaryColor: Colors.cyan,
                imageSize:
                    _cameraController!.value.previewSize ??
                    const Size(640, 480),
                previewSize: const Size(300, 300), // Fixed size for now
                rotation: InputImageRotation.rotation0deg,
                animationValue: _pulseAnimation.value,
                showLandmarks: true,
                showContours: false,
              ),
            ),
          ),

        // Verification overlay
        if (_isVerifying)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Verifying face...',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

        // Face detection status
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _detectedFace != null
                      ? Icons.face_rounded
                      : Icons.face_retouching_off,
                  color: _detectedFace != null ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _detectedFace != null ? 'Face detected' : 'No face detected',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification Status',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          if (_verificationMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isVerified
                    ? CustomColors.getSuccessColor(context).withValues(alpha: 0.1)
                    : CustomColors.getErrorColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isVerified ? Icons.check_circle : Icons.error,
                    color: _isVerified
                        ? CustomColors.getSuccessColor(context)
                        : CustomColors.getErrorColor(context),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _verificationMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _isVerified
                            ? CustomColors.getSuccessColor(context)
                            : CustomColors.getErrorColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_similarityScore != null) ...[
            Text(
              'Similarity Score: ${(_similarityScore! * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: CustomColors.getOnSurfaceColor(context).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _similarityScore!,
              backgroundColor: CustomColors.getSecondaryColor(
                context,
              ).withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                _similarityScore! >= 0.6
                    ? CustomColors.getSuccessColor(context)
                    : CustomColors.getWarningColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Threshold: 60%',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CustomColors.getOnSurfaceColor(context).withValues(alpha: 0.5),
              ),
            ),
          ] else ...[
            Text(
              'User: ${widget.userId}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: CustomColors.getOnSurfaceColor(context).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Position your face in the camera and tap "Verify Face" when ready.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CustomColors.getOnSurfaceColor(context).withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _detectedFace != null && !_isVerifying
                ? _verifyFace
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.getPrimaryColor(context),
              foregroundColor: CustomColors.getOnPrimaryColor(context),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isVerifying
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.face_retouching_natural_rounded, size: 20),
            label: Text(
              _isVerifying ? 'Verifying...' : 'Verify Face',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, size: 20),
            label: Text('Back', style: GoogleFonts.inter(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
