#!/usr/bin/env bash
# Open psql inside the lab container.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
  exec podman exec -it "$CONTAINER_NAME" psql -U demo -d pgday "$@"
fi
if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  exec docker exec -it "$CONTAINER_NAME" psql -U demo -d pgday "$@"
fi
echo "Container ${CONTAINER_NAME} not running. Start with ./scripts/up.sh" >&2
exit 1
