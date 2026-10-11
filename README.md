# Snapmaker Orca on Bazzite

Install and launch scripts for [Snapmaker Orca](https://github.com/Snapmaker/OrcaSlicer) on [Bazzite](https://bazzite.gg) (immutable Fedora). Packaging only — upstream binaries come from Snapmaker’s GitHub releases.

### Check for a new upstream release

```bash
./upstream-version.sh
./install.sh --appimage --version vX.Y.Z   # example after checking tag
```

[Bazzite](https://bazzite.gg) is an immutable Fedora (rpm-ostree) system. The recommended way to run [Snapmaker Orca](https://github.com/Snapmaker/OrcaSlicer) is **user Flatpak** from upstream releases — no `rpm-ostree install` of build dependencies on the host.

## Quick install (recommended)

```bash
cd snapmaker-orca-bazzite
chmod +x install.sh
./install.sh
```

Launch (**recommended on Bazzite — AppImage**, better web UI / login):

```bash
./launch-appimage.sh
```

Flatpak (optional):

```bash
./run.sh
```

Or directly:

```bash
flatpak run io.github.Snapmaker.Snapmaker_Orca
```

### `GLib-GObject-CRITICAL` + `local server init` then immediate return

Usually **a second launch** while Orca is already open, or a **broken Flatpak** session after `GDK_SCALE` was applied. Fix:

```bash
flatpak kill io.github.Snapmaker.Snapmaker_Orca
flatpak override --user --reset io.github.Snapmaker.Snapmaker_Orca
./configure-flatpak-ui.sh
```

Prefer the AppImage instead: `./launch-appimage.sh`

### Crashes right after “Initializing StaticPrintConfigs” (exit 139)

An old Flatpak config under `~/.var/app/io.github.Snapmaker.Snapmaker_Orca/config` (from a previous Orca/Bambu install) can segfault on startup. Reset it:

```bash
./run.sh --reset-config
./run.sh
```

The font lines (`add font of HarmonyOS_Sans_SC_Bold returns 1`) and Gtk-CRITICAL spam in the terminal are noisy but usually harmless once the window opens.

### Web home / login looks blank or broken (Bazzite + NVIDIA + 200% scale)

The built-in home and login UI use **WebKit + Flutter** inside the Flatpak. On Wayland with NVIDIA this often needs extra permissions and env vars:

```bash
./configure-flatpak-ui.sh   # once
./run.sh
```

If panels are still empty, try XWayland:

```bash
./run.sh --x11
```

**AppImage fallback** (runs outside Flatpak, usually better for login):

```bash
./install.sh --appimage
~/Applications/Snapmaker_Orca.AppImage
```

You can slice and export G-code **without** cloud login. The **Device** tab shows “missing connection” until a printer is linked; account sign-in is separate from that screen.

This script:

1. Ensures the Flathub remote (user)
2. Installs **org.gnome.Platform//49** (required by the official bundle)
3. Downloads the matching **Snapmaker_Orca-Linux-flatpak_…** asset for your CPU (`x86_64` or `aarch64`)
4. Installs the app with `flatpak install --user`

### Options

| Flag | Purpose |
|------|---------|
| `./install.sh --version v2.4.0` | Pin a release tag |
| `./install.sh --bundle ./Snapmaker_Orca….flatpak` | Install a file you already downloaded |
| `./install.sh --appimage` | Put the Ubuntu AppImage in `~/Applications` (alternative; no Flatpak sandbox) |

## Build your own Flatpak on Bazzite

Upstream ships `build_flatpak.sh`. On a minimal Bazzite host you may not have `flatpak-builder` layered; use a **distrobox** so the host stays clean:

```bash
chmod +x build-flatpak.sh
./build-flatpak.sh --box -i --low-memory -j 4
```

Then install the bundle:

```bash
./install.sh --bundle OrcaSlicer-src/Snapmaker_Orca-Linux-flatpak_V*.flatpak
```

Expect **30–90+ minutes** and **~10 GB** disk for a from-source Flatpak build.

## Native compile (AppImage) in distrobox

Upstream `build_linux.sh` does not ship `scripts/linux.d/bazzite`. After cloning OrcaSlicer, copy this repo’s shim:

```bash
git clone --depth 1 https://github.com/Snapmaker/OrcaSlicer.git
cp snapmaker-orca-bazzite/scripts/linux.d/bazzite OrcaSlicer/scripts/linux.d/bazzite
```

Inside Fedora distrobox (not on the immutable host):

```bash
cd OrcaSlicer
git lfs pull
./build_linux.sh -u    # once: dnf deps
./build_linux.sh -dsi  # deps + slicer + AppImage
```

## Printer udev (USB serial)

Flatpak already has `--device=all`. If a USB printer still does not appear, add udev rules on the host (one-time, may require reboot):

```bash
sudo wget -O /etc/udev/rules.d/99-3d-printers.rules \
  https://raw.githubusercontent.com/prusa3d/PrusaSlicer/master/resources/udev/99-3d-printers.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## Why not rpm-ostree layer?

OrcaSlicer’s native build pulls dozens of `-devel` packages and a pinned CMake toolchain. Layering that on Bazzite bloats the image and fights the Atomic update model. Flatpak matches how Bazzite is designed to ship desktop apps.

## Source

- Upstream: https://github.com/Snapmaker/OrcaSlicer  
- App ID: `io.github.Snapmaker.Snapmaker_Orca`
