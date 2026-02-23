#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM_INSTALL=0

if [[ "${1:-}" == "--system" ]]; then
  SYSTEM_INSTALL=1
fi

find_desktop_file() {
  local candidate
  for candidate in "$@"; do
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

write_dock_item() {
  local out_file="$1"
  local desktop_file="$2"
  cat > "${out_file}" <<EOF
[PlankDockItemPreferences]
Launcher=file://${desktop_file}
EOF
}

echo "Installing MiniOS user config into ${HOME}..."

install -d "${HOME}/.local/bin"
install -m 0755 "${ROOT_DIR}/scripts/minios-session.sh" "${HOME}/.local/bin/minios-session"

install -d "${HOME}/.config/openbox"
install -d "${HOME}/.config/picom"
install -d "${HOME}/.config/tint2"
install -d "${HOME}/.config/rofi"
install -d "${HOME}/.config/minios"
install -d "${HOME}/.local/share/xsessions"
install -d "${HOME}/.config/plank/dock1/launchers"

install -m 0644 "${ROOT_DIR}/config/openbox/rc.xml" "${HOME}/.config/openbox/rc.xml"
install -m 0644 "${ROOT_DIR}/config/openbox/menu.xml" "${HOME}/.config/openbox/menu.xml"
install -m 0644 "${ROOT_DIR}/config/picom/picom.conf" "${HOME}/.config/picom/picom.conf"
install -m 0644 "${ROOT_DIR}/config/tint2/tint2rc" "${HOME}/.config/tint2/tint2rc"
install -m 0644 "${ROOT_DIR}/config/rofi/config.rasi" "${HOME}/.config/rofi/config.rasi"
if [[ ! -f "${HOME}/.config/minios/session.env" ]]; then
  install -m 0644 "${ROOT_DIR}/config/minios/session.env" "${HOME}/.config/minios/session.env"
fi

browser_desktop="$(find_desktop_file \
  /var/lib/snapd/desktop/applications/firefox_firefox.desktop \
  /usr/share/applications/firefox.desktop \
  /usr/share/applications/firefox_firefox.desktop || true)"
files_desktop="$(find_desktop_file \
  /usr/share/applications/org.gnome.Nautilus.desktop \
  /usr/share/applications/nautilus.desktop || true)"
terminal_desktop="$(find_desktop_file \
  /usr/share/applications/org.gnome.Terminal.desktop \
  /usr/share/applications/gnome-terminal.desktop \
  /usr/share/applications/xfce4-terminal.desktop || true)"
editor_desktop="$(find_desktop_file \
  /usr/share/applications/org.gnome.gedit.desktop \
  /usr/share/applications/gedit.desktop \
  /usr/share/applications/mousepad.desktop || true)"

rm -f "${HOME}/.config/plank/dock1/launchers/"*.dockitem
if [[ -n "${browser_desktop}" ]]; then
  write_dock_item "${HOME}/.config/plank/dock1/launchers/01-browser.dockitem" "${browser_desktop}"
fi
if [[ -n "${files_desktop}" ]]; then
  write_dock_item "${HOME}/.config/plank/dock1/launchers/02-files.dockitem" "${files_desktop}"
fi
if [[ -n "${terminal_desktop}" ]]; then
  write_dock_item "${HOME}/.config/plank/dock1/launchers/03-terminal.dockitem" "${terminal_desktop}"
fi
if [[ -n "${editor_desktop}" ]]; then
  write_dock_item "${HOME}/.config/plank/dock1/launchers/04-editor.dockitem" "${editor_desktop}"
fi

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
