"""Configuration for intelligence-api."""

import os
from pathlib import Path

class Config:
    # Database
    DB_PATH = os.getenv("INTELLIGENCE_DB_PATH", "/data/intelligence/owner-intelligence.db")

    # Server
    HOST = os.getenv("INTELLIGENCE_API_HOST", "127.0.0.1")
    PORT = int(os.getenv("INTELLIGENCE_API_PORT", "8004"))

    # Logging
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

    # Query defaults
    DEFAULT_LIMIT = int(os.getenv("DEFAULT_LIMIT", "20"))
    MAX_LIMIT = int(os.getenv("MAX_LIMIT", "100"))

    # Ensure paths exist
    @classmethod
    def validate(cls):
        if not Path(cls.DB_PATH).exists():
            raise FileNotFoundError(f"Database not found: {cls.DB_PATH}")
