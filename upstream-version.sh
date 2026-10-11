#!/usr/bin/env bash
# Print latest Snapmaker Orca release tag and suggested install command.
set -euo pipefail
API=https://api.github.com/repos/Snapmaker/OrcaSlicer/releases/latest
TAG="$(curl -fsSL "$API" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[[ -n "$TAG" ]] || { echo "Could not fetch latest tag." >&2; exit 1; }
echo "Latest upstream: $TAG"
echo "Install/update Flatpak bundle: ./install.sh --version $TAG --reinstall"
echo "Install/update AppImage:       ./install.sh --appimage --version $TAG"
