#!/usr/bin/env bash
# Build Snapmaker Orca Flatpak on Bazzite without layering devel RPMs on the host.
# Uses a Fedora toolbox/distrobox when flatpak-builder or build tools are missing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="${ORCA_REPO:-https://github.com/Snapmaker/OrcaSlicer.git}"
REPO_REF="${ORCA_REF:-main}"
SRC="${ORCA_SRC:-$ROOT/OrcaSlicer-src}"
BOX="${ORCA_DISTROBOX:-orca-build}"
USE_BOX=0

usage() {
  sed -n '2,12p' "$0"
  echo ""
  echo "Environment:"
  echo "  ORCA_REPO, ORCA_REF, ORCA_SRC, ORCA_DISTROBOX"
  echo ""
  echo "Options:"
  echo "  --box         Build inside distrobox '$BOX' (recommended on clean Bazzite)"
  echo "  -j N          Parallel jobs (passed to build_flatpak.sh)"
  echo "  --low-memory  Cap parallel jobs (OOM-safe)"
  echo "  -i            Install GNOME 49 Flatpak SDK/runtime before build"
}

JOBS=""
LOW_MEM=0
INSTALL_RT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --box) USE_BOX=1; shift ;;
    -j) JOBS="$2"; shift 2 ;;
    --low-memory) LOW_MEM=1; shift ;;
    -i) INSTALL_RT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

host_has_builder() {
  command -v flatpak-builder >/dev/null && command -v cmake >/dev/null && command -v ninja >/dev/null
}

ensure_source() {
  if [[ ! -d "$SRC/.git" ]]; then
    echo "==> Cloning $REPO_URL ($REPO_REF)"
    git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$SRC"
    (cd "$SRC" && git lfs pull 2>/dev/null || true)
  else
    echo "==> Using existing clone: $SRC"
    (cd "$SRC" && git fetch --depth 1 origin "$REPO_REF" && git checkout "$REPO_REF" && git pull --ff-only)
  fi
}

run_build() {
  local args=()
  [[ -n "$JOBS" ]] && args+=(-j "$JOBS")
  [[ "$LOW_MEM" -eq 1 ]] && args+=(--low-memory)
  [[ "$INSTALL_RT" -eq 1 ]] && args+=(-i)
  cd "$SRC"
  ./build_flatpak.sh "${args[@]}"
  echo ""
  echo "Bundle(s) in: $SRC/Snapmaker_Orca-Linux-flatpak_*.flatpak"
  echo "Install: $ROOT/install.sh --bundle /path/to/bundle.flatpak"
}

if [[ "$USE_BOX" -eq 0 ]] && ! host_has_builder; then
  echo "flatpak-builder/cmake/ninja not all on host — use --box or install:"
  echo "  distrobox create -n $BOX -i fedora:latest --init-hooks"
  echo "  distrobox enter $BOX -- sudo dnf install -y flatpak flatpak-builder cmake ninja-build pkg-config git git-lfs"
  exit 1
fi

ensure_source

if [[ "$USE_BOX" -eq 1 ]]; then
  if ! command -v distrobox >/dev/null; then
    echo "distrobox required for --box" >&2
    exit 1
  fi
  if ! distrobox list 2>/dev/null | grep -q "[[:space:]]$BOX[[:space:]]"; then
    echo "==> Creating distrobox '$BOX' (Fedora)"
    distrobox create -n "$BOX" -i fedora:latest -Y
    distrobox enter "$BOX" -- sudo dnf install -y \
      flatpak flatpak-builder cmake ninja-build pkg-config git git-lfs \
      gcc gcc-c++ patchelf
  fi
  BUILD_INNER=(./build_flatpak.sh)
  [[ -n "$JOBS" ]] && BUILD_INNER+=(-j "$JOBS")
  [[ "$LOW_MEM" -eq 1 ]] && BUILD_INNER+=(--low-memory)
  [[ "$INSTALL_RT" -eq 1 ]] && BUILD_INNER+=(-i)
  INNER_CMD="$(printf '%q ' "${BUILD_INNER[@]}")"
  distrobox enter "$BOX" -- bash -lc "
set -euo pipefail
SRC='$SRC'
REPO_URL='$REPO_URL'
REPO_REF='$REPO_REF'
if [[ ! -d \"\$SRC/.git\" ]]; then
  git clone --depth 1 --branch \"\$REPO_REF\" \"\$REPO_URL\" \"\$SRC\"
  (cd \"\$SRC\" && git lfs pull 2>/dev/null || true)
fi
cd \"\$SRC\"
$INNER_CMD
"
  exit 0
fi

run_build
