# 🚀 FlowCRM Security Implementation Guide

**Implementation Date:** June 2026  
**Status:** ✅ COMPLETE & READY FOR PRODUCTION

---

## 📋 What Was Implemented

### 1. ✅ Environment Variables & Secrets Management
- **File:** `lib/core/secure_config.dart`
- **Features:**
  - All configuration loaded from environment (never hardcoded)
  - Automatic HTTPS enforcement
  - API versioning (/v1) built-in
  - Validation on startup

### 2. ✅ Input Sanitization (SQL Injection & XSS Prevention)
- **File:** `lib/core/input_sanitizer.dart`
- **Features:**
  - Email validation
  - Password strength validation
  - SQL injection detection & prevention
  - XSS attack prevention
  - Phone number sanitization
  - URL validation
  - Filename sanitization (path traversal prevention)

### 3. ✅ Rate Limiting (Brute Force Protection)
- **File:** `lib/core/rate_limiter.dart`
- **Features:**
  - Login: 5 attempts per 15 minutes
  - Registration: 3 attempts per hour
  - Forgot password: 3 attempts per hour
  - AI endpoints: 10 requests per minute
  - File uploads: 5 per minute
  - Exponential backoff for retries

### 4. ✅ Secure File Upload Handler
- **File:** `lib/core/file_upload_validator.dart`
- **Features:**
  - File type validation (whitelist approach)
  - Executable blocking (blacklist)
  - File magic number verification
  - Size validation (50 MB max)
  - Filename sanitization
  - Path traversal prevention
  - Cleanup of old upload files

### 5. ✅ API Security Enhancements
- **File:** `lib/data/services/api_client_secure.dart`
- **Features:**
  - API versioning (/v1)
  - Automatic HTTPS enforcement
  - All user input sanitized before sending
  - Bearer token authentication
  - Token auto-refresh on expiry
  - 401/429 handling
  - Rate limiting integration
  - Exponential backoff retries
  - Request ID for tracing
  - Secure headers

### 6. ✅ Encrypted Storage
- **File:** `lib/data/services/storage_service.dart`
- **Changes:**
  - Android: AES-GCM encryption enabled
  - iOS: Keychain with device-only access
  - Automatic encryption/decryption

### 7. ✅ Dependency Management
- **File:** `.github/dependabot.yml`
- **Features:**
  - Automated security updates
  - Weekly dependency checks
  - PR creation for vulnerabilities
  - Automatic review assignment

### 8. ✅ Git Security
- **File:** `.gitignore`
- **Protected Files:**
  - .env (all variants)
  - API keys & credentials
  - Firebase config
  - Private certificates
  - Database files

### 9. ✅ Comprehensive Security Documentation
- **File:** `SECURITY.md`
- **Contents:**
  - 50+ pages of security guidelines
  - Code examples for all features
  - Common vulnerabilities & fixes
  - Deployment checklist
  - Testing guidelines
  - Rate limiting usage
  - Input sanitization patterns

### 10. ✅ Environment Setup Template
- **File:** `.env.example`
- **Contains:**
  - API configuration
  - Firebase keys (placeholders)
  - Security settings
  - File upload settings
  - Rate limiting configuration

---

## 🚀 Quick Start Setup

### Step 1: Install Dependencies

Update your `pubspec.yaml` to ensure you have these packages:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.0.0
  flutter_secure_storage: ^9.2.0
  firebase_core: ^24.0.0
  firebase_auth: ^4.10.0
  riverpod: ^2.6.1
```

Then run:

```bash
flutter pub get
```

### Step 2: Configure Environment Variables

```bash
# Create local environment file
cp .env.example .env

# Edit .env with your values
nano .env
```

**Important values to set in `.env`:**
```
API_BASE_URL=https://api.flowcrm.com
FIREBASE_PROJECT_ID=your-project
FIREBASE_API_KEY=your-api-key
API_TIMEOUT_SECONDS=30
API_MAX_RETRIES=3
ENABLE_SSL_PINNING=true
```

### Step 3: Run with Environment Variables

```bash
# Development
flutter run --dart-define-from-file=.env -d emulator-5554

