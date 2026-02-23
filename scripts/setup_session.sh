#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM_INSTALL=0

if [[ "${1:-}" == "--system" ]]; then
  SYSTEM_INSTALL=1
fi

echo "Installing MiniOS user config into ${HOME}..."

install -d "${HOME}/.local/bin"
install -m 0755 "${ROOT_DIR}/scripts/minios-session.sh" "${HOME}/.local/bin/minios-session"

install -d "${HOME}/.config/openbox"
install -d "${HOME}/.config/picom"
install -d "${HOME}/.config/tint2"
install -d "${HOME}/.config/rofi"
install -d "${HOME}/.local/share/xsessions"

install -m 0644 "${ROOT_DIR}/config/openbox/rc.xml" "${HOME}/.config/openbox/rc.xml"
install -m 0644 "${ROOT_DIR}/config/openbox/menu.xml" "${HOME}/.config/openbox/menu.xml"
install -m 0644 "${ROOT_DIR}/config/picom/picom.conf" "${HOME}/.config/picom/picom.conf"
install -m 0644 "${ROOT_DIR}/config/tint2/tint2rc" "${HOME}/.config/tint2/tint2rc"
install -m 0644 "${ROOT_DIR}/config/rofi/config.rasi" "${HOME}/.config/rofi/config.rasi"

sed "s|__SESSION_EXEC__|${HOME}/.local/bin/minios-session|g" \
  "${ROOT_DIR}/config/session/minios.desktop" \
  > "${HOME}/.local/share/xsessions/minios.desktop"

echo "User-local session installed: ${HOME}/.local/share/xsessions/minios.desktop"

if [[ "${SYSTEM_INSTALL}" -eq 1 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not available; cannot perform --system install."
    exit 1
  fi

  echo "Installing system-wide session entry..."
  sudo install -d /usr/local/bin
  sudo install -m 0755 "${ROOT_DIR}/scripts/minios-session.sh" /usr/local/bin/minios-session

  tmpfile="$(mktemp)"
  sed "s|__SESSION_EXEC__|/usr/local/bin/minios-session|g" \
    "${ROOT_DIR}/config/session/minios.desktop" \
    > "${tmpfile}"
  sudo install -d /usr/share/xsessions
  sudo install -m 0644 "${tmpfile}" /usr/share/xsessions/minios.desktop
  rm -f "${tmpfile}"

  echo "System-wide session installed: /usr/share/xsessions/minios.desktop"
fi

echo "Done. Log out and select 'MiniOS' at the login screen."
