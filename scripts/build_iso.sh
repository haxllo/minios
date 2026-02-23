#!/usr/bin/env bash
set -euo pipefail

on_error() {
  local exit_code="$1"
  echo "ISO build failed (exit ${exit_code})."
  echo "Check build logs under: ${BUILD_ROOT}"
  echo "Tip: if you see start-stop-daemon diversion errors, this script now applies a live-build hotfix automatically."
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash scripts/build_iso.sh"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${ROOT_DIR}/build/live"
OUTPUT_DIR="${ROOT_DIR}/build/output"
trap 'on_error "$?"' ERR

if ! command -v lb >/dev/null 2>&1; then
  echo "Missing live-build ('lb'). Run scripts/install_base.sh first."
  exit 1
fi

apply_live_build_hotfix() {
  local lb_file="/usr/lib/live/build/lb_chroot_dpkg"
  local marker_begin="# begin-remove-after: released:forky"
  local marker_end="# end-remove-after"
  local backup_file

  if [[ ! -f "${lb_file}" ]]; then
    return 0
  fi

  # Known live-build issue: duplicate start-stop-daemon diversion cleanup on usr-merged systems.
  if grep -qF "${marker_begin}" "${lb_file}" && grep -qF -- "--remove /usr/sbin/start-stop-daemon" "${lb_file}"; then
    backup_file="${lb_file}.minios.bak"
    if [[ ! -f "${backup_file}" ]]; then
      cp "${lb_file}" "${backup_file}"
      echo "Backed up live-build helper to ${backup_file}"
    fi

    sed -i "/${marker_begin}/,/${marker_end}/d" "${lb_file}"
    echo "Applied live-build start-stop-daemon diversion workaround."
  fi
}

apply_live_build_hotfix

echo "Preparing build directories..."
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"
mkdir -p "${OUTPUT_DIR}"
cd "${BUILD_ROOT}"

echo "Configuring live-build..."
lb config \
  --mode ubuntu \
  --distribution jammy \
  --archive-areas "main restricted universe multiverse" \
  --binary-images iso-hybrid \
  --debian-installer live

mkdir -p config/package-lists
cat > config/package-lists/minios.list.chroot <<'EOF'
linux-generic
linux-headers-generic
xorg
lightdm
openbox
tint2
picom
rofi
plank
firefox
nautilus
gnome-terminal
gedit
eog
network-manager-gnome
pavucontrol
xfce4-settings
fonts-noto
fonts-noto-color-emoji
mesa-utils
xdg-utils
EOF

if apt-cache show nvidia-driver-470 >/dev/null 2>&1; then
  echo "nvidia-driver-470" >> config/package-lists/minios.list.chroot
fi

mkdir -p config/includes.chroot/etc/skel/.config/openbox
mkdir -p config/includes.chroot/etc/skel/.config/picom
mkdir -p config/includes.chroot/etc/skel/.config/tint2
mkdir -p config/includes.chroot/etc/skel/.config/rofi
mkdir -p config/includes.chroot/etc/skel/.config/minios
mkdir -p config/includes.chroot/etc/skel/.local/bin
mkdir -p config/includes.chroot/etc/skel/.local/share/xsessions

cp "${ROOT_DIR}/config/openbox/rc.xml" config/includes.chroot/etc/skel/.config/openbox/rc.xml
cp "${ROOT_DIR}/config/openbox/menu.xml" config/includes.chroot/etc/skel/.config/openbox/menu.xml
cp "${ROOT_DIR}/config/picom/picom.conf" config/includes.chroot/etc/skel/.config/picom/picom.conf
cp "${ROOT_DIR}/config/tint2/tint2rc" config/includes.chroot/etc/skel/.config/tint2/tint2rc
cp "${ROOT_DIR}/config/rofi/config.rasi" config/includes.chroot/etc/skel/.config/rofi/config.rasi
cp "${ROOT_DIR}/config/minios/session.env" config/includes.chroot/etc/skel/.config/minios/session.env
cp "${ROOT_DIR}/scripts/minios-session.sh" config/includes.chroot/etc/skel/.local/bin/minios-session
chmod 0755 config/includes.chroot/etc/skel/.local/bin/minios-session

sed "s|__SESSION_EXEC__|/home/user/.local/bin/minios-session|g" \
  "${ROOT_DIR}/config/session/minios.desktop" \
  > config/includes.chroot/etc/skel/.local/share/xsessions/minios.desktop

echo "Building ISO..."
lb build

shopt -s nullglob
iso_files=( ./*.iso )
if (( ${#iso_files[@]} == 0 )); then
  echo "Build finished but no ISO found."
  exit 1
fi

for iso in "${iso_files[@]}"; do
  cp -f "${iso}" "${OUTPUT_DIR}/"
done

echo "ISO build complete. Output:"
ls -1 "${OUTPUT_DIR}"/*.iso
