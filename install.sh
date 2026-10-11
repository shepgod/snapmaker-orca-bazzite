#!/usr/bin/env bash
# Install Snapmaker Orca on Bazzite (immutable Fedora) via the official release Flatpak.
# Does not layer RPMs on the host — user Flatpak only.
set -euo pipefail

APP_ID=io.github.Snapmaker.Snapmaker_Orca
FLATHUB=https://dl.flathub.org/repo/flathub.flatpakrepo
GITHUB_API=https://api.github.com/repos/Snapmaker/OrcaSlicer/releases/latest
RUNTIME=org.gnome.Platform//49
SDK=org.gnome.Sdk//49

usage() {
  sed -n '2,20p' "$0"
  echo ""
  echo "Options:"
  echo "  --version TAG   Install a specific release tag (e.g. v2.4.0) instead of latest"
  echo "  --bundle PATH   Install from a local .flatpak file (skip download)"
  echo "  --appimage      Install Ubuntu AppImage to ~/Applications instead of Flatpak"
  echo "  --reinstall     Replace existing user Flatpak (flatpak install --reinstall)"
  echo "  --force         Same as --reinstall"
  echo "  -h, --help      Show this help"
}

flatpak_is_installed() {
  flatpak info --user "$APP_ID" &>/dev/null
}

print_launch_hint() {
  echo ""
  echo "Launch with:"
  echo "  flatpak run $APP_ID"
}

resolve_release_tag() {
  if [[ -n "$RELEASE_TAG" ]]; then
    return
  fi
  RELEASE_TAG="$(curl -fsSL "$GITHUB_API" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [[ -n "$RELEASE_TAG" ]] || { echo "Could not determine release version." >&2; exit 1; }
}

asset_version() {
  local ver="${RELEASE_TAG#v}"
  echo "V${ver}"
}

install_appimage() {
  command -v curl >/dev/null || { echo "curl required" >&2; exit 1; }
  resolve_release_tag
  local ver_asset apps_dir dest name url desktop_dir
  ver_asset="$(asset_version)"
  apps_dir="${HOME}/Applications"
  mkdir -p "$apps_dir"
  name="Snapmaker_Orca_Linux_AppImage_Ubuntu2404_${ver_asset}.AppImage"
  url="https://github.com/Snapmaker/OrcaSlicer/releases/download/${RELEASE_TAG}/${name}"
  dest="$apps_dir/Snapmaker_Orca.AppImage"
  echo "==> Downloading AppImage to $dest"
  curl -fsSL -o "$dest" "$url"
  chmod +x "$dest"
  desktop_dir="${HOME}/.local/share/applications"
  mkdir -p "$desktop_dir"
  cat > "$desktop_dir/snapmaker-orca-appimage.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Snapmaker Orca
Comment=FDM slicer (AppImage)
Exec=${dest} %F
Icon=Snapmaker_Orca
Terminal=false
Categories=Graphics;Engineering;
MimeType=model/3mf;application/vnd.ms-3mfdocument;application/sla;application/x-amf;
EOF
  echo "AppImage ready: $dest"
  echo "Desktop entry: $desktop_dir/snapmaker-orca-appimage.desktop"
}

install_flatpak() {
  if flatpak_is_installed && [[ "$REINSTALL" -eq 0 ]]; then
    echo "==> Already installed (user): $APP_ID"
    flatpak info --user "$APP_ID" | sed -n '1,8p'
    echo ""
    echo "Nothing to do. Re-run with --reinstall to replace the app from a bundle."
    print_launch_hint
    return 0
  fi

  flatpak remote-add --user --if-not-exists flathub "$FLATHUB"

  echo "==> GNOME 49 runtime (required by Snapmaker Orca Flatpak)"
  flatpak install --user -y flathub "$RUNTIME" "$SDK" || flatpak install --user -y flathub "$RUNTIME"

  local workdir local_bundle asset url ver_asset
  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' RETURN

  if [[ -n "$BUNDLE" ]]; then
    [[ -f "$BUNDLE" ]] || { echo "Bundle not found: $BUNDLE" >&2; exit 1; }
    local_bundle="$BUNDLE"
  else
    echo "==> Resolving release from Snapmaker/OrcaSlicer"
    resolve_release_tag
    ver_asset="$(asset_version)"
    asset="Snapmaker_Orca-Linux-flatpak_${ver_asset}_${FLATPAK_ARCH}.flatpak"
    url="https://github.com/Snapmaker/OrcaSlicer/releases/download/${RELEASE_TAG}/${asset}"
    local_bundle="$workdir/$asset"
    echo "==> Downloading $url"
    curl -fsSL -o "$local_bundle" "$url"
  fi

  echo "==> Installing Flatpak (user)"
  local install_args=(install --user -y)
  [[ "$REINSTALL" -eq 1 ]] && install_args+=(--reinstall)
  flatpak "${install_args[@]}" "$local_bundle"

  echo ""
  echo "Installed."
  print_launch_hint
}

RELEASE_TAG=""
BUNDLE=""
USE_APPIMAGE=0
REINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) RELEASE_TAG="$2"; shift 2 ;;
    --bundle) BUNDLE="$2"; shift 2 ;;
    --appimage) USE_APPIMAGE=1; shift ;;
    --reinstall|--force) REINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  # Do not `source` os-release: its VERSION= would clobber RELEASE_TAG.
  OS_ID="$(. /etc/os-release && echo "$ID")"
  OS_ID_LIKE="$(. /etc/os-release && echo "$ID_LIKE")"
  if [[ "$OS_ID" != "bazzite" && "$OS_ID_LIKE" != *fedora* ]]; then
    echo "Note: this script targets Bazzite / Fedora Atomic; detected ID=${OS_ID:-unknown}." >&2
  fi
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) FLATPAK_ARCH=x86_64 ;;
  aarch64|arm64) FLATPAK_ARCH=aarch64 ;;
  *) echo "Unsupported CPU architecture: $ARCH" >&2; exit 2 ;;
esac

command -v flatpak >/dev/null || {
  echo "flatpak is required on Bazzite. It should be preinstalled; try: rpm-ostree status" >&2
  exit 1
}

if [[ "$USE_APPIMAGE" -eq 1 ]]; then
  install_appimage
  exit 0
fi

install_flatpak

echo ""
echo "Optional: open 3MF/STL from the file manager after first launch (MIME types register with the app)."
