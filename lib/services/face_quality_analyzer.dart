import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/face_registration_models.dart';
import '../utils/logger.dart';

class FaceQualityAnalyzer {
  static const double _minFaceSize = 0.12; // Minimum face size as fraction of image (more lenient)
  static const double _maxFaceSize = 0.85;  // Maximum face size as fraction of image (increased)
  static const double _optimalFaceSize = 0.45; // Optimal face size (increased for better detail)
  
  static const double _minLightingScore = 50.0;  // More lenient minimum brightness
  static const double _maxLightingScore = 220.0; // Higher maximum brightness tolerance
  static const double _optimalLightingScore = 130.0; // Slightly brighter optimal
  
  static const double _minEyeOpenness = 0.25; // More lenient eye openness threshold
  static const double _minSmileIntensity = 0.15; // More lenient smile detection
  static const double _maxHeadRotation = 35.0; // Maximum allowed head rotation degrees
  static const double _minLandmarkConfidence = 0.7; // Minimum landmark detection confidence

  static FaceQualityAnalysis analyzeFaceQuality(
    Face face,
    File imageFile,
    String stepId,
  ) {
    try {
      Logger.info('🔍 Analyzing face quality for step: $stepId');
      
      final issues = <String>[];
      final recommendations = <String>[];
      
      // Analyze basic face metrics with enhanced landmark validation
      final lightingScore = _analyzeLighting(face, imageFile, issues, recommendations);
      final sharpnessScore = _analyzeSharpness(face, imageFile, issues, recommendations);
      final poseScore = _analyzePose(face, stepId, issues, recommendations);
      final symmetryScore = _analyzeSymmetry(face, issues, recommendations);
      final eyeOpennessScore = _analyzeEyeOpenness(face, issues, recommendations);
      final mouthVisibilityScore = _analyzeMouthVisibility(face, issues, recommendations);
      final landmarkQualityScore = _analyzeLandmarkQuality(face, issues, recommendations);
      final contourCompletenessScore = _analyzeContourCompleteness(face, issues, recommendations);
      
      // Calculate overall quality score with weighted factors including new metrics
      final overallScore = _calculateOverallQuality(
        lightingScore,
        sharpnessScore,
        poseScore,
        symmetryScore,
        eyeOpennessScore,
        mouthVisibilityScore,
        landmarkQualityScore,
        contourCompletenessScore,
      );
      
      Logger.info('✅ Face quality analysis completed:');
      Logger.info('   Overall: ${(overallScore * 100).toStringAsFixed(1)}%');
      Logger.info('   Lighting: ${(lightingScore * 100).toStringAsFixed(1)}%');
      Logger.info('   Sharpness: ${(sharpnessScore * 100).toStringAsFixed(1)}%');
      Logger.info('   Pose: ${(poseScore * 100).toStringAsFixed(1)}%');
      
      return FaceQualityAnalysis(
        lighting: lightingScore,
        sharpness: sharpnessScore,
        pose: poseScore,
        symmetry: symmetryScore,
        eyeOpenness: eyeOpennessScore,
        mouthVisibility: mouthVisibilityScore,
        landmarkQuality: landmarkQualityScore,
        contourCompleteness: contourCompletenessScore,
        overall: overallScore,
        issues: issues,
        recommendations: recommendations,
      );
      
    } catch (e) {
      Logger.error('❌ Error analyzing face quality: $e');
      return FaceQualityAnalysis(
        lighting: 0.5,
        sharpness: 0.5,
        pose: 0.5,
        symmetry: 0.5,
        eyeOpenness: 0.5,
        mouthVisibility: 0.5,
        landmarkQuality: 0.5,
        contourCompleteness: 0.5,
        overall: 0.5,
        issues: ['Analysis failed'],
        recommendations: ['Please try again'],
      );
    }
  }
  
