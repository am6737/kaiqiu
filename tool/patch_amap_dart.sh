#!/usr/bin/env bash
# Patch amap_flutter_{base,map,location} Dart sources in the pub-cache:
# replace the `hashValues(...)` top-level function (removed in Flutter 3.19)
# with `Object.hash(...)`. amap 3.0.0 hasn't been updated.
#
# Idempotent — re-running is a no-op once patched.
# Run after `flutter pub get`, before `flutter build`.

set -euo pipefail

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
PKG_DIR="$PUB_CACHE/hosted/pub.dev"

if [[ ! -d "$PKG_DIR" ]]; then
  echo "pub-cache not found at $PKG_DIR; nothing to patch" >&2
  exit 0
fi

patched=0
while IFS= read -r -d '' dir; do
  while IFS= read -r -d '' file; do
    if grep -q 'hashValues(' "$file"; then
      perl -i -pe 's/\bhashValues\(/Object.hash(/g' "$file"
      echo "patched: ${file#$PKG_DIR/}"
      patched=$((patched + 1))
    fi
  done < <(find "$dir" -name '*.dart' -type f -print0)
done < <(find "$PKG_DIR" -maxdepth 1 -type d \
  \( -name 'amap_flutter_base-*' \
  -o -name 'amap_flutter_map-*' \
  -o -name 'amap_flutter_location-*' \) -print0)

if [[ $patched -eq 0 ]]; then
  echo "no amap Dart files needed patching"
fi
