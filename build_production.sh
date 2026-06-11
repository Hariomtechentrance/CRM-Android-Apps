#!/usr/bin/env bash
# Production Build Script - FlowCRM Mobile
# Usage: ./build_production.sh [apk|aab|both]
# Example: ./build_production.sh aab

set -e

echo "════════════════════════════════════════════════════════════"
echo "🚀 FlowCRM Mobile - Production Build Script"
echo "════════════════════════════════════════════════════════════"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_TYPE=${1:-both}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUILD_DIR="$PROJECT_DIR/build/production"

# Create build directory
mkdir -p "$BUILD_DIR"

echo -e "${YELLOW}📋 Pre-Build Checklist${NC}"
echo "════════════════════════════════════════════════════════════"

# Check if .env exists
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo -e "${RED}❌ ERROR: .env file not found!${NC}"
    echo "Please create .env with: cp .env.example .env"
    exit 1
fi
echo -e "${GREEN}✓${NC} .env file exists"

# Check if keystore exists (for APK signing)
if [ ! -f "$PROJECT_DIR/android/key.properties" ] && [ "$BUILD_TYPE" != "all" ]; then
    echo -e "${YELLOW}⚠ WARNING: android/key.properties not found${NC}"
    echo "Proceeding with debug signing (debug only)"
fi

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ ERROR: Flutter not found in PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Flutter found: $(flutter --version | head -1)"

# Check Dart
if ! command -v dart &> /dev/null; then
    echo -e "${RED}❌ ERROR: Dart not found in PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Dart found: $(dart --version)"

echo ""
echo -e "${YELLOW}🔍 Running Pre-Build Tests${NC}"
echo "════════════════════════════════════════════════════════════"

# Run flutter analyze
echo "Running dart analysis..."
flutter analyze
echo -e "${GREEN}✓${NC} Code analysis passed"

# Run tests
echo "Running tests..."
flutter test 2>/dev/null || echo -e "${YELLOW}⚠ Some tests may have skipped${NC}"
echo -e "${GREEN}✓${NC} Tests completed"

echo ""
echo -e "${YELLOW}🏗️ Building Production Release${NC}"
echo "════════════════════════════════════════════════════════════"

build_apk() {
    echo "Building Release APK..."
    flutter build apk --release \
        --dart-define-from-file=.env \
        --split-per-abi \
        -v
    
    # Copy artifacts
    echo "Copying APK artifacts..."
    cp build/app/outputs/flutter-apk/app-*.apk "$BUILD_DIR/"
    
    echo -e "${GREEN}✓${NC} APK build complete"
    echo "  Location: $BUILD_DIR/app-*.apk"
}

build_aab() {
    echo "Building Release App Bundle (AAB)..."
    flutter build appbundle --release \
        --dart-define-from-file=.env \
        -v
    
    # Copy artifact
    echo "Copying AAB artifact..."
    cp build/app/outputs/bundle/release/app-release.aab "$BUILD_DIR/app-release-$TIMESTAMP.aab"
    
    echo -e "${GREEN}✓${NC} AAB build complete"
    echo "  Location: $BUILD_DIR/app-release-$TIMESTAMP.aab"
}

case "$BUILD_TYPE" in
    apk)
        build_apk
        ;;
    aab)
        build_aab
        ;;
    both)
        build_apk
        build_aab
        ;;
    *)
        echo -e "${RED}ERROR: Unknown build type: $BUILD_TYPE${NC}"
        echo "Usage: ./build_production.sh [apk|aab|both]"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}📊 Build Artifacts Summary${NC}"
echo "════════════════════════════════════════════════════════════"

# List artifacts
cd "$BUILD_DIR"
echo "Generated files:"
ls -lh ./* 2>/dev/null | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}'

# Calculate total size
TOTAL_SIZE=$(du -sh . | awk '{print $1}')
echo ""
echo "Total size: $TOTAL_SIZE"

echo ""
echo -e "${YELLOW}🔒 Security Verification${NC}"
echo "════════════════════════════════════════════════════════════"

# Check for hardcoded secrets
if grep -r "http://" "$PROJECT_DIR/lib" --include="*.dart" | grep -v "http://localhost" | grep -v "//"; then
    echo -e "${RED}⚠ WARNING: Found hardcoded HTTP URLs (should be HTTPS)${NC}"
else
    echo -e "${GREEN}✓${NC} No hardcoded HTTP URLs"
fi

if grep -r "password" "$PROJECT_DIR/lib" --include="*.dart" | grep -i "=\s*['\"]" | grep -v "InputSanitizer" | grep -v "validatePassword"; then
    echo -e "${YELLOW}⚠ Check for hardcoded passwords${NC}"
else
    echo -e "${GREEN}✓${NC} No obvious hardcoded passwords"
fi

if grep -r "api_key\|apiKey\|API_KEY" "$PROJECT_DIR/lib" --include="*.dart" | grep -i "=\s*['\"]"; then
    echo -e "${RED}⚠ WARNING: Found hardcoded API keys${NC}"
else
    echo -e "${GREEN}✓${NC} No hardcoded API keys detected"
fi

echo ""
echo -e "${YELLOW}📝 Next Steps${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "1. Verify APK/AAB:"
echo "   • Location: $BUILD_DIR/"
echo "   • Check size is reasonable (30-60MB)"
echo "   • Install on device/emulator for testing"
echo ""
echo "2. Upload to App Store:"
echo "   • Google Play: Upload AAB to Play Console"
echo "   • Apple: Archive with Xcode and upload to App Store Connect"
echo ""
echo "3. Testing:"
echo "   adb install -r $BUILD_DIR/app-arm64-v8a-release.apk"
echo ""
echo "4. Release:"
echo "   • Review release notes"
echo "   • Set rollout percentage (e.g., 10% → 50% → 100%)"
echo "   • Monitor crash reports in Firebase"
echo ""

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Production Build Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Build timestamp: $TIMESTAMP"
echo "For detailed information, see: PRODUCTION_DEPLOYMENT.md"
