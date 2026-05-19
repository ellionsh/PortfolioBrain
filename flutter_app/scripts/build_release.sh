#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:-apk}"

case "$target" in
  apk)
    flutter build apk --release --dart-define=PB_CLEAR_RELEASE_PREFS=true
    ;;
  aab)
    flutter build appbundle --release --dart-define=PB_CLEAR_RELEASE_PREFS=true
    ;;
  ios)
    flutter build ios --release --dart-define=PB_CLEAR_RELEASE_PREFS=true
    ;;
  *)
    echo "Usage: $0 [apk|aab|ios]"
    exit 2
    ;;
esac
