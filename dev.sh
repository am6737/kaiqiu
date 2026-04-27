#!/usr/bin/env bash
set -e

PORT="${1:-8080}"
HOST="0.0.0.0"
BUILD_DIR="build/web"
FLUTTER="$HOME/flutter/bin/flutter"

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
  fi
}
trap cleanup EXIT

build() {
  echo "🔨 Building Flutter web..."
  $FLUTTER build web --release --quiet
  echo "✅ Build complete"
}

serve() {
  kill $(lsof -t -i:"$PORT") 2>/dev/null || true
  cd "$BUILD_DIR"
  python3 -m http.server "$PORT" --bind "$HOST" &
  SERVER_PID=$!
  cd - >/dev/null
  echo "🌐 Serving on http://$HOST:$PORT"
}

build
serve

echo ""
echo "Commands:"
echo "  r  — rebuild & refresh"
echo "  q  — quit"
echo ""

while true; do
  read -rsn1 key
  case "$key" in
    r|R)
      echo ""
      build
      echo "🔄 Refresh your browser to see changes"
      ;;
    q|Q)
      echo "Bye!"
      exit 0
      ;;
  esac
done
