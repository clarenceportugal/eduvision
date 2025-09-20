import 'dart:async';
import 'data_cache_service.dart';
import 'api_service.dart';
import '../utils/performance_monitor.dart';

class OptimizedApiService {
  static const Duration timeout = Duration(seconds: 10);
  static final Map<String, Completer> _pendingRequests = {};

  /// Get data with caching and request deduplication
  static Future<T> getCachedData<T>(
    String cacheKey,
    Future<T> Function() fetchFunction, {
    Duration? cacheDuration,
    int maxRetries = 2,
  }) async {
    return await PerformanceApiCall.trackApiCall(
      'getCachedData_$cacheKey',
      () async {
        // Check if we have valid cached data
        final cachedData = await DataCacheService.getCachedData<T>(cacheKey);
        if (cachedData != null) {
          return cachedData;
        }

        // Check if there's already a pending request for this key
        if (_pendingRequests.containsKey(cacheKey)) {
          return await _pendingRequests[cacheKey]!.future as T;
        }

        // Create a new completer for this request
        final completer = Completer<T>();
        _pendingRequests[cacheKey] = completer;

        try {
          // Fetch fresh data with retry logic
          T data = await _fetchWithRetry(fetchFunction, maxRetries);
          
          // Cache the data
          await DataCacheService.cacheData(
            cacheKey,
            data,
            duration: cacheDuration,
          );
          
          completer.complete(data);
          return data;
        } catch (e) {
          completer.completeError(e);
          rethrow;
        } finally {
          _pendingRequests.remove(cacheKey);
        }
      },
    );
  }

