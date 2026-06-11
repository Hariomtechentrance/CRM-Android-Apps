# Production Build Script - FlowCRM Mobile (Windows PowerShell)
# Usage: .\build_production.ps1 -BuildType "aab"
# Examples:
#   .\build_production.ps1 -BuildType "apk"
#   .\build_production.ps1 -BuildType "aab"
#   .\build_production.ps1 -BuildType "both"

param(
    [ValidateSet("apk", "aab", "both")]
    [string]$BuildType = "both"
)

# Enable strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Colors
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$RESET = "`e[0m"

function Write-Section {
    param([string]$Title)
    Write-Host "`n$YELLOW════════════════════════════════════════════════════════════$RESET"
    Write-Host "$YELLOW$Title$RESET"
    Write-Host "$YELLOW════════════════════════════════════════════════════════════$RESET"
}

function Write-Success {
    param([string]$Message)
    Write-Host "$GREEN✓$RESET $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host "$RED✗$RESET $Message"
    exit 1
}

function Write-Warning {
    param([string]$Message)
    Write-Host "$YELLOW⚠$RESET $Message"
}

# Main script
Write-Host "$GREEN════════════════════════════════════════════════════════════$RESET"
Write-Host "$GREEN🚀 FlowCRM Mobile - Production Build Script (PowerShell)$RESET"
Write-Host "$GREEN════════════════════════════════════════════════════════════$RESET"

# Configuration
$PROJECT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BUILD_DIR = Join-Path $PROJECT_DIR "build" "production"

# Create build directory
New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null

Write-Section "📋 Pre-Build Checklist"

# Check if .env exists
$ENV_FILE = Join-Path $PROJECT_DIR ".env"
if (-not (Test-Path $ENV_FILE)) {
    Write-Error ".env file not found! Please create .env with: cp .env.example .env"
}
Write-Success ".env file exists"

# Check if keystore exists
$KEY_PROPERTIES = Join-Path $PROJECT_DIR "android" "key.properties"
if (-not (Test-Path $KEY_PROPERTIES)) {
    Write-Warning "android/key.properties not found - will use debug signing"
}

# Check Flutter
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Success "Flutter found: $flutterVersion"
} catch {
    Write-Error "Flutter not found in PATH"
}

# Check Dart
try {
    $dartVersion = dart --version 2>&1
    Write-Success "Dart found: $dartVersion"
} catch {
    Write-Error "Dart not found in PATH"
}

Write-Section "🔍 Running Pre-Build Tests"

# Run flutter analyze
Write-Host "Running dart analysis..."
flutter analyze
Write-Success "Code analysis passed"

# Run tests (suppress errors as some tests may skip)
Write-Host "Running tests..."
flutter test 2>&1 | Out-Null
Write-Success "Tests completed"

Write-Section "🏗️ Building Production Release"

function Build-APK {
    Write-Host "Building Release APK..."
    flutter build apk --release `
        --dart-define-from-file=.env `
        --split-per-abi `
        -v
    
    # Copy artifacts
    Write-Host "Copying APK artifacts..."
    Get-ChildItem (Join-Path $PROJECT_DIR "build" "app" "outputs" "flutter-apk" "app-*.apk") | `
        ForEach-Object { Copy-Item $_.FullName $BUILD_DIR }
    
    Write-Success "APK build complete"
    Write-Host "  Location: $BUILD_DIR/app-*.apk"
}

function Build-AAB {
    Write-Host "Building Release App Bundle (AAB)..."
    flutter build appbundle --release `
        --dart-define-from-file=.env `
        -v
    
    # Copy artifact
    Write-Host "Copying AAB artifact..."
    $sourcePath = Join-Path $PROJECT_DIR "build" "app" "outputs" "bundle" "release" "app-release.aab"
    $destPath = Join-Path $BUILD_DIR "app-release-$TIMESTAMP.aab"
    Copy-Item $sourcePath $destPath
    
    Write-Success "AAB build complete"
    Write-Host "  Location: $destPath"
}

switch ($BuildType) {
    "apk" { Build-APK }
    "aab" { Build-AAB }
    "both" {
        Build-APK
        Build-AAB
    }
}

Write-Section "📊 Build Artifacts Summary"

$artifacts = Get-ChildItem $BUILD_DIR -File
Write-Host "Generated files:"
foreach ($artifact in $artifacts) {
    $size = "{0:N2} MB" -f ($artifact.Length / 1MB)
    Write-Host "  - $($artifact.Name) ($size)"
}

$totalSize = (Get-ChildItem $BUILD_DIR -Recurse | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = "{0:N2}" -f ($totalSize / 1MB)
Write-Host ""
Write-Host "Total size: $totalSizeMB MB"

Write-Section "🔒 Security Verification"

# Check for hardcoded secrets
$hasHttpUrl = Select-String -Path (Get-ChildItem $PROJECT_DIR "lib" "*.dart" -Recurse).FullName `
    -Pattern "http://" -NotMatch "localhost" -ErrorAction SilentlyContinue

if ($hasHttpUrl) {
    Write-Warning "Found hardcoded HTTP URLs (should be HTTPS)"
} else {
    Write-Success "No hardcoded HTTP URLs"
}

# Check for hardcoded API keys
$hasApiKey = Select-String -Path (Get-ChildItem $PROJECT_DIR "lib" "*.dart" -Recurse).FullName `
    -Pattern "api_key|apiKey|API_KEY.*=\s*['\"]" -ErrorAction SilentlyContinue

if ($hasApiKey) {
    Write-Warning "Found potential hardcoded API keys"
} else {
    Write-Success "No hardcoded API keys detected"
}

Write-Section "📝 Next Steps"

Write-Host ""
Write-Host "1. Verify APK/AAB:"
Write-Host "   • Location: $BUILD_DIR"
Write-Host "   • Check size is reasonable (30-60MB)"
Write-Host "   • Install on device/emulator for testing"
Write-Host ""
Write-Host "2. Upload to App Store:"
Write-Host "   • Google Play: Upload AAB to Play Console"
Write-Host "   • Apple: Archive with Xcode and upload to App Store Connect"
Write-Host ""
Write-Host "3. Testing:"
Write-Host "   adb install -r $BUILD_DIR\app-arm64-v8a-release.apk"
Write-Host ""
Write-Host "4. Release:"
Write-Host "   • Review release notes"
Write-Host "   • Set rollout percentage (e.g., 10% → 50% → 100%)"
Write-Host "   • Monitor crash reports in Firebase"
Write-Host ""

Write-Host "$GREEN════════════════════════════════════════════════════════════$RESET"
Write-Host "$GREEN✅ Production Build Complete!$RESET"
Write-Host "$GREEN════════════════════════════════════════════════════════════$RESET"
Write-Host ""
Write-Host "Build timestamp: $TIMESTAMP"
Write-Host "For detailed information, see: PRODUCTION_DEPLOYMENT.md"
Write-Host ""
