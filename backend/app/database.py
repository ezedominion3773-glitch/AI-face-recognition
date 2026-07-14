"""
Async SQLAlchemy engine, session factory, and database initialisation helpers.
Supports fallback to local SQLite database when PostgreSQL is unavailable.
"""

import json
import logging
try:
    import numpy as np
except ImportError:
    np = None
from sqlalchemy import event, text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.types import TypeDecorator, Text

from app.config import settings

logger = logging.getLogger("app.database")

# Local SQLite fallback URL
SQLITE_URL = "sqlite+aiosqlite:///./faceapp.db"


# ── Dialect-Agnostic Vector Type ─────────────────────────────────────────────
class VectorType(TypeDecorator):
    """
    A dialect-agnostic vector type.
    On PostgreSQL, it uses the pgvector Vector type.
    On SQLite, it stores the vector as a JSON-serialized text string.
    """
    impl = Text
    cache_ok = True

    def __init__(self, dim: int):
        super().__init__()
        self.dim = dim

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            from pgvector.sqlalchemy import Vector
            return dialect.type_descriptor(Vector(self.dim))
        else:
            return dialect.type_descriptor(Text())

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        if dialect.name == "postgresql":
            return value
        # For SQLite/etc., store as JSON string
        if np is not None and isinstance(value, np.ndarray):
            value = value.tolist()
        return json.dumps(value)

    def process_result_value(self, value, dialect):
        if value is None:
            return None
        if dialect.name == "postgresql":
            if np is not None and isinstance(value, np.ndarray):
                return value.tolist()
            return value
        # For SQLite/etc., load from JSON string
        return json.loads(value)


# ── Engine & Session Factory Builder ──────────────────────────────────────────
def create_engine_and_session(url: str):
    """Create an async SQLAlchemy engine and session factory for the given URL."""
    if url.startswith("sqlite"):
        eng = create_async_engine(url, echo=False)
        # Enable WAL mode and foreign key constraints for SQLite
        @event.listens_for(eng.sync_engine, "connect")
        def set_sqlite_pragma(dbapi_connection, connection_record):
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.close()
    else:
        eng = create_async_engine(
            url,
            echo=False,
            pool_size=10,
            max_overflow=20,
        )
    
    session_factory = async_sessionmaker(
        eng,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    return eng, session_factory


# Initialize default engine & session factory
try:
    engine, async_session = create_engine_and_session(settings.DATABASE_URL)
except Exception as exc:
    if "postgresql" in settings.DATABASE_URL:
        print(f"[WARNING] Failed to create PostgreSQL engine (probably missing asyncpg driver): {exc}")
        print(f"[FALLBACK] Falling back to local SQLite: {SQLITE_URL}")
        engine, async_session = create_engine_and_session(SQLITE_URL)
    else:
        raise exc


# ── Declarative Base ─────────────────────────────────────────────────────────
class Base(DeclarativeBase):
    """Base class for all ORM models."""
    pass


# ── Dependency ───────────────────────────────────────────────────────────────
async def get_db() -> AsyncSession:
    """FastAPI dependency that yields an async database session."""
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()


# ── Initialisation ───────────────────────────────────────────────────────────
async def init_db() -> None:
    """
    Create the pgvector extension (if connected to PostgreSQL) and all ORM tables.
    Gracefully falls back to SQLite if connection to PostgreSQL fails.
    """
    global engine, async_session
    
    try:
        # Attempt to connect and initialize using configured database
        async with engine.begin() as conn:
            if engine.dialect.name == "postgresql":
                await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
            await conn.run_sync(Base.metadata.create_all)
        print(f"[SUCCESS] Database initialised successfully using dialect: {engine.dialect.name}")
    except Exception as exc:
        # If PostgreSQL failed and we're not already on SQLite, try fallback
        if engine.dialect.name == "postgresql" and settings.DATABASE_URL != SQLITE_URL:
            print(f"[WARNING] PostgreSQL connection failed: {exc}")
            print(f"[FALLBACK] Gracefully falling back to local SQLite: {SQLITE_URL}")
            engine, async_session = create_engine_and_session(SQLITE_URL)
            
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            print("[SUCCESS] Database initialised successfully using local SQLite fallback")
        else:
            raise exc
