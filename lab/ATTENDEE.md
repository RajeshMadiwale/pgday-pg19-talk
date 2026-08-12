# Attendee lab — run the PGDay demo with Podman

**Talk:** PostgreSQL 19 SQL/PGQ: When Similarity Alone Is Not Enough  
**Question:** Can contractors access production databases?

## Quick start

```bash
cd pgday-pg19-ai/lab
chmod +x scripts/*.sh sql/init/*.sh
./scripts/gui.sh         # builds if needed, starts DB + GUI, opens browser
```

GUI: **http://127.0.0.1:8788** (first build may take several minutes)

In the GUI: click **A → B → C**, press `A`/`B`/`C`, or hit **Run A → B → C**.
Deep link a single step with `?demo=c`.

Both containers keep running after you close the terminal.

```bash
./scripts/run-demo.sh    # terminal version of the same demo
./scripts/psql.sh        # interactive SQL
./scripts/down.sh        # stop
./scripts/down.sh --wipe # stop + delete volume
```

## Requirements
- Podman 4+ (or Docker)
- `podman compose` / `podman-compose` / `docker compose`
- Internet on first build (`postgres:19beta2` + compile `pgvector`)

macOS: `podman machine start` if the VM is stopped.

## Connection
| | |
|---|---|
| Host | `localhost` |
| Port | `54329` (override with `PGDAY_PORT`) |
| DB / user / pass | `pgday` / `demo` / `demo` |

```bash
psql "postgresql://demo:demo@localhost:54329/pgday"
```

## What you will see
| Demo | Meaning |
|---|---|
| **A** SQL keyword | Miss / incomplete |
| **B** pgvector | Relevant doc, no decision |
| **C** SQL/PGQ hybrid | Policy → deny → system = **No** |
| **C fallback** | Same path via joins if graph SQL fails |

## Mental model
**Similarity finds candidates. Graphs explain relationships.**

## Note
Postgres 19 is beta. Label syntax is `(x IS label)`, not Cypher `(x:label)`. Teaching embeddings are 3-D on purpose.
