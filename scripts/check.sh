#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "Running bash syntax checks..."
scripts=(
  scripts/install_base.sh
  scripts/setup_session.sh
  scripts/minios-session.sh
  scripts/build_iso.sh
  scripts/check.sh
)

for script in "${scripts[@]}"; do
  bash -n "${script}"
  echo "ok: ${script}"
done

if command -v shellcheck >/dev/null 2>&1; then
  echo "Running shellcheck..."
  shellcheck "${scripts[@]}"
else
  echo "shellcheck not installed, skipping lint."
fi

echo "Checks passed."
