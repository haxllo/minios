#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/build_iso_modern.sh [--preflight]

Options:
  --preflight   Run environment checks only, skip actual ISO build.

Environment:
  MINIOS_BUILD_MIN_FREE_GB   Minimum free disk space required (default: 20).
  MINIOS_SKIP_APT_UPDATE=1   Skip apt index refresh during preflight.
  MINIOS_KEEP_CHROOT=1       Keep previous modern build chroot directory.
EOF
}

on_error() {
  local exit_code="$1"
  echo "Modern ISO build failed (exit ${exit_code})."
  echo "Build root: ${BUILD_ROOT}"
  if [[ -n "${BUILD_LOG:-}" ]]; then
    echo "Detailed log: ${BUILD_LOG}"
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}"
    return 1
  fi
}

check_url() {
  local url="$1"
  if ! wget --spider --timeout=15 --tries=2 "${url}" >/dev/null 2>&1; then
    echo "Cannot reach required mirror URL: ${url}"
    return 1
  fi
}

preflight_checks() {
  local avail_gb
  local apt_skip="${MINIOS_SKIP_APT_UPDATE:-0}"

  echo "Running preflight checks for modern builder..."
  require_cmd mmdebstrap
  require_cmd mksquashfs
  require_cmd grub-mkrescue
  require_cmd xorriso
  require_cmd rsync
  require_cmd wget
  require_cmd chroot
  require_cmd dpkg-query

  if [[ -r /proc/version ]] && grep -qi "microsoft" /proc/version; then
    echo "This build must run on real Linux/VM, not inside WSL."
    return 1
  fi

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "Host OS: ${PRETTY_NAME:-unknown}"
  fi

  avail_gb="$(df --output=avail -BG "${ROOT_DIR}" | tail -n 1 | tr -dc '0-9')"
  if [[ -z "${avail_gb}" ]]; then
    echo "Unable to determine free disk space at ${ROOT_DIR}."
    return 1
  fi
  if (( avail_gb < MIN_FREE_GB )); then
    echo "Not enough free disk space at ${ROOT_DIR}: ${avail_gb} GiB available, ${MIN_FREE_GB} GiB required."
    return 1
  fi
  echo "Disk check OK: ${avail_gb} GiB free (min ${MIN_FREE_GB} GiB)."

  check_url "http://archive.ubuntu.com/ubuntu/dists/jammy/Release"
  check_url "http://archive.ubuntu.com/ubuntu/dists/jammy-updates/Release"
  check_url "http://security.ubuntu.com/ubuntu/dists/jammy-security/Release"
  echo "Mirror reachability OK."

  if [[ "${apt_skip}" == "1" ]]; then
    echo "Skipping apt index refresh (MINIOS_SKIP_APT_UPDATE=1)."
  else
    echo "Refreshing apt indexes..."
    apt-get update -qq
  fi

  if apt-cache show nvidia-driver-470 >/dev/null 2>&1; then
    echo "Detected nvidia-driver-470 in apt sources."
  else
    echo "Warning: nvidia-driver-470 not found in apt sources; ISO will be built without it."
  fi

  echo "Preflight checks passed."
}

build_chroot() {
  local packages_csv
  local packages
  packages=(
    systemd-sysv
    ubuntu-standard
    sudo
    casper
    initramfs-tools
    dbus-x11
    linux-generic
    linux-headers-generic
    xorg
    xinit
    lightdm
    lightdm-gtk-greeter
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
    curl
    wget
    rsync
    btrfs-progs
    timeshift
  )

  if apt-cache show nvidia-driver-470 >/dev/null 2>&1; then
    packages+=(nvidia-driver-470)
  fi

  packages_csv="$(IFS=,; echo "${packages[*]}")"

  mmdebstrap \
    --architectures=amd64 \
    --variant=minbase \
    --components="main,restricted,universe,multiverse" \
    --include="${packages_csv}" \
    jammy "${CHROOT_DIR}" \
    "deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse" \
    "deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse" \
    "deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse"

  cp /etc/resolv.conf "${CHROOT_DIR}/etc/resolv.conf"
  if chroot "${CHROOT_DIR}" /usr/bin/env bash -lc 'command -v apt-get >/dev/null 2>&1'; then
    chroot "${CHROOT_DIR}" apt-get update
  else
    echo "apt-get not present in chroot variant; skipping chroot apt refresh."
  fi
  if chroot "${CHROOT_DIR}" /usr/bin/env bash -lc 'command -v update-initramfs >/dev/null 2>&1'; then
    chroot "${CHROOT_DIR}" update-initramfs -u -k all
  else
    echo "update-initramfs not present in chroot variant; skipping initramfs refresh."
  fi
}

