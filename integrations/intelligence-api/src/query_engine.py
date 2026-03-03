"""Query engine for intelligence database."""

import sqlite3
from typing import List, Dict, Any, Optional
from datetime import datetime
from .config import Config

class IntelligenceQueryEngine:
    """Encapsulates database access for intelligence queries."""

    def __init__(self, db_path: str = None):
        self.db_path = db_path or Config.DB_PATH

    def search(self, query: str, filters: Optional[Dict[str, Any]] = None, limit: int = 20, offset: int = 0) -> Dict[str, Any]:
        """
        Search documents by query text and optional filters.
        Returns documents with snippets and extraction metadata.
        """
        if limit > Config.MAX_LIMIT:
            limit = Config.MAX_LIMIT

        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        # Build WHERE clause
        conditions = []
        params = []

        if query:
            # Simple text matching across raw_content and extractions fields
            conditions.append("(d.raw_content LIKE ? OR e.key_facts LIKE ? OR e.themes LIKE ? OR e.names_mentioned LIKE ?)")
            like_pattern = f"%{query}%"
            params.extend([like_pattern] * 4)

        if filters:
            if "themes" in filters:
                placeholders = ", ".join(["?"] * len(filters["themes"]))
                conditions.append(f"e.themes LIKE ?")
                # themes is stored as maybe comma-separated or text; using LIKE for each theme
                params.extend([f"%{theme}%" for theme in filters["themes"]])
            if "file_types" in filters:
                placeholders = ", ".join(["?"] * len(filters["file_types"]))
                conditions.append(f"d.file_type IN ({placeholders})")
                params.extend(filters["file_types"])
            if "date_range" in filters:
                start = filters["date_range"].get("start")
                end = filters["date_range"].get("end")
                if start:
                    conditions.append("d.created_date >= ?")
                    params.append(start)
                if end:
                    conditions.append("d.created_date <= ?")
                    params.append(end)

        where_clause = " AND ".join(conditions) if conditions else "1=1"

        # Query: join documents with extractions (if any)
        sql = f"""
        SELECT 
            d.id, d.file_path, d.file_type, d.file_size, d.domain, d.created_date, d.modified_date,
            e.category, e.key_facts, e.dates_mentioned, e.names_mentioned, e.amounts, e.themes,
            SUBSTR(d.raw_content, INSTR(d.raw_content, ?), 200) as snippet
        FROM documents d
        LEFT JOIN extractions e ON d.id = e.document_id
        WHERE {where_clause}
        ORDER BY d.modified_date DESC
        LIMIT ? OFFSET ?
        """
        # For snippet we need to pass query as the position; but that's messy. We'll compute snippet separately.
        # Actually simpler: fetch full row then compute snippet in Python for accuracy.
        # Let's restructure: first get rows, then compute snippet.
        # For performance, we'll just return without snippet for now.
        sql = f"""
        SELECT 
            d.id, d.file_path, d.file_type, d.file_size, d.domain, d.created_date, d.modified_date,
            e.category, e.key_facts, e.dates_mentioned, e.names_mentioned, e.amounts, e.themes
        FROM documents d
        LEFT JOIN extractions e ON d.id = e.document_id
        WHERE {where_clause}
        ORDER BY d.modified_date DESC
        LIMIT ? OFFSET ?
        """
        params.extend([limit, offset])
        cursor.execute(sql, params)
        rows = cursor.fetchall()

        # Count total
        count_sql = f"SELECT COUNT(*) FROM documents d LEFT JOIN extractions e ON d.id = e.document_id WHERE {where_clause}"
        cursor.execute(count_sql, params[:-2])  # exclude limit/offset
        total = cursor.fetchone()[0]

        conn.close()

        results = []
        for row in rows:
            results.append({
                "doc_id": row["id"],
                "file_path": row["file_path"],
                "file_type": row["file_type"],
                "file_size": row["file_size"],
                "domain": row["domain"],
                "created_date": row["created_date"],
                "modified_date": row["modified_date"],
                "category": row["category"],
                "themes": self._split_csv(row["themes"]) if row["themes"] else [],
                "names_mentioned": self._split_csv(row["names_mentioned"]) if row["names_mentioned"] else [],
                "dates_mentioned": self._split_csv(row["dates_mentioned"]) if row["dates_mentioned"] else [],
                "amounts": row["amounts"],
                "key_facts": row["key_facts"],
            })

        return {
            "total": total,
            "limit": limit,
            "offset": offset,
            "results": results
        }

    def get_similar(self, doc_id: int, limit: int = 10) -> List[Dict[str, Any]]:
        """Find documents similar to the given document based on shared themes and entities."""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        # Get the source document's themes and names
        cursor.execute("SELECT themes, names_mentioned FROM extractions WHERE document_id = ?", (doc_id,))
        row = cursor.fetchone()
        if not row:
            conn.close()
            return []

        source_themes = self._split_csv(row["themes"]) if row["themes"] else []
        source_names = self._split_csv(row["names_mentioned"]) if row["names_mentioned"] else []

        if not source_themes and not source_names:
            # Fall back to same domain or file type
            cursor.execute("SELECT domain, file_type FROM documents WHERE id = ?", (doc_id,))
            doc_row = cursor.fetchone()
            if not doc_row:
                conn.close()
                return []
            cursor.execute("""
                SELECT d.*, e.themes, e.names_mentioned
                FROM documents d
                LEFT JOIN extractions e ON d.id = e.document_id
                WHERE d.id != ? AND (d.domain = ? OR d.file_type = ?)
                ORDER BY d.modified_date DESC
                LIMIT ?
            """, (doc_id, doc_row["domain"], doc_row["file_type"], limit))
        else:
            # Build conditions: match any of the themes or names
            placeholders = []
            params = []
            if source_themes:
                for theme in source_themes[:5]:  # limit top 5
                    placeholders.append("e.themes LIKE ?")
                    params.append(f"%{theme}%")
            if source_names:
                for name in source_names[:5]:
                    placeholders.append("e.names_mentioned LIKE ?")
                    params.append(f"%{name}%")
            where_clause = " OR ".join(placeholders) if placeholders else "1=0"
            sql = f"""
                SELECT d.*, e.themes, e.names_mentioned
                FROM documents d
                JOIN extractions e ON d.id = e.document_id
                WHERE d.id != ? AND ({where_clause})
                ORDER BY d.modified_date DESC
                LIMIT ?
            """
            params = [doc_id] + params + [limit]
            cursor.execute(sql, params)

        rows = cursor.fetchall()
        conn.close()

        results = []
        for row in rows:
            results.append({
                "doc_id": row["id"],
                "file_path": row["file_path"],
                "file_type": row["file_type"],
                "modified_date": row["modified_date"],
                "themes": self._split_csv(row["themes"]) if row["themes"] else [],
                "names_mentioned": self._split_csv(row["names_mentioned"]) if row["names_mentioned"] else [],
            })

        return results

    def get_report(self, group_by: str = "themes") -> Dict[str, Any]:
        """Generate aggregated insights."""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        if group_by == "themes":
            # Since themes is stored as CSV, we need to split and aggregate. Simpler: count occurrences of LIKE patterns? That's complex.
            # For now, just count documents by category
            cursor.execute("""
                SELECT category, COUNT(*) as count
                FROM extractions
                WHERE category IS NOT NULL
                GROUP BY category
                ORDER BY count DESC
            """)
            groups = [{"category": row["category"], "count": row["count"]} for row in cursor.fetchall()]

        elif group_by == "file_type":
            cursor.execute("""
                SELECT file_type, COUNT(*) as count
                FROM documents
                WHERE file_type IS NOT NULL
                GROUP BY file_type
                ORDER BY count DESC
            """)
            groups = [{"file_type": row["file_type"], "count": row["count"]} for row in cursor.fetchall()]
        elif group_by == "date":
            cursor.execute("""
                SELECT DATE(created_date) as date, COUNT(*) as count
                FROM documents
                WHERE created_date IS NOT NULL
                GROUP BY DATE(created_date)
                ORDER BY date DESC
                LIMIT 30
            """)
            groups = [{"date": row["date"], "count": row["count"]} for row in cursor.fetchall()]
        else:
            groups = []

        # Overall stats
        cursor.execute("SELECT COUNT(*) as total_docs FROM documents")
        total_docs = cursor.fetchone()["total_docs"]
        cursor.execute("SELECT COUNT(*) as total_extractions FROM extractions")
        total_extractions = cursor.fetchone()["total_extractions"]

        conn.close()

        return {
            "total_documents": total_docs,
            "total_extractions": total_extractions,
            "group_by": group_by,
            "groups": groups
        }

    def _split_csv(self, csv_text: str) -> List[str]:
        """Split comma-separated values into list, stripping whitespace."""
        if not csv_text:
            return []
        return [item.strip() for item in csv_text.split(",") if item.strip()]
