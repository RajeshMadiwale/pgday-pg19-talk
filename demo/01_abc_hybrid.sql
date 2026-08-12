-- =============================================================================
-- PGDay demo: PostgreSQL 19 + pgvector hybrid retrieval (A → B → C)
-- Validate SQL/PGQ against current Postgres 19 docs before live delivery.
-- Requires: PostgreSQL 19+, CREATE EXTENSION vector;
-- Embeddings below are tiny teaching vectors (3-d). Replace with real model
-- output in a lab if you want — dimensionality must match across rows.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS vector;

DROP PROPERTY GRAPH IF EXISTS access_kg;
DROP TABLE IF EXISTS document_entities;
DROP TABLE IF EXISTS relationships;
DROP TABLE IF EXISTS entities;
DROP TABLE IF EXISTS documents;

-- ---------------------------------------------------------------------------
-- 1) Schema
-- ---------------------------------------------------------------------------
CREATE TABLE documents (
  id          int PRIMARY KEY,
  title       text NOT NULL,
  body        text NOT NULL,
  embedding   vector(3) NOT NULL
);

CREATE TABLE entities (
  id    int PRIMARY KEY,
  name  text NOT NULL UNIQUE,
  kind  text NOT NULL CHECK (kind IN ('Policy','Role','System','Control'))
);

-- Directed edges for the property graph
CREATE TABLE relationships (
  id           int PRIMARY KEY,
  src_entity   int NOT NULL REFERENCES entities(id),
  dst_entity   int NOT NULL REFERENCES entities(id),
  rel_type     text NOT NULL
);

CREATE TABLE document_entities (
  document_id int NOT NULL REFERENCES documents(id),
  entity_id   int NOT NULL REFERENCES entities(id),
  PRIMARY KEY (document_id, entity_id)
);

-- ---------------------------------------------------------------------------
-- 2) Seed data (intentionally small + dramatic)
-- ---------------------------------------------------------------------------
INSERT INTO documents (id, title, body, embedding) VALUES
  (1, 'Access control overview',
   'Employees access systems based on role. Production systems are highly restricted. See linked policies for exceptions and contractor rules.',
   '[0.92, 0.10, 0.08]'),
  (2, 'Password reset FAQ',
   'Users can reset passwords via SSO. Contractors use the partner portal for credential recovery.',
   '[0.15, 0.90, 0.05]'),
  (3, 'Laptop encryption guide',
   'All corporate laptops must enable full-disk encryption before connecting to VPN.',
   '[0.05, 0.20, 0.95]');

INSERT INTO entities (id, name, kind) VALUES
  (10, 'ContractorAccess', 'Policy'),
  (11, 'ProductionDeny',   'Control'),
  (12, 'BreakGlass',       'Control'),
  (13, 'Contractor',       'Role'),
  (14, 'ProductionDB',     'System');

INSERT INTO relationships (id, src_entity, dst_entity, rel_type) VALUES
  (1, 10, 13, 'APPLIES_TO'),      -- ContractorAccess applies to Contractor
  (2, 10, 11, 'ENFORCES'),        -- ContractorAccess enforces ProductionDeny
  (3, 11, 14, 'PROTECTS'),        -- ProductionDeny protects ProductionDB
  (4, 12, 11, 'OVERRIDES');       -- BreakGlass can override ProductionDeny

-- Overview doc is about the contractor access policy
INSERT INTO document_entities (document_id, entity_id) VALUES
  (1, 10),
  (1, 13);

-- Optional ANN index (fine even on tiny demo)
CREATE INDEX documents_embedding_hnsw
  ON documents USING hnsw (embedding vector_cosine_ops);

-- ---------------------------------------------------------------------------
-- 3) PostgreSQL 19 property graph over existing tables
-- Syntax: confirm against docs if beta naming differs slightly.
-- ---------------------------------------------------------------------------
CREATE PROPERTY GRAPH access_kg
  VERTEX TABLES (
    entities KEY (id) LABEL entity PROPERTIES (id, name, kind),
    documents KEY (id) LABEL document PROPERTIES (id, title)
  )
  EDGE TABLES (
    relationships
      KEY (id)
      SOURCE KEY (src_entity) REFERENCES entities (id)
      DESTINATION KEY (dst_entity) REFERENCES entities (id)
      LABEL link
      PROPERTIES (rel_type),
    document_entities
      KEY (document_id, entity_id)
      SOURCE KEY (document_id) REFERENCES documents (id)
      DESTINATION KEY (entity_id) REFERENCES entities (id)
      LABEL mentions
  );

