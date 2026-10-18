#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WALLPAPER="${1:-$REPO/wallpaper/aperture.jpg}"

[ -f "$WALLPAPER" ] || {
  echo "no such wallpaper: $WALLPAPER" >&2
  exit 1
}

osascript -e "tell application \"System Events\" to set picture of every desktop to \"$WALLPAPER\""
echo "wallpaper set: $WALLPAPER"
