#!/usr/bin/env bash
# Build and start PostgreSQL 19 + pgvector lab.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

echo "==> Building image (Postgres 19 beta + pgvector)…"
"${COMPOSE[@]}" build

echo "==> Starting container on localhost:${PGDAY_PORT}…"
"${COMPOSE[@]}" up -d

echo "==> Waiting for healthy database…"
for i in $(seq 1 60); do
  if podman exec "$CONTAINER_NAME" pg_isready -U demo -d pgday >/dev/null 2>&1 \
     || docker exec "$CONTAINER_NAME" pg_isready -U demo -d pgday >/dev/null 2>&1; then
    echo "==> Ready."
    echo
    echo "  host: localhost"
    echo "  port: ${PGDAY_PORT}"
    echo "  db:   pgday"
    echo "  user: demo"
    echo "  pass: demo"
    echo
    echo "Next: ./scripts/run-demo.sh"
    exit 0
  fi
  sleep 2
done

echo "Database did not become ready in time. Check: podman logs ${CONTAINER_NAME}" >&2
exit 1
