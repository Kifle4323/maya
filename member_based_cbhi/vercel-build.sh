#!/usr/bin/env bash
set -euo pipefail

# ── Fix 1: Allow Flutter to run as root (Vercel runs as root) ────────────────
export FLUTTER_ALLOW_ROOT=1 PUB_ALLOW_SUDO=1

# ── Fix 2: Fix git "dubious ownership" errors ────────────────────────────────
git config --global --add safe.directory '*'

FLUTTER_ROOT="/vercel/flutter"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "Installing Flutter SDK..."

  # Fetch latest stable release archive path via stdin (avoids ARG_MAX limit)
  RELEASES_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
  ARCHIVE_PATH="$(curl -fsSL "$RELEASES_URL" | node -e '
    let raw = "";
    process.stdin.on("data", d => raw += d);
    process.stdin.on("end", () => {
      const data = JSON.parse(raw);
      const hash = data.current_release.stable;
      const release = data.releases.find(r => r.hash === hash);
      if (!release) process.exit(1);
      process.stdout.write(release.archive);
    });
  ')"

  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/${ARCHIVE_PATH}" \
    -o /tmp/flutter.tar.xz
  rm -rf "$FLUTTER_ROOT"
  mkdir -p /vercel
  tar -xf /tmp/flutter.tar.xz -C /vercel
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter config --enable-web --no-analytics
flutter --version
flutter pub get

API_URL="${CBHI_API_BASE_URL:-https://member-based-cbhi.vercel.app/api/v1}"
echo "Building with API: $API_URL"

flutter build web --release \
  --dart-define=CBHI_API_BASE_URL="$API_URL" \
  --dart-define=APP_ENV="production"
