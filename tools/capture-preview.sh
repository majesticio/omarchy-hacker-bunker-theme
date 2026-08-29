#!/bin/bash
set -euo pipefail

output_path=${1:-preview.png}
original_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
preview_class="org.hacker-bunker.preview"
capture_dir=$(mktemp -d /tmp/hacker-bunker-preview.XXXXXX)
btop_config="$capture_dir/btop.conf"

cleanup() {
  local status=$? address

  while IFS= read -r address; do
    [[ -n $address ]] || continue
    hyprctl dispatch \
      "hl.dsp.window.close({ window = \"address:$address\" })" \
      >/dev/null 2>&1 || true
  done < <(hyprctl clients -j | jq -r --arg class "$preview_class" '.[] | select(.class == $class) | .address')

  hyprctl dispatch \
    "hl.dsp.focus({ workspace = \"$original_workspace\" })" \
    >/dev/null 2>&1 || true
  return "$status"
}
trap cleanup EXIT

hypr_exec() {
  local command
  printf -v command '%q ' "$@"
  hyprctl dispatch "hl.dsp.exec_cmd([[$command]])" >/dev/null
}

# Panels are global shell surfaces and can follow the focused workspace. Keep
# private queues, weather details, and menus out of a public theme preview.
omarchy-shell -q shell hide io.github.majesticio.desert-radio
omarchy-shell -q shell hide io.github.majesticio.desert-weather
omarchy-shell -q shell hide omarchy.menu

hyprctl dispatch 'hl.dsp.focus({ workspace = "99" })' >/dev/null
sleep 0.4

cp "$HOME/.config/btop/btop.conf" "$btop_config"
sed -i 's/^shown_boxes = .*/shown_boxes = "cpu mem"/' "$btop_config"

hypr_exec kitty --class "$preview_class" --title "ABYSS-01 // IDENTITY" \
  bash -lc 'fastfetch; exec sleep infinity'
sleep 0.8

hypr_exec kitty --class "$preview_class" --title "ABYSS-01 // TELEMETRY" \
  btop --config "$btop_config"
sleep 2

screenshot_path=$(OMARCHY_SCREENSHOT_DIR="$capture_dir" \
  omarchy capture screenshot fullscreen save | tail -n 1)

[[ -f $screenshot_path ]]
cp "$screenshot_path" "$output_path"

echo "$output_path"
