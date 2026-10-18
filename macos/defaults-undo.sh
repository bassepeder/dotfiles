#!/usr/bin/env bash
set -euo pipefail

defaults write com.apple.dock orientation -string bottom
defaults delete com.apple.dock autohide-delay 2>/dev/null || true
defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
# autohide is left on: it was enabled before defaults.sh.

killall Dock
echo "Reverted."
