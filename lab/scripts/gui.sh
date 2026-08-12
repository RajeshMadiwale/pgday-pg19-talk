#!/usr/bin/env bash
# Open the stage demo GUI (runs as a container, survives terminal close).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

GUI_PORT="${GUI_PORT:-8788}"
export GUI_PORT PGDAY_PORT

echo "==> Starting lab + GUI containers…"
"${COMPOSE[@]}" up -d

URL="http://127.0.0.1:${GUI_PORT}"
echo "==> Waiting for GUI…"
for _ in $(seq 1 40); do
  if curl -fsS -o /dev/null "${URL}/api/health" 2>/dev/null; then
    echo "==> GUI ready: ${URL}"
    if command -v open >/dev/null 2>&1; then open "$URL"; fi
    echo "    Keys in GUI: A / B / C (or 1 / 2 / 3) · R = run all"
    exit 0
  fi
  sleep 1
done

echo "GUI did not come up. Check: podman logs pgday-pg19-ai-gui" >&2
exit 1
