# 🚀 Production Deployment Guide - FlowCRM Mobile

**Version:** 1.0.0  
**Last Updated:** June 2026  
**Status:** Ready for Production Release

---

## 📋 Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Signing Configuration](#signing-configuration)
3. [Build Instructions](#build-instructions)
4. [Release Artifacts](#release-artifacts)
5. [App Store Deployment](#app-store-deployment)
6. [Post-Deployment Verification](#post-deployment-verification)
7. [Monitoring & Rollback](#monitoring--rollback)
8. [Troubleshooting](#troubleshooting)

---

## ✅ Pre-Deployment Checklist

### Code Quality
- [ ] All tests passing: `flutter test`
- [ ] No lint errors: `flutter analyze`
- [ ] No TODO comments in production code
- [ ] Security audit completed (see SECURITY_IMPLEMENTATION_SUMMARY.md)
- [ ] All security modules initialized
- [ ] Input validation active on all user inputs
- [ ] Rate limiting enabled on sensitive endpoints
- [ ] File upload validation in place

### Configuration
- [ ] `.env` file created with production values (NEVER commit this)
- [ ] `API_BASE_URL` points to production backend (HTTPS)
- [ ] `ENABLE_SSL_PINNING` set to `true` for production
- [ ] Firebase configuration matches production project
- [ ] All environment variables properly set
- [ ] Database credentials in backend (never in mobile app)
- [ ] API keys in backend (never in mobile app)

### Security Verification
- [ ] No hardcoded secrets in code
- [ ] No private keys in repository
- [ ] All credentials in environment variables only
- [ ] Firebase credentials configured
- [ ] SSL/TLS certificates valid and pinned
- [ ] Token encryption enabled in storage_service.dart
- [ ] Rate limiting properly configured

### Backend Readiness
- [ ] Production database configured
- [ ] All `/v1` API endpoints tested
- [ ] Authentication server operational
- [ ] File upload storage ready
- [ ] Email service configured
- [ ] Payment processing (if applicable) configured
- [ ] CDN/asset delivery configured
- [ ] Monitoring and logging active

### Testing
- [ ] Manual end-to-end testing completed
- [ ] Tested on Android 12+ and iOS 14+
- [ ] Network resilience tested
- [ ] Rate limiting tested
- [ ] File upload tested
- [ ] Authentication flow tested
- [ ] Session expiry tested
- [ ] Error handling verified
- [ ] Performance acceptable (cold start < 3s)

### Signing & Build
- [ ] Release keystore created and backed up
- [ ] Keystore password stored securely (not in Git)
- [ ] Signing configuration added to build.gradle.kts
- [ ] Version code incremented: `versionCode = X`
- [ ] Version name set: `versionName = "1.0.0"`

### Git & Version Control
- [ ] `.env` in .gitignore (verified)
- [ ] Keystore file in .gitignore (verified)
- [ ] No secrets in commit history
- [ ] All security code committed
- [ ] Version tag created: `git tag v1.0.0`
- [ ] Release branch created: `git branch release/1.0.0`

### Documentation
- [ ] Release notes written
- [ ] Deployment checklist completed
- [ ] Rollback procedure documented
- [ ] Known issues documented
- [ ] System requirements specified

---

## 🔐 Signing Configuration

### Step 1: Create Release Keystore

```bash
# Generate a new keystore for production (do this once per app)
keytool -genkey -v -keystore flowcrm_release.keystore \
  -keyalg RSA -keysize 2048 -validity 10950 \
  -alias flowcrm_prod_key

# Output: flowcrm_release.keystore
# Store this file SECURELY (NOT in Git, NOT on GitHub)
# Back up to secure location: encrypted external drive, password manager, etc.
```

**CRITICAL:** 
- This keystore is required to sign future updates
- Without it, you cannot push updates to the app store
- Anyone with this keystore can sign apps as you
- Store password securely (use a password manager)

### Step 2: Add Signing Configuration

Create file: `android/key.properties`

```properties
storeFile=../flowcrm_release.keystore
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=flowcrm_prod_key
keyPassword=YOUR_KEY_PASSWORD
```

**IMPORTANT:** Add to `.gitignore`:

```bash
android/key.properties
*.keystore
*.jks
```

### Step 3: Update build.gradle.kts

Replace the release signing configuration in `android/app/build.gradle.kts`:

```kotlin
android {
    // ... existing config ...

    signingConfigs {
        release {
            keyAlias = System.getenv("FLOWCRM_KEY_ALIAS") ?: properties["keyAlias"] ?: ""
            keyPassword = System.getenv("FLOWCRM_KEY_PASSWORD") ?: properties["keyPassword"] ?: ""
            storeFile = file(System.getenv("FLOWCRM_STORE_FILE") ?: properties["storeFile"] ?: "")
            storePassword = System.getenv("FLOWCRM_STORE_PASSWORD") ?: properties["storePassword"] ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

---

## 🏗️ Build Instructions

### Build for Production (APK)

```bash
# Navigate to project directory
cd /path/to/flowcrm_mobile

# Build release APK (requires signing config)
flutter build apk --release \
  --dart-define-from-file=.env \
  --split-per-abi

# Output: build/app/outputs/flutter-apk/app-*.apk
```

### Build for Production (App Bundle - Recommended for Google Play)

```bash
# Build Android App Bundle (smaller, optimized)
flutter build appbundle --release \
  --dart-define-from-file=.env

# Output: build/app/outputs/bundle/release/app-release.aab
```

### Build for Production (iOS)

```bash
# Build iOS release
flutter build ios --release \
  --dart-define-from-file=.env

# Archive in Xcode (use Xcode: Product → Archive)
# Or via command line:
cd ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner -configuration Release \
  -derivedDataPath build \
  -archivePath build/Runner.xcarchive archive

# Output: build/Runner.xcarchive
```

### Build Settings

**All production builds include:**
- ✅ Minification enabled (code obfuscation)
- ✅ Resource shrinking (unused resources removed)
- ✅ Security config validation
- ✅ Environment variables loaded from .env
- ✅ HTTPS enforcement
- ✅ Input sanitization
- ✅ Rate limiting active
- ✅ Token encryption

---

## 📦 Release Artifacts

### APK Structure

```
build/app/outputs/flutter-apk/
├── app-armeabi-v7a-release.apk    (ARM 32-bit)
├── app-arm64-v8a-release.apk      (ARM 64-bit - REQUIRED)
├── app-x86-release.apk            (Intel x86)
└── app-x86_64-release.apk         (Intel x64 - for emulator)
```

**For Google Play:** Upload `app-release.aab` (App Bundle)

### Artifact Verification

```bash
# Verify signing certificate
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Check APK structure
aapt dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Install for testing
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### Build Output Size

Expect:
- APK: 40-50 MB per architecture
- App Bundle: 20-30 MB (Google Play optimizes per device)
- iOS IPA: 60-80 MB

---

## 📱 App Store Deployment

### Google Play Store

#### Prerequisites
1. Google Play Developer Account ($25 one-time fee)
2. App signed with release keystore
3. App Bundle (AAB) ready
4. Screenshots, descriptions, graphics

#### Upload Steps

1. **Visit [Google Play Console](https://play.google.com/console)**

2. **Create Release**
   - Select app → Releases → Create new release
   - Upload `app-release.aab`

3. **Fill App Details**
   - Title: "FlowCRM - Business Management"
   - Description: Your app description
   - Screenshots: Add 2-5 screenshots
   - Feature graphic: 1024x500 PNG
   - Category: Business

4. **Set Permissions**
   - Review permissions in app/src/main/AndroidManifest.xml
   - Explain why each permission is needed

5. **Target Audience**
   - Select minimum age
   - Select countries for release

6. **Content Rating**
   - Complete content rating questionnaire
   - Get content rating certificate

7. **Review & Deploy**
   - Review all details
   - Select "Internal testing" for first release
   - Get feedback before public release
   - Then promote to production

### Apple App Store

#### Prerequisites
1. Apple Developer Account ($99/year)
2. App signed with Apple distribution certificate
3. Provisioning profile created
4. Build archived in Xcode

#### Upload Steps

1. **Archive in Xcode**
   ```
   Product → Archive → Validate App → Upload to App Store
   ```

2. **Transporter App** (alternative)
   ```bash
   # Download from Apple App Store
   # Login with Apple ID
   # Select .ipa file and upload
   ```

3. **App Store Connect**
   - View upload in App Store Connect
   - Add app information
   - Submit for review
   - Apple reviews (typically 24 hours)
   - App goes live

---

## ✅ Post-Deployment Verification

### Immediate (Day 0)

- [ ] App appears in store (may take 30min-2 hours)
- [ ] Download and install from store
- [ ] Test login flow
- [ ] Test basic functionality
- [ ] Check network requests (use Charles Proxy)
- [ ] Verify rate limiting active
- [ ] Confirm HTTPS only
- [ ] Monitor crash reports (Firebase)

### First 24 Hours

- [ ] Monitor for crash reports
- [ ] Check analytics: active users, session duration
- [ ] Review logs for errors
- [ ] Monitor API response times
- [ ] Verify no 500 errors
- [ ] Check rate limiting working
- [ ] Verify encryption working (check storage)

### First Week

- [ ] Monitor server performance
- [ ] Review user feedback
- [ ] Check for critical bugs
- [ ] Monitor crash rates
- [ ] Verify all endpoints working
- [ ] Monitor data sync
- [ ] Check memory usage trends
- [ ] Review security logs

### Ongoing (Monthly)

- [ ] Security patches applied
- [ ] Dependencies updated via Dependabot
- [ ] Performance monitored
- [ ] User engagement metrics
- [ ] Crash rate < 0.5%
- [ ] Session success rate > 99%

---

## 🔙 Monitoring & Rollback

### Monitoring Dashboard

**Firebase Console** → Your Project → Analytics/Performance/Crashlytics

**Track:**
- Active users (DAU/MAU)
- Crash-free users
- API latency
- Network errors
- User retention

### Setting Up Alerts

Firebase → Alerts → Create threshold alerts for:
- Crash-free sessions < 95%
- Latency > 3 seconds
- Error rate > 1%

### Rollback Procedure

If critical issue discovered:

**Google Play:**
1. Google Play Console → Releases → Production
2. Create new version with fix
3. Upload new APK/AAB
4. Review (expedited) 
5. Deploy

**Apple App Store:**
1. Fix issue locally
2. Increment build number
3. Archive in Xcode
4. Upload via Transporter
5. Submit for review (expedited)

**Minimum Time to Rollback:**
- Google Play: 2-4 hours (after approval)
- Apple App Store: 12-24 hours (review time)

---

## 🐛 Troubleshooting

### Build Fails: "Keystore not found"

```bash
# Verify keystore file exists
ls -la android/key.properties
ls -la flowcrm_release.keystore

# Solution: Ensure both files exist and path is correct
```

### Build Fails: "Resource shrinking errors"

```bash
# Solution: Add keep rules for specific classes
# Create android/app/proguard-rules.pro:
-keep class com.flowcrm.** { *; }
-keepclassmembers class * {
  public protected *;
}
```

### APK Won't Install: "Certificate mismatch"

```bash
# You're using different keystore
# Solution: Uninstall app first
adb uninstall com.flowcrm.flowcrm_mobile

# Then reinstall
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### App Crashes on Startup

**Check logs:**
```bash
adb logcat | grep "FlowCRM"
```

**Common causes:**
- `SecureConfig.validateConfig()` failed → Check .env variables
- Firebase not initialized → Check google-services.json
- Missing permission → Check AndroidManifest.xml

**Solution:**
1. Check Firebase console for errors
2. Verify .env file has all required variables
3. Check Crashlytics for stack trace
4. Review recent changes in Git

### Rate Limiting Triggered

If users report "Too many requests":

**Causes:**
- Initial sync requests too aggressive
- Background refresh too frequent
- Network retry loop

**Solutions:**
- Review rate limits in `rate_limiter.dart`
- Adjust API_RATE_LIMIT_REQUESTS in .env
- Reduce background sync frequency
- Implement request batching

### Memory Usage High

If app using > 200MB RAM:

**Causes:**
- Image caching too aggressive
- List not recycled (FutureBuilder creating new instances)
- Listeners not disposed

**Solutions:**
1. Add memory profiling: Flutter DevTools → Memory tab
2. Check for unclosed streams
3. Verify image cache size: `imageCache.maximumSize = 100`
4. Profile with DevTools

### Poor Performance on Startup

**Causes:**
- SecureConfig validation slow
- Firebase initialization slow
- API call on first screen

**Solutions:**
1. Move API calls to background
2. Use lazy loading for data
3. Profile with Flutter DevTools → Timeline tab
4. Pre-cache critical data

---

## 📞 Emergency Contacts

**App Issues:** `support@flowcrm.com`  
**Security Issues:** `security@flowcrm.com`  
**Backend Issues:** `backend-team@flowcrm.com`

---

## 📚 Related Documentation

- [SECURITY.md](SECURITY.md) - Security implementation details
- [QUICK_START.md](QUICK_START.md) - Integration guide
- [SECURITY_SETUP.md](SECURITY_SETUP.md) - Security setup
- [README.md](README.md) - Project overview

---

## ✨ Production Release Checklist

```
FINAL VERIFICATION:
☐ All tests passing
☐ Security audit complete
☐ All environment variables set
☐ Keystore backed up
☐ Build successful (no warnings)
☐ APK/AAB size acceptable
☐ App installs and runs
☐ All features working
☐ No hardcoded secrets
☐ Rate limiting active
☐ HTTPS enforced
☐ Input validation active
☐ Crash reporting enabled
☐ Analytics enabled
☐ Monitoring alerts set
☐ Rollback procedure tested
☐ Team trained on deployment
☐ Documentation up to date

APPROVED FOR DEPLOYMENT: _______________________

Date: ________________  Signature: ________________
```

---

**Your app is now ready for production deployment!** 🎉

For any issues, refer to [SECURITY_IMPLEMENTATION_SUMMARY.md](SECURITY_IMPLEMENTATION_SUMMARY.md) for complete implementation details.
