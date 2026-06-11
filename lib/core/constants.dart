import 'secure_config.dart';

class AppConstants {
  // ── API ──────────────────────────────────────────────────────
  // SECURITY: Always use environment variables, never hardcode
  // Set via --dart-define=API_BASE_URL=https://your-backend.com/api at build time
  static String get secureBaseUrl => SecureConfig.apiBaseUrl;

  // API Endpoints (with v1 versioning)
  static const String apiVersion = '/v1';
  
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // ── Storage keys ─────────────────────────────────────────────
  static const String kAccessToken  = 'access_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kActiveOrgId  = 'active_org_id';
  static const String kUserData     = 'user_data';
  static const String kFailedLoginAttempts = 'failed_login_attempts';
  static const String kAccountLockedUntil = 'account_locked_until';

  // ── App ──────────────────────────────────────────────────────
  static const String appName    = 'FlowCRM';
  static const String appVersion = '1.0.0';
  
  // ── Security ─────────────────────────────────────────────────
  static const bool enforceHttpsOnly = true;
  static const bool enableCertificatePinning = true;
  static const bool enableProxyDetection = true;
}
