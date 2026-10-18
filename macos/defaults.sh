#!/usr/bin/env bash
set -euo pipefail

defaults write com.apple.dock orientation -string left
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15

killall Dock
echo "Applied."