  static double _analyzeLighting(
    Face face,
    File imageFile,
    List<String> issues,
    List<String> recommendations,
  ) {
    try {
      // Analyze face region lighting
      final boundingBox = face.boundingBox;
      
      // Estimate lighting from face size and position (proxy analysis)
      final faceArea = boundingBox.width * boundingBox.height;
      final imageCenter = math.Point(boundingBox.left + boundingBox.width / 2, 
                                   boundingBox.top + boundingBox.height / 2);
      
      // Basic lighting estimation based on face position and size
      var lightingScore = 0.8; // Default good lighting
      
      // Face too close to edges might indicate poor lighting
      if (boundingBox.left < 50 || boundingBox.top < 50) {
        lightingScore -= 0.2;
        issues.add('Face is too close to image edge');
        recommendations.add('Center your face in the frame');
      }
      
      // Very small face might indicate backlighting
      if (faceArea < 10000) {
        lightingScore -= 0.3;
        issues.add('Face appears small, possible backlighting');
        recommendations.add('Move closer to the camera or improve lighting');
      }
      
      return math.max(0.0, math.min(1.0, lightingScore));
      
    } catch (e) {
      Logger.error('Error analyzing lighting: $e');
      return 0.6;
    }
  }
  
  static double _analyzeSharpness(
    Face face,
    File imageFile,
    List<String> issues,
    List<String> recommendations,
  ) {
    try {
      // Estimate sharpness from landmark detection quality
      final landmarks = face.landmarks;
      
      var sharpnessScore = 0.7; // Default moderate sharpness
      
      // More landmarks detected usually means sharper image
      if (landmarks.length >= 6) {
        sharpnessScore += 0.2;
      } else if (landmarks.length <= 3) {
        sharpnessScore -= 0.3;
        issues.add('Low landmark detection - image may be blurry');
        recommendations.add('Hold the device steady and ensure good focus');
      }
      
      // Check face size as proxy for image quality
      final boundingBox = face.boundingBox;
      final faceSize = boundingBox.width * boundingBox.height;
      
      if (faceSize > 40000) { // Large face usually means better detail
        sharpnessScore += 0.1;
      } else if (faceSize < 15000) {
        sharpnessScore -= 0.2;
        issues.add('Face appears small in image');
        recommendations.add('Move closer to the camera');
      }
      
      return math.max(0.0, math.min(1.0, sharpnessScore));
      
    } catch (e) {
      Logger.error('Error analyzing sharpness: $e');
      return 0.6;
    }
  }
  
  static double _analyzePose(
    Face face,
    String stepId,
    List<String> issues,
    List<String> recommendations,
  ) {
    try {
      final headEulerAngleY = face.headEulerAngleY ?? 0.0;
      final headEulerAngleX = face.headEulerAngleX ?? 0.0;
      final headEulerAngleZ = face.headEulerAngleZ ?? 0.0;
      
      var poseScore = 1.0;
      
      // Check pose based on registration step
      switch (stepId) {
        case 'center':
          // For center step, face should be straight
          if (headEulerAngleY.abs() > 10) {
            poseScore -= 0.3;
            issues.add('Face not centered (turn: ${headEulerAngleY.toStringAsFixed(1)}°)');
            recommendations.add('Look straight at the camera');
          }
          if (headEulerAngleX.abs() > 10) {
            poseScore -= 0.2;
            issues.add('Head tilt detected (tilt: ${headEulerAngleX.toStringAsFixed(1)}°)');
            recommendations.add('Keep your head level');
          }
          break;
          
        case 'up':
          // For up step, expect upward tilt (more lenient range)
          if (headEulerAngleX > -3 || headEulerAngleX < -30) {
            poseScore -= 0.3; // Reduced penalty
            issues.add('Incorrect upward pose (tilt: ${headEulerAngleX.toStringAsFixed(1)}°)');
            recommendations.add('Tilt your head up slightly (10-20° upward)');
          } else if (headEulerAngleX <= -10 && headEulerAngleX >= -20) {
            poseScore += 0.1; // Bonus for optimal range
          }
          break;
          
        case 'down':
          // For down step, expect downward tilt (more lenient range)
          if (headEulerAngleX < 3 || headEulerAngleX > 30) {
            poseScore -= 0.3; // Reduced penalty
            issues.add('Incorrect downward pose (tilt: ${headEulerAngleX.toStringAsFixed(1)}°)');
            recommendations.add('Tilt your head down slightly (10-20° downward)');
          } else if (headEulerAngleX >= 10 && headEulerAngleX <= 20) {
            poseScore += 0.1; // Bonus for optimal range
          }
          break;
          
        case 'left':
          // For left step, expect left turn (more lenient range)
          if (headEulerAngleY > -5 || headEulerAngleY < -40) {
            poseScore -= 0.3; // Reduced penalty
            issues.add('Incorrect left pose (turn: ${headEulerAngleY.toStringAsFixed(1)}°)');
            recommendations.add('Turn your head to the left (15-25° left)');
          } else if (headEulerAngleY <= -15 && headEulerAngleY >= -25) {
            poseScore += 0.1; // Bonus for optimal range
          }
          break;
          
        case 'right':
          // For right step, expect right turn (more lenient range)
          if (headEulerAngleY < 5 || headEulerAngleY > 40) {
            poseScore -= 0.3; // Reduced penalty
            issues.add('Incorrect right pose (turn: ${headEulerAngleY.toStringAsFixed(1)}°)');
            recommendations.add('Turn your head to the right (15-25° right)');
          } else if (headEulerAngleY >= 15 && headEulerAngleY <= 25) {
            poseScore += 0.1; // Bonus for optimal range
          }
          break;
      }
      
      // General pose quality checks
      if (headEulerAngleZ.abs() > 15) {
        poseScore -= 0.2;
        issues.add('Head roll detected (roll: ${headEulerAngleZ.toStringAsFixed(1)}°)');
        recommendations.add('Keep your head upright, avoid tilting sideways');
      }
      
      return math.max(0.0, math.min(1.0, poseScore));
      
    } catch (e) {
      Logger.error('Error analyzing pose: $e');
      return 0.7;
    }
  }
  