inject_minios_config() {
  mkdir -p "${CHROOT_DIR}/etc/skel/.config/openbox"
  mkdir -p "${CHROOT_DIR}/etc/skel/.config/picom"
  mkdir -p "${CHROOT_DIR}/etc/skel/.config/tint2"
  mkdir -p "${CHROOT_DIR}/etc/skel/.config/rofi"
  mkdir -p "${CHROOT_DIR}/etc/skel/.config/minios"
  mkdir -p "${CHROOT_DIR}/etc/skel/.local/bin"
  mkdir -p "${CHROOT_DIR}/etc/skel/.local/share/xsessions"

  cp "${ROOT_DIR}/config/openbox/rc.xml" "${CHROOT_DIR}/etc/skel/.config/openbox/rc.xml"
  cp "${ROOT_DIR}/config/openbox/menu.xml" "${CHROOT_DIR}/etc/skel/.config/openbox/menu.xml"
  cp "${ROOT_DIR}/config/picom/picom.conf" "${CHROOT_DIR}/etc/skel/.config/picom/picom.conf"
  cp "${ROOT_DIR}/config/tint2/tint2rc" "${CHROOT_DIR}/etc/skel/.config/tint2/tint2rc"
  cp "${ROOT_DIR}/config/rofi/config.rasi" "${CHROOT_DIR}/etc/skel/.config/rofi/config.rasi"
  cp "${ROOT_DIR}/config/minios/session.env" "${CHROOT_DIR}/etc/skel/.config/minios/session.env"
  cp "${ROOT_DIR}/scripts/minios-session.sh" "${CHROOT_DIR}/etc/skel/.local/bin/minios-session"
  chmod 0755 "${CHROOT_DIR}/etc/skel/.local/bin/minios-session"

  mkdir -p "${CHROOT_DIR}/usr/local/bin"
  mkdir -p "${CHROOT_DIR}/usr/share/xsessions"
  cp "${ROOT_DIR}/scripts/minios-session.sh" "${CHROOT_DIR}/usr/local/bin/minios-session"
  chmod 0755 "${CHROOT_DIR}/usr/local/bin/minios-session"

  sed "s|__SESSION_EXEC__|/usr/local/bin/minios-session|g" \
    "${ROOT_DIR}/config/session/minios.desktop" \
    > "${CHROOT_DIR}/usr/share/xsessions/minios.desktop"
}

configure_live_runtime() {
  local lightdm_conf_dir
  lightdm_conf_dir="${CHROOT_DIR}/etc/lightdm/lightdm.conf.d"

  mkdir -p "${lightdm_conf_dir}"
  cat > "${lightdm_conf_dir}/50-minios-live.conf" <<'EOF'
[Seat:*]
autologin-user=ubuntu
autologin-user-timeout=0
user-session=minios
greeter-session=lightdm-gtk-greeter
allow-guest=false
EOF

  mkdir -p "${CHROOT_DIR}/etc/systemd/system"
  ln -sfn /lib/systemd/system/graphical.target "${CHROOT_DIR}/etc/systemd/system/default.target"
  ln -sfn /lib/systemd/system/lightdm.service "${CHROOT_DIR}/etc/systemd/system/display-manager.service"
}

validate_chroot_runtime() {
  local missing=0

  if [[ ! -x "${CHROOT_DIR}/usr/local/bin/minios-session" ]]; then
    echo "Validation error: /usr/local/bin/minios-session missing or not executable in chroot."
    missing=1
  fi
  if [[ ! -f "${CHROOT_DIR}/usr/share/xsessions/minios.desktop" ]]; then
    echo "Validation error: /usr/share/xsessions/minios.desktop missing in chroot."
    missing=1
  fi
  if [[ ! -f "${CHROOT_DIR}/etc/lightdm/lightdm.conf.d/50-minios-live.conf" ]]; then
    echo "Validation error: LightDM live config missing in chroot."
    missing=1
  fi
  if [[ ! -e "${CHROOT_DIR}/etc/systemd/system/default.target" ]]; then
    echo "Validation error: default.target missing in chroot."
    missing=1
  fi
  if [[ ! -e "${CHROOT_DIR}/etc/systemd/system/display-manager.service" ]]; then
    echo "Validation error: display-manager.service alias missing in chroot."
    missing=1
  fi
  if ! ls "${CHROOT_DIR}"/boot/vmlinuz-* >/dev/null 2>&1; then
    echo "Validation error: no kernel image found under chroot /boot."
    missing=1
  fi
  if ! ls "${CHROOT_DIR}"/boot/initrd.img-* >/dev/null 2>&1; then
    echo "Validation error: no initrd found under chroot /boot."
    missing=1
  fi

  if [[ "${missing}" -ne 0 ]]; then
    return 1
  fi
}

