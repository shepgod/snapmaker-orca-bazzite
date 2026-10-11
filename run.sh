#!/usr/bin/env bash
# Launch Snapmaker Orca Flatpak (use ./launch-appimage.sh if web UI / login fails).
set -euo pipefail

APP_ID=io.github.Snapmaker.Snapmaker_Orca
DATA="${HOME}/.var/app/${APP_ID}"

usage() {
  sed -n '2,5p' "$0"
  echo ""
  echo "Options:"
  echo "  --reset-config   Move aside Flatpak config (fixes instant crash / exit 139)"
  echo "  --x11            Force XWayland (if Wayland web panels stay blank)"
  echo "  -h, --help"
}

RESET=0
FORCE_X11=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset-config) RESET=1; shift ;;
    --x11) FORCE_X11=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

if [[ "$RESET" -eq 1 ]]; then
  if [[ -d "${DATA}/config" ]]; then
    bak="${DATA}/config.bak.$(date +%Y%m%d-%H%M%S)"
    mv "${DATA}/config" "$bak"
    echo "Moved ${DATA}/config -> $bak"
  else
    echo "No config dir at ${DATA}/config"
  fi
fi

if flatpak override --user --show "$APP_ID" 2>/dev/null | grep -q 'GDK_SCALE='; then
  echo "Warning: GDK_SCALE override can crash Flatpak on Bazzite — run:" >&2
  echo "  flatpak override --user --reset $APP_ID && ./configure-flatpak-ui.sh" >&2
fi

# Second instance exits with GLib errors; forward args to the running copy if possible.
if flatpak ps 2>/dev/null | grep -q "$APP_ID"; then
  echo "Snapmaker Orca is already running — focus that window or flatpak kill $APP_ID" >&2
  exit 0
fi

RUN_ENV=(--env=WEBKIT_DISABLE_DMABUF_RENDERER=1 --env=WEBKIT_DISABLE_COMPOSITING_MODE=1 --env=LC_ALL=C.UTF-8)
if [[ "$FORCE_X11" -eq 1 ]]; then
  RUN_ENV+=(--env=GDK_BACKEND=x11)
fi

exec flatpak run "${RUN_ENV[@]}" "$APP_ID" "$@"
