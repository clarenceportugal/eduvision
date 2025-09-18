import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';

class CloudinaryService {
  static final Dio _dio = Dio();

  static Future<Map<String, dynamic>> uploadFaceImage({
    required String userId,
    required File imageFile,
    String imageType = 'face_capture',
    String? stepName,
    int? stepNumber,
  }) async {
    try {
      // 
      // 
      // 
      // 
      // 
      // 

      String fileName = imageFile.path.split('/').last;

      // Build form data with step information
      final formDataMap = <String, dynamic>{
        'userId': userId,
        'imageType': imageType,
        'face_image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      };

      // Add step information if provided
      if (stepName != null) {
        formDataMap['stepName'] = stepName;
      }
      if (stepNumber != null) {
        formDataMap['stepNumber'] = stepNumber.toString();
      }

      FormData formData = FormData.fromMap(formDataMap);

      print(
        '🔍 Making POST request to: ${ServerConfig.serverUrl}/api/upload-face',
      );

      final response = await _dio.post(
        '${ServerConfig.serverUrl}/api/upload-face',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      // 
      // 

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {
          'success': false,
          'message': 'Upload failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      // 
      // 
      return {'success': false, 'message': 'Upload failed: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> uploadFaceImageFromBytes({
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
    String imageType = 'face_capture',
    String? stepName,
    int? stepNumber,
  }) async {
    try {
      // Build form data with step information
      final formDataMap = <String, dynamic>{
        'userId': userId,
        'imageType': imageType,
        'face_image': MultipartFile.fromBytes(imageBytes, filename: fileName),
      };

      // Add step information if provided
      if (stepName != null) {
        formDataMap['stepName'] = stepName;
      }
      if (stepNumber != null) {
        formDataMap['stepNumber'] = stepNumber.toString();
      }

      FormData formData = FormData.fromMap(formDataMap);

      final response = await _dio.post(
        '${ServerConfig.serverUrl}/api/upload-face',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {
          'success': false,
          'message': 'Upload failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      // 
      // 
      return {'success': false, 'message': 'Upload failed: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> getUserFaceImages(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ServerConfig.serverUrl}/api/user-faces/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.body};
      } else {
        return {
          'success': false,
          'message': 'Failed to get user images: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting user images: ${e.toString()}',
      };
    }
  }

  // Clear all face images for a user (use when starting new registration)
  static Future<Map<String, dynamic>> clearUserFaceImages(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ServerConfig.serverUrl}/api/user-faces/$userId/clear'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Face images cleared successfully'};
      } else {
        return {
          'success': false,
          'message': 'Failed to clear face images: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error clearing face images: ${e.toString()}',
      };
    }
  }

  // Complete face registration with all captured angles
  static Future<Map<String, dynamic>> completeFaceRegistration({
    required String userId,
    required Map<String, dynamic> registrationData,
  }) async {
    try {
      final response = await _dio.post(
        '${ServerConfig.serverUrl}/api/complete-face-registration',
        data: {'userId': userId, 'registrationData': registrationData},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Registration completed successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to complete registration: ${response.statusCode}',
        };
      }
    } catch (e) {
      // 
      return {
        'success': false,
        'message': 'Error completing registration: ${e.toString()}',
      };
    }
  }
}
