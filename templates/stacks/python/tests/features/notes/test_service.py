"""Notes business rules.
REQ-IDs: none - kit example feature
"""

from datetime import UTC, datetime, timedelta

from app.features.notes.models import Note
from app.features.notes.service import clean_input, search, summary


def test_clean_input_tidies_spaces() -> None:
    """Extra spaces are removed; nothing to fix."""
    data = clean_input("  Buy   milk ", "  2 litres  ")
    assert (data.title, data.body, data.ok) == ("Buy milk", "2 litres", True)


def test_missing_title_explains_the_fix() -> None:
    """An empty title gets a plain-language message."""
    assert clean_input("   ", "").errors["title"] == "Give the note a title."


def test_too_long_values_say_how_long() -> None:
    """Over-long title and text say the limit and the current length."""
    data = clean_input("x" * 121, "y" * 2001)
    assert "120" in data.errors["title"] and "121" in data.errors["title"]
    assert "2001" in data.errors["body"]


def test_search_matches_all_words_newest_first() -> None:
    """Every word must appear; results are newest first; empty search returns all."""
    now = datetime.now(UTC)
    old = Note(id=1, title="Milk", body="buy semi skimmed", created_at=now - timedelta(days=1))
    new = Note(id=2, title="Bread", body="buy rye", created_at=now)
    assert search([old, new], "buy milk") == [old]
    assert search([old, new], "") == [new, old]


def test_summary_wording() -> None:
    """Singular, plural and search wording."""
    assert summary(1, "") == "1 note"
    assert summary(3, "") == "3 notes"
    assert summary(1, " milk ") == "1 note matches “milk”"
    assert summary(2, "milk") == "2 notes match “milk”"
