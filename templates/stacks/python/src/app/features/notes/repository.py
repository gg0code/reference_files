"""Database access for notes: the only place that reads or writes the notes table.
REQ-IDs: none - kit example feature
"""

from sqlmodel import Session, col, select

from app.features.notes.models import Note, NoteInput


def active_notes(session: Session) -> list[Note]:
    """All notes that are not archived.

    Calls: none
    """
    return list(session.exec(select(Note).where(col(Note.archived).is_(False))))


def add(session: Session, data: NoteInput) -> Note:
    """Save a new note.

    Calls: none
    """
    note = Note(title=data.title, body=data.body)
    session.add(note)
    session.commit()
    session.refresh(note)
    return note


def set_archived(session: Session, note_id: int, archived: bool) -> Note | None:
    """Archive (delete) or restore (undo) a note; None if it does not exist.

    Calls: none
    """
    note = session.get(Note, note_id)
    if note is None:
        return None
    note.archived = archived
    session.add(note)
    session.commit()
    session.refresh(note)
    return note
