# 🔒 SECURITY GUIDELINES - FlowCRM Mobile

**Last Updated:** June 2026  
**Status:** CRITICAL - Read Before Development

---

## 📋 Table of Contents

1. [Quick Start Security Checklist](#quick-start-security-checklist)
2. [Secrets Management](#secrets-management)
3. [Authentication & Authorization](#authentication--authorization)
4. [Input Validation & Sanitization](#input-validation--sanitization)
5. [Rate Limiting](#rate-limiting)
6. [API Security](#api-security)
7. [File Upload Security](#file-upload-security)
8. [Storage Security](#storage-security)
9. [Network Security](#network-security)
10. [Dependency Management](#dependency-management)
11. [Common Vulnerabilities](#common-vulnerabilities)
12. [Testing Security](#testing-security)
13. [Deployment Checklist](#deployment-checklist)

---

## ✅ Quick Start Security Checklist

- [ ] Never hardcode API keys, use `.env` and `SecureConfig`
- [ ] All user input is sanitized before API calls
- [ ] All API endpoints use HTTPS (enforced in code)
- [ ] Firebase authentication is enabled and properly configured
- [ ] Rate limiting is active on all sensitive endpoints
- [ ] File uploads are validated by type, size, and magic numbers
- [ ] Encrypted storage enabled on Android (`encryptedSharedPreferences: true`)
- [ ] `.env` files are in `.gitignore` and NEVER committed
- [ ] No console.log statements with sensitive data
- [ ] All API calls include proper error handling
- [ ] OWASP Top 10 vulnerabilities are addressed

---

## 🔐 Secrets Management

### ❌ WRONG - Never do this:

```dart
// DON'T hardcode API keys!
const String apiKey = "sk_test_123456789";
const String baseUrl = "http://api.example.com"; // HTTP!
const String firebaseKey = "AIzaSyD...";

class MyService {
  final String secret = "password123"; // Hardcoded secret
}
```

### ✅ RIGHT - Use environment variables:

```dart
import 'core/secure_config.dart';
import 'core/input_sanitizer.dart';

// Load from environment
final baseUrl = SecureConfig.apiBaseUrl; // Returns /v1 versioned URL
final timeout = SecureConfig.apiTimeoutSeconds;

// For production, use .env file:
// API_BASE_URL=https://api.flowcrm.com
// FIREBASE_API_KEY=your_key_here
```

### Setup Steps:

1. **Create `.env` file (LOCAL ONLY):**
   ```bash
   cp .env.example .env
   # Edit .env with real values - NEVER COMMIT THIS FILE
   ```

2. **Verify `.env` is in `.gitignore`:**
   ```
   .env
   .env.local
   .env.*.local
   ```

3. **Run Flutter with environment variables:**
   ```bash
   flutter run --dart-define-from-file=.env
   ```

4. **For CI/CD**, use GitHub Actions secrets:
   ```yaml
   - run: flutter run --dart-define=API_URL=${{ secrets.API_URL }}
   ```

---

## 🔑 Authentication & Authorization

### Firebase Setup (REQUIRED):

```dart
// Ensure Firebase is initialized
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // REQUIRED: Initialize Firebase before API calls
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}
```

### Login with Rate Limiting:

```dart
import 'core/rate_limiter.dart';
import 'data/services/api_client.dart';

// Rate limiting automatically prevents brute force
try {
  final response = await apiClient.login(email, password);
  // Handles: max 5 attempts per 15 minutes per email
} catch (e) {
  if (e.toString().contains('Too many')) {
    print('Account temporarily locked');
  }
}
```

### Required: No Public APIs

All API endpoints MUST require authentication:

```dart
// ❌ WRONG - Public endpoint
Future<Response> getPublicData() => dio.get('/public/data');

// ✅ RIGHT - All endpoints require Bearer token
Future<Response> getUserData() => dio.get('/users/me'); // Auto adds Bearer token
```

### Multi-Factor Authentication (2FA):

```dart
// Check if user has 2FA enabled
if (user.twoFactorEnabled) {
  // Show 2FA code input screen
  final verified = await show2FADialog();
  if (!verified) {
    throw Exception('2FA verification failed');
  }
}
```

---

## 🛡️ Input Validation & Sanitization

### ALL user input must be sanitized:

```dart
import 'core/input_sanitizer.dart';

// ❌ WRONG - Direct API call with user input
Future<void> searchParties(String query) {
  return apiClient.getParties(search: query); // Vulnerable!
}

// ✅ RIGHT - Sanitize first
Future<void> searchParties(String query) {
  try {
    final safe = InputSanitizer.sanitizeSqlInput(query);
    return apiClient.getParties(search: safe);
  } catch (e) {
    print('Invalid search input');
  }
}
```

### Sanitization Examples:

```dart
import 'core/input_sanitizer.dart';

// Email validation
try {
  final email = InputSanitizer.sanitizeEmail(userInput);
  // Returns: test@example.com (lowercase)
  // Throws: FormatException if invalid
} catch (e) {
  print('Invalid email');
}

// Password validation (strength check)
try {
  InputSanitizer.validatePassword(password);
  // Requires: 8+ chars, uppercase, lowercase, number, special char
} catch (e) {
  print('Weak password');
}

// General user input (blocks SQL injection & XSS)
try {
  final safe = InputSanitizer.sanitizeUserInput(userInput);
  // Removes: null bytes, HTML tags, SQL keywords
  // Max length: 1000 chars
} catch (e) {
  print('Invalid input');
}

// Phone number
final phone = InputSanitizer.sanitizePhoneNumber("+1-234-567-8900");

// URL validation
try {
  final url = InputSanitizer.sanitizeUrl("https://example.com");
  // Throws: if HTTP (not HTTPS) or javascript: protocol
} catch (e) {
  print('Invalid URL');
}

// Filename
final safe = InputSanitizer.sanitizeFilename(userFilename);
// Removes: path traversal (../, /), special chars
```

### Form Input Pattern:

```dart
// Example: Login form
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  Future<void> handleLogin() async {
    try {
      // Sanitize inputs
      final email = InputSanitizer.sanitizeEmail(emailCtrl.text);
      InputSanitizer.validatePassword(passwordCtrl.text);

      // API call with rate limiting
      final response = await ApiClient().login(email, passwordCtrl.text);
      
      // Success
      if (response.statusCode == 200) {
        // Navigate to home
      }
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password'),
          ),
          ElevatedButton(
            onPressed: handleLogin,
            child: Text('Login'),
          ),
        ],
      ),
    );
  }
}
```

---

## ⏱️ Rate Limiting

### Built-in Rate Limiters:

```dart
import 'core/rate_limiter.dart';

// Login: 5 attempts per 15 minutes
ApiRateLimiters.canAttemptLogin(email);

// Registration: 3 attempts per hour
ApiRateLimiters.canAttemptRegister(email);

// Forgot password: 3 attempts per hour
ApiRateLimiters.canAttemptForgotPassword(email);

// AI endpoints: 10 requests per minute
ApiRateLimiters.canCallAiEndpoint(userId);

// Get remaining AI calls
final remaining = ApiRateLimiters.getRemainingAiCalls(userId);

// Get time until next AI call is allowed
final waitSeconds = ApiRateLimiters.getTimeUntilNextAiCall(userId);
```

### Custom Rate Limiter:

```dart
import 'core/rate_limiter.dart';

// Create custom limiter: 20 requests per hour
final limiter = RateLimiter(
  maxRequests: 20,
  windowDuration: Duration(hours: 1),
);

if (limiter.isAllowed('user-123')) {
  // Proceed
} else {
  print('Rate limit exceeded');
}
```

---

## 🌐 API Security

### API Versioning (Required):

```dart
// ✅ All endpoints automatically use /v1
// BaseURL: https://api.flowcrm.com/v1

// Examples:
GET /v1/auth/profile
POST /v1/parties
PATCH /v1/leads/123
DELETE /v1/invoices/456
```

### HTTPS Only (Enforced):

```dart
// ❌ This will be REJECTED
const url = "http://api.flowcrm.com"; // Not HTTPS!

// ✅ This is REQUIRED
const url = "https://api.flowcrm.com"; // HTTPS enforced
```

### Bearer Token Format:

```dart
// Authorization header is automatically added
// Format: Bearer <token>
// Example: Authorization: Bearer eyJhbGc...

// Tokens are securely stored using flutter_secure_storage
// Android: Encrypted SharedPreferences
// iOS: Keychain
```

### Example API Call with All Security:

```dart
import 'data/services/api_client.dart';
import 'core/input_sanitizer.dart';
import 'core/rate_limiter.dart';

Future<void> createLead(String name, String email) async {
  // 1. Sanitize inputs
  final safeName = InputSanitizer.sanitizeUserInput(name);
  final safeEmail = InputSanitizer.sanitizeEmail(email);

  // 2. Check rate limits
  if (!ApiRateLimiters.canAttemptLogin(email)) {
    throw Exception('Rate limited');
  }

  // 3. API call (auto handles: auth, versioning, HTTPS, retries)
  try {
    final response = await ApiClient().createLead({
      'name': safeName,
      'email': safeEmail,
    });

    if (response.statusCode == 201) {
      print('Lead created');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## 📁 File Upload Security

### Validation Required:

```dart
import 'core/file_upload_validator.dart';

Future<void> uploadDocument(File file) async {
  // 1. Validate file
  final validation = await FileUploadValidator.validateFile(file);

  if (!validation.isValid) {
    print('Upload failed: ${validation.message}');
    return;
  }

  // 2. Check rate limits
  final userId = await getLoggedInUserId();
  if (!ApiRateLimiters.canUploadFile(userId)) {
    print('Too many uploads, try again later');
    return;
  }

  // 3. Create safe filename
  final safeFilename = FileUploadValidator.createSafeFilename(
    file.path.split('/').last,
    null,
  );

  // 4. Upload
  // ... upload logic
}
```

### Allowed File Types:

- **Documents:** pdf, doc, docx, xls, xlsx, txt, csv
- **Images:** jpg, jpeg, png, gif
- **Max Size:** 50 MB

### Blocked File Types:

- Executables: exe, bat, cmd, com, pif, scr, vbs, js, jar
- Archives: zip, rar, 7z (unless explicitly allowed)
- Scripts: sh, bin, app
- All other types

### Validation Checks:

1. ✅ File exists
2. ✅ Extension is allowed
3. ✅ Extension is not blocked
4. ✅ Filename has no path traversal (../, /)
5. ✅ Filename has no null bytes
6. ✅ File size ≤ 50 MB
7. ✅ File magic numbers match extension
8. ✅ Filename is safe (no special chars)

---

## 💾 Storage Security

### Secure Token Storage (Encrypted):

```dart
import 'data/services/storage_service.dart';

final storage = StorageService();

// Save tokens (automatically encrypted)
await storage.saveTokens(
  accessToken: token,
  refreshToken: refreshToken,
);

// Retrieve (automatically decrypted)
final accessToken = await storage.getAccessToken();

// Clear all data on logout
await storage.clearAll();
```

### Storage Configuration:

```dart
// Android: AES-GCM encryption
AndroidOptions(
  encryptedSharedPreferences: true,
  keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
  storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
)

// iOS: Keychain with device-only accessibility
IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device_only,
)
```

### What to Store Securely:

- ✅ Access tokens
- ✅ Refresh tokens
- ✅ User credentials (if necessary)
- ✅ Session data

### What NOT to Store:

- ❌ API keys
- ❌ Passwords (use tokens instead)
- ❌ Credit card info (handle server-side)
- ❌ PII (store ID only, fetch from server)

---

## 🔗 Network Security

### HTTPS Certificate Pinning (Optional but Recommended):

```dart
// In SecureConfig
static const bool enableSslPinning = true;
static const String certificatePin = "sha256/AAAAAAAAAA...";

// Certificate pinning configured in Dio
// Rejects connections not matching the pinned certificate
```

### Proxy Detection (Recommended):

```dart
// In SecureConfig
static const bool enableProxyDetection = true;

// Detects and warns if app is running through proxy
// (Useful for detecting MITM attacks)
```

### No Plain HTTP:

```dart
// ❌ Will be rejected
dio.get('http://api.example.com/data');

// ✅ Only HTTPS accepted
dio.get('https://api.example.com/data');
```

---

## 📦 Dependency Management

### Check for Vulnerable Dependencies:

```bash
# List outdated packages
flutter pub outdated

# Run pub.dev security audit
dart pub publish --dry-run
```

### Dependabot Automatic Updates:

- Checks for security updates weekly
- Creates PRs for vulnerable dependencies
- Requires review before merging
- Config file: `.github/dependabot.yml`

### Update Dependencies Regularly:

```bash
# Check for updates
flutter pub outdated

# Update specific package
flutter pub upgrade package_name

# Update all packages
flutter pub upgrade

# Get new pubspec.lock
flutter pub get
```

### Dangerous Dependencies to Avoid:

- Packages with known CVEs
- Unmaintained packages (no updates in 2+ years)
- Packages that hardcode secrets
- Packages that bypass SSL verification

---

## ⚠️ Common Vulnerabilities

### 1. SQL Injection

```dart
// ❌ VULNERABLE
api.get('/parties?search=$userInput');

// ✅ SAFE
final safe = InputSanitizer.sanitizeSqlInput(userInput);
api.get('/parties?search=$safe');
```

### 2. XSS (Cross-Site Scripting)

```dart
// ❌ VULNERABLE
Text(userInput); // Direct display

// ✅ SAFE
final safe = InputSanitizer.sanitizeXssInput(userInput);
Text(safe);
```

### 3. Hardcoded Secrets

```dart
// ❌ NEVER DO THIS
const apiKey = "sk_test_123";

// ✅ USE ENVIRONMENT VARIABLES
final apiKey = SecureConfig.apiKey;
```

### 4. Insecure Storage

```dart
// ❌ VULNERABLE
SharedPreferences.getInstance().setString('token', token);

// ✅ SECURE
await StorageService().saveTokens(accessToken: token, refreshToken: refreshToken);
```

### 5. Missing Rate Limiting

```dart
// ❌ VULNERABLE - Can be brute forced
Future<void> login(String email, String password) {
  return api.login(email, password);
}

// ✅ SAFE - Has rate limiting
Future<void> login(String email, String password) {
  if (!ApiRateLimiters.canAttemptLogin(email)) {
    throw Exception('Too many attempts');
  }
  return api.login(email, password);
}
```

### 6. Missing Input Validation

```dart
// ❌ VULNERABLE
api.updateProfile({'name': nameInput});

// ✅ SAFE
final name = InputSanitizer.sanitizeUserInput(nameInput);
api.updateProfile({'name': name});
```

---

## 🧪 Testing Security

### Unit Tests for Input Sanitization:

```dart
test('sanitizeEmail should validate format', () {
  expect(
    () => InputSanitizer.sanitizeEmail('invalid'),
    throwsFormatException,
  );
});

test('sanitizeUserInput should block SQL injection', () {
  expect(
    () => InputSanitizer.sanitizeUserInput("'; DROP TABLE--"),
    throwsFormatException,
  );
});
```

### Test File Uploads:

```dart
test('should reject executable files', () async {
  final result = await FileUploadValidator.validateFile(exeFile);
  expect(result.isValid, false);
});

test('should validate file magic numbers', () async {
  final result = await FileUploadValidator.validateFile(jpgFile);
  expect(result.isValid, true);
});
```

### Test Rate Limiting:

```dart
test('should rate limit login attempts', () {
  var canAttempt = ApiRateLimiters.canAttemptLogin('user@example.com');
  expect(canAttempt, true);

  // Simulate 5 failed attempts
  for (int i = 0; i < 5; i++) {
    ApiRateLimiters.canAttemptLogin('user@example.com');
  }

  // 6th attempt should fail
  canAttempt = ApiRateLimiters.canAttemptLogin('user@example.com');
  expect(canAttempt, false);
});
```

---

## ✅ Deployment Checklist

Before deploying to production:

### Code Security
- [ ] No hardcoded API keys or secrets
- [ ] All user input is sanitized
- [ ] All APIs require authentication
- [ ] HTTPS is enforced
- [ ] Rate limiting is active
- [ ] Error messages don't leak sensitive info
- [ ] No console.log with sensitive data
- [ ] Firebase is properly initialized

### Configuration
- [ ] `.env` file is in `.gitignore`
- [ ] Environment variables are set in production
- [ ] SecureConfig validates configuration
- [ ] API version is correct (/v1)
- [ ] Timeout values are reasonable

### Dependencies
- [ ] No known CVEs in pubspec.lock
- [ ] All dependencies are up to date
- [ ] Dependabot is configured
- [ ] No beta/pre-release versions in production

### Storage
- [ ] Encrypted storage is enabled on Android
- [ ] Tokens are cleared on logout
- [ ] No sensitive data in SharedPreferences

### Network
- [ ] All URLs are HTTPS
- [ ] Certificate pinning configured (optional)
- [ ] Proxy detection enabled (optional)
- [ ] SSL verification enabled

### Testing
- [ ] Security tests pass
- [ ] Input validation tests pass
- [ ] Rate limiting tests pass
- [ ] File upload tests pass

### Monitoring
- [ ] Logging is configured (but not sensitive data)
- [ ] Error tracking is enabled (Sentry/Firebase Crashlytics)
- [ ] API monitoring is active
- [ ] Rate limiting metrics are tracked

### Release
- [ ] Build is signed with release key
- [ ] APK/IPA is verified
- [ ] Release notes don't mention security fixes in detail
- [ ] Code obfuscation enabled (for sensitive code)
- [ ] ProGuard rules configured (Android)

---

## 📞 Security Issues

Found a security vulnerability? **DO NOT** open a GitHub issue!

1. Email: security@flowcrm.com
2. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Your name (optional)

3. We will:
   - Confirm receipt within 24 hours
   - Investigate immediately
   - Provide update within 7 days
   - Credit you if desired

---

## 📚 Resources

- [OWASP Top 10 Mobile](https://owasp.org/www-project-mobile-top-10/)
- [Flutter Security Best Practices](https://flutter.dev/docs/deployment/security)
- [Dart Security Guidelines](https://dart.dev/guides/security)
- [Firebase Security Rules](https://firebase.google.com/docs/database/security)
- [CWE Top 25](https://cwe.mitre.org/top25/)

---

**Last Update:** June 2026  
**Version:** 1.0  
**Status:** ACTIVE & ENFORCED