  /// Fetch data with retry logic
  static Future<T> _fetchWithRetry<T>(
    Future<T> Function() fetchFunction,
    int maxRetries,
  ) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts <= maxRetries) {
      try {
        return await fetchFunction();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        attempts++;
        
        if (attempts <= maxRetries) {
          // Wait before retrying (exponential backoff)
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
    }

    throw lastException ?? Exception('Failed to fetch data after $maxRetries retries');
  }

  /// Load multiple data sources in parallel
  static Future<Map<String, dynamic>> loadDashboardData({
    required String collegeName,
    required String courseName,
  }) async {
    final futures = <String, Future>{
      'userCounts': getCachedData(
        DataCacheService.userCounts,
        () => ApiService.getSuperadminUserCounts(),
        cacheDuration: DataCacheService.userCountsDuration,
      ),
      'colleges': getCachedData(
        DataCacheService.colleges,
        () => ApiService.getSuperadminColleges(),
        cacheDuration: DataCacheService.collegesDuration,
      ),
      'rooms': getCachedData(
        '${DataCacheService.rooms}_$collegeName',
        () => ApiService.getSuperadminRooms(collegeName),
        cacheDuration: DataCacheService.roomsDuration,
      ),
      'schedules': getCachedData(
        '${DataCacheService.schedules}_$courseName',
        () => ApiService.getSuperadminSchedules(courseName),
        cacheDuration: DataCacheService.schedulesDuration,
      ),
      'facultyLogs': getCachedData(
        '${DataCacheService.facultyLogs}_$courseName',
        () => ApiService.getSuperadminFacultyLogs(courseName),
        cacheDuration: DataCacheService.facultyLogsDuration,
      ),
    };

    final results = <String, dynamic>{};
    final errors = <String, String>{};

    // Execute all requests in parallel
    await Future.wait(
      futures.entries.map((entry) async {
        try {
          results[entry.key] = await entry.value;
        } catch (e) {
          errors[entry.key] = e.toString();
          // Provide fallback data for non-critical endpoints
          if (entry.key == 'rooms') {
            results[entry.key] = [];
          } else if (entry.key == 'schedules') {
            results[entry.key] = [];
          } else if (entry.key == 'facultyLogs') {
            results[entry.key] = [];
          }
        }
      }),
    );

    return {
      'data': results,
      'errors': errors,
    };
  }

  /// Load user management data in parallel
  static Future<Map<String, dynamic>> loadUserManagementData() async {
    final futures = <String, Future>{
      'deans': getCachedData(
        DataCacheService.deans,
        () => ApiService.getSuperadminDeans(),
        cacheDuration: DataCacheService.deansDuration,
      ),
      'instructors': getCachedData(
        DataCacheService.instructors,
        () => ApiService.getSuperadminInstructors(),
        cacheDuration: DataCacheService.instructorsDuration,
      ),
      'programChairs': getCachedData(
        DataCacheService.programChairs,
        () => ApiService.getSuperadminProgramChairs(),
        cacheDuration: DataCacheService.programChairsDuration,
      ),
      'allUsers': getCachedData(
        DataCacheService.allUsers,
        () => ApiService.getAllUsers(),
        cacheDuration: DataCacheService.allUsersDuration,
      ),
    };

    final results = <String, dynamic>{};
    final errors = <String, String>{};

    await Future.wait(
      futures.entries.map((entry) async {
        try {
          results[entry.key] = await entry.value;
        } catch (e) {
          errors[entry.key] = e.toString();
        }
      }),
    );

    return {
      'data': results,
      'errors': errors,
    };
  }

  /// Load pending approvals data in parallel
  static Future<Map<String, dynamic>> loadPendingApprovalsData() async {
    final futures = <String, Future>{
      'pendingDeans': getCachedData(
        DataCacheService.pendingDeans,
        () => ApiService.getSuperadminPendingDeans(),
        cacheDuration: DataCacheService.pendingDeansDuration,
      ),
      'pendingInstructors': getCachedData(
        DataCacheService.pendingInstructors,
        () => ApiService.getSuperadminPendingInstructors(),
        cacheDuration: DataCacheService.pendingInstructorsDuration,
      ),
      'pendingProgramChairs': getCachedData(
        DataCacheService.pendingProgramChairs,
        () => ApiService.getSuperadminPendingProgramChairs(),
        cacheDuration: DataCacheService.pendingProgramChairsDuration,
      ),
    };

    final results = <String, dynamic>{};
    final errors = <String, String>{};

    await Future.wait(
      futures.entries.map((entry) async {
        try {
          results[entry.key] = await entry.value;
        } catch (e) {
          errors[entry.key] = e.toString();
        }
      }),
    );

    return {
      'data': results,
      'errors': errors,
    };
  }

  /// Load courses for a specific college
  static Future<List<dynamic>> loadCourses(String collegeCode) async {
    return await getCachedData(
      '${DataCacheService.courses}_$collegeCode',
      () => ApiService.getSuperadminCourses(collegeCode),
      cacheDuration: DataCacheService.coursesDuration,
    );
  }

  /// Load live status with short cache duration
  static Future<Map<String, dynamic>> loadLiveStatus(String collegeName) async {
    return await getCachedData(
      '${DataCacheService.liveStatus}_$collegeName',
      () => ApiService.getDeanLiveStatus(collegeName),
      cacheDuration: DataCacheService.liveStatusDuration,
    );
  }

  /// Invalidate specific cache entries
  static Future<void> invalidateCache(String cacheKey) async {
    // Clear cache by setting a very short duration and letting it expire
    await DataCacheService.cacheData(cacheKey, null, duration: Duration.zero);
  }

  /// Invalidate all cache
  static Future<void> invalidateAllCache() async {
    await DataCacheService.clearAllCache();
  }

  /// Preload critical data for better performance
  static Future<void> preloadCriticalData() async {
    try {
      // Preload colleges and user counts as they're commonly needed
      await Future.wait([
        getCachedData(
          DataCacheService.colleges,
          () => ApiService.getSuperadminColleges(),
          cacheDuration: DataCacheService.collegesDuration,
        ),
        getCachedData(
          DataCacheService.userCounts,
          () => ApiService.getSuperadminUserCounts(),
          cacheDuration: DataCacheService.userCountsDuration,
        ),
      ]);
    } catch (e) {
      // Silently fail preloading
      print('Preload failed: $e');
    }
  }

  /// Clear expired cache entries periodically
  static Future<void> cleanupExpiredCache() async {
    await DataCacheService.clearExpiredCache();
  }
}
