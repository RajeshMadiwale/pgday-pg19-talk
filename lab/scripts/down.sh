#!/usr/bin/env bash
# Stop and remove the lab container (keeps named volume unless --wipe).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

if [[ "${1:-}" == "--wipe" ]]; then
  echo "==> Stopping and wiping volume…"
  "${COMPOSE[@]}" down -v
else
  echo "==> Stopping…"
  "${COMPOSE[@]}" down
fi
echo "Done."
