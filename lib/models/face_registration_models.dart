import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class RegistrationStep {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> qualityChecks;
  final double? minQualityThreshold;

  const RegistrationStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.qualityChecks,
    this.minQualityThreshold = 0.7,
  });
}

class StepQualityData {
  final int stepIndex;
  final double overallQuality;
  final Map<String, double> qualityMetrics;
  final DateTime completedAt;
  final File? capturedPhoto;
  final List<double>? embedding;
  final Map<String, dynamic>? faceAnalysis;
  final Face? detectedFace;

  StepQualityData({
    required this.stepIndex,
    required this.overallQuality,
    required this.qualityMetrics,
    required this.completedAt,
    this.capturedPhoto,
    this.embedding,
    this.faceAnalysis,
    this.detectedFace,
  });

  bool get isHighQuality => overallQuality >= 0.8;
  bool get isAcceptableQuality => overallQuality >= 0.6;
}

class FaceEmbeddingData {
  final List<double> embedding;
  final double quality;
  final String stepId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final Face detectedFace;

  FaceEmbeddingData({
    required this.embedding,
    required this.quality,
    required this.stepId,
    required this.timestamp,
    required this.metadata,
    required this.detectedFace,
  });
}

class FaceDataPoint {
  final String stepId;
  final Face detectedFace;
  final Map<FaceLandmarkType, math.Point<int>> landmarks;
  final Map<FaceContourType, List<math.Point<int>>> contours;
  final Map<String, dynamic> qualityMetrics;
  final DateTime timestamp;
  final double lightingScore;
  final double sharpnessScore;
  final double poseScore;

  FaceDataPoint({
    required this.stepId,
    required this.detectedFace,
    required this.landmarks,
    required this.contours,
    required this.qualityMetrics,
    required this.timestamp,
    required this.lightingScore,
    required this.sharpnessScore,
    required this.poseScore,
  });

  double get overallQuality => (lightingScore + sharpnessScore + poseScore) / 3.0;
}

class FaceQualityAnalysis {
  final double lighting;
  final double sharpness;
  final double pose;
  final double symmetry;
  final double eyeOpenness;
  final double mouthVisibility;
  final double landmarkQuality;
  final double contourCompleteness;
  final double overall;
  final List<String> issues;
  final List<String> recommendations;

  FaceQualityAnalysis({
    required this.lighting,
    required this.sharpness,
    required this.pose,
    required this.symmetry,
    required this.eyeOpenness,
    required this.mouthVisibility,
    required this.landmarkQuality,
    required this.contourCompleteness,
    required this.overall,
    required this.issues,
    required this.recommendations,
  });

  bool get isAcceptable => overall >= 0.6;
  bool get isHighQuality => overall >= 0.8;
  bool get isPerfectQuality => overall >= 0.9;
  
  // Comprehensive quality metrics
  Map<String, double> get allMetrics => {
    'lighting': lighting,
    'sharpness': sharpness,
    'pose': pose,
    'symmetry': symmetry,
    'eyeOpenness': eyeOpenness,
    'mouthVisibility': mouthVisibility,
    'landmarkQuality': landmarkQuality,
    'contourCompleteness': contourCompleteness,
    'overall': overall,
  };
}

enum FaceRegistrationState {
  notStarted,
  initializing,
  inProgress,
  stepComplete,
  allStepsComplete,
  processingData,
  completed,
  error,
}

class RegistrationProgress {
  final int totalSteps;
  final int completedSteps;
  final int currentStep;
  final double overallProgress;
  final double averageQuality;
  final FaceRegistrationState state;
  final String? errorMessage;

  RegistrationProgress({
    required this.totalSteps,
    required this.completedSteps,
    required this.currentStep,
    required this.overallProgress,
    required this.averageQuality,
    required this.state,
    this.errorMessage,
  });

  bool get isComplete => completedSteps >= totalSteps;
  double get qualityScore => averageQuality;
}
