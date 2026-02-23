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
- `scripts/build_iso.sh`: builds a live ISO using `live-build`
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
sudo bash scripts/build_iso.sh
```

If successful, ISO output is copied into `build/output/`.

## Notes

- WSL is excellent for authoring scripts/configs, but desktop graphics and driver behavior must be validated in a VM or on real hardware.
- `scripts/install_base.sh` intentionally prefers stability over latest packages.
- Session stability flags live in `~/.config/minios/session.env`.

## Stability tuning

MiniOS starts panel/dock/tray/compositor under a watchdog and logs to:

`~/.local/state/minios/session.log`

On unstable graphics stacks (especially VMs), compositor is disabled automatically.

To force behavior, edit `~/.config/minios/session.env`:

```bash
MINIOS_ENABLE_COMPOSITOR=0    # safest
MINIOS_ENABLE_WATCHDOG=1      # keep auto-restart enabled
```