-- =============================================================================
-- DEMO QUESTION (keep on screen for A/B/C):
--   "Can contractors access production databases?"
-- Query embedding ≈ meaning of that question (teaching vector)
-- =============================================================================
-- Shared query vector for demos B and C:
--   '[0.88, 0.12, 0.10]'  ≈ close to document 1 (Access control overview)

-- ---------------------------------------------------------------------------
-- DEMO A — SQL only (keyword). Expect: weak / empty / misleading.
-- ---------------------------------------------------------------------------
SELECT id, title, body
FROM documents
WHERE body ILIKE '%contractor%production%'
   OR title ILIKE '%contractor%production%';
-- Likely: 0 rows (wording mismatch). Point this out.

-- Softer SQL still incomplete:
SELECT id, title
FROM documents
WHERE body ILIKE '%contractor%' OR body ILIKE '%production%';
-- Returns overview + maybe noise; no policy decision.

-- ---------------------------------------------------------------------------
-- DEMO B — Vector only. Expect: relevant doc, incomplete decision.
-- ---------------------------------------------------------------------------
SELECT id, title,
       1 - (embedding <=> '[0.88, 0.12, 0.10]') AS similarity
FROM documents
ORDER BY embedding <=> '[0.88, 0.12, 0.10]'
LIMIT 1;
-- Returns: Access control overview — "see linked policies" (shallow).

-- ---------------------------------------------------------------------------
-- DEMO C — Hybrid: vector candidate → graph expand → grounded answer context
-- ---------------------------------------------------------------------------
WITH top_doc AS (
  SELECT id, title, body
  FROM documents
  ORDER BY embedding <=> '[0.88, 0.12, 0.10]'
  LIMIT 1
)
SELECT
  d.title AS retrieved_doc,
  g.policy_name,
  g.control_name,
  g.system_name,
  g.how_linked
FROM top_doc d
CROSS JOIN LATERAL (
  SELECT *
  FROM GRAPH_TABLE (
    access_kg
    MATCH
      (doc IS document WHERE doc.id = d.id)
        -[IS mentions]->(pol IS entity WHERE pol.name = 'ContractorAccess')
        -[IS link]->(ctl IS entity)
        -[IS link]->(sys IS entity WHERE sys.name = 'ProductionDB')
    COLUMNS (
      pol.name AS policy_name,
      ctl.name AS control_name,
      sys.name AS system_name,
      'doc→policy→control→system' AS how_linked
    )
  ) AS gt
) g;

-- Expected story to narrate:
-- Retrieved doc: Access control overview
-- Policy: ContractorAccess
-- Control: ProductionDeny
-- System: ProductionDB
-- Answer: Contractors do NOT get production DB access; BreakGlass overrides exist.

-- Optional encore (if time): show BreakGlass override edge
SELECT *
FROM GRAPH_TABLE (
  access_kg
  MATCH (bg IS entity WHERE bg.name = 'BreakGlass')
        -[l IS link]->(ctl IS entity WHERE ctl.name = 'ProductionDeny')
  COLUMNS (bg.name AS override, l.rel_type AS rel, ctl.name AS control)
) AS x;

-- =============================================================================
-- Speaker backup if PROPERTY GRAPH syntax differs on your beta build:
-- Fall back to equivalent relational joins and say:
-- "SQL/PGQ rewrites to relational plans — here is the same path as joins."
-- =============================================================================
WITH top_doc AS (
  SELECT id, title FROM documents
  ORDER BY embedding <=> '[0.88, 0.12, 0.10]' LIMIT 1
)
SELECT d.title,
       p.name AS policy,
       c.name AS control,
       s.name AS system
FROM top_doc d
JOIN document_entities de ON de.document_id = d.id
JOIN entities p ON p.id = de.entity_id AND p.name = 'ContractorAccess'
JOIN relationships r1 ON r1.src_entity = p.id AND r1.rel_type = 'ENFORCES'
JOIN entities c ON c.id = r1.dst_entity
JOIN relationships r2 ON r2.src_entity = c.id AND r2.rel_type = 'PROTECTS'
JOIN entities s ON s.id = r2.dst_entity;