  static double _analyzeSymmetry(
    Face face,
    List<String> issues,
    List<String> recommendations,
  ) {
    try {
      final landmarks = face.landmarks;
      var symmetryScore = 0.8; // Default good symmetry
      
      // Check if we have key landmarks for symmetry analysis
      final leftEye = landmarks[FaceLandmarkType.leftEye];
      final rightEye = landmarks[FaceLandmarkType.rightEye];
      final leftMouth = landmarks[FaceLandmarkType.leftMouth];
      final rightMouth = landmarks[FaceLandmarkType.rightMouth];
      
      if (leftEye != null && rightEye != null) {
        // Check eye level symmetry
        final eyeHeightDiff = (leftEye.position.y - rightEye.position.y).abs();
        if (eyeHeightDiff > 20) {
          symmetryScore -= 0.3;
          issues.add('Eyes appear uneven');
          recommendations.add('Ensure your face is level and well-lit');
        }
      }
      
      if (leftMouth != null && rightMouth != null) {
        // Check mouth symmetry
        final mouthHeightDiff = (leftMouth.position.y - rightMouth.position.y).abs();
        if (mouthHeightDiff > 15) {
          symmetryScore -= 0.2;
          issues.add('Mouth appears asymmetric');
          recommendations.add('Keep a neutral expression or smile evenly');
        }
      }
      
      return math.max(0.0, math.min(1.0, symmetryScore));
      
    } catch (e) {
      Logger.error('Error analyzing symmetry: $e');
      return 0.7;
    }
  }
  
  static double _analyzeEyeOpenness(
    Face face,
    List<String> issues,
    List<String> recommendations,
  ) {
    try {
      final leftEyeOpenProbability = face.leftEyeOpenProbability ?? 0.5;
      final rightEyeOpenProbability = face.rightEyeOpenProbability ?? 0.5;
      
      final avgEyeOpenness = (leftEyeOpenProbability + rightEyeOpenProbability) / 2;
      
      var eyeScore = avgEyeOpenness;
      
      if (avgEyeOpenness < _minEyeOpenness) {
        issues.add('Eyes appear closed or partially closed');
        recommendations.add('Keep your eyes open and look at the camera');
        eyeScore = 0.2;
      } else if (avgEyeOpenness < 0.6) {
        issues.add('Eyes appear squinted');
        recommendations.add('Open your eyes naturally');
      }
      
      // Check for blink detection consistency
      final eyeDifference = (leftEyeOpenProbability - rightEyeOpenProbability).abs();
      if (eyeDifference > 0.4) {
        eyeScore -= 0.2;
        issues.add('Inconsistent eye openness detected');
        recommendations.add('Avoid blinking or squinting during capture');
      }
      
      return math.max(0.0, math.min(1.0, eyeScore));
      
    } catch (e) {
      Logger.error('Error analyzing eye openness: $e');
      return 0.7;
    }
  }
  
