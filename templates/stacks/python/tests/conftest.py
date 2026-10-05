"""Test setup: a fresh temporary database and app per test.
REQ-IDs: none - starter app
"""

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import SQLModel


@pytest.fixture
def client(tmp_path, monkeypatch) -> Iterator[TestClient]:
    """A test client for an app on an empty SQLite database in a temporary folder."""
    monkeypatch.setenv("SECRET_KEY", "test-secret-key-0123456789")
    monkeypatch.setenv("DATABASE_URL", f"sqlite:///{tmp_path / 'test.db'}")
    monkeypatch.setenv("RATE_LIMIT_PER_MINUTE", "1000")
    from app.config import get_settings
    from app.shared.db import get_engine

    get_settings.cache_clear()
    get_engine.cache_clear()
    import app.features.notes.models  # noqa: F401  # register the tables
    from app.main import create_app

    SQLModel.metadata.create_all(get_engine())
    with TestClient(create_app(), raise_server_exceptions=False) as c:
        c.get("/")  # receive the CSRF cookie like a browser would
        yield c
    get_engine().dispose()
    get_settings.cache_clear()
    get_engine.cache_clear()


def csrf(client: TestClient) -> dict[str, str]:
    """The header htmx sends with every change."""
    return {"X-CSRF-Token": client.cookies.get("csrftoken", ""), "HX-Request": "true"}
