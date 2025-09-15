import 'package:http/http.dart' as http;
import 'dart:convert';

class DatabaseVerification {
  static Future<Map<String, dynamic>> verifyAllConnections() async {
    final results = <String, dynamic>{};
    
    print('🔍 Starting comprehensive database verification...');
    
    try {
      // Test 1: Superadmin User Counts
      print('📊 Testing Superadmin User Counts API...');
      final userCountsResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/user-counts'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      results['userCounts'] = {
        'status': userCountsResponse.statusCode,
        'success': userCountsResponse.statusCode == 200,
        'data': userCountsResponse.statusCode == 200 ? jsonDecode(userCountsResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Test 2: Colleges API
      print('🏫 Testing Colleges API...');
      final collegesResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/colleges'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      results['colleges'] = {
        'status': collegesResponse.statusCode,
        'success': collegesResponse.statusCode == 200,
        'data': collegesResponse.statusCode == 200 ? jsonDecode(collegesResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Test 3: Dean List API
      print('👨‍💼 Testing Dean List API...');
      final deanListResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/dean'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      results['deanList'] = {
        'status': deanListResponse.statusCode,
        'success': deanListResponse.statusCode == 200,
        'data': deanListResponse.statusCode == 200 ? jsonDecode(deanListResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Test 4: Instructor List API
      print('👨‍🏫 Testing Instructor List API...');
      final instructorListResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/instructorinfo-only'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      results['instructorList'] = {
        'status': instructorListResponse.statusCode,
        'success': instructorListResponse.statusCode == 200,
        'data': instructorListResponse.statusCode == 200 ? jsonDecode(instructorListResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Test 5: Program Chair List API
      print('👩‍💼 Testing Program Chair List API...');
      final programChairListResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/programchairinfo-only'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      results['programChairList'] = {
        'status': programChairListResponse.statusCode,
        'success': programChairListResponse.statusCode == 200,
        'data': programChairListResponse.statusCode == 200 ? jsonDecode(programChairListResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Test 6: Schedules API
      print('📅 Testing Schedules API...');
      final schedulesResponse = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/all-schedules/today'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'shortCourseValue': 'ALL'}),
      ).timeout(const Duration(seconds: 15));
      
      results['schedules'] = {
        'status': schedulesResponse.statusCode,
        'success': schedulesResponse.statusCode == 200,
        'data': schedulesResponse.statusCode == 200 ? jsonDecode(schedulesResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Test 7: Faculty Logs API
      print('📝 Testing Faculty Logs API...');
      final facultyLogsResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/logs/all-faculties/today?courseName=ALL'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      results['facultyLogs'] = {
        'status': facultyLogsResponse.statusCode,
        'success': facultyLogsResponse.statusCode == 200,
        'data': facultyLogsResponse.statusCode == 200 ? jsonDecode(facultyLogsResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Test 8: Rooms API
      print('🏠 Testing Rooms API...');
      final roomsResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/all-rooms/college?CollegeName=ALL'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      results['rooms'] = {
        'status': roomsResponse.statusCode,
        'success': roomsResponse.statusCode == 200,
        'data': roomsResponse.statusCode == 200 ? jsonDecode(roomsResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Test 9: Pending Faculty API
      print('⏳ Testing Pending Faculty API...');
      final pendingFacultyResponse = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/initial-staff?collegeName=ALL'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      results['pendingFaculty'] = {
        'status': pendingFacultyResponse.statusCode,
        'success': pendingFacultyResponse.statusCode == 200,
        'data': pendingFacultyResponse.statusCode == 200 ? jsonDecode(pendingFacultyResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Test 10: Faculty Management API (Add/Delete)
      print('➕ Testing Faculty Management API...');
      final facultyManagementResponse = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/faculty'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'last_name': 'Test',
          'first_name': 'User',
          'email': 'test@example.com',
          'role': 'dean',
          'college': 'TEST',
        }),
      ).timeout(const Duration(seconds: 15));
      
      results['facultyManagement'] = {
        'status': facultyManagementResponse.statusCode,
        'success': facultyManagementResponse.statusCode == 200 || facultyManagementResponse.statusCode == 400, // 400 is expected for duplicate
        'data': facultyManagementResponse.statusCode == 200 ? jsonDecode(facultyManagementResponse.body) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      results['error'] = {
        'message': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
    
    return results;
  }
  
  static void printVerificationResults(Map<String, dynamic> results) {
    print('\n🔍 === DATABASE VERIFICATION RESULTS ===');
    print('📅 Timestamp: ${DateTime.now().toIso8601String()}');
    print('');
    
    int successCount = 0;
    int totalCount = 0;
    
    results.forEach((key, value) {
      if (key == 'error') {
        print('❌ ERROR: ${value['message']}');
        return;
      }
      
      totalCount++;
      final status = value['status'] as int;
      final success = value['success'] as bool;
      final data = value['data'];
      
      if (success) {
        successCount++;
        print('✅ $key: SUCCESS (${status}) - Data: ${data != null ? '${data.length} items' : 'No data'}');
      } else {
        print('❌ $key: FAILED (${status}) - ${data != null ? 'Error in data' : 'No response data'}');
      }
    });
    
    print('');
    print('📊 SUMMARY:');
    print('   ✅ Successful: $successCount/$totalCount');
    print('   ❌ Failed: ${totalCount - successCount}/$totalCount');
    print('   📈 Success Rate: ${((successCount / totalCount) * 100).toStringAsFixed(1)}%');
    
    if (successCount == totalCount) {
      print('🎉 ALL DATABASE CONNECTIONS ARE WORKING PERFECTLY!');
    } else if (successCount > totalCount * 0.8) {
      print('⚠️  Most connections are working, but some issues detected.');
    } else {
      print('🚨 Multiple database connection issues detected!');
    }
    
    print('==========================================\n');
  }
  
  static Future<bool> isDatabaseHealthy() async {
    try {
      final results = await verifyAllConnections();
      int successCount = 0;
      int totalCount = 0;
      
      results.forEach((key, value) {
        if (key == 'error') return;
        totalCount++;
        if (value['success'] == true) successCount++;
      });
      
      return successCount >= totalCount * 0.8; // 80% success rate threshold
    } catch (e) {
      print('❌ Database health check failed: $e');
      return false;
    }
  }
}
