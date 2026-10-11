#!/usr/bin/env bash
# Preferred launcher on Bazzite: official AppImage (WebKit/login works better than Flatpak here).
set -euo pipefail

APPIMAGE="${SNAPMAKER_ORCA_APPIMAGE:-${HOME}/Applications/Snapmaker_Orca.AppImage}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -x "$APPIMAGE" ]]; then
  echo "AppImage not found at $APPIMAGE — installing v2.4.0…" >&2
  "$SCRIPT_DIR/install.sh" --appimage --version v2.4.0
fi

exec "$APPIMAGE" "$@"
