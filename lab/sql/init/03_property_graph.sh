#!/bin/bash
set -euo pipefail
echo "Attempting CREATE PROPERTY GRAPH access_kg…"
if psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
DROP PROPERTY GRAPH IF EXISTS access_kg;

CREATE PROPERTY GRAPH access_kg
  VERTEX TABLES (
    documents KEY (id) LABEL document,
    entities  KEY (id) LABEL entity
  )
  EDGE TABLES (
    relationships
      KEY (id)
      SOURCE KEY (src_entity) REFERENCES entities (id)
      DESTINATION KEY (dst_entity) REFERENCES entities (id)
      LABEL link,
    document_entities
      KEY (document_id, entity_id)
      SOURCE KEY (document_id) REFERENCES documents (id)
      DESTINATION KEY (entity_id) REFERENCES entities (id)
      LABEL mentions
  );
SQL
then
  echo "Property graph access_kg created."
else
  echo "WARNING: PROPERTY GRAPH not created."
  echo "Demo C will use C_fallback_joins.sql"
fi
