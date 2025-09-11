import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'services/cloudinary_service.dart';

class TestCaptureScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const TestCaptureScreen({super.key, required this.userData});

  @override
  State<TestCaptureScreen> createState() => _TestCaptureScreenState();
}

class _TestCaptureScreenState extends State<TestCaptureScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  String? _lastCapturedPath;
  String? _lastUploadUrl;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    print('🎥 Initializing camera for test...');
    
    // Request camera permission
    final permission = await Permission.camera.request();
    if (permission != PermissionStatus.granted) {
      print('❌ Camera permission denied');
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        print('❌ No cameras available');
        return;
      }

      // Use front camera for face capture
      CameraDescription frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
      
      print('✅ Camera initialized successfully');
    } catch (e) {
      print('❌ Camera initialization failed: $e');
    }
  }

  Future<void> _testCapture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('❌ Camera not ready');
      return;
    }

    if (_isCapturing) {
      print('❌ Already capturing');
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      print('📸 Taking test photo...');
      
      // Take the picture
      final XFile photo = await _cameraController!.takePicture();
      print('✅ Photo taken: ${photo.path}');
      
      setState(() {
        _lastCapturedPath = photo.path;
      });

      // Test upload to Cloudinary
      if (widget.userData['_id'] != null) {
        print('☁️ Testing Cloudinary upload...');
        
        final uploadResult = await CloudinaryService.uploadFaceImage(
          userId: widget.userData['_id'],
          imageFile: File(photo.path),
          imageType: 'test_capture',
        );
        
        if (uploadResult['success']) {
          print('✅ Upload successful!');
          setState(() {
            _lastUploadUrl = uploadResult['data']['image_url'];
          });
        } else {
          print('❌ Upload failed: ${uploadResult['message']}');
        }
      }
      
    } catch (e) {
      print('❌ Capture failed: $e');
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Face Capture'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
            child: _isCameraInitialized
                ? CameraPreview(_cameraController!)
                : Center(
                    child: CircularProgressIndicator(),
                  ),
          ),
          
          // Controls and status
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Capture button
                  ElevatedButton(
                    onPressed: _isCapturing ? null : _testCapture,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                    ),
                    child: _isCapturing 
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('📸 Test Capture & Upload'),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Status
                  if (_lastCapturedPath != null) ...[
                    Text('✅ Last captured: ${_lastCapturedPath!.split('/').last}'),
                    SizedBox(height: 10),
                  ],
                  
                  if (_lastUploadUrl != null) ...[
                    Text('☁️ Uploaded to:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    SelectableText(
                      _lastUploadUrl!,
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
