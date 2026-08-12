#!/usr/bin/env bash
# Resolve compose command: prefer `podman compose`, then podman-compose, then docker compose.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if podman compose version >/dev/null 2>&1; then
  COMPOSE=(podman compose -f compose.yaml)
elif command -v podman-compose >/dev/null 2>&1; then
  COMPOSE=(podman-compose -f compose.yaml)
elif docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose -f compose.yaml)
else
  echo "Need Podman Compose (podman compose) or docker compose." >&2
  exit 1
fi

export COMPOSE
export ROOT
export CONTAINER_NAME="${CONTAINER_NAME:-pgday-pg19-ai}"
export PGDAY_PORT="${PGDAY_PORT:-54329}"
