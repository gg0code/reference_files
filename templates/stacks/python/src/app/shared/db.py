"""Database engine and the per-request session.
REQ-IDs: none - starter app
"""

from collections.abc import Iterator
from functools import lru_cache

from sqlalchemy import Engine, text
from sqlmodel import Session, create_engine

from app.config import get_settings


@lru_cache
def get_engine() -> Engine:
    """Create the database engine once (SQLite needs check_same_thread off for the web server).

    Calls: get_settings:config.py:src/app
    """
    url = get_settings().database_url
    args = {"check_same_thread": False} if url.startswith("sqlite") else {}
    return create_engine(url, connect_args=args, pool_pre_ping=True)


def get_session() -> Iterator[Session]:
    """One session per request, closed afterwards (used with FastAPI Depends).

    Calls: get_engine:db.py:src/app/shared
    """
    with Session(get_engine()) as session:
        yield session


def database_ok() -> bool:
    """True if the database answers a trivial query (used by /health).

    Calls: get_engine:db.py:src/app/shared
    """
    try:
        with get_engine().connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception:  # noqa: BLE001  # any failure means "not reachable"; /health reports it
        return False
    return True
