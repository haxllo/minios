#!/usr/bin/env bash
set -euo pipefail

export XDG_CURRENT_DESKTOP="MiniOS"
export XDG_SESSION_DESKTOP="MiniOS"
export GTK_THEME="${GTK_THEME:-Yaru}"
export GDK_BACKEND="${GDK_BACKEND:-x11}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-0}"

pids=()

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/minios"
LOG_FILE="${STATE_DIR}/session.log"
mkdir -p "${STATE_DIR}"
touch "${LOG_FILE}"

SESSION_ENV="${HOME}/.config/minios/session.env"
if [[ -f "${SESSION_ENV}" ]]; then
  # shellcheck disable=SC1090
  . "${SESSION_ENV}"
fi

MINIOS_ENABLE_COMPOSITOR="${MINIOS_ENABLE_COMPOSITOR:-auto}"
MINIOS_ENABLE_WATCHDOG="${MINIOS_ENABLE_WATCHDOG:-1}"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${LOG_FILE}"
}

cleanup() {
  local pid
  for pid in "${pids[@]:-}"; do
    kill "${pid}" >/dev/null 2>&1 || true
  done
  wait >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

stop_stale() {
  local proc
  for proc in picom tint2 plank nm-applet xfsettingsd; do
    pkill -u "${UID}" -x "${proc}" >/dev/null 2>&1 || true
  done
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

should_enable_compositor() {
  if [[ "${MINIOS_ENABLE_COMPOSITOR}" == "1" ]]; then
    return 0
  fi
  if [[ "${MINIOS_ENABLE_COMPOSITOR}" == "0" ]]; then
    return 1
  fi

  if command_exists systemd-detect-virt && systemd-detect-virt --quiet; then
    return 1
  fi
  return 0
}

start_once() {
  local name="$1"
  shift
  if ! command_exists "$1"; then
    log "skip ${name}: missing $1"
    return
  fi
  "$@" >> "${LOG_FILE}" 2>&1 &
  pids+=("$!")
  log "started ${name}"
}

start_supervised() {
  local name="$1"
  shift

  if ! command_exists "$1"; then
    log "skip ${name}: missing $1"
    return
  fi

  (
    set +e
    local crash_count=0
    local child_pid=
    trap 'if [[ -n "${child_pid}" ]]; then kill "${child_pid}" >/dev/null 2>&1 || true; fi; exit 0' INT TERM

    while true; do
      "$@" >> "${LOG_FILE}" 2>&1 &
      child_pid="$!"
      wait "${child_pid}"
      local status=$?
      child_pid=

      if [[ "${status}" -eq 0 ]]; then
        crash_count=0
        sleep 1
      else
        crash_count=$((crash_count + 1))
        log "${name} exited with status ${status} (restart ${crash_count})"
        if (( crash_count >= 5 )); then
          log "${name} is unstable; backing off for 10s"
          sleep 10
          crash_count=0
        else
          sleep 2
        fi
      fi
    done
  ) &

  pids+=("$!")
  log "started supervised ${name}"
}

stop_stale

if [[ "${MINIOS_ENABLE_WATCHDOG}" == "1" ]]; then
  start_supervised xfsettingsd xfsettingsd
  start_supervised nm-applet nm-applet --indicator
  start_supervised tint2 tint2 -c "${HOME}/.config/tint2/tint2rc"
  start_supervised plank plank
else
  start_once xfsettingsd xfsettingsd
  start_once nm-applet nm-applet --indicator
  start_once tint2 tint2 -c "${HOME}/.config/tint2/tint2rc"
  start_once plank plank
fi

if should_enable_compositor; then
  if [[ "${MINIOS_ENABLE_WATCHDOG}" == "1" ]]; then
    start_supervised picom picom --config "${HOME}/.config/picom/picom.conf"
  else
    start_once picom picom --config "${HOME}/.config/picom/picom.conf"
  fi
  log "compositor enabled"
else
  log "compositor disabled (auto-safe mode)"
fi

openbox >> "${LOG_FILE}" 2>&1 &
wm_pid="$!"
wait "${wm_pid}"
