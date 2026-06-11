#!/usr/bin/env bash
set -euo pipefail

# This script builds the Flutter web app and serves the output
# Railpack looks for a start script to determine how to build/run the app.

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter not found in PATH. Install Flutter or ensure it's available in the build environment."
  exit 1
fi

echo "Running flutter pub get..."
flutter pub get

echo "Building Flutter web (release)..."
flutter build web --release

PORT=${PORT:-8080}

if command -v python3 >/dev/null 2>&1; then
  echo "Serving build/web on port $PORT using python3 http.server"
  python3 -m http.server "$PORT" --directory build/web
elif command -v python >/dev/null 2>&1; then
  echo "Serving build/web on port $PORT using python http.server"
  python -m http.server "$PORT" --directory build/web
else
  echo "Build produced files at build/web. Please serve them with a static file server."
  echo "Example: install python and re-run this script, or use 'npx serve build/web' on Node.js environments."
  exit 0
fi
