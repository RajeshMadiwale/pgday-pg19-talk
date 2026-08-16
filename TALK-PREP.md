# Talk preparation — PostgreSQL 19 SQL/PGQ: When Similarity Alone Is Not Enough

**Speaker:** Rajesh Madiwale · Sr Solution Architect, Yugabyte
**Event:** PGDay 2026 · 30 minutes · 12 slides

---

## 1. The one sentence to remember

> SQL keeps the facts. pgvector finds the meaning. SQL/PGQ explains the relationships.

If you only get one message across in thirty minutes, make it this one.

---

## 2. Before you walk on stage

Start everything with a single command:

```bash
cd /Users/madiwale/PGDay-2026/pgday-pg19-ai/lab
podman compose up -d
```

| What | URL | Use it for |
|---|---|---|
| Slides | http://127.0.0.1:8790 | The talk |
| Demo GUI | http://127.0.0.1:8788 | Live A / B / C queries |

All three containers use `restart: unless-stopped`, so they survive closing the
terminal and a laptop sleep.

**Checklist**

- [ ] Both URLs open in separate browser windows
- [ ] Press `F` on the slides for fullscreen
- [ ] Run demo C once privately so the first live run is warm
- [ ] Zoom the browser to 110–125% if the room is deep
- [ ] Fonts load from Google Fonts. Without wifi the system font is used and the
      deck still looks correct, so this is not a risk

**Slide controls**

| Key | Action |
|---|---|
| `→` / `Space` | Next slide |
| `←` | Previous slide |
| `F` | Fullscreen |
| `S` | Show or hide your speaker notes |
| Click a card on slide 3 | Flip it to reveal the definition |

---

## 3. Timing plan

| Time | Slides | Section |
|---|---|---|
| 0–2 min | 1–2 | Title and agenda |
| 2–7 min | 3–4 | What SQL/PGQ is, and its advantages |
| 7–13 min | 5–6 | The old challenge, and the real problem |
| 13–16 min | 7 | Comparing SQL, pgvector and SQL/PGQ |
| 16–25 min | 8–10 | Live demo, one question three ways |
| 25–27 min | after C | Expert credibility lines (limit · toy vectors · under the hood) |
| 27–30 min | 11–12 | Benefits, thank you, questions |

**If you are running late:** shorten slide 4 (advantages) and slide 5 (the old
challenge). Keep Demo C and at least the first credibility line (the PG19 limit).
Never cut Demo C.

---

## 4. Introduction to SQL/PGQ

Read this once the night before. You do not need to recite it on stage — it is
the mental model behind slides 3–4 and Demo C. If someone asks a foundational
question after the talk, answer from here.

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

### Honest PostgreSQL 19 limit (say this once)

Variable-length paths are **not supported yet**. A fixed pattern such as
`document → policy → control → system` works. A quantifier such as `{1,3}`
returns:

```text
ERROR: element pattern quantifier is not supported
```

Fixed shapes are enough for many AI evidence paths. Be upfront about the ceiling —
that is what makes the talk credible.

### One sentence for the room

> “SQL/PGQ is how we ask relationship questions *inside* PostgreSQL — over the
> tables we already trust — and bring back a path we can explain.”

---

## 5. What to say, slide by slide

### Slide 1 — Title
Introduce yourself in one sentence and move on quickly.

> "Good morning. I am Rajesh Madiwale, Solution Architect at Yugabyte, and I have
> spent about thirteen years working with databases. Today I want to talk about a
> new feature in PostgreSQL 19 that changes how we answer relationship questions."

### Slide 2 — Agenda
Read the five points as promises. About thirty seconds.

### Slide 3 — What is SQL/PGQ?
This is the on-stage version of **§4 Introduction to SQL/PGQ**. Read the banner,
then **click each card** to reveal its definition. Say the word first, click,
then explain in your own words.

- **Vertex** — a row treated as a point in the graph. Nothing is copied.
- **Edge** — a row connecting two vertices in a direction, usually a table with
  two foreign keys.
