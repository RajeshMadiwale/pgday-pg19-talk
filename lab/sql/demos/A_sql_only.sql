-- DEMO A — SQL only (keyword)
-- Question: Can contractors access production databases?
-- Expect: 0 rows (wording mismatch) — or weak hits on the softer query.

\echo
\echo '=== DEMO A: SQL only (keyword) ==='
\echo 'Question: Can contractors access production databases?'
\echo

\echo '-- Strict keyword match (often empty):'
SELECT id, title
FROM documents
WHERE body ILIKE '%contractor%production%'
   OR title ILIKE '%contractor%production%';

\echo
\echo '-- Softer keyword match (still no decision path):'
SELECT id, title
FROM documents
WHERE body ILIKE '%contractor%'
   OR body ILIKE '%production%';
