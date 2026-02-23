# GT 720 Profile

## Objective

Prioritize responsiveness and stability over visual complexity.

## Recommended baseline

- Session: Xorg
- Driver: `nvidia-driver-470` (when supported by distro packages)
- Refresh target: stable 60 FPS pacing
- Effects: minimal blur/transparency

## Visual effects budget

- Disable full-screen blur.
- Keep shadows simple and low-radius.
- Prefer opaque surfaces for launcher and panels.
- Keep animation durations short (120-180ms).

## Rendering guidance

- Redraw only changed regions where possible.
- Keep icon sizes modest to reduce texture memory pressure.
- Avoid expensive compositing on full-screen windows.

## Operational guidance

- Pin to known-good kernel/driver combinations.
- Snapshot before upgrades.
- Validate suspend/resume, multi-monitor, and login cycles after updates.
