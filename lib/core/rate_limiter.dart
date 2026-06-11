import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Rate limiter to prevent brute force attacks on expensive operations
class RateLimiter {
  final Map<String, List<DateTime>> _requestHistory = {};
  final int maxRequests;
  final Duration windowDuration;

  RateLimiter({
    required this.maxRequests,
    required this.windowDuration,
  });

  /// Check if a request is allowed for the given key
  bool isAllowed(String key) {
    final now = DateTime.now();
    
    // Initialize if first time
    if (!_requestHistory.containsKey(key)) {
      _requestHistory[key] = [];
    }
    
    final history = _requestHistory[key]!;
    
    // Remove old requests outside the window
    history.removeWhere((timestamp) {
      return now.difference(timestamp) > windowDuration;
    });
    
    // Check if limit exceeded
    if (history.length >= maxRequests) {
      return false;
    }
    
    // Add current request
    history.add(now);
    return true;
  }

  /// Get remaining requests for a key
  int getRemainingRequests(String key) {
    final now = DateTime.now();
    
    if (!_requestHistory.containsKey(key)) {
      return maxRequests;
    }
    
    final history = _requestHistory[key]!;
    
    // Remove old requests outside the window
    history.removeWhere((timestamp) {
      return now.difference(timestamp) > windowDuration;
    });
    
    return maxRequests - history.length;
  }

  /// Get time until next request is allowed (in seconds)
  double? getTimeUntilNextRequest(String key) {
    if (!_requestHistory.containsKey(key)) {
      return null;
    }
    
    final history = _requestHistory[key]!;
    
    if (history.isEmpty || history.length < maxRequests) {
      return null;
    }
    
    final oldestRequest = history.first;
    final now = DateTime.now();
    final nextAllowedTime = oldestRequest.add(windowDuration);
    
    if (nextAllowedTime.isBefore(now)) {
      return null;
    }
    
    return nextAllowedTime.difference(now).inMilliseconds / 1000;
  }

  /// Reset rate limit for a key
  void reset(String key) {
    _requestHistory.remove(key);
  }

  /// Clear all rate limit history
  void clearAll() {
    _requestHistory.clear();
  }
}

/// API-specific rate limiters
class ApiRateLimiters {
  static final loginLimiter = RateLimiter(
    maxRequests: 5,
    windowDuration: const Duration(minutes: 15),
  );

  static final registerLimiter = RateLimiter(
    maxRequests: 3,
    windowDuration: const Duration(hours: 1),
  );

  static final forgotPasswordLimiter = RateLimiter(
    maxRequests: 3,
    windowDuration: const Duration(hours: 1),
  );

  static final aiEndpointLimiter = RateLimiter(
    maxRequests: 10,
    windowDuration: const Duration(minutes: 1),
  );

  static final uploadLimiter = RateLimiter(
    maxRequests: 5,
    windowDuration: const Duration(minutes: 1),
  );

  static final generalApiLimiter = RateLimiter(
    maxRequests: 100,
    windowDuration: const Duration(minutes: 1),
  );

  /// Check login attempt
  static bool canAttemptLogin(String email) {
    return loginLimiter.isAllowed(email);
  }

  /// Check registration attempt
  static bool canAttemptRegister(String email) {
    return registerLimiter.isAllowed(email);
  }

  /// Check forgot password attempt
  static bool canAttemptForgotPassword(String email) {
    return forgotPasswordLimiter.isAllowed(email);
  }

  /// Check AI endpoint request
  static bool canCallAiEndpoint(String userId) {
    return aiEndpointLimiter.isAllowed(userId);
  }

  /// Check file upload attempt
  static bool canUploadFile(String userId) {
    return uploadLimiter.isAllowed(userId);
  }

  /// Get remaining AI endpoint calls
  static int getRemainingAiCalls(String userId) {
    return aiEndpointLimiter.getRemainingRequests(userId);
  }

  /// Get time until next AI endpoint call is allowed
  static double? getTimeUntilNextAiCall(String userId) {
    return aiEndpointLimiter.getTimeUntilNextRequest(userId);
  }

  /// Reset all rate limiters for a user (e.g., on logout)
  static void resetUserLimiters(String userId) {
    loginLimiter.reset(userId);
    forgotPasswordLimiter.reset(userId);
    aiEndpointLimiter.reset(userId);
    uploadLimiter.reset(userId);
    generalApiLimiter.reset(userId);
  }
}

/// Exponential backoff for retries
class ExponentialBackoff {
  final int maxRetries;
  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;

  ExponentialBackoff({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(seconds: 60),
  });

  /// Get delay for the given retry attempt (0-indexed)
  Duration getDelay(int retryAttempt) {
    if (retryAttempt < 0 || retryAttempt >= maxRetries) {
      throw ArgumentError('Invalid retry attempt');
    }

    final exponentialDelay = Duration(
      milliseconds:
          (initialDelay.inMilliseconds * math.pow(multiplier, retryAttempt)).toInt(),
    );

    // Cap at maxDelay
    return exponentialDelay.compareTo(maxDelay) > 0 ? maxDelay : exponentialDelay;
  }

  /// Add jitter to delay to prevent thundering herd
  Duration getDelayWithJitter(int retryAttempt) {
    final baseDelay = getDelay(retryAttempt);
    final jitterMs = (baseDelay.inMilliseconds * 0.1 * (2 * (0.5 - 0.5))).toInt();
    return Duration(milliseconds: baseDelay.inMilliseconds + jitterMs);
  }
}
