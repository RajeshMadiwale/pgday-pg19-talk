-- DEMO C fallback — same path as joins (what SQL/PGQ rewrites toward)
-- Use if PROPERTY GRAPH / GRAPH_TABLE is unavailable on your build.

\echo
\echo '=== DEMO C FALLBACK: Hybrid via relational joins ==='
\echo 'Same story as SQL/PGQ — useful if GRAPH_TABLE is unavailable.'
\echo

WITH top_doc AS (
  SELECT id, title
  FROM documents
  ORDER BY embedding <=> '[0.88, 0.12, 0.10]'
  LIMIT 1
)
SELECT
  d.title AS retrieved_doc,
  p.name AS policy_name,
  c.name AS control_name,
  s.name AS system_name,
  'doc→policy→control→system' AS how_linked
FROM top_doc d
JOIN document_entities de ON de.document_id = d.id
JOIN entities p ON p.id = de.entity_id AND p.name = 'ContractorAccess'
JOIN relationships r1 ON r1.src_entity = p.id AND r1.rel_type = 'ENFORCES'
JOIN entities c ON c.id = r1.dst_entity
JOIN relationships r2 ON r2.src_entity = c.id AND r2.rel_type = 'PROTECTS'
JOIN entities s ON s.id = r2.dst_entity;

\echo
\echo 'Answer: contractors do NOT get production DB access (BreakGlass is separate).'
