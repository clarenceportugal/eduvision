import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://eduvision-dura.onrender.com/api';
  static const Duration timeout = Duration(seconds: 15);

  // Generic request method
  static Future<Map<String, dynamic>> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final defaultHeaders = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      final requestHeaders = {...defaultHeaders, ...?headers};
      
      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: requestHeaders).timeout(timeout);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: requestHeaders).timeout(timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // 
      // 

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // 
      rethrow;
    }
  }

  // Generic list request method
  static Future<List<dynamic>> _makeListRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final defaultHeaders = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      final requestHeaders = {...defaultHeaders, ...?headers};
      
      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: requestHeaders).timeout(timeout);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: requestHeaders).timeout(timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // 
      // 

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // 
      rethrow;
    }
  }

  // Dean API methods
  static Future<Map<String, dynamic>> getDeanDashboardData(String collegeName) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '/dean/dashboard?collegeName=$collegeName',
    );
  }

  static Future<int> getDeanInstructorCount(String collegeName) async {
    try {
      final response = await _makeRequest(
        method: 'GET',
        endpoint: '/api/auth/dean/instructor-count?collegeName=$collegeName',
      );
      return response['count'] ?? 0;
    } catch (e) {
      // 
      return 0;
    }
  }

  static Future<List<dynamic>> getDeanSchedules(String collegeName, String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/api/auth/dean/schedules/today?collegeName=$collegeName&courseName=${courseName.isEmpty ? 'ALL' : courseName}',
    );
  }

  static Future<List<dynamic>> getDeanColleges() async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/dean/colleges',
    );
  }

  static Future<List<dynamic>> getDeanRooms(String collegeName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/dean/rooms/college?CollegeName=$collegeName',
    );
  }

  static Future<List<dynamic>> getDeanFacultyLogs(String collegeName, String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/dean/logs/faculties/today?collegeName=$collegeName&courseName=$courseName',
    );
  }

  static Future<Map<String, dynamic>> updateDeanProfile(Map<String, dynamic> profileData) async {
    return await _makeRequest(
      method: 'PUT',
      endpoint: '/dean/profile',
      body: profileData,
    );
  }

  static Future<List<dynamic>> getDeanFacultyList(String collegeName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/dean/faculty-list?collegeName=$collegeName',
    );
  }

  static Future<List<dynamic>> getDeanFacultyReports(String collegeName, String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/dean/faculty-reports?collegeName=$collegeName&courseName=$courseName',
    );
  }

  static Future<Uint8List> downloadDeanFacultyReport(String collegeName, String courseName) async {
    final response = await http.get(
      Uri.parse('$baseUrl/dean/faculty-reports/download?collegeName=$collegeName&courseName=$courseName'),
      headers: {'Accept': 'application/octet-stream'},
    ).timeout(timeout);
    
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download report: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getDeanLiveStatus(String collegeName) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '/dean/live-status?collegeName=$collegeName',
    );
  }

  static Future<Map<String, dynamic>> startDeanLiveStream(String collegeName) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/dean/live-stream/start',
      body: {'collegeName': collegeName},
    );
  }

  static Future<Map<String, dynamic>> stopDeanLiveStream(String collegeName) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/dean/live-stream/stop',
      body: {'collegeName': collegeName},
    );
  }

  // Program Chair API methods
  static Future<Map<String, dynamic>> getProgramChairDashboardData(String courseName) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '/programchairperson/dashboard?courseName=$courseName',
    );
  }

  static Future<List<dynamic>> getProgramChairSchedules(String courseName) async {
    return await _makeListRequest(
      method: 'POST',
      endpoint: '/programchairperson/schedules/today',
      body: {'courseName': courseName},
    );
  }

  static Future<List<dynamic>> getProgramChairFacultyList(String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/programchairperson/faculty-list?courseName=$courseName',
    );
  }

  static Future<List<dynamic>> getProgramChairPendingFaculty(String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/programchairperson/pending-faculty?courseName=$courseName',
    );
  }

  static Future<Map<String, dynamic>> acceptFaculty(String facultyId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/programchairperson/faculty/accept',
      body: {'facultyId': facultyId},
    );
  }

  static Future<Map<String, dynamic>> rejectFaculty(String facultyId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/programchairperson/faculty/reject',
      body: {'facultyId': facultyId},
    );
  }

  static Future<List<dynamic>> getProgramChairFacultyReports(String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/programchairperson/faculty-reports?courseName=$courseName',
    );
  }

  static Future<Uint8List> downloadProgramChairFacultyReport(String courseName) async {
    final response = await http.get(
      Uri.parse('$baseUrl/programchairperson/faculty-reports/download?courseName=$courseName'),
      headers: {'Accept': 'application/octet-stream'},
    ).timeout(timeout);
    
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download report: ${response.statusCode}');
    }
  }

  // Superadmin API methods
  static Future<Map<String, dynamic>> getSuperadminUserCounts() async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '/superadmin/user-counts',
    );
  }

  static Future<List<dynamic>> getSuperadminColleges() async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/superadmin/colleges',
    );
  }

  static Future<List<dynamic>> getSuperadminRooms(String collegeName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/superadmin/all-rooms/college?CollegeName=$collegeName',
    );
  }

  static Future<List<dynamic>> getSuperadminSchedules(String courseName) async {
    return await _makeListRequest(
      method: 'POST',
      endpoint: '/superadmin/all-schedules/today',
      body: {'shortCourseValue': courseName},
    );
  }

  static Future<List<dynamic>> getSuperadminFacultyLogs(String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/superadmin/logs/all-faculties/today?courseName=$courseName',
    );
  }

  static Future<List<dynamic>> getSuperadminCourses(String collegeCode) async {
    return await _makeListRequest(
      method: 'POST',
      endpoint: '/superadmin/selected-college',
      body: {'collegeCode': collegeCode},
    );
  }

  static Future<List<dynamic>> getSuperadminDeans() async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/superadmin/deans',
    );
  }

  static Future<List<dynamic>> getSuperadminInstructors() async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/superadmin/instructors',
    );
  }

  static Future<List<dynamic>> getSuperadminProgramChairs() async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/superadmin/program-chairs',
    );
  }

  static Future<List<dynamic>> getSuperadminPendingDeans() async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/superadmin/pending-deans',
    );
  }

  static Future<List<dynamic>> getSuperadminPendingInstructors() async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/superadmin/pending-instructors',
    );
  }

  static Future<List<dynamic>> getSuperadminPendingProgramChairs() async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/superadmin/pending-program-chairs',
    );
  }

  static Future<Map<String, dynamic>> acceptDean(String deanId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/superadmin/dean/accept',
      body: {'deanId': deanId},
    );
  }

  static Future<Map<String, dynamic>> rejectDean(String deanId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/superadmin/dean/reject',
      body: {'deanId': deanId},
    );
  }

  static Future<Map<String, dynamic>> acceptInstructor(String instructorId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/superadmin/instructor/accept',
      body: {'instructorId': instructorId},
    );
  }

  static Future<Map<String, dynamic>> rejectInstructor(String instructorId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/superadmin/instructor/reject',
      body: {'instructorId': instructorId},
    );
  }

  static Future<Map<String, dynamic>> acceptProgramChair(String programChairId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/superadmin/program-chair/accept',
      body: {'programChairId': programChairId},
    );
  }

  static Future<Map<String, dynamic>> rejectProgramChair(String programChairId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/superadmin/program-chair/reject',
      body: {'programChairId': programChairId},
    );
  }

  // Additional Program Chair API methods
  static Future<List<dynamic>> getDeanCourses(String collegeName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/dean/courses?collegeName=$collegeName',
    );
  }

  static Future<int> getProgramChairInstructorCount(String courseName) async {
    final response = await _makeRequest(
      method: 'GET',
      endpoint: '/programchairperson/instructor-count?courseName=$courseName',
    );
    return response['count'] ?? 0;
  }

  static Future<int> getProgramChairSchedulesCount(String courseName) async {
    final response = await _makeRequest(
      method: 'GET',
      endpoint: '/programchairperson/schedules-count?courseName=$courseName',
    );
    return response['count'] ?? 0;
  }

  static Future<List<dynamic>> getProgramChairFacultyLogs(String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/programchairperson/faculty-logs?courseName=$courseName',
    );
  }

  static Future<List<dynamic>> getProgramChairFaculty(String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/programchairperson/faculty?courseName=$courseName',
    );
  }

  static Future<List<dynamic>> getProgramChairDailyReport(String courseName) async {
    return await _makeListRequest(
      method: 'GET',
      endpoint: '/programchairperson/daily-report?courseName=$courseName',
    );
  }

  static Future<Uint8List> generateProgramChairReport(String courseName) async {
    final response = await http.get(
      Uri.parse('$baseUrl/programchairperson/generate-report?courseName=$courseName'),
      headers: {'Accept': 'application/octet-stream'},
    ).timeout(timeout);
    
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to generate report: ${response.statusCode}');
    }
  }

  // Utility methods
  static void logApiCall(String endpoint, dynamic response) {
    // 
    // 
  }

  static void handleApiResponse(
    dynamic response,
    Function(dynamic) onSuccess,
    Function(String) onError,
  ) {
    try {
      if (response is Map<String, dynamic>) {
        if (response['success'] == true || response['status'] == 'success') {
          onSuccess(response['data'] ?? response);
        } else {
          onError(response['message'] ?? 'Unknown error occurred');
        }
      } else if (response is List) {
        onSuccess(response);
      } else {
        onSuccess(response);
      }
    } catch (e) {
      onError('Failed to process API response: $e');
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'displayName': prefs.getString('displayName') ?? '',
      'role': prefs.getString('role') ?? '',
      'college': prefs.getString('college') ?? '',
      'course': prefs.getString('course') ?? '',
    };
  }
}
