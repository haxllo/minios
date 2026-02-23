# MiniOS

MiniOS is a custom Linux desktop build scaffold focused on:
- smooth day-to-day desktop behavior on older NVIDIA hardware
- predictable updates with pinned base versions
- a clean, launcher-first workflow with lightweight visuals

This repository is meant to be developed from WSL or any Linux shell, then tested in a VM or on bare metal.

## Current target profile

- Base distro: Ubuntu 22.04 LTS
- Display stack: Xorg
- NVIDIA path: `nvidia-driver-470` when available
- Session stack: `openbox + tint2 + plank + rofi + picom`

## Repository layout

- `scripts/install_base.sh`: installs core packages on target machine
- `scripts/setup_session.sh`: deploys session and user configs
- `scripts/build_iso_modern.sh`: builds a live ISO using `mmdebstrap + squashfs + grub-mkrescue` (recommended)
- `scripts/build_iso.sh`: legacy fallback builder using `live-build`
- `scripts/check.sh`: local script checks
- `config/`: baseline session/compositor/launcher configs
- `docs/`: architecture notes and hardware profile guidance

## Quick start

1. Clone this repo on your target Ubuntu 22.04 machine.
2. Install base dependencies and desktop stack:

```bash
sudo bash scripts/install_base.sh
```

3. Install user-local session files:

```bash
bash scripts/setup_session.sh
```

4. Optional: install system-wide session entry:

```bash
bash scripts/setup_session.sh --system
```

5. Log out, then pick `MiniOS` from the login session menu.

## Build ISO

```bash
sudo bash scripts/build_iso_modern.sh
```

If successful, ISO output is copied into `build/output/`.
Detailed logs are written to `build/logs/`.

Run a fast safety check before a long build:

```bash
sudo bash scripts/build_iso_modern.sh --preflight
```

Preflight validates:
- required tools (`mmdebstrap`, `mksquashfs`, `grub-mkrescue`, `xorriso`)
- free disk space (default minimum: 20 GiB)
- Ubuntu mirror reachability
- apt index refresh (can skip with `MINIOS_SKIP_APT_UPDATE=1`)

Legacy builder (fallback only):

```bash
sudo bash scripts/build_iso.sh --preflight
sudo bash scripts/build_iso.sh
```

If build fails and `build/output/` is empty:
- Read console output and logs in `build/live/`.
- A known `live-build` bug can fail on `start-stop-daemon` diversion cleanup.
- `scripts/build_iso.sh` now auto-applies a host-side workaround to `/usr/lib/live/build/lb_chroot_dpkg` and keeps a backup at:
  `/usr/lib/live/build/lb_chroot_dpkg.minios.bak`
- Another known `live-build` issue may reference obsolete syslinux theme packages
  (`syslinux-themes-ubuntu-oneiric`, `gfxboot-theme-ubuntu`) and fail near the end.
  The script now auto-removes those references from `/usr/lib/live/build/lb_binary_syslinux`
  when those packages are unavailable, with backup at:
  `/usr/lib/live/build/lb_binary_syslinux.minios.bak`

## Notes

- WSL is excellent for authoring scripts/configs, but desktop graphics and driver behavior must be validated in a VM or on real hardware.
- `scripts/install_base.sh` intentionally prefers stability over latest packages.
- Session stability flags live in `~/.config/minios/session.env`.
- Modern builder scratch files are in `build/modern/`.

## Stability tuning

MiniOS starts panel/dock/tray/compositor under a watchdog and logs to:

`~/.local/state/minios/session.log`

On unstable graphics stacks (especially VMs), compositor is disabled automatically.

To force behavior, edit `~/.config/minios/session.env`:

```bash
MINIOS_ENABLE_COMPOSITOR=0    # safest
MINIOS_ENABLE_WATCHDOG=1      # keep auto-restart enabled
```