  static double _analyzeMouthVisibility(
    Face face,
    List<String> issues,
    List<String> recommendations,
  ) {
    try {
      final landmarks = face.landmarks;
      var mouthScore = 0.8; // Default good mouth visibility
      
      // Check if mouth landmarks are detected
      final leftMouth = landmarks[FaceLandmarkType.leftMouth];
      final rightMouth = landmarks[FaceLandmarkType.rightMouth];
      final bottomMouth = landmarks[FaceLandmarkType.bottomMouth];
      
      if (leftMouth == null || rightMouth == null) {
        mouthScore -= 0.4;
        issues.add('Mouth landmarks not clearly detected');
        recommendations.add('Ensure your mouth is clearly visible');
      }
      
      if (bottomMouth == null) {
        mouthScore -= 0.2;
        issues.add('Lower lip not clearly detected');
        recommendations.add('Avoid covering your mouth');
      }
      
      // Check for smile detection if available
      final smilingProbability = face.smilingProbability ?? 0.0;
      
      // For smile step, we want to detect a smile
      if (smilingProbability > 0.7) {
        mouthScore += 0.1; // Bonus for clear smile detection
      }
      
      return math.max(0.0, math.min(1.0, mouthScore));
      
    } catch (e) {
      Logger.error('Error analyzing mouth visibility: $e');
      return 0.7;
    }
  }
  
  static double _analyzeLandmarkQuality(
    Face face,
    List<String> issues,
    List<String> recommendations,
  ) {
    try {
      final landmarks = face.landmarks;
      var landmarkScore = 1.0;
      int detectedLandmarks = 0;
      int totalExpectedLandmarks = 0;
      
      // Define critical landmarks for face registration accuracy
      final criticalLandmarks = {
        FaceLandmarkType.leftEye: 'Left Eye',
        FaceLandmarkType.rightEye: 'Right Eye',
        FaceLandmarkType.noseBase: 'Nose Base',
        FaceLandmarkType.leftMouth: 'Left Mouth Corner',
        FaceLandmarkType.rightMouth: 'Right Mouth Corner',
        FaceLandmarkType.bottomMouth: 'Bottom Mouth',
        FaceLandmarkType.leftCheek: 'Left Cheek',
        FaceLandmarkType.rightCheek: 'Right Cheek',
      };
      
      totalExpectedLandmarks = criticalLandmarks.length;
      
      // Check each critical landmark
      criticalLandmarks.forEach((type, name) {
        final landmark = landmarks[type];
        if (landmark != null) {
          detectedLandmarks++;
        } else {
          issues.add('$name landmark not detected');
          recommendations.add('Ensure $name is clearly visible and well-lit');
        }
      });
      
      // Calculate landmark detection ratio
      final detectionRatio = detectedLandmarks / totalExpectedLandmarks;
      landmarkScore = detectionRatio;
      
      // Bonus for detecting additional landmarks
      final additionalLandmarks = {
        FaceLandmarkType.leftEar: 'Left Ear',
        FaceLandmarkType.rightEar: 'Right Ear',
      };
      
      int bonusLandmarks = 0;
      additionalLandmarks.forEach((type, name) {
        if (landmarks[type] != null) {
          bonusLandmarks++;
        }
      });
      
      if (bonusLandmarks > 0) {
        landmarkScore += (bonusLandmarks * 0.05); // 5% bonus per additional landmark
      }
      
      // Quality thresholds
      if (detectionRatio < 0.6) {
        issues.add('Poor landmark detection (${(detectionRatio * 100).toInt()}%)');
        recommendations.add('Improve lighting and face positioning for better landmark detection');
      } else if (detectionRatio < 0.8) {
        issues.add('Moderate landmark detection quality');
        recommendations.add('Adjust angle and lighting for better feature visibility');
      }
      
      Logger.info('   Landmarks detected: $detectedLandmarks/$totalExpectedLandmarks (${(detectionRatio * 100).toInt()}%)');
      
      return math.max(0.0, math.min(1.0, landmarkScore));
      
    } catch (e) {
      Logger.error('Error analyzing landmark quality: $e');
      return 0.5;
    }
  }
  
