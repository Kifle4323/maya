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
  RELEASES_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
  
  # Pin to Flutter 3.41.7 (Dart 3.7.x — satisfies sdk: ^3.10.1)
  ARCHIVE_PATH="stable/linux/flutter_linux_3.41.7-stable.tar.xz"

  if [ -z "$ARCHIVE_PATH" ]; then
    echo "ERROR: Failed to determine Flutter archive path."
    exit 1
  fi

  echo ">>> Downloading $ARCHIVE_PATH..."
  curl -fssL "https://storage.googleapis.com/flutter_infra_release/releases/${ARCHIVE_PATH}" -o /tmp/flutter.tar.xz
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
flutter doctor -v

# --- Memory optimization ---
export DART_VM_OPTIONS="--max-old-space-size=4096"
export NODE_OPTIONS="--max-old-space-size=4096"

API_URL="${CBHI_API_BASE_URL:-https://member-based-cbhi.vercel.app/api/v1}"
echo ">>> Building for production..."
echo ">>> API Base URL: $API_URL"

flutter clean
flutter pub get

# Use a single-line command to avoid shell escaping issues
flutter build web --release --no-tree-shake-icons --no-source-maps --no-pub --base-href / \
  --dart-define=CBHI_API_BASE_URL="$API_URL" \
  --dart-define=APP_ENV="production"

echo ">>> Build complete."


