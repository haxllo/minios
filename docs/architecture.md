# MiniOS Architecture

## Goal

Provide a polished, low-maintenance Linux desktop profile with:
- stable frame pacing
- lightweight UI effects
- predictable update behavior

## Layers

1. Base OS layer
- Ubuntu 22.04 LTS
- stable kernel line
- rollback-friendly filesystem tooling (`btrfs` + snapshot tools)

2. Graphics/session layer
- Xorg session path for legacy NVIDIA stability
- Openbox window manager
- Picom compositor with conservative settings

3. UX layer
- `rofi` launcher for fast app/file command access
- `plank` dock for pinned/running apps
- `tint2` top panel for workspace, clock, tray

4. Distribution layer
- reproducible package list
- primary ISO build using `mmdebstrap + squashfs + grub-mkrescue`
- legacy ISO build fallback using `live-build`
- pinned defaults and hardware profile docs

## Why this stack

- Lower GPU overhead than heavier desktop environments.
- Easy to reason about and debug component by component.
- Can be shipped as an opinionated desktop image without writing a kernel.

## Release model

- Keep base and driver branches conservative.
- Batch updates and validate on staging VM before daily-driver rollout.
- Keep a known-good rollback snapshot before upgrades.
