import 'dart:async';
import 'package:flutter/foundation.dart';

class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, List<Duration>> _measurements = {};

  /// Start timing a performance metric
  static void startTimer(String key) {
    if (kDebugMode) {
      _timers[key] = Stopwatch()..start();
      print('⏱️ Started timer: $key');
    }
  }

  /// Stop timing and record the duration
  static Duration? stopTimer(String key) {
    if (kDebugMode) {
      final timer = _timers.remove(key);
      if (timer != null) {
        timer.stop();
        final duration = timer.elapsed;
        _measurements.putIfAbsent(key, () => []).add(duration);
        print('⏱️ Stopped timer: $key - ${duration.inMilliseconds}ms');
        return duration;
      }
    }
    return null;
  }

  /// Get average duration for a metric
  static Duration? getAverageDuration(String key) {
    if (kDebugMode) {
      final measurements = _measurements[key];
      if (measurements != null && measurements.isNotEmpty) {
        final totalMs = measurements.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
        return Duration(milliseconds: totalMs ~/ measurements.length);
      }
    }
    return null;
  }

  /// Get all measurements for a metric
  static List<Duration>? getMeasurements(String key) {
    if (kDebugMode) {
      return _measurements[key]?.toList();
    }
    return null;
  }

  /// Clear all measurements
  static void clearMeasurements() {
    if (kDebugMode) {
      _timers.clear();
      _measurements.clear();
      print('⏱️ Cleared all performance measurements');
    }
  }

  /// Get performance summary
  static Map<String, dynamic> getPerformanceSummary() {
    if (kDebugMode) {
      final summary = <String, dynamic>{};
      for (final entry in _measurements.entries) {
        final measurements = entry.value;
        if (measurements.isNotEmpty) {
          final totalMs = measurements.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
          final averageMs = totalMs ~/ measurements.length;
          final minMs = measurements.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
          final maxMs = measurements.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
          
          summary[entry.key] = {
            'count': measurements.length,
            'average_ms': averageMs,
            'min_ms': minMs,
            'max_ms': maxMs,
            'total_ms': totalMs,
          };
        }
      }
      return summary;
    }
    return {};
  }

  /// Log performance summary
  static void logPerformanceSummary() {
    if (kDebugMode) {
      final summary = getPerformanceSummary();
      print('📊 Performance Summary:');
      for (final entry in summary.entries) {
        final data = entry.value as Map<String, dynamic>;
        print('  ${entry.key}: ${data['count']} calls, avg: ${data['average_ms']}ms, min: ${data['min_ms']}ms, max: ${data['max_ms']}ms');
      }
    }
  }
}

/// Performance tracking mixin for widgets
mixin PerformanceTracking {
  void trackPerformance(String operation, Future<void> Function() operationFunction) async {
    PerformanceMonitor.startTimer(operation);
    try {
      await operationFunction();
    } finally {
      PerformanceMonitor.stopTimer(operation);
    }
  }

  void trackSyncPerformance(String operation, void Function() operationFunction) {
    PerformanceMonitor.startTimer(operation);
    try {
      operationFunction();
    } finally {
      PerformanceMonitor.stopTimer(operation);
    }
  }
}

/// Performance-aware API call wrapper
class PerformanceApiCall {
  static Future<T> trackApiCall<T>(
    String operation,
    Future<T> Function() apiCall,
  ) async {
    PerformanceMonitor.startTimer('api_$operation');
    try {
      final result = await apiCall();
      PerformanceMonitor.stopTimer('api_$operation');
      return result;
    } catch (e) {
      PerformanceMonitor.stopTimer('api_$operation');
      rethrow;
    }
  }
}