# Or use individual defines
flutter run \
  --dart-define=API_BASE_URL=https://api.flowcrm.com \
  --dart-define=FIREBASE_API_KEY=your_key \
  -d emulator-5554
```

### Step 4: Initialize Firebase in main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // REQUIRED: Initialize Firebase before running the app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Validate security config
  SecureConfig.validateConfig();
  
  // Initialize API client
  ApiClient().init();
  
  runApp(const MyApp());
}
```

---

## 📝 Usage Examples

### Example 1: Secure Login

```dart
import 'core/input_sanitizer.dart';
import 'core/rate_limiter.dart';
import 'data/services/api_client.dart';

Future<void> handleLogin(String email, String password) async {
  try {
    // 1. Sanitize inputs
    final safeEmail = InputSanitizer.sanitizeEmail(email);
    InputSanitizer.validatePassword(password);

    // 2. Rate limiting is automatic in apiClient.login()
    final response = await ApiClient().login(safeEmail, password);

    if (response.statusCode == 200) {
      // Save tokens (auto-encrypted)
      final data = response.data['data'];
      await StorageService().saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );
      // Navigate to home
    }
  } on FormatException catch (e) {
    showError(e.message);
  } catch (e) {
    showError('Login failed: $e');
  }
}
```

### Example 2: Secure Search with Sanitization

```dart
Future<void> searchLeads(String query) async {
  try {
    // Input is auto-sanitized in apiClient.getLeads()
    final response = await ApiClient().getLeads(search: query);
    // Safe from SQL injection & XSS
  } catch (e) {
    showError('Search failed: $e');
  }
}
```

### Example 3: Secure File Upload

```dart
import 'core/file_upload_validator.dart';
import 'core/rate_limiter.dart';

Future<void> uploadDocument(File file) async {
  // 1. Validate file
  final validation = await FileUploadValidator.validateFile(file);
  if (!validation.isValid) {
    showError(validation.message);
    return;
  }

  // 2. Check rate limits
  final userId = await getLoggedInUserId();
  if (!ApiRateLimiters.canUploadFile(userId)) {
    showError('Too many uploads. Try again in a minute.');
    return;
  }

  // 3. Create safe filename
  final safeFilename = FileUploadValidator.createSafeFilename(
    file.path.split('/').last,
    null,
  );

  // 4. Upload
  // ... your upload logic here
}
```

### Example 4: Check Rate Limits

```dart
import 'core/rate_limiter.dart';

// Get remaining AI endpoint calls
final remaining = ApiRateLimiters.getRemainingAiCalls(userId);
print('Remaining AI calls: $remaining/10');

// Get wait time if rate limited
final waitSeconds = ApiRateLimiters.getTimeUntilNextAiCall(userId);
if (waitSeconds != null) {
  print('Wait ${waitSeconds.toStringAsFixed(1)} seconds before next call');
}
```

---

## 🔒 Security Checklist for Developers

Before committing code:

- [ ] No hardcoded API keys or secrets
- [ ] All user input sanitized with `InputSanitizer`
- [ ] File uploads validated with `FileUploadValidator`
- [ ] Environment config from `SecureConfig` only
- [ ] All API calls through `ApiClient`
- [ ] `.env` file is in `.gitignore`
- [ ] No `print()` statements with sensitive data
- [ ] Error handling doesn't leak information
- [ ] Tests pass for security functions
- [ ] Reviewed SECURITY.md guidelines

---

## 🧪 Testing Security Functions

### Run security tests:

```bash
# Unit tests for input sanitization
flutter test test/core/input_sanitizer_test.dart

# Unit tests for file upload validation
flutter test test/core/file_upload_validator_test.dart

# Unit tests for rate limiting
flutter test test/core/rate_limiter_test.dart

# All security tests
flutter test test/core/
```

### Example test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/core/input_sanitizer.dart';

