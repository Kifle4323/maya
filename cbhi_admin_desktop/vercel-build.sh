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
  
  # More robust Node script to get the latest stable archive path
  ARCHIVE_PATH=$(curl -fssL "$RELEASES_URL" | node -e '
    let raw = "";
    process.stdin.on("data", chunk => raw += chunk);
    process.stdin.on("end", () => {
      try {
        const data = JSON.parse(raw);
        const stableHash = data.current_release.stable;
        const release = data.releases.find(r => r.hash === stableHash || r.version === stableHash);
        if (release && release.archive) {
          process.stdout.write(release.archive);
        } else {
          console.error("No release found for hash:", stableHash);
          process.exit(1);
        }
      } catch (e) {
        console.error("Error parsing JSON:", e.message);
        process.exit(1);
      }
    });
  ')

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

echo ">>> Running flutter create to refresh platform files..."
flutter create . --platforms web

echo ">>> Running pub get..."
flutter pub get

# --- Fix 3: Memory & Build Optimization ---
# Increase memory limits for the Dart VM and Flutter tool
export DART_VM_OPTIONS="--max-old-space-size=4096"
export NODE_OPTIONS="--max-old-space-size=4096"

API_URL="${CBHI_API_BASE_URL:-https://member-based-cbhi.vercel.app/api/v1}"
echo ">>> Building for production..."
echo ">>> API Base URL: $API_URL"

# Ensure a clean slate
flutter clean

# Use a single-line command to avoid shell escaping issues
flutter build web --release --no-source-maps --base-href / --dart-define=CBHI_API_BASE_URL="$API_URL" --dart-define=APP_ENV="production" --dart2js-optimization=O2 --verbose --no-pub

echo ">>> Build complete."


