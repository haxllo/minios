#!/usr/bin/env bash
set -euo pipefail

export XDG_CURRENT_DESKTOP="MiniOS"
export XDG_SESSION_DESKTOP="MiniOS"
export GTK_THEME="${GTK_THEME:-Yaru}"

start_bg() {
  if command -v "$1" >/dev/null 2>&1; then
    shift
    "$@" &
  fi
}

start_bg xfsettingsd xfsettingsd
start_bg nm-applet nm-applet --indicator
start_bg picom picom --config "${HOME}/.config/picom/picom.conf"
start_bg tint2 tint2 -c "${HOME}/.config/tint2/tint2rc"
start_bg plank plank

exec openbox
