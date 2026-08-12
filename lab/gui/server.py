#!/usr/bin/env python3
"""PGDay demo GUI backend — talks to Podman Postgres via psql (no extra deps)."""
from __future__ import annotations

import json
import os
import subprocess
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
STATIC = ROOT
CONTAINER = os.environ.get("CONTAINER_NAME", "pgday-pg19-ai")
HOST = os.environ.get("GUI_HOST", "127.0.0.1")
PORT = int(os.environ.get("GUI_PORT", "8788"))

# Two ways to reach Postgres:
#   in-container  : PGHOST set -> run psql directly over the compose network
#   on the host   : no PGHOST  -> shell out to `podman exec` / `docker exec`
PGHOST = os.environ.get("PGHOST")
PGPORT = os.environ.get("PGPORT", "5432")
PGUSER = os.environ.get("PGUSER", "demo")
PGDATABASE = os.environ.get("PGDATABASE", "pgday")

QUESTION = "Can contractors access production databases?"

DEMOS = {
    "a": {
        "id": "a",
        "title": "Demo A · SQL only",
        "subtitle": "Searching by keywords",
        "headline": "Exact words only",
        "explanation": (
            "Normal SQL looks for the exact words in the question. "
            "If the document uses different wording, the search returns nothing — "
            "even when the policy already exists in the database."
        ),
        "why": "Keywords match letters, not meaning. So the evidence path never starts.",
        "verdict": "No usable answer — the keywords never matched.",
        "tone": "bad",
        "graph": {
            "mode": "miss",
            "nodes": ["Document", "Policy", "Control", "System"],
            "lit": [],
        },
        "sql": """SELECT id, title
FROM documents
WHERE body ILIKE '%contractor%production%'
   OR title ILIKE '%contractor%production%';""",
        "sql_soft": """SELECT id, title
FROM documents
WHERE body ILIKE '%contractor%'
   OR body ILIKE '%production%';""",
    },
    "b": {
        "id": "b",
        "title": "Demo B · Vector only",
        "subtitle": "Searching by meaning",
        "headline": "Find the right document",
        "explanation": (
            "pgvector compares meaning, not exact wording. "
            "It finds the Access control overview document — the right subject area — "
            "but that document only says “see the linked policies.” "
            "We still cannot decide whether contractors may access production."
        ),
        "why": "Similarity finds a starting point. It does not follow relationships.",
        "verdict": "Relevant document found — still no decision path.",
        "tone": "warn",
        "graph": {
            "mode": "partial",
            "nodes": ["Document", "Policy", "Control", "System"],
            "lit": ["Document"],
        },
        "sql": """SELECT id, title,
       round((1 - (embedding <=> '[0.88, 0.12, 0.10]'))::numeric, 3) AS similarity
FROM documents
ORDER BY embedding <=> '[0.88, 0.12, 0.10]'
LIMIT 1;""",
    },
    "c": {
        "id": "c",
        "title": "Demo C · Hybrid",
        "subtitle": "pgvector + SQL/PGQ",
        "headline": "Follow the evidence path",
        "explanation": (
            "We start from the document found by pgvector, then use SQL/PGQ to walk "
            "the relationships already stored in PostgreSQL: "
            "document → contractor policy → deny control → production database. "
            "Now the answer is not only “No” — it is explainable."
        ),
        "why": "SQL/PGQ turns a relevant document into a grounded evidence path.",
        "verdict": "Answer: No — contractors cannot access production databases.",
        "tone": "ok",
        "graph": {
            "mode": "full",
            "nodes": ["Document", "ContractorAccess", "ProductionDeny", "ProductionDB"],
            "lit": ["Document", "ContractorAccess", "ProductionDeny", "ProductionDB"],
            "edges": ["mentions", "ENFORCES", "PROTECTS"],
        },
        "sql": """SELECT *
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
) AS g;""",
        "sql_encore": """SELECT *
FROM GRAPH_TABLE (
  access_kg
  MATCH
    (bg IS entity WHERE bg.name = 'BreakGlass')
      -[l IS link]->(ctl IS entity WHERE ctl.name = 'ProductionDeny')
  COLUMNS (bg.name AS override, l.rel_type AS rel, ctl.name AS control)
) AS x;""",
        "sql_fallback": """WITH top_doc AS (
  SELECT id, title FROM documents
  ORDER BY embedding <=> '[0.88, 0.12, 0.10]' LIMIT 1
)
SELECT d.title AS retrieved_doc, p.name AS policy_name,
       c.name AS control_name, s.name AS system_name
FROM top_doc d
JOIN document_entities de ON de.document_id = d.id
JOIN entities p ON p.id = de.entity_id AND p.name = 'ContractorAccess'
JOIN relationships r1 ON r1.src_entity = p.id AND r1.rel_type = 'ENFORCES'
JOIN entities c ON c.id = r1.dst_entity
JOIN relationships r2 ON r2.src_entity = c.id AND r2.rel_type = 'PROTECTS'
JOIN entities s ON s.id = r2.dst_entity;""",
    },
}


def container_runtime() -> str:
    for cmd in ("podman", "docker"):
        try:
            r = subprocess.run(
                [cmd, "inspect", CONTAINER],
                capture_output=True,
                text=True,
                check=False,
            )
            if r.returncode == 0:
                return cmd
        except FileNotFoundError:
            continue
    raise RuntimeError(f"Container {CONTAINER} not found. Start lab with ./scripts/up.sh")


PSQL_FLAGS = ["-v", "ON_ERROR_STOP=1", "-A", "-F", "\t", "-P", "footer=off"]