  static double _analyzeContourCompleteness(
    Face face,
    List<String> issues,
    List<String> recommendations,
  ) {
    try {
      final contours = face.contours;
      var contourScore = 1.0;
      int detectedContours = 0;
      int totalExpectedContours = 0;
      
      // Define critical contours for comprehensive face shape analysis
      final criticalContours = {
        FaceContourType.face: 'Face Outline',
        FaceContourType.leftEyebrowTop: 'Left Eyebrow Top',
        FaceContourType.leftEyebrowBottom: 'Left Eyebrow Bottom',
        FaceContourType.rightEyebrowTop: 'Right Eyebrow Top',
        FaceContourType.rightEyebrowBottom: 'Right Eyebrow Bottom',
        FaceContourType.leftEye: 'Left Eye Contour',
        FaceContourType.rightEye: 'Right Eye Contour',
        FaceContourType.upperLipTop: 'Upper Lip Top',
        FaceContourType.upperLipBottom: 'Upper Lip Bottom',
        FaceContourType.lowerLipTop: 'Lower Lip Top',
        FaceContourType.lowerLipBottom: 'Lower Lip Bottom',
        FaceContourType.noseBridge: 'Nose Bridge',
        FaceContourType.noseBottom: 'Nose Bottom',
      };
      
      totalExpectedContours = criticalContours.length;
      
      // Check each critical contour
      criticalContours.forEach((type, name) {
        final contour = contours[type];
        if (contour != null && contour.points.isNotEmpty) {
          detectedContours++;
          
          // Check contour quality (minimum points for a good contour)
          if (contour.points.length < 3) {
            contourScore -= 0.05; // Penalty for low-quality contours
          }
        } else {
          issues.add('$name contour not detected');
          recommendations.add('Ensure $name is clearly visible');
        }
      });
      
      // Calculate contour detection ratio
      final detectionRatio = detectedContours / totalExpectedContours;
      contourScore *= detectionRatio;
      
      // Quality thresholds
      if (detectionRatio < 0.5) {
        issues.add('Poor contour detection (${(detectionRatio * 100).toInt()}%)');
        recommendations.add('Improve lighting and reduce shadows for better contour detection');
      } else if (detectionRatio < 0.7) {
        issues.add('Moderate contour detection quality');
        recommendations.add('Adjust positioning for better facial feature visibility');
      }
      
      Logger.info('   Contours detected: $detectedContours/$totalExpectedContours (${(detectionRatio * 100).toInt()}%)');
      
      return math.max(0.0, math.min(1.0, contourScore));
      
    } catch (e) {
      Logger.error('Error analyzing contour completeness: $e');
      return 0.5;
    }
  }

  static double _calculateOverallQuality(
    double lighting,
    double sharpness,
    double pose,
    double symmetry,
    double eyeOpenness,
    double mouthVisibility,
    double landmarkQuality,
    double contourCompleteness,
  ) {
    // Enhanced weighted quality calculation with new metrics
    const weights = {
      'lighting': 0.20,        // Reduced to make room for new metrics
      'sharpness': 0.15,       // Reduced
      'pose': 0.20,            // Maintained - critical for registration
      'symmetry': 0.12,        // Reduced
      'eyeOpenness': 0.08,     // Reduced
      'mouthVisibility': 0.05, // Maintained
      'landmarkQuality': 0.15, // NEW - very important for accuracy
      'contourCompleteness': 0.05, // NEW - helps with shape analysis
    };
    
    final weightedScore = 
        (lighting * weights['lighting']!) +
        (sharpness * weights['sharpness']!) +
        (pose * weights['pose']!) +
        (symmetry * weights['symmetry']!) +
        (eyeOpenness * weights['eyeOpenness']!) +
        (mouthVisibility * weights['mouthVisibility']!) +
        (landmarkQuality * weights['landmarkQuality']!) +
        (contourCompleteness * weights['contourCompleteness']!);
    
    return math.max(0.0, math.min(1.0, weightedScore));
  }
  
  static String getQualityFeedback(FaceQualityAnalysis analysis) {
    if (analysis.overall >= 0.9) {
      return 'Excellent quality! Perfect face capture.';
    } else if (analysis.overall >= 0.8) {
      return 'Great quality! Face captured successfully.';
    } else if (analysis.overall >= 0.7) {
      return 'Good quality. Minor improvements possible.';
    } else if (analysis.overall >= 0.6) {
      return 'Acceptable quality. Some issues detected.';
    } else if (analysis.overall >= 0.4) {
      return 'Poor quality. Please address the issues.';
    } else {
      return 'Very poor quality. Please retry with better conditions.';
    }
  }
  
  static Color getQualityColor(double quality) {
    if (quality >= 0.8) return Colors.green;
    if (quality >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
