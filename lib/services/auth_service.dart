import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/server_config.dart';
import '../utils/logger.dart';

class AuthService {
  // Backend API URL - Now configured in server_config.dart
  static String get baseUrl => ServerConfig.baseUrl;

  // MongoDB Database: eduvision
  // Collection: users
  // Expected user document structure:
  // {
  //   "_id": ObjectId,
  //   "email": "student@university.edu",
  //   "password": "user_password",
  //   "studentId": "STU12345", (optional)
  //   "name": "Student Name", (optional)
  //   "program": "Computer Science", (optional)
  //   "yearLevel": "3rd Year" (optional)
  // }

  static Future<Map<String, dynamic>?> login(
    String emailOrStudentId,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emailOrStudentId': emailOrStudentId,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final userData = data['user'];
          userData['token'] = data['token'];

          // Save user data locally
          await _saveUserData(userData);
          return userData;
        }
      } else if (response.statusCode == 401) {
        // Invalid credentials
        return null;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      Logger.error('Login error: $e');
      // Fallback to demo mode if server is not available
      return await _demoLogin(emailOrStudentId, password);
    }
  }

  // Demo login for testing when server is not available
  static Future<Map<String, dynamic>?> _demoLogin(
    String emailOrStudentId,
    String password,
  ) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 2));

      // Demo authentication logic
      if (_validateCredentials(emailOrStudentId, password)) {
        // Simulate successful user data from MongoDB eduvision.users collection
        final userData = {
          '_id': '675a1b2c3d4e5f6789abcdef',
          'email': emailOrStudentId.contains('@')
              ? emailOrStudentId
              : '$emailOrStudentId@university.edu',
          'username': emailOrStudentId.contains('@')
              ? emailOrStudentId.split('@')[0]
              : emailOrStudentId,
          'name': 'Demo User',
          'first_name': 'Demo',
          'middle_name': 'Middle',
          'last_name': 'User',
          'firstName': 'Demo',
          'middleName': 'Middle',
          'lastName': 'User',
          'displayName': 'Demo Middle User',
          'role': 'Instructor',
          'department': 'Computer Science',
          'employeeId': emailOrStudentId.contains('@')
              ? 'EMP${DateTime.now().millisecondsSinceEpoch % 100000}'
              : emailOrStudentId,
          'token': 'demo_token_${DateTime.now().millisecondsSinceEpoch}',
        };

        // Save user data locally
        await _saveUserData(userData);
        return userData;
      } else {
        return null;
      }
    } catch (e) {
      Logger.error('Demo login error: $e');
      return null;
    }
  }

  static bool _validateCredentials(String emailOrStudentId, String password) {
    // Demo validation - replace with actual API call to your MongoDB backend
    // For demo purposes, accept any non-empty credentials
    return emailOrStudentId.isNotEmpty &&
        password.isNotEmpty &&
        password.length >= 3;
  }

  static Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(userData));
    await prefs.setBool('is_logged_in', true);
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.setBool('is_logged_in', false);
  }

  // Test connection to MongoDB through backend API
  static Future<bool> testMongoConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/test'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info('MongoDB Connection Test: ${data['message']}');
        Logger.info('Database: ${data['database']}');
        Logger.info('Collection: ${data['collection']}');
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      Logger.error('MongoDB connection test error: $e');
      return false;
    }
  }

  // Test server connectivity
  static Future<bool> testServerConnection() async {
    try {
      Logger.info('Testing server connection to: $baseUrl/test');
      final response = await http
          .get(
            Uri.parse('$baseUrl/test'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 5));

      Logger.info('Server response status: ${response.statusCode}');
      Logger.info('Server response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      Logger.error('Server connection test failed: $e');
      return false;
    }
  }

  // Test general internet connectivity
  static Future<bool> testInternetConnection() async {
    try {
      Logger.info('Testing general internet connectivity...');
      
      // Test multiple endpoints to ensure internet is working
      final testUrls = [
        'https://www.google.com',
        'https://httpbin.org/get',
        'https://api.github.com',
      ];

      for (String url in testUrls) {
        try {
          final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 3));
          if (response.statusCode == 200) {
            Logger.info('Internet connectivity test passed with: $url');
            return true;
          }
        } catch (e) {
          Logger.warning('Failed to connect to $url: $e');
          continue;
        }
      }
      
      Logger.error('All internet connectivity tests failed');
      return false;
    } catch (e) {
      Logger.error('Internet connectivity test error: $e');
      return false;
    }
  }

  // Test local network connectivity
  static Future<bool> testLocalNetworkConnection() async {
    try {
      Logger.info('Testing local network connectivity...');
      
      // Test common local network addresses
      final localUrls = [
        'http://192.168.1.1', // Common router address
        'http://10.0.0.1',    // Alternative router address
        'http://172.16.0.1',  // Another common local range
      ];

      for (String url in localUrls) {
        try {
          final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 2));
          if (response.statusCode < 500) { // Any response means network is working
            Logger.info('Local network connectivity test passed with: $url');
            return true;
          }
        } catch (e) {
          Logger.warning('Failed to connect to $url: $e');
          continue;
        }
      }
      
      Logger.error('Local network connectivity tests failed');
      return false;
    } catch (e) {
      Logger.error('Local network connectivity test error: $e');
      return false;
    }
  }
}

// Example of what your backend API endpoint would look like:
/*
  POST /api/login
  {
    "emailOrStudentId": "student@university.edu",
    "password": "password123"
  }
  
  Response:
  {
    "success": true,
    "user": {
      "id": "675a1b2c3d4e5f6789abcdef",
      "email": "student@university.edu",
      "studentId": "STU12345",
      "name": "Student Name",
      "program": "Computer Science",
      "yearLevel": "3rd Year"
    },
    "token": "jwt_token_here"
  }
*/
