/// Secure configuration manager that loads environment variables
/// Never hardcodes secrets - all values come from environment or secure storage
class SecureConfig {
  static const String _apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.flowcrm.com');
  static const int _apiTimeoutSeconds =
      int.fromEnvironment('API_TIMEOUT_SECONDS', defaultValue: 30);
  static const int _apiMaxRetries =
      int.fromEnvironment('API_MAX_RETRIES', defaultValue: 3);
  static const int _aiRateLimitRequests =
      int.fromEnvironment('AI_RATE_LIMIT_REQUESTS', defaultValue: 10);
  static const int _aiRateLimitWindowMinutes =
      int.fromEnvironment('AI_RATE_LIMIT_WINDOW_MINUTES', defaultValue: 1);
  static const bool _enableSslPinning =
      bool.fromEnvironment('ENABLE_SSL_PINNING', defaultValue: true);
  static const int _maxFailedLoginAttempts =
      int.fromEnvironment('MAX_FAILED_LOGIN_ATTEMPTS', defaultValue: 5);
  static const int _lockoutDurationMinutes =
      int.fromEnvironment('LOCKOUT_DURATION_MINUTES', defaultValue: 15);
  static const int _maxUploadSizeMb =
      int.fromEnvironment('MAX_UPLOAD_SIZE_MB', defaultValue: 50);

  /// Get API base URL (v1 versioning)
  static String get apiBaseUrl => '$_apiBaseUrl/v1';

  /// Get API timeout in seconds
  static int get apiTimeoutSeconds => _apiTimeoutSeconds;

  /// Get max API retries
  static int get apiMaxRetries => _apiMaxRetries;

  /// Get AI rate limit requests
  static int get aiRateLimitRequests => _aiRateLimitRequests;

  /// Get AI rate limit window in minutes
  static int get aiRateLimitWindowMinutes => _aiRateLimitWindowMinutes;

  /// Check if SSL pinning is enabled
  static bool get enableSslPinning => _enableSslPinning;

  /// Get max failed login attempts before lockout
  static int get maxFailedLoginAttempts => _maxFailedLoginAttempts;

  /// Get lockout duration in minutes
  static int get lockoutDurationMinutes => _lockoutDurationMinutes;

  /// Get max upload size in MB
  static int get maxUploadSizeMb => _maxUploadSizeMb;

  /// Validate configuration is correct — throws in both debug and release builds
  static void validateConfig() {
    if (!_apiBaseUrl.startsWith('https://')) throw StateError('API_BASE_URL must use HTTPS');
    if (_apiTimeoutSeconds <= 0) throw StateError('API_TIMEOUT_SECONDS must be positive');
    if (_apiMaxRetries < 0) throw StateError('API_MAX_RETRIES must be non-negative');
    if (_aiRateLimitRequests <= 0) throw StateError('AI_RATE_LIMIT_REQUESTS must be positive');
    if (_maxFailedLoginAttempts <= 0) throw StateError('MAX_FAILED_LOGIN_ATTEMPTS must be positive');
  }
}
