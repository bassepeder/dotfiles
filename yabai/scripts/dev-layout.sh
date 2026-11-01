#!/usr/bin/env bash
# Windows stay tiled, never floating: --grid only places floating windows, but
# yabai's directional --focus/--swap/--warp only walk tiled ones.
# --insert toggles if the window already has insert state, so a rebuild can pick the wrong axis; rerun or fix with alt-e.
set -euo pipefail

SPACE=2
LEFT_RATIO=0.4 # terminal column width as a fraction of the split; neovide gets the rest

yabai -m space --focus "$SPACE" 2>/dev/null || true

wait_for_new_window() {
  local app="$1" known="$2" id
  for _ in $(seq 1 50); do
    id="$(yabai -m query --windows | jq -r --arg app "$app" '
      .[] | select(.app == $app) | .id
    ' | grep -vxF "$known" | head -n1)"
    if [ -n "$id" ]; then
      echo "$id"
      return 0
    fi
    sleep 0.1
  done
  echo "timed out waiting for a new $app window" >&2
  return 1
}

x_of() { yabai -m query --windows --window "$1" | jq -r '.frame.x'; }
y_of() { yabai -m query --windows --window "$1" | jq -r '.frame.y'; }
w_of() { yabai -m query --windows --window "$1" | jq -r '.frame.w'; }
is_less() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a < b) }'; }

neovide_id="$(yabai -m query --windows | jq -r '.[] | select(.app=="neovide") | .id' | head -n1)"
if [ -z "$neovide_id" ]; then
  known_neovide="$(yabai -m query --windows | jq -r '.[] | select(.app=="neovide") | .id')"
  neovide >/dev/null 2>&1 &
  neovide_id="$(wait_for_new_window "neovide" "$known_neovide")"
fi
yabai -m window "$neovide_id" --space "$SPACE" 2>/dev/null || true

kitty_ids=()
while IFS= read -r id; do
  kitty_ids+=("$id")
done < <(yabai -m query --windows | jq -r '.[] | select(.app=="kitty") | .id')

while [ "${#kitty_ids[@]}" -lt 2 ]; do
  # bash 3.2 treats an empty "${arr[@]}" as unbound under set -u
  known_kitty="$(printf '%s\n' ${kitty_ids[@]+"${kitty_ids[@]}"})"
  kitty -1 >/dev/null 2>&1 &
  new_id="$(wait_for_new_window "kitty" "$known_kitty")"
  kitty_ids+=("$new_id")
done

# Query order isn't positional; pick top/bottom by frame.y so already_arranged is stable.
if is_less "$(y_of "${kitty_ids[1]}")" "$(y_of "${kitty_ids[0]}")"; then
  term_top="${kitty_ids[1]}"
  term_bottom="${kitty_ids[0]}"
else
  term_top="${kitty_ids[0]}"
  term_bottom="${kitty_ids[1]}"
fi
for id in "$term_top" "$term_bottom"; do
  yabai -m window "$id" --space "$SPACE" 2>/dev/null || true
done

for id in "$neovide_id" "$term_top" "$term_bottom"; do
  is_floating="$(yabai -m query --windows --window "$id" | jq -r '."is-floating"')"
  [ "$is_floating" = "true" ] && yabai -m window "$id" --toggle float
done

already_arranged() {
  is_less "$(x_of "$term_top")" "$(x_of "$neovide_id")" &&
    is_less "$(w_of "$term_top")" "$(w_of "$neovide_id")" &&
    is_less "$(y_of "$term_top")" "$(y_of "$term_bottom")"
}

if ! already_arranged; then
  # Which side --insert puts the incoming window on isn't reliable, so verify and --swap.
  yabai -m window "$neovide_id" --insert west
  yabai -m window "$term_top" --warp "$neovide_id"
  is_less "$(x_of "$term_top")" "$(x_of "$neovide_id")" ||
    yabai -m window "$neovide_id" --swap "$term_top"

  yabai -m window "$term_top" --insert south
  yabai -m window "$term_bottom" --warp "$term_top"
  is_less "$(y_of "$term_top")" "$(y_of "$term_bottom")" ||
    yabai -m window "$term_top" --swap "$term_bottom"

  yabai -m window "$neovide_id" --ratio "abs:$LEFT_RATIO"
fi

yabai -m window --focus "$neovide_id"