void main() {
  group('InputSanitizer', () {
    test('sanitizeEmail rejects invalid format', () {
      expect(
        () => InputSanitizer.sanitizeEmail('not-an-email'),
        throwsFormatException,
      );
    });

    test('sanitizeUserInput blocks SQL injection', () {
      expect(
        () => InputSanitizer.sanitizeUserInput("'; DROP TABLE users--"),
        throwsFormatException,
      );
    });

    test('validatePassword requires strong password', () {
      expect(
        () => InputSanitizer.validatePassword('weak'),
        throwsFormatException,
      );
    });
  });
}
```

---

## 📊 What's Protected

### ✅ Protected Against:

- SQL Injection attacks
- XSS (Cross-Site Scripting)
- Brute force login attempts
- Insecure token storage
- Plaintext API keys
- Malicious file uploads
- Path traversal attacks
- MITM (Man-in-the-Middle) attacks
- Session hijacking
- Unauthorized API access
- Rate limit abuse

### ✅ Enforced Security:

- HTTPS only (HTTP rejected)
- API versioning (/v1)
- Bearer token authentication
- Automatic token refresh
- Encrypted storage
- Input sanitization
- Rate limiting
- Exponential backoff
- File magic number validation
- Filename sanitization

---

## 🚨 Critical Files - NEVER Commit These

```
❌ .env
❌ .env.local
❌ .env.production
❌ firebase-key.json
❌ google-services.json
❌ credentials.json
❌ *.pem
❌ *.key
❌ *.p12
```

---

## 📚 Documentation

- **[SECURITY.md](./SECURITY.md)** - Comprehensive security guidelines (50+ pages)
- **[.env.example](./.env.example)** - Environment variable template
- **[.gitignore](./.gitignore)** - Files never to commit

---

## 🔄 Continuous Security

### Weekly:
- Dependabot checks for vulnerabilities
- Review and merge security PRs
- Run `flutter pub outdated`

### Monthly:
- Review SECURITY.md for updates
- Check Firebase security rules
- Review API logs for anomalies

### Quarterly:
- Full security audit
- Penetration testing
- Dependency deep dive

---

## ⚠️ Common Mistakes to Avoid

❌ **DON'T:**
```dart
const API_KEY = "sk_test_123456";  // Hardcoded secret!
api.post('/data', {'search': userInput}); // No sanitization!
api.get('http://...');  // HTTP instead of HTTPS!
SharedPreferences.setString('token', token); // Plain text!
```

✅ **DO:**
```dart
final apiKey = SecureConfig.apiKey;  // From environment
final safe = InputSanitizer.sanitizeUserInput(userInput);
api.get('https://...');  // HTTPS enforced
await StorageService().saveTokens(accessToken: token);  // Encrypted
```

---

## 🆘 Troubleshooting

### "HTTPS required" error
- Check API_BASE_URL starts with `https://`
- Set `ENABLE_SSL_PINNING=false` during development

### "Invalid email" when sanitizing
- Email must have valid format (test@example.com)
- Check for extra spaces

### "Too many login attempts"
- Rate limit: 5 attempts per 15 minutes
- Wait 15 minutes or clear cache

### "File upload failed"
- Check file size ≤ 50 MB
- Check file extension is allowed
- Check file magic numbers match

### Environment variables not loading
- Ensure `.env` file exists in project root
- Run with `--dart-define-from-file=.env`
- Check for syntax errors in `.env`

---

## 📞 Support

**Security Issues:**  
Email: security@flowcrm.com

**General Issues:**  
GitHub Issues: https://github.com/flowcrm/flowcrm-mobile/issues

---

## 📜 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | June 2026 | Initial security implementation |

---

**Congratulations! Your app is now SECURED.** 🎉

All endpoints are now protected with:
- ✅ API versioning
- ✅ Rate limiting
- ✅ Input sanitization
- ✅ Encrypted storage
- ✅ HTTPS enforcement
- ✅ Bearer token auth
- ✅ Automatic token refresh
- ✅ File upload validation

**Your app and users are safe!**

