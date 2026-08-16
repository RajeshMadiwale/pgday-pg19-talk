# PGDay 2026 — PostgreSQL 19 SQL/PGQ

**Title:** PostgreSQL 19 SQL/PGQ: When Similarity Alone Is Not Enough  
**Speaker:** Rajesh Madiwale · Sr Solution Architect, Yugabyte · 30 min

## Podman lab (you + attendees)
```bash
cd pgday-pg19-ai/lab
chmod +x scripts/*.sh sql/init/*.sh
./scripts/up.sh && ./scripts/gui.sh   # GUI → http://127.0.0.1:8788
# or: ./scripts/run-demo.sh           # terminal
```
Handout: [`lab/ATTENDEE.md`](lab/ATTENDEE.md)

## Package
| Path | Purpose |
|---|---|
| `lab/` | Containerized Postgres 19 + pgvector + A/B/C demos |
| `slides/` | HTML deck (open http://127.0.0.1:8790 after `podman compose up -d`) |
| `slides/PGDay-2026-SQL-PGQ.pdf` | **12-page PDF** for sharing / review |
| `demo/` | Single-file SQL sketch |

## Design
Dark grid theme, `#ff7a45` accent, Inter / Inter Tight / JetBrains Mono, Yugabyte logo.
