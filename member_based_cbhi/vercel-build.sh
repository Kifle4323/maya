#!/usr/bin/env bash
set -euo pipefail

RELEASES_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
FLUTTER_ROOT="$HOME/flutter"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "Installing Flutter SDK..."
  RELEASES_JSON="$(curl -fsSL "$RELEASES_URL")"
  ARCHIVE_PATH="$(node -e 'const data = JSON.parse(process.argv[1]); const hash = data.current_release.stable; const release = data.releases.find((item) => item.hash === hash); if (!release) process.exit(1); process.stdout.write(release.archive);' "$RELEASES_JSON")"
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/${ARCHIVE_PATH}" -o /tmp/flutter.tar.xz
  rm -rf "$FLUTTER_ROOT"
  tar -xf /tmp/flutter.tar.xz -C "$HOME"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter config --enable-web
flutter --version
flutter pub get

# CBHI_API_BASE_URL is set as a Vercel environment variable
# pointing to the Railway backend, e.g.:
#   https://cbhi-backend.up.railway.app/api/v1
API_URL="${CBHI_API_BASE_URL:-http://localhost:3000/api/v1}"
echo "Building with API: $API_URL"

flutter build web --release \
  --dart-define=CBHI_API_BASE_URL="$API_URL"
