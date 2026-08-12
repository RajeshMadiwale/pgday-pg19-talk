-- Schema + seed for: "Can contractors access production databases?"
-- Tiny 3-d embeddings are for teaching only (replace with real model dims in real apps).

DROP TABLE IF EXISTS document_entities CASCADE;
DROP TABLE IF EXISTS relationships CASCADE;
DROP TABLE IF EXISTS entities CASCADE;
DROP TABLE IF EXISTS documents CASCADE;

CREATE TABLE documents (
  id        int PRIMARY KEY,
  title     text NOT NULL,
  body      text NOT NULL,
  embedding vector(3) NOT NULL
);

CREATE TABLE entities (
  id   int PRIMARY KEY,
  name text NOT NULL UNIQUE,
  kind text NOT NULL CHECK (kind IN ('Policy', 'Role', 'System', 'Control'))
);

CREATE TABLE relationships (
  id         int PRIMARY KEY,
  src_entity int NOT NULL REFERENCES entities (id),
  dst_entity int NOT NULL REFERENCES entities (id),
  rel_type   text NOT NULL
);

CREATE TABLE document_entities (
  document_id int NOT NULL REFERENCES documents (id),
  entity_id   int NOT NULL REFERENCES entities (id),
  PRIMARY KEY (document_id, entity_id)
);

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
  (11, 'ProductionDeny', 'Control'),
  (12, 'BreakGlass', 'Control'),
  (13, 'Contractor', 'Role'),
  (14, 'ProductionDB', 'System');

INSERT INTO relationships (id, src_entity, dst_entity, rel_type) VALUES
  (1, 10, 13, 'APPLIES_TO'),
  (2, 10, 11, 'ENFORCES'),
  (3, 11, 14, 'PROTECTS'),
  (4, 12, 11, 'OVERRIDES');

INSERT INTO document_entities (document_id, entity_id) VALUES
  (1, 10),
  (1, 13);

CREATE INDEX documents_embedding_hnsw
  ON documents USING hnsw (embedding vector_cosine_ops);
