"""Business rules for notes: plain functions, no web or database code (doclint D5).
REQ-IDs: none - kit example feature
"""

from app.features.notes.models import Note, NoteInput

TITLE_MAX = 120
BODY_MAX = 2000


def clean_input(title: str, body: str) -> NoteInput:
    """Tidy what the user typed and explain, in plain words, anything that must change.

    Calls: none
    """
    title = " ".join(title.split())
    body = body.strip()
    errors: dict[str, str] = {}
    if not title:
        errors["title"] = "Give the note a title."
    elif len(title) > TITLE_MAX:
        errors["title"] = f"Keep the title under {TITLE_MAX} characters (now {len(title)})."
    if len(body) > BODY_MAX:
        errors["body"] = f"Keep the text under {BODY_MAX} characters (now {len(body)})."
    return NoteInput(title=title, body=body, errors=errors)


def matches(note: Note, query: str) -> bool:
    """True if every word of the search appears in the title or the text (case does not matter).

    Calls: none
    """
    haystack = f"{note.title} {note.body}".casefold()
    return all(word in haystack for word in query.casefold().split())


def search(notes: list[Note], query: str) -> list[Note]:
    """Notes matching the search, newest first; all notes when the search is empty.

    Calls: matches:service.py:src/app/features/notes
    """
    found = [n for n in notes if matches(n, query)] if query.strip() else list(notes)
    return sorted(found, key=lambda n: n.created_at, reverse=True)


def summary(count: int, query: str) -> str:
    """The line above the list, e.g. “3 notes” or “1 note matches “milk””.

    Calls: none
    """
    noun = "note" if count == 1 else "notes"
    if query.strip():
        verb = "matches" if count == 1 else "match"
        return f"{count} {noun} {verb} “{query.strip()}”"
    return f"{count} {noun}"
