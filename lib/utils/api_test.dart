import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiTest {
  static Future<Map<String, dynamic>> testAllConnections(String courseName) async {
    final results = <String, dynamic>{};
    
    try {
      // Test 1: Schedules API
      print('Testing Schedules API...');
      final shortCourseName = courseName.replaceAll(RegExp(r'^bs', caseSensitive: false), '').toUpperCase();
      final schedulesResponse = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/all-schedules/today'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'shortCourseName': shortCourseName}),
      ).timeout(const Duration(seconds: 10));
      
      results['schedules'] = {
        'status': schedulesResponse.statusCode,
        'success': schedulesResponse.statusCode == 200,
        'data': schedulesResponse.statusCode == 200 ? jsonDecode(schedulesResponse.body) : null,
      };
      
      // Test 2: Instructor Count API
      print('Testing Instructor Count API...');
      final instructorCountResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/count/instructors?course=$courseName'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['instructorCount'] = {
        'status': instructorCountResponse.statusCode,
        'success': instructorCountResponse.statusCode == 200,
        'data': instructorCountResponse.statusCode == 200 ? jsonDecode(instructorCountResponse.body) : null,
      };
      
      // Test 3: Schedules Count Today API
      print('Testing Schedules Count Today API...');
      final schedulesCountResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/schedules-count/today?course=$courseName'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['schedulesCount'] = {
        'status': schedulesCountResponse.statusCode,
        'success': schedulesCountResponse.statusCode == 200,
        'data': schedulesCountResponse.statusCode == 200 ? jsonDecode(schedulesCountResponse.body) : null,
      };
      
      // Test 4: Faculty Logs API
      print('Testing Faculty Logs API...');
      final facultyLogsResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/logs/all-faculties/today?courseName=$courseName'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['facultyLogs'] = {
        'status': facultyLogsResponse.statusCode,
        'success': facultyLogsResponse.statusCode == 200,
        'data': facultyLogsResponse.statusCode == 200 ? jsonDecode(facultyLogsResponse.body) : null,
      };
      
      // Test 5: Faculty List API
      print('Testing Faculty List API...');
      final facultyListResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/faculty?course=$courseName'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['facultyList'] = {
        'status': facultyListResponse.statusCode,
        'success': facultyListResponse.statusCode == 200,
        'data': facultyListResponse.statusCode == 200 ? jsonDecode(facultyListResponse.body) : null,
      };
      
      // Test 6: Pending Faculty API
      print('Testing Pending Faculty API...');
      final pendingFacultyResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/initial-faculty?courseName=$courseName'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['pendingFaculty'] = {
        'status': pendingFacultyResponse.statusCode,
        'success': pendingFacultyResponse.statusCode == 200,
        'data': pendingFacultyResponse.statusCode == 200 ? jsonDecode(pendingFacultyResponse.body) : null,
      };
      
      // Test 7: Daily Report API
      print('Testing Daily Report API...');
      final dailyReportResponse = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/show-daily-report'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'CourseName': courseName}),
      ).timeout(const Duration(seconds: 10));
      
      results['dailyReport'] = {
        'status': dailyReportResponse.statusCode,
        'success': dailyReportResponse.statusCode == 200,
        'data': dailyReportResponse.statusCode == 200 ? jsonDecode(dailyReportResponse.body) : null,
      };
      
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
  }

  static Future<Map<String, dynamic>> testSuperadminConnections(String collegeName) async {
    final results = <String, dynamic>{};
    
    try {
      // Test 1: User Counts API
      print('Testing User Counts API...');
      final userCountsResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/user-counts'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['userCounts'] = {
        'status': userCountsResponse.statusCode,
        'success': userCountsResponse.statusCode == 200,
        'data': userCountsResponse.statusCode == 200 ? jsonDecode(userCountsResponse.body) : null,
      };
      
      // Test 2: Colleges API
      print('Testing Colleges API...');
      final collegesResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/colleges'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['colleges'] = {
        'status': collegesResponse.statusCode,
        'success': collegesResponse.statusCode == 200,
        'data': collegesResponse.statusCode == 200 ? jsonDecode(collegesResponse.body) : null,
      };
      
      // Test 3: Rooms API
      print('Testing Rooms API...');
      final roomsResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/all-rooms/college?CollegeName=$collegeName'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['rooms'] = {
        'status': roomsResponse.statusCode,
        'success': roomsResponse.statusCode == 200,
        'data': roomsResponse.statusCode == 200 ? jsonDecode(roomsResponse.body) : null,
      };
      
      // Test 4: Schedules API
      print('Testing Schedules API...');
      final schedulesResponse = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/all-schedules/today'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'shortCourseValue': 'ALL'}),
      ).timeout(const Duration(seconds: 10));
      
      results['schedules'] = {
        'status': schedulesResponse.statusCode,
        'success': schedulesResponse.statusCode == 200,
        'data': schedulesResponse.statusCode == 200 ? jsonDecode(schedulesResponse.body) : null,
      };
      
      // Test 5: Faculty Logs API
      print('Testing Faculty Logs API...');
      final facultyLogsResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/logs/all-faculties/today?courseName=ALL'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['facultyLogs'] = {
        'status': facultyLogsResponse.statusCode,
        'success': facultyLogsResponse.statusCode == 200,
        'data': facultyLogsResponse.statusCode == 200 ? jsonDecode(facultyLogsResponse.body) : null,
      };
      
      // Test 6: Dean List API
      print('Testing Dean List API...');
      final deanListResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/dean'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['deanList'] = {
        'status': deanListResponse.statusCode,
        'success': deanListResponse.statusCode == 200,
        'data': deanListResponse.statusCode == 200 ? jsonDecode(deanListResponse.body) : null,
      };
      
      // Test 7: Instructor List API
      print('Testing Instructor List API...');
      final instructorListResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/instructorinfo-only'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['instructorList'] = {
        'status': instructorListResponse.statusCode,
        'success': instructorListResponse.statusCode == 200,
        'data': instructorListResponse.statusCode == 200 ? jsonDecode(instructorListResponse.body) : null,
      };
      
      // Test 8: Program Chair List API
      print('Testing Program Chair List API...');
      final programChairListResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/programchairinfo-only'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['programChairList'] = {
        'status': programChairListResponse.statusCode,
        'success': programChairListResponse.statusCode == 200,
        'data': programChairListResponse.statusCode == 200 ? jsonDecode(programChairListResponse.body) : null,
      };
      
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
  }
  
  static void printTestResults(Map<String, dynamic> results) {
    print('\n=== API CONNECTION TEST RESULTS ===');
    
    results.forEach((key, value) {
      if (key == 'error') {
        print('❌ ERROR: $value');
        return;
      }
      
      final status = value['status'] as int;
      final success = value['success'] as bool;
      final data = value['data'];
      
      if (success) {
        print('✅ $key: SUCCESS (Status: $status)');
        if (data is List) {
          print('   Data count: ${data.length}');
        } else if (data is Map) {
          print('   Data keys: ${data.keys.toList()}');
        }
      } else {
        print('❌ $key: FAILED (Status: $status)');
      }
    });
    
    print('=====================================\n');
  }
}
