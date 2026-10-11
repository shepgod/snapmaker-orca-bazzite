#!/usr/bin/env bash
# One-time Flatpak permission/env fixes for Snapmaker Orca on Bazzite (Wayland + NVIDIA + HiDPI).
set -euo pipefail

APP_ID=io.github.Snapmaker.Snapmaker_Orca

if ! flatpak info --user "$APP_ID" &>/dev/null; then
  echo "Install the app first: ./install.sh" >&2
  exit 1
fi

echo "==> Applying user overrides for $APP_ID"

flatpak override --user "$APP_ID" \
  --socket=wayland \
  --socket=fallback-x11 \
  --device=dri

# WebKit/Flutter panel on NVIDIA in GNOME 49 runtime (see upstream entrypoint + Bambu #3440).
flatpak override --user "$APP_ID" \
  --env=WEBKIT_DISABLE_DMABUF_RENDERER=1 \
  --env=WEBKIT_DISABLE_COMPOSITING_MODE=1 \
  --env=LC_ALL=C.UTF-8

# OAuth / saved login via Secret Service (KWallet on KDE variants).
flatpak override --user "$APP_ID" \
  --talk-name=org.freedesktop.secrets \
  --talk-name=org.kde.KWallet5 \
  --talk-name=org.freedesktop.portal.Desktop \
  --talk-name=org.freedesktop.portal.OpenURI

# Do NOT set GDK_SCALE here: Bazzite/GNOME already applies scaling-factor; doubling it
# breaks WebKit panels and can trigger early GLib/GTK crashes in the Flatpak build.
# Opt-in only: ./configure-flatpak-ui.sh --gdk-scale 2
if [[ "${1:-}" == "--gdk-scale" && -n "${2:-}" ]]; then
  flatpak override --user "$APP_ID" --env="GDK_SCALE=$2"
  echo "    GDK_SCALE=$2 (manual)"
  shift 2
fi

echo "==> Current overrides:"
flatpak override --user --show "$APP_ID" || true
echo ""
echo "Launch with: ./run.sh"