def psql_command() -> list[str]:
    if PGHOST:
        return ["psql", "-h", PGHOST, "-p", PGPORT, "-U", PGUSER, "-d", PGDATABASE, *PSQL_FLAGS]
    runtime = container_runtime()
    return [runtime, "exec", "-i", CONTAINER, "psql", "-U", PGUSER, "-d", PGDATABASE, *PSQL_FLAGS]


def run_sql(sql: str) -> dict:
    proc = subprocess.run(
        psql_command(),
        input=sql,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "query failed").strip()
        return {"ok": False, "error": err, "columns": [], "rows": []}

    lines = [ln for ln in proc.stdout.splitlines() if ln.strip() != ""]
    # Filter psql chatter
    lines = [ln for ln in lines if not ln.startswith("SET") and not ln.startswith("CREATE")]
    if not lines:
        return {"ok": True, "columns": [], "rows": [], "empty": True}

    columns = lines[0].split("\t")
    rows = [ln.split("\t") for ln in lines[1:]]
    return {"ok": True, "columns": columns, "rows": rows, "empty": len(rows) == 0}


def health() -> dict:
    try:
        ver = run_sql("SELECT version();")
        if not ver.get("ok"):
            return {"ok": False, "error": ver.get("error", "database not reachable")}
        version = ver["rows"][0][0] if ver.get("rows") else ""
        graph = run_sql("SELECT count(*) FROM pg_class WHERE relname = 'access_kg';")
        return {
            "ok": True,
            "container": CONTAINER,
            "runtime": "network" if PGHOST else "exec",
            "version": version,
            "graph_ready": bool(graph.get("ok")),
        }
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "error": str(e)}


def run_demo(which: str) -> dict:
    meta = DEMOS[which]
    out: dict = {
        "id": which,
        "title": meta["title"],
        "subtitle": meta["subtitle"],
        "headline": meta.get("headline", meta["subtitle"]),
        "explanation": meta.get("explanation", ""),
        "why": meta.get("why", ""),
        "verdict": meta["verdict"],
        "tone": meta["tone"],
        "question": QUESTION,
        "sql": meta["sql"],
        "graph": meta.get("graph", {}),
        "used_fallback": False,
    }

    if which == "a":
        primary = run_sql(meta["sql"])
        soft = run_sql(meta["sql_soft"])
        out["primary"] = primary
        out["soft"] = soft
        out["sql_soft"] = meta["sql_soft"]
        return out

    if which == "b":
        out["primary"] = run_sql(meta["sql"])
        return out

    # Demo C — try GRAPH_TABLE, fall back to joins
    primary = run_sql(meta["sql"])
    if not primary.get("ok"):
        primary = run_sql(meta["sql_fallback"])
        out["used_fallback"] = True
        out["sql"] = meta["sql_fallback"]
        out["verdict"] = "Join fallback (same path SQL/PGQ rewrites to). " + meta["verdict"]

    # Prefer live names from the query result for the graph labels
    graph = dict(meta.get("graph") or {})
    if primary.get("ok") and primary.get("rows"):
        cols = primary.get("columns") or []
        row = primary["rows"][0]
        def col(name: str):
            try:
                return row[cols.index(name)]
            except ValueError:
                return None
        nodes = [
            "Document",
            col("policy_name") or "ContractorAccess",
            col("control_name") or "ProductionDeny",
            col("system_name") or "ProductionDB",
        ]
        graph = {
            "mode": "full",
            "nodes": nodes,
            "lit": nodes,
            "edges": graph.get("edges", ["mentions", "ENFORCES", "PROTECTS"]),
        }
    out["graph"] = graph
    out["primary"] = primary
    encore = run_sql(meta["sql_encore"])
    out["encore"] = encore
    out["sql_encore"] = meta["sql_encore"]
    return out


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print(f"[gui] {self.address_string()} {fmt % args}")

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code: int, payload: dict) -> None:
        self._send(code, json.dumps(payload).encode(), "application/json; charset=utf-8")

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/", "/index.html"):
            html = (STATIC / "index.html").read_bytes()
            self._send(200, html, "text/html; charset=utf-8")
            return

        if path == "/api/health":
            self._json(200, health())
            return

        if path == "/api/meta":
            self._json(
                200,
                {
                    "question": QUESTION,
                    "demos": [
                        {"id": d["id"], "title": d["title"], "subtitle": d["subtitle"]}
                        for d in DEMOS.values()
                    ],
                },
            )
            return

        if path.startswith("/api/demo/"):
            which = path.rsplit("/", 1)[-1].lower()
            if which not in DEMOS:
                self._json(404, {"ok": False, "error": "unknown demo"})
                return
            try:
                self._json(200, run_demo(which))
            except Exception as e:  # noqa: BLE001
                self._json(500, {"ok": False, "error": str(e)})
            return

        # static assets next to index if any
        candidate = (STATIC / path.lstrip("/")).resolve()
        if candidate.is_file() and STATIC in candidate.parents:
            ctype = "application/octet-stream"
            if candidate.suffix == ".css":
                ctype = "text/css"
            elif candidate.suffix == ".js":
                ctype = "application/javascript"
            elif candidate.suffix == ".svg":
                ctype = "image/svg+xml"
            self._send(200, candidate.read_bytes(), ctype)
            return

        self._json(404, {"ok": False, "error": "not found"})


def main() -> None:
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"PGDay demo GUI → http://{HOST}:{PORT}")
    print(f"Container: {CONTAINER}")
    print("Press Ctrl+C to stop.")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
