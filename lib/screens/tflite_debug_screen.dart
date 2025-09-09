import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../widgets/animated_wave_background.dart';
import '../services/face_embedding_service.dart';
import '../services/tflite_deep_learning_service.dart';
import '../utils/logger.dart';
import '../utils/custom_colors.dart';

class TFLiteDebugScreen extends StatefulWidget {
  const TFLiteDebugScreen({super.key});

  @override
  State<TFLiteDebugScreen> createState() => _TFLiteDebugScreenState();
}

class _TFLiteDebugScreenState extends State<TFLiteDebugScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Services
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();
  final TFLiteDeepLearningService _tfliteService = TFLiteDeepLearningService();

  // Camera
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  List<CameraDescription>? _cameras;

  // Face detection
  Face? _detectedFace;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  // Analysis results
  Map<String, dynamic>? _facialAnalysis;
  List<double>? _faceEmbedding;
  bool _isAnalyzing = false;
  String _statusMessage = 'Initializing...';

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
    _animationController.forward();

    _initializeServices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      setState(() => _statusMessage = 'Initializing TensorFlow Lite...');

      await _embeddingService.initialize();

      setState(() => _statusMessage = 'Initializing camera...');
      await _initializeCamera();

      setState(() => _statusMessage = 'Ready for face analysis');
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
      Logger.error('Initialization error: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() => _statusMessage = 'Camera permission denied');
        return;
      }

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _statusMessage = 'No cameras available');
        return;
      }

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

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      setState(() => _statusMessage = 'Camera error: $e');
      Logger.error('Camera initialization error: $e');
    }
  }

  Future<void> _analyzeCurrentFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      setState(() => _statusMessage = 'Camera not ready');
      return;
    }

    if (_isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Analyzing face with TensorFlow Lite...';
      _facialAnalysis = null;
      _faceEmbedding = null;
    });

    try {
      // Take a picture
      final XFile photo = await _cameraController!.takePicture();
      final photoFile = File(photo.path);

      // Detect face
      final inputImage = InputImage.fromFilePath(photo.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() => _statusMessage = 'No face detected');
        await photoFile.delete();
        return;
      }

      final face = faces.first;
      setState(() => _detectedFace = face);

      // Generate embedding using TensorFlow Lite
      final embedding = await _embeddingService.generateEmbedding(
        photoFile,
        face,
      );

      // Analyze facial attributes
      final analysis = await _embeddingService.analyzeFacialAttributes(
        photoFile,
        face,
      );

      // Clean up
      await photoFile.delete();

      if (mounted) {
        setState(() {
          _faceEmbedding = embedding;
          _facialAnalysis = analysis;
          _statusMessage = 'Analysis completed successfully!';
        });
      }
    } catch (e) {
      setState(() => _statusMessage = 'Analysis error: $e');
      Logger.error('Face analysis error: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
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
                    ).withOpacity(0.9),
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
                  'TensorFlow Lite Debug',
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
                      _buildStatusSection(),
                      const SizedBox(height: 24),
                      _buildCameraSection(),
                      const SizedBox(height: 24),
                      _buildAnalysisButton(),
                      const SizedBox(height: 24),
                      if (_facialAnalysis != null) _buildAnalysisResults(),
                      if (_faceEmbedding != null) _buildEmbeddingInfo(),
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

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CustomColors.getPrimaryColor(context).withOpacity(0.1),
            CustomColors.getPrimaryColor(context).withOpacity(0.05),
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
              Icons.psychology,
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
                  'TensorFlow Lite Status',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CustomColors.getOnSurfaceColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: CustomColors.getOnSurfaceColor(
                      context,
                    ).withOpacity(0.7),
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
      height: MediaQuery.of(context).size.height * 0.35, // Responsive height
      decoration: BoxDecoration(
        color: CustomColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CustomColors.getSecondaryColor(context).withOpacity(0.2),
          width: 2,
        ),
      ),
      child:
          _isCameraInitialized && _cameraController!.value.previewSize != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Center(
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.width.toDouble(),
                  height: _cameraController!.value.previewSize!.height
                      .toDouble(),
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildAnalysisButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isAnalyzing ? null : _analyzeCurrentFace,
        style: ElevatedButton.styleFrom(
          backgroundColor: CustomColors.getPrimaryColor(context),
          foregroundColor: CustomColors.getOnPrimaryColor(context),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isAnalyzing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CustomColors.getOnPrimaryColor(context),
                  ),
                ),
              )
            : const Icon(Icons.psychology, size: 20),
        label: Text(
          _isAnalyzing
              ? 'Analyzing with TensorFlow Lite...'
              : 'Analyze Face with AI',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAnalysisResults() {
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
            'Facial Analysis Results',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Emotion analysis
          if (_facialAnalysis!['emotion'] != null) ...[
            Text(
              'Emotions:',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._buildEmotionBars(
              _facialAnalysis!['emotion'] as Map<String, dynamic>,
            ),
            const SizedBox(height: 16),
          ],

          // Age and gender
          if (_facialAnalysis!['age'] != null) ...[
            _buildInfoRow('Age', '${_facialAnalysis!['age']} years'),
            const SizedBox(height: 8),
          ],
          if (_facialAnalysis!['gender'] != null) ...[
            _buildInfoRow(
              'Gender',
              '${_facialAnalysis!['gender']} (${(_facialAnalysis!['gender_confidence'] * 100).toStringAsFixed(1)}%)',
            ),
            const SizedBox(height: 8),
          ],

          // Other attributes
          if (_facialAnalysis!['facial_symmetry'] != null) ...[
            _buildInfoRow(
              'Facial Symmetry',
              '${(_facialAnalysis!['facial_symmetry'] * 100).toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 8),
          ],
          if (_facialAnalysis!['smile_intensity'] != null) ...[
            _buildInfoRow(
              'Smile Intensity',
              '${(_facialAnalysis!['smile_intensity'] * 100).toStringAsFixed(1)}%',
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildEmotionBars(Map<String, dynamic> emotions) {
    return emotions.entries.map((entry) {
      final emotion = entry.key;
      final value = entry.value as double;
      final percentage = (value * 100).toStringAsFixed(1);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  emotion.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                Text('$percentage%', style: GoogleFonts.inter(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getEmotionColor(emotion),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.yellow;
      case 'sad':
        return Colors.blue;
      case 'angry':
        return Colors.red;
      case 'surprise':
        return Colors.orange;
      case 'fear':
        return Colors.purple;
      case 'disgust':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.inter()),
      ],
    );
  }

  Widget _buildEmbeddingInfo() {
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
            'Face Embedding',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Dimensions', '${_faceEmbedding!.length}D'),
          const SizedBox(height: 8),
          _buildInfoRow(
            'L2 Norm',
            _calculateL2Norm(_faceEmbedding!).toStringAsFixed(4),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Min Value',
            _faceEmbedding!.reduce((a, b) => a < b ? a : b).toStringAsFixed(4),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Max Value',
            _faceEmbedding!.reduce((a, b) => a > b ? a : b).toStringAsFixed(4),
          ),
        ],
      ),
    );
  }

  double _calculateL2Norm(List<double> embedding) {
    return math.sqrt(
      embedding.fold<double>(0.0, (sum, val) => sum + val * val),
    );
  }
}
