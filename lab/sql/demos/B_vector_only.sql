-- DEMO B — Vector only (pgvector)
-- Question embedding ≈ meaning of the question (teaching 3-d vector)
-- Expect: Access control overview — relevant but incomplete ("see linked policies")

\echo
\echo '=== DEMO B: Vector only (pgvector) ==='
\echo 'Question: Can contractors access production databases?'
\echo

SELECT
  id,
  title,
  round((1 - (embedding <=> '[0.88, 0.12, 0.10]'))::numeric, 3) AS similarity
FROM documents
ORDER BY embedding <=> '[0.88, 0.12, 0.10]'
LIMIT 1;

\echo
\echo 'Note: relevant document, but no policy decision yet.'
