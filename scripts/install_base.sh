#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash scripts/install_base.sh"
  exit 1
fi

if [[ -r /proc/version ]] && grep -qi "microsoft" /proc/version; then
  echo "This script installs desktop packages and should run on target Linux, not inside WSL."
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "Cannot detect distribution. Missing /etc/os-release."
  exit 1
fi

echo "Detected system: ${PRETTY_NAME:-unknown}"
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "Warning: this scaffold is tuned for Ubuntu. Continuing anyway."
fi
if [[ "${VERSION_ID:-}" != "22.04" ]]; then
  echo "Warning: recommended target is Ubuntu 22.04 LTS for this profile."
fi

echo "Updating apt package index..."
apt-get update

echo "Installing core desktop stack and tooling..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  linux-generic \
  linux-headers-generic \
  xorg \
  xinit \
  lightdm \
  openbox \
  tint2 \
  picom \
  rofi \
  plank \
  firefox \
  nautilus \
  gnome-terminal \
  gedit \
  eog \
  network-manager-gnome \
  pavucontrol \
  xfce4-settings \
  fonts-noto \
  fonts-noto-color-emoji \
  mesa-utils \
  xdg-utils \
  btrfs-progs \
  timeshift \
  live-build \
  curl \
  git

if apt-cache show nvidia-driver-470 >/dev/null 2>&1; then
  echo "Installing nvidia-driver-470..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-driver-470
else
  echo "nvidia-driver-470 package is unavailable in current apt sources."
fi

echo "Pinning away HWE metapackages to reduce unexpected kernel jumps..."
install -d /etc/apt/preferences.d
cat > /etc/apt/preferences.d/minios-kernel.pref <<'EOF'
Package: linux-generic-hwe-22.04 linux-headers-generic-hwe-22.04 linux-image-generic-hwe-22.04
Pin: release *
Pin-Priority: -1
EOF

echo "Enabling display manager..."
systemctl enable lightdm

echo "Base install complete."
echo "Next: run 'bash scripts/setup_session.sh' as your normal user."
