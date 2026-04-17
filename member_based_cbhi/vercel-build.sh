#!/usr/bin/env bash
set -euo pipefail

RELEASES_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
FLUTTER_ROOT="$HOME/flutter"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "Installing Flutter SDK..."
  RELEASES_JSON="$(curl -fsSL "$RELEASES_URL")"
  ARCHIVE_PATH="$(echo "$RELEASES_JSON" | node -e '
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
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/${ARCHIVE_PATH}" -o /tmp/flutter.tar.xz
  rm -rf "$FLUTTER_ROOT"
  tar -xf /tmp/flutter.tar.xz -C "$HOME"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter config --enable-web
flutter --version
flutter pub get

# CBHI_API_BASE_URL is set as a Vercel environment variable.
# Set it in: Vercel Dashboard → Project Settings → Environment Variables
API_URL="${CBHI_API_BASE_URL:-https://member-based-cbhi.vercel.app/api/v1}"
echo "Building with API: $API_URL"

flutter build web --release \
  --dart-define=CBHI_API_BASE_URL="$API_URL" \
  --dart-define=APP_ENV="production"
