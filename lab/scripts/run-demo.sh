#!/usr/bin/env bash
# Run Demo A → B → C for attendees (and speaker rehearsal).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

run_sql() {
  local file="$1"
  if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
    podman exec -i "$CONTAINER_NAME" psql -U demo -d pgday -v ON_ERROR_STOP=1 < "$file"
  elif docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    docker exec -i "$CONTAINER_NAME" psql -U demo -d pgday -v ON_ERROR_STOP=1 < "$file"
  else
    echo "Container ${CONTAINER_NAME} not running. Start with ./scripts/up.sh" >&2
    exit 1
  fi
}

echo
echo "############################################################"
echo "# PGDay lab — Same question. Three answers. One database. #"
echo "# Q: Can contractors access production databases?         #"
echo "############################################################"

run_sql "$ROOT/sql/demos/A_sql_only.sql"
run_sql "$ROOT/sql/demos/B_vector_only.sql"

echo
echo "==> Trying Demo C with SQL/PGQ GRAPH_TABLE…"
if run_sql "$ROOT/sql/demos/C_hybrid_graph.sql"; then
  echo
  echo "==> Demo C (SQL/PGQ) succeeded."
else
  echo
  echo "==> GRAPH_TABLE unavailable or failed — running join fallback…"
  run_sql "$ROOT/sql/demos/C_fallback_joins.sql"
fi

echo
echo "Done. Mental model: similarity finds candidates; graphs explain relationships."
