# Intelligence Query API

FastAPI service providing search and insights over the ChromaDB/SQLite intelligence store.

## Endpoints

- `GET /health` — Liveness probe
- `GET /ready` — Readiness probe (database connectivity)
- `POST /search` — Search documents by query and filters
- `POST /similar` — Find similar documents by ID
- `GET /report` — Aggregated reports (group by themes, file_type, date)

## Configuration

Environment variables:
- `INTELLIGENCE_DB_PATH` — path to SQLite database (default: `/data/intelligence/owner-intelligence.db`)
- `INTELLIGENCE_API_HOST` — host to bind (default: `127.0.0.1`)
- `INTELLIGENCE_API_PORT` — port (default: `8004`)
- `LOG_LEVEL` — logging level (default: `INFO`)
- `DEFAULT_LIMIT` — default page size
- `MAX_LIMIT` — maximum page size

## Running locally

```bash
cd integrations/intelligence-api
python -m src.api
```

Or with uvicorn:
```bash
uvicorn src.api:app --host 127.0.0.1 --port 8004
```

## Deployment

This service is part of the Chelestra-Sea realm (networking/integration). It will be deployed as a standalone process on ola-claw-main or as a systemd service.

## Integration

Pryan-Fire TradeOrchestrator will call this API to enrich trading signals with historical intelligence.
