"""Starter app platform: health, security headers, CSRF, friendly errors, rate limit.
REQ-IDs: none - starter app (checklist B3, C2, C4, O2, O3)
"""

from fastapi.testclient import TestClient
from tests.conftest import csrf


def test_health_reports_ok(client: TestClient) -> None:
    """Health is 200 with the database up."""
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["database"] == "ok"


def test_security_headers_and_request_id(client: TestClient) -> None:
    """Every page carries the security headers and a request ID."""
    r = client.get("/")
    assert "default-src 'self'" in r.headers["Content-Security-Policy"]
    assert r.headers["X-Content-Type-Options"] == "nosniff"
    assert r.headers["X-Request-ID"]


def test_change_without_csrf_token_is_refused(client: TestClient) -> None:
    """A POST without the CSRF token gets a 403, not a change."""
    r = client.post("/notes", data={"title": "x"})
    assert r.status_code == 403
    assert "expired" in r.text


def test_unknown_page_is_friendly(client: TestClient) -> None:
    """A missing page shows the friendly 404, never a stack trace."""
    r = client.get("/no-such-page")
    assert r.status_code == 404
    assert "could not find" in r.text
    assert "Traceback" not in r.text


def test_htmx_error_comes_back_as_toast(client: TestClient) -> None:
    """For htmx requests, errors become a toast in the toast area."""
    r = client.post("/notes/999/archive", headers=csrf(client))
    assert r.status_code == 404
    assert r.headers["HX-Retarget"] == "#toasts"
    assert "toast-error" in r.text


def test_rate_limit(client: TestClient, monkeypatch) -> None:
    """Above the limit, changes get a 429."""
    from app.config import get_settings
    from app.main import create_app

    monkeypatch.setenv("RATE_LIMIT_PER_MINUTE", "2")
    get_settings.cache_clear()
    with TestClient(create_app(), raise_server_exceptions=False) as c:
        c.get("/")
        codes = [
            c.post("/notes", data={"title": "a"}, headers=csrf(c)).status_code for _ in range(3)
        ]
    assert codes[-1] == 429