- **Pattern** — the shape you draw inside `MATCH`. PostgreSQL returns every path
  that fits it, as ordinary rows.

> "The important part is that this sits on top of tables we already have. We are
> not loading our data into a graph engine. We are describing the relationships
> that were always there."

### Slide 4 — Advantages
Four points. The first one is the strongest, so slow down on it.

> "The query now looks like the business question. Anyone reviewing it can read
> the path — policy, control, system — instead of decoding a chain of joins."

### Slide 5 — The challenge before PGQ
Be respectful here. Many people in the room run these approaches in production
today, and they work.

> "Before this, we had two honest choices. Stay in PostgreSQL and write self-joins,
> or recursive CTEs when the depth could change — which works, but the SQL gets
> long and hard to review. Or move the data to a graph database, which also works,
> but now you are running two systems and keeping them in step."

Land it: **"Both choices work. Neither is free."**

### Slide 6 — The real problem
This slide justifies the whole talk. Take your time.

> "Imagine an internal AI assistant, and someone asks: can contractors access
> production databases? This is not really a search problem. The answer is not
> written in any single document. It only exists across the connections — a
> document points to a contractor policy, that policy enforces a deny control,
> and that control protects the production database.
> And because this is a security question, a document that merely looks relevant
> is not an acceptable answer. We have to be able to prove it."

### Slide 7 — The comparison
Never say SQL or vectors are bad. Say they answer different questions.

> "Normal SQL finds exact facts, and that is where our trusted data lives. But on
> its own it misses different wording, and long paths become long joins.
> pgvector finds similar meaning, so 'contractor' can still match 'third-party
> staff'. But on its own it gives us a relevant document, never the decision.
> SQL/PGQ finds connected facts, and it adds the one thing missing — the evidence
> path that explains the answer."

### Slides 8, 9, 10 — The live demo
Keep the same question on screen throughout.
Each demo uses the **same path diagram**, lighting up more of it each time:

| Demo | What lights up |
|---|---|
| 1 · SQL | Everything dark / red — keywords found nothing |
| 2 · pgvector | Only the Document node is lit |
| 3 · Hybrid | The full path lights up in green |

1. **Normal SQL** — run it, get no rows. Point at the dark path.
   > "Zero rows. The policy does exist. We simply did not use the same words the
   > document uses."

2. **pgvector** — run it, find the overview document. Point at the single lit node.
   > "Now we find the right document. But look — the rest of the path is still dark.
   > The document only says 'see the linked policies'."

3. **pgvector + SQL/PGQ** — run it, then narrate the fully lit path out loud.
   > "Document → ContractorAccess → ProductionDeny → ProductionDB."

   **Pause for two seconds.** Then deliver the answer:

   > "So the answer is no, contractors cannot access production databases — and
   > more importantly, we can show exactly why."

Expected result:

```
Access control overview | ContractorAccess | ProductionDeny | ProductionDB
```

After the answer lands, deliver the three **expert credibility** lines below
(about 45–60 seconds total). Do not turn them into a new slide.

### Slide 11 — Benefits
Close on value, not syntax. These are the four things the room just watched.

### Slide 12 — Thank you
Thank the organisers, invite one or two questions, offer to continue detailed
discussions afterwards.

---

## 6. Expert credibility lines (say these out loud)

These three sentences are what separate a product demo from an expert talk.
Say them after Demo C, before the benefits slide. Keep them short.

### 1. Name one real PostgreSQL 19 limit (~20 sec)

> "One honest limit in PostgreSQL 19 today: variable-length paths are not
> supported yet. A fixed pattern like document → policy → control → system
> works. A quantifier such as `{1,3}` does not — the server returns
> `element pattern quantifier is not supported`. Fixed shapes are enough for
> many AI retrieval paths; deep multi-hop analytics may still need a dedicated
> graph engine."

**Why this matters:** experts trust speakers who know the ceiling.

