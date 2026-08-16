## Understand SQL/PGQ



### What it is

**SQL/PGQ** means *SQL / Property Graph Queries*. It is part of the **SQL:2023**
standard, and **PostgreSQL 19** is where community PostgreSQL brings a useful
slice of it into the product.

In plain language: you already store people, documents, policies, and systems as
**tables**. Those rows already point at each other through foreign keys. SQL/PGQ
lets you **name that shape as a graph** and **ask for paths** in a way that looks
like the business question, instead of a chain of joins you have to decode.

The three words that matter:

| Word | What it means in PostgreSQL |
|---|---|
| **Vertex** | A row treated as a node — for example a document, a policy, a system |
| **Edge** | A row that connects two vertices in a direction — usually a table with two foreign keys |
| **Pattern** | The path shape you write inside `MATCH` — PostgreSQL returns every match as ordinary rows |

Nothing is copied. The property graph is a **definition over existing tables**.
Same data, same backups, same source of truth.

### Purpose — why it exists

Relational databases are excellent at facts. They are awkward at *stories about
facts*: multi-hop links that a human would draw on a whiteboard.

The purpose of SQL/PGQ is to close that gap **without leaving PostgreSQL**:

1. **Ask the relationship question in the shape of the question** — not as five
   joins you have to reverse-engineer later.
2. **Keep trusted data in one place** — no ETL into a graph store just to answer
   “who is connected to what, and how?”
3. **Return an explainable path** — not only a yes/no or a top document, but the
   chain of evidence a reviewer can follow.
4. **Stay standard SQL** — `GRAPH_TABLE` is a table expression; the rest of your
   reporting, security, and tooling still applies.

In one line: **SQL/PGQ exists so relationship answers stay inside the database
of record, in a form humans and machines can both trust.**

### How useful it is in AI

This is the “why should an AI audience care?” half of the introduction. Use it
when you introduce the problem slide, when you set up Demo C, or in Q&A.

#### The gap AI has today

Large language models are fluent. Vector search is good at *similarity*. Neither
is enough when the real answer lives **across several trusted rows**:

- The model may invent a connection that never existed in your schema.
- pgvector may return a document that *sounds* right, then leave the assistant
  to guess what that document implies for production access, risk, or ownership.
- Classical RAG stops at “here are the top chunks.” Security and compliance
  questions need “here is the **path of facts** that proves the answer.”

SQL/PGQ fills that gap **inside PostgreSQL**, next to the same tables your
application already writes.

#### What changes when you add SQL/PGQ to an AI stack

| AI need | Without SQL/PGQ | With SQL/PGQ |
|---|---|---|
| **Grounding** | Model memory + similar text | Rows from tables you already trust |
| **Evidence** | “This document looks relevant” | `document → policy → control → system` |
| **Decision quality** | Similarity score only | Similarity *plus* a connected path |
| **Hallucinations** | Model invents the join | Model narrates a path PostgreSQL returned |
| **Audit / replay** | Hard to reproduce | Same `GRAPH_TABLE` query, same answer |
| **Architecture** | Vector DB + optional graph DB | Often **one PostgreSQL** (SQL + pgvector + PGQ) |
| **Agents** | Free-form SQL or vague tools | A bounded path query as a tool |

#### The hybrid pattern (this talk’s Demo C)

```text
  natural-language question
            │
            ▼
     pgvector top-k          ← meaning: “which documents feel relevant?”
            │
            ▼
     SQL/PGQ MATCH           ← relationships: “what path connects them?”
            │
            ▼
     model narrates the path ← language: turn rows into a clear answer
            │
            ▼
     human (or agent) sees answer + evidence path
```

Division of labour that keeps you honest:

- **pgvector** finds candidates by meaning.
- **SQL/PGQ** expands candidates into connected facts.
- **The model** explains those facts in plain language — it does **not** invent
  the edges.

Without the graph step, RAG often stops at a relevant document and lets the
model guess the rest. With SQL/PGQ, the model is fed a **path of facts**.

#### Where it helps most in AI products

Concrete places this pattern shows up:

