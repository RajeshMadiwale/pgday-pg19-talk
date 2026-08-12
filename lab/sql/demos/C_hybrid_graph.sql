-- PostgreSQL 19 uses (x IS label), not Cypher (x:label)
\echo
\echo '=== DEMO C: Hybrid (pgvector + SQL/PGQ) ==='
\echo 'Question: Can contractors access production databases?'
\echo

\echo '-- Step 1: semantic candidate (same as Demo B)'
SELECT id, title
FROM documents
ORDER BY embedding <=> '[0.88, 0.12, 0.10]'
LIMIT 1;

\echo
\echo '-- Step 2: expand relationships with GRAPH_TABLE (SQL/PGQ)'
SELECT *
FROM GRAPH_TABLE (
  access_kg
  MATCH
    (doc IS document WHERE doc.id = 1)
      -[IS mentions]->(pol IS entity WHERE pol.name = 'ContractorAccess')
      -[IS link]->(ctl IS entity)
      -[IS link]->(sys IS entity WHERE sys.name = 'ProductionDB')
  COLUMNS (
    doc.title AS retrieved_doc,
    pol.name AS policy_name,
    ctl.name AS control_name,
    sys.name AS system_name
  )
) AS g;

\echo
\echo 'Answer: contractors do NOT get production DB access (BreakGlass is separate).'
\echo

\echo '-- Optional: BreakGlass override edge'
SELECT *
FROM GRAPH_TABLE (
  access_kg
  MATCH
    (bg IS entity WHERE bg.name = 'BreakGlass')
      -[l IS link]->(ctl IS entity WHERE ctl.name = 'ProductionDeny')
  COLUMNS (bg.name AS override, l.rel_type AS rel, ctl.name AS control)
) AS x;
