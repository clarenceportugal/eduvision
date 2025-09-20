import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DataCacheService {
  static const String _cachePrefix = 'data_cache_';
  static const Duration _defaultCacheDuration = Duration(minutes: 5);

  /// Cache data with expiration
  static Future<void> cacheData(
    String key,
    dynamic data, {
    Duration? duration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '${cacheKey}_timestamp';
      
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'duration': (duration ?? _defaultCacheDuration).inMilliseconds,
      };
      
      await prefs.setString(cacheKey, jsonEncode(cacheData));
      await prefs.setString(timestampKey, DateTime.now().millisecondsSinceEpoch.toString());
      
      if (kDebugMode) {
        print('Data cached for key: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error caching data: $e');
      }
    }
  }

  /// Get cached data if not expired
  static Future<T?> getCachedData<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '${cacheKey}_timestamp';
      
      final cachedString = prefs.getString(cacheKey);
      final timestampString = prefs.getString(timestampKey);
      
      if (cachedString == null || timestampString == null) {
        return null;
      }
      
      final cacheData = jsonDecode(cachedString);
      final timestamp = int.parse(timestampString);
      final duration = cacheData['duration'] as int;
      
      // Check if cache is expired
      if (DateTime.now().millisecondsSinceEpoch - timestamp > duration) {
        await _clearCacheKey(key);
        return null;
      }
      
      if (kDebugMode) {
        print('Data retrieved from cache for key: $key');
      }
      
      return cacheData['data'] as T?;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cached data: $e');
      }
      return null;
    }
  }

  /// Check if data exists in cache and is not expired
  static Future<bool> hasValidCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '${cacheKey}_timestamp';
      
      final cachedString = prefs.getString(cacheKey);
      final timestampString = prefs.getString(timestampKey);
      
      if (cachedString == null || timestampString == null) {
        return false;
      }
      
      final cacheData = jsonDecode(cachedString);
      final timestamp = int.parse(timestampString);
      final duration = cacheData['duration'] as int;
      
      return DateTime.now().millisecondsSinceEpoch - timestamp <= duration;
    } catch (e) {
      return false;
    }
  }

  /// Clear specific cache entry
  static Future<void> _clearCacheKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '${cacheKey}_timestamp';
      
      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cache key: $e');
      }
    }
  }

  /// Clear all cached data
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          await prefs.remove(key);
        }
      }
      
      if (kDebugMode) {
        print('All cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing all cache: $e');
      }
    }
  }

  /// Clear expired cache entries
  static Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final keysToRemove = <String>[];
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) && !key.endsWith('_timestamp')) {
          final timestampKey = '${key}_timestamp';
          final timestampString = prefs.getString(timestampKey);
          
          if (timestampString != null) {
            final timestamp = int.parse(timestampString);
            final cachedString = prefs.getString(key);
            
            if (cachedString != null) {
              final cacheData = jsonDecode(cachedString);
              final duration = cacheData['duration'] as int;
              
              if (DateTime.now().millisecondsSinceEpoch - timestamp > duration) {
                keysToRemove.add(key);
                keysToRemove.add(timestampKey);
              }
            }
          }
        }
      }
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      if (kDebugMode && keysToRemove.isNotEmpty) {
        print('Cleared ${keysToRemove.length} expired cache entries');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing expired cache: $e');
      }
    }
  }

  /// Cache keys for different data types
  static const String userCounts = 'user_counts';
  static const String colleges = 'colleges';
  static const String rooms = 'rooms';
  static const String schedules = 'schedules';
  static const String facultyLogs = 'faculty_logs';
  static const String deans = 'deans';
  static const String instructors = 'instructors';
  static const String programChairs = 'program_chairs';
  static const String allUsers = 'all_users';
  static const String pendingDeans = 'pending_deans';
  static const String pendingInstructors = 'pending_instructors';
  static const String pendingProgramChairs = 'pending_program_chairs';
  static const String courses = 'courses';
  static const String liveStatus = 'live_status';

  /// Cache durations for different data types
  static const Duration userCountsDuration = Duration(minutes: 10);
  static const Duration collegesDuration = Duration(hours: 2);
  static const Duration roomsDuration = Duration(minutes: 30);
  static const Duration schedulesDuration = Duration(minutes: 5);
  static const Duration facultyLogsDuration = Duration(minutes: 2);
  static const Duration deansDuration = Duration(hours: 1);
  static const Duration instructorsDuration = Duration(hours: 1);
  static const Duration programChairsDuration = Duration(hours: 1);
  static const Duration allUsersDuration = Duration(minutes: 15);
  static const Duration pendingDeansDuration = Duration(minutes: 5);
  static const Duration pendingInstructorsDuration = Duration(minutes: 5);
  static const Duration pendingProgramChairsDuration = Duration(minutes: 5);
  static const Duration coursesDuration = Duration(hours: 1);
  static const Duration liveStatusDuration = Duration(seconds: 30);
}
