#!/usr/bin/env bash
set -e

# Allow Flutter to run as root (Vercel runs as root)
export FLUTTER_ALLOW_ROOT=1
export PUB_ALLOW_SUDO=1

# Git safety
git config --global --add safe.directory '*' || true

FLUTTER_ROOT="$HOME/flutter"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo ">>> Installing Flutter SDK..."

  # Pin to Flutter 3.41.7 (Dart 3.7.x — satisfies sdk: ^3.10.1)
  ARCHIVE_PATH="stable/linux/flutter_linux_3.41.7-stable.tar.xz"

  echo ">>> Downloading $ARCHIVE_PATH..."
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/${ARCHIVE_PATH}" -o /tmp/flutter.tar.xz
  rm -rf "$FLUTTER_ROOT"
  tar -xf /tmp/flutter.tar.xz -C "$HOME"
  rm /tmp/flutter.tar.xz
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

echo ">>> Configuring Flutter..."
flutter --version
flutter config --no-analytics
flutter config --enable-web

# Memory optimization
export DART_VM_OPTIONS="--max-old-space-size=4096"
export NODE_OPTIONS="--max-old-space-size=4096"

# Clean first, then fetch dependencies (steering rule: clean THEN pub get)
echo ">>> Cleaning and fetching dependencies..."
flutter clean
flutter pub get

# The backend is deployed at member-based-cbhi.vercel.app.
# Override by setting CBHI_API_BASE_URL in the Vercel project environment variables.
API_URL="${CBHI_API_BASE_URL:-https://member-based-cbhi.vercel.app/api/v1}"
echo ">>> Building for production..."
echo ">>> API Base URL: $API_URL"

flutter build web --release \
  --no-tree-shake-icons \
  --no-source-maps \
  --no-pub \
  --base-href / \
  --dart-define=CBHI_API_BASE_URL="$API_URL" \
  --dart-define=APP_ENV="production"

echo ">>> Build complete."