1. **Access / security assistants** — “Can contractors reach production?” needs
   a path, not a similar paragraph (this talk’s example).
2. **Policy and compliance copilots** — map a control to the systems and owners
   it actually covers.
3. **Impact analysis** — “If this service fails, what depends on it?” as a fixed
   downstream path over inventory tables.
4. **Data lineage for AI features** — show which sources and transforms fed a
   training or inference dataset.
5. **Knowledge assistants over enterprise entities** — people, teams, apps,
   tickets, and documents linked by real foreign keys, not only by embedding
   distance.
6. **Agent tool calling** — expose a small, named path query (`GRAPH_TABLE` with
   a fixed `MATCH`) instead of giving the agent open-ended write access.

#### Lines you can say on stage (~20–30 sec)

> “AI is good at language. pgvector is good at meaning. Neither one proves a
> relationship. SQL/PGQ is how we ask the relationship question inside
> PostgreSQL, so the assistant returns an evidence path — not a guess.”

> “In this demo, the vector step finds the document. The graph step turns that
> document into a decision we can defend.”

#### When to use it — and when not to

**Reach for SQL/PGQ in an AI design when:**

- The answer spans **more than one hop** of business entities
- A similarity hit alone is **not enough to act on** (security, money, PII)
- You need the reply to be **reproducible in SQL** for audit
- You prefer **one PostgreSQL** over a vector store plus a separate graph store

**Do not force it when:**

- A single-table lookup or keyword filter already answers the question
- You only need “similar documents,” not a connected decision
- You need deep, variable-length graph analytics that PostgreSQL 19 cannot
  express yet — say so, and keep a dedicated graph engine for that slice

#### Takeaway for AI architects

> **Similarity finds candidates. Graphs explain connections. SQL keeps the
> facts. Put all three in PostgreSQL when the path is fixed and the data is
> already there — that is where SQL/PGQ becomes useful for AI.**

### How you use it (the two statements)

**1. Declare the graph once** — map tables to vertices and edges:

```sql
CREATE PROPERTY GRAPH access_kg
  VERTEX TABLES ( document, entity )
  EDGE TABLES (
    mentions
      SOURCE KEY (document_id) REFERENCES document (id)
      DESTINATION KEY (entity_id) REFERENCES entity (id)
  );
```

**2. Query a path with `GRAPH_TABLE` + `MATCH`:**

```sql
SELECT *
FROM GRAPH_TABLE (
  access_kg
  MATCH (doc IS document)
        -[IS mentions]->(pol IS entity)
        -[IS enforces]->(ctl IS entity)
        -[IS protects]->(sys IS entity)
  COLUMNS ( doc.title, pol.name, ctl.name, sys.name )
) AS g;
```

Read that `MATCH` left to right: *document mentions policy, policy enforces
control, control protects system*. That is the evidence path the talk ends on.

### Syntax you must keep straight

PostgreSQL 19 uses **`IS` for labels**, not Cypher’s colon:

```sql
-- correct in PostgreSQL 19
MATCH (doc IS document)-[IS mentions]->(pol IS entity)

-- Cypher style — will not work here
MATCH (doc:document)-[:mentions]->(pol:entity)
```

`GRAPH_TABLE` returns a **normal result set**. You can `WHERE`, `JOIN`,
`ORDER BY`, and aggregate on it like any other subquery.

### How it sits next to SQL and pgvector

| Tool | Question it answers well |
|---|---|
| **SQL** | Exact facts — “does this row exist?”, “what is the status?” |
| **pgvector** | Meaning — “which document is about contractor access?” |
| **SQL/PGQ** | Relationships — “which path connects that document to production?” |

They are independent features. This talk **combines** pgvector and SQL/PGQ
because AI retrieval often needs both: find a candidate by meaning, then expand
by relationships until you have an explainable answer.

### What it is not

- **Not a second database.** No Neo4j-style copy of the data for this pattern.
- **Not a replacement for every graph workload.** Deep analytics, variable-depth
  walks, and huge multi-hop graphs may still belong in a dedicated graph engine.
- **Not magic.** The planner still works against your tables and indexes. Bad
  indexes still hurt.
