"""FastAPI application for intelligence query service."""

from typing import Optional
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse
import logging
from .config import Config
from .query_engine import IntelligenceQueryEngine

# Configure logging
logging.basicConfig(level=Config.LOG_LEVEL)
logger = logging.getLogger(__name__)

# Initialize
app = FastAPI(title="Intelligence Query API", version="0.1.0")
engine = IntelligenceQueryEngine()

@app.on_event("startup")
def validate_db():
    try:
        Config.validate()
        logger.info(f"Connected to database: {Config.DB_PATH}")
    except Exception as e:
        logger.error(f"Startup failed: {e}")
        raise

@app.get("/health")
def health():
    """Liveness probe."""
    return {"status": "ok", "service": "intelligence-api"}

@app.get("/ready")
def ready():
    """Readiness probe — check database connectivity."""
    try:
        # Simple test query
        conn = sqlite3.connect(Config.DB_PATH)
        conn.execute("SELECT 1")
        conn.close()
        return {"status": "ready", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database not ready: {e}")

@app.post("/search")
def search(
    query: str = Query(None, description="Search query string"),
    limit: int = Query(Config.DEFAULT_LIMIT, ge=1, le=Config.MAX_LIMIT),
    offset: int = Query(0, ge=0),
    themes: Optional[str] = Query(None, description="Comma-separated themes filter"),
    file_types: Optional[str] = Query(None, description="Comma-separated file types (e.g., pdf,docx)"),
    start_date: Optional[str] = Query(None, description="ISO start date"),
    end_date: Optional[str] = Query(None, description="ISO end date")
):
    """Search intelligence database with optional filters."""
    filters = {}
    if themes:
        filters["themes"] = [t.strip() for t in themes.split(",") if t.strip()]
    if file_types:
        filters["file_types"] = [ft.strip() for ft in file_types.split(",") if ft.strip()]
    if start_date or end_date:
        filters["date_range"] = {}
        if start_date:
            filters["date_range"]["start"] = start_date
        if end_date:
            filters["date_range"]["end"] = end_date

    try:
        result = engine.search(query=query or "", filters=filters if filters else None, limit=limit, offset=offset)
        return result
    except Exception as e:
        logger.exception("Search failed")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/similar")
def similar(
    doc_id: int,
    limit: int = Query(Config.DEFAULT_LIMIT, ge=1, le=Config.MAX_LIMIT)
):
    """Find documents similar to the given document ID."""
    try:
        results = engine.get_similar(doc_id=doc_id, limit=limit)
        return {"doc_id": doc_id, "limit": limit, "similar": results}
    except Exception as e:
        logger.exception("Similar query failed")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/report")
def report(group_by: str = Query("themes", enum=["themes", "file_type", "date"])):
    """Generate aggregated insights report."""
    try:
        report = engine.get_report(group_by=group_by)
        return report
    except Exception as e:
        logger.exception("Report generation failed")
        raise HTTPException(status_code=500, detail=str(e))

# Import for health check
import sqlite3
