"""Notes pages: add with validation, search, delete with Undo, and the no-JavaScript path.
REQ-IDs: none - kit example feature
"""

from fastapi.testclient import TestClient
from tests.conftest import csrf


def test_empty_state_on_first_visit(client: TestClient) -> None:
    """With no notes, the page explains what to do."""
    r = client.get("/notes")
    assert r.status_code == 200
    assert "No notes yet" in r.text


def test_invalid_input_keeps_what_was_typed(client: TestClient) -> None:
    """A missing title returns the form with the message and the typed text."""
    r = client.post("/notes", data={"title": "", "body": "keep me"}, headers=csrf(client))
    assert r.status_code == 422
    assert "Give the note a title." in r.text
    assert "keep me" in r.text
    assert 'aria-invalid="true"' in r.text


def test_add_then_search(client: TestClient) -> None:
    """Adding shows a toast and the note; search narrows the list."""
    r = client.post("/notes", data={"title": "Buy milk", "body": ""}, headers=csrf(client))
    assert r.status_code == 200
    assert "Added “Buy milk”." in r.text
    client.post("/notes", data={"title": "Call Sam", "body": ""}, headers=csrf(client))
    r = client.get("/notes", params={"q": "milk"}, headers={"HX-Request": "true"})
    assert "Buy milk" in r.text and "Call Sam" not in r.text
    assert "1 note matches “milk”" in r.text


def test_delete_offers_undo_and_undo_restores(client: TestClient) -> None:
    """Delete archives with an Undo button; Undo brings the note back."""
    client.post("/notes", data={"title": "Temp", "body": ""}, headers=csrf(client))
    r = client.post("/notes/1/archive", headers=csrf(client))
    assert "Undo" in r.text and "/notes/1/restore" in r.text
    assert "No notes yet" in client.get("/notes").text
    r = client.post("/notes/1/restore", headers=csrf(client))
    assert "Restored “Temp”." in r.text
    assert "Temp" in client.get("/notes").text


def test_plain_form_without_javascript(client: TestClient) -> None:
    """Without htmx: a valid form redirects to the page; an invalid one shows the full page."""
    token = client.cookies.get("csrftoken", "")
    r = client.post("/notes", data={"title": "Plain", "csrf_token": token}, follow_redirects=False)
    assert r.status_code == 303
    r = client.post("/notes", data={"title": "", "csrf_token": token})
    assert r.status_code == 422
    assert "<html" in r.text and "Give the note a title." in r.text
