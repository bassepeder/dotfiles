# yabai

Built from [bassepeder/yabai](https://github.com/bassepeder/yabai) (upstream plus macOS 27 fixes), not Homebrew. Install or update with:

```bash
curl -fsSL https://raw.githubusercontent.com/bassepeder/yabai/macos27/scripts/install-fork.sh | bash
```

It signs the binary with a stable self-signed cert so Accessibility grants survive rebuilds, and rewrites the scripting addition's sudoers rule for the new sha256. A leftover `~/Library/LaunchAgents/com.koekeishiya.yabai.plist` from upstream will fail to start next to `com.asmvik.yabai`; `launchctl list | grep yabai` should show only the latter.

skhd still comes from the `asmvik/formulae` tap. macOS keys its Accessibility/Input Monitoring grants to the resolved Cellar path, so `brew upgrade` silently breaks them (`must be run with accessibility access! abort..`). `install.sh` checks and prints the exact paths to re-add.