assemble_iso_tree() {
  local kernel_path
  local initrd_path

  mkdir -p "${STAGING_DIR}/boot/grub"
  mkdir -p "${STAGING_DIR}/casper"
  touch "${STAGING_DIR}/MINIOS"

  kernel_path="$(ls -1 "${CHROOT_DIR}"/boot/vmlinuz-* | sort | tail -n 1)"
  initrd_path="$(ls -1 "${CHROOT_DIR}"/boot/initrd.img-* | sort | tail -n 1)"

  if [[ -z "${kernel_path}" || -z "${initrd_path}" ]]; then
    echo "Missing kernel or initrd in chroot."
    return 1
  fi

  cp "${kernel_path}" "${STAGING_DIR}/casper/vmlinuz"
  cp "${initrd_path}" "${STAGING_DIR}/casper/initrd"

  chroot "${CHROOT_DIR}" dpkg-query -W --showformat='${Package} ${Version}\n' \
    > "${STAGING_DIR}/casper/filesystem.manifest"

  du -sx --block-size=1 "${CHROOT_DIR}" | cut -f1 \
    > "${STAGING_DIR}/casper/filesystem.size"

  mksquashfs "${CHROOT_DIR}" "${STAGING_DIR}/casper/filesystem.squashfs" \
    -comp xz -xattrs -wildcards -e boot

  cat > "${STAGING_DIR}/boot/grub/grub.cfg" <<'EOF'
search --set=root --file /MINIOS
set default=0
set timeout=5

menuentry "MiniOS Live" {
  linux /casper/vmlinuz boot=casper systemd.unit=graphical.target quiet splash ---
  initrd /casper/initrd
}

menuentry "MiniOS Live (Safe Graphics)" {
  linux /casper/vmlinuz boot=casper systemd.unit=graphical.target nomodeset quiet splash ---
  initrd /casper/initrd
}

menuentry "MiniOS Live (Debug Console)" {
  linux /casper/vmlinuz boot=casper systemd.unit=multi-user.target nosplash ---
  initrd /casper/initrd
}
EOF
}

create_iso() {
  local iso_name
  iso_name="minios-v2-jammy-amd64-$(date '+%Y%m%d-%H%M').iso"
  ISO_PATH="${OUTPUT_DIR}/${iso_name}"

  grub-mkrescue -o "${ISO_PATH}" "${STAGING_DIR}" -- -volid "MINIOS_V2_JAMMY"

  if [[ ! -f "${ISO_PATH}" ]]; then
    echo "Build finished but ISO not found: ${ISO_PATH}"
    return 1
  fi
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash scripts/build_iso_modern.sh"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${ROOT_DIR}/build/modern"
CHROOT_DIR="${BUILD_ROOT}/chroot"
STAGING_DIR="${BUILD_ROOT}/staging"
OUTPUT_DIR="${ROOT_DIR}/build/output"
LOG_DIR="${ROOT_DIR}/build/logs"
BUILD_LOG=""
ISO_PATH=""
MIN_FREE_GB="${MINIOS_BUILD_MIN_FREE_GB:-20}"
KEEP_CHROOT="${MINIOS_KEEP_CHROOT:-0}"
PRECHECK_ONLY=0

if [[ "${1:-}" == "--preflight" ]]; then
  PRECHECK_ONLY=1
elif [[ -n "${1:-}" ]]; then
  usage
  exit 1
fi

trap 'on_error "$?"' ERR

preflight_checks
if [[ "${PRECHECK_ONLY}" -eq 1 ]]; then
  exit 0
fi

mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"
BUILD_LOG="${LOG_DIR}/iso-modern-$(date '+%Y%m%d-%H%M%S').log"
exec > >(tee "${BUILD_LOG}") 2>&1

echo "Preparing modern build directories..."
if [[ "${KEEP_CHROOT}" == "1" ]]; then
  rm -rf "${STAGING_DIR}"
else
  rm -rf "${BUILD_ROOT}"
fi
mkdir -p "${CHROOT_DIR}" "${STAGING_DIR}"

if [[ "${KEEP_CHROOT}" != "1" ]]; then
  echo "Building root filesystem with mmdebstrap..."
  build_chroot
else
  echo "Reusing existing chroot because MINIOS_KEEP_CHROOT=1"
fi

echo "Injecting MiniOS session configuration..."
inject_minios_config

echo "Configuring live runtime defaults..."
configure_live_runtime

echo "Validating chroot runtime essentials..."
validate_chroot_runtime

echo "Assembling ISO staging tree..."
assemble_iso_tree

echo "Generating ISO..."
create_iso

echo "Modern ISO build complete."
echo "Output ISO: ${ISO_PATH}"
echo "Build log: ${BUILD_LOG}"
