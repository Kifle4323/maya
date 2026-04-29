#!/usr/bin/env bash
set -e

# --- Fix 1: Allow Flutter to run as root (Vercel runs as root) ---
export FLUTTER_ALLOW_ROOT=1
export PUB_ALLOW_SUDO=1

# --- Fix 2: Git safety ---
git config --global --add safe.directory '*' || true

FLUTTER_ROOT="$HOME/flutter"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo ">>> Installing Flutter SDK..."

  # Pin to Flutter 3.41.7 (ships Dart SDK 3.10.x stable)
  ARCHIVE_PATH="stable/linux/flutter_linux_3.41.7-stable.tar.xz"

  echo ">>> Downloading $ARCHIVE_PATH..."
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/${ARCHIVE_PATH}" -o /tmp/flutter.tar.xz
  rm -rf "$FLUTTER_ROOT"
  tar -xf /tmp/flutter.tar.xz -C "$HOME"
  rm /tmp/flutter.tar.xz
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

# Configuration
echo ">>> Configuring Flutter..."
flutter --version
flutter config --no-analytics
flutter config --enable-web

# --- Fix 3: Memory & Build Optimization ---
export DART_VM_OPTIONS="--max-old-space-size=4096"
export NODE_OPTIONS="--max-old-space-size=4096"

# Clean slate first, then fetch dependencies
echo ">>> Cleaning and fetching dependencies..."
flutter clean
flutter pub get

echo ">>> Running dart analyze to surface compile errors early..."
flutter analyze --no-fatal-infos 2>&1 | tail -80 || true

API_URL="${CBHI_API_BASE_URL:-https://maya-u8mf.onrender.com/api/v1}"
# Normalize: strip trailing slash and /api/v1 suffix, then always append /api/v1
API_URL="${API_URL%/}"
API_URL="${API_URL%/api/v1}"
API_URL="${API_URL}/api/v1"
echo ">>> Building for production..."
echo ">>> API Base URL: $API_URL"

flutter build web --release \
  --no-source-maps \
  --base-href / \
  --dart-define=CBHI_API_BASE_URL="$API_URL" \
  --dart-define=APP_ENV="production" \
  --dart2js-optimization=O2 \
  --no-tree-shake-icons \
  --no-pub

echo ">>> Build complete."