### 2. Admit the toy embeddings (~15 sec)

> "These embeddings are three-dimensional teaching vectors, on purpose. In
> production you would use a real model and higher dimensions. The retrieval
> pattern is the same: find a candidate by meaning, then expand by
> relationships."

**Why this matters:** stops the first skeptical question before it starts.

### 3. One under-the-hood line (~15 sec)

> "SQL/PGQ is not a second store. A property graph is only a definition placed
> over tables you already have. The planner resolves the pattern relationally —
> same data, same backups, same source of truth."

**Why this matters:** this is the architect-level insight of the talk.

### Optional, only if someone presses in Q&A

Show that the same path can be written as ordinary joins (the GUI fallback
already does this):

> "If GRAPH_TABLE were unavailable, this rewrites to the join shape you already
> know. SQL/PGQ is a clearer way to ask the same relationship question — not a
> different database."

### Do not add on stage

- No `EXPLAIN` dumps
- No AGE / `ltree` / recursive CTE deep-dive
- No extra architecture slides
- No expanding the demo schema

Credibility comes from clarity and honesty, not from more content.

---

## 7. Questions you should expect

**Does this replace Neo4j or a dedicated graph database?**
> Not for every workload. For deep graph analytics or very large traversals, a
> purpose-built engine is still the right tool. What changed is that a large set
> of relationship questions no longer justifies a second database.

**Is the data copied into a graph structure?**
> No. A property graph is a definition placed over existing tables. The rows stay
> where they are, and PostgreSQL remains the single source of truth.

**How does it perform?**
> The graph pattern is resolved against your normal tables, so ordinary indexing
> and planning apply. Benchmark it for your own shapes before committing.

**Is SQL/PGQ PostgreSQL-specific?**
> No, it comes from the SQL:2023 standard, so the skill is transferable.

**Do I need pgvector to use SQL/PGQ?**
> No, they are independent. This talk combines them because AI retrieval needs
> both meaning and relationships.

**What are the limits in PostgreSQL 19?**
> Variable-length paths are not supported yet. If you write a quantifier such as
> `-[IS link]->{1,3}`, the server returns
> `ERROR: element pattern quantifier is not supported`. Patterns must be a fixed
> shape in this release. Be upfront about this — it builds credibility.

**Why are the embeddings only 3-dimensional?**
> Teaching vectors, on purpose. A production model would produce higher-dimension
> embeddings. The hybrid pattern — candidate by meaning, then expand by graph —
> stays the same.

**Can I try this myself?**
> Yes, share `lab/ATTENDEE.md`. The whole environment runs in containers.

---

## 8. Syntax detail you must not get wrong

PostgreSQL 19 uses `IS` for labels, not the Cypher colon:

```sql
MATCH (doc IS document)-[IS mentions]->(pol IS entity)   -- correct
MATCH (doc:document)-[:mentions]->(pol:entity)           -- wrong, Cypher style
```

If someone quotes Cypher at you, this is the difference to point out.

---

## 9. If the demo fails

1. Check the containers: `podman ps`
2. Restart everything: `podman compose up -d`
3. If `GRAPH_TABLE` misbehaves, the GUI automatically falls back to the
   equivalent relational joins and labels them. Use it as a teaching moment:
   > "This is exactly what SQL/PGQ rewrites to internally — and this is the
   > version we used to write by hand."
4. Worst case, the expected output is on slide 10. Read it and continue.

Stay calm. The audience follows your reaction, not the error.

---

## 10. Rehearsal plan

- **First pass:** read the notes aloud, no timer, get comfortable with the words.
- **Second pass:** with a timer. Target 25 minutes so you have buffer.
- **Third pass:** demo only, until you can run A, B and C without looking.
- **Fourth pass:** practise the three credibility lines until they sound natural,
  not recited.
- **Final pass:** full run in fullscreen, standing, speaking at presentation volume.

Practise the two-second pause on slide 10. That silence is what makes the answer
land. Then practise the three credibility lines immediately after it.
