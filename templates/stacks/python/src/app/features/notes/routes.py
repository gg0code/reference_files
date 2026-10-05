"""HTTP for notes: read the request, call the service and repository, return HTML.
REQ-IDs: none - kit example feature
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlmodel import Session
from starlette.responses import Response

from app.features.notes import repository, service
from app.shared.db import get_session
from app.shared.security import csrf_protect
from app.shared.ui import is_htmx, render

router = APIRouter(prefix="/notes", dependencies=[Depends(csrf_protect)])
DB = Annotated[Session, Depends(get_session)]


def list_context(session: Session, query: str) -> dict[str, object]:
    """What the list needs: the matching notes and the summary line.

    Calls: active_notes:repository.py:src/app/features/notes,
           search:service.py:src/app/features/notes, summary:service.py:src/app/features/notes
    """
    notes = service.search(repository.active_notes(session), query)
    return {"notes": notes, "q": query, "summary": service.summary(len(notes), query)}


@router.get("", response_class=HTMLResponse)
def notes_page(request: Request, session: DB, q: str = "") -> HTMLResponse:
    """The notes page; for a search typed into the box (htmx), only the list.

    Calls: list_context:routes.py:src/app/features/notes, render:ui.py:src/app/shared
    """
    ctx = list_context(session, q)
    name = "notes_list.html" if is_htmx(request) else "notes_page.html"
    return render(request, name, ctx)


@router.post("", response_class=HTMLResponse)
def create_note(
    request: Request,
    session: DB,
    title: Annotated[str, Form()] = "",
    body: Annotated[str, Form()] = "",
) -> Response:
    """Add a note. Problems come back next to the fields, keeping what the user typed.
    Works with and without JavaScript: htmx gets page parts, a plain form gets a full page.

    Calls: clean_input:service.py:src/app/features/notes, add:repository.py:src/app/features/notes,
           list_context:routes.py:src/app/features/notes, render:ui.py:src/app/shared
    """
    data = service.clean_input(title, body)
    if not data.ok:
        if is_htmx(request):
            return render(request, "notes_form.html", {"form": data}, status_code=422)
        ctx = list_context(session, "")
        ctx["form"] = data
        return render(request, "notes_page.html", ctx, status_code=422)
    note = repository.add(session, data)
    if not is_htmx(request):
        return RedirectResponse("/notes", status_code=303)
    ctx = list_context(session, "")
    ctx.update({"form": None, "flash": f"Added “{note.title}”."})
    return render(request, "notes_saved.html", ctx)


@router.post("/{note_id}/archive", response_class=HTMLResponse)
def archive_note(request: Request, session: DB, note_id: int) -> HTMLResponse:
    """Delete (archive) a note and offer Undo, instead of asking "are you sure?".

    Calls: set_archived:repository.py:src/app/features/notes,
           list_context:routes.py:src/app/features/notes, render:ui.py:src/app/shared
    """
    note = repository.set_archived(session, note_id, archived=True)
    if note is None:
        raise HTTPException(status_code=404)
    ctx = list_context(session, "")
    ctx.update(
        {
            "message": f"Deleted “{note.title}”.",
            "undo_url": f"/notes/{note_id}/restore",
            "note_id": note_id,
        }
    )
    return render(request, "notes_archived.html", ctx)


@router.post("/{note_id}/restore", response_class=HTMLResponse)
def restore_note(request: Request, session: DB, note_id: int) -> HTMLResponse:
    """Undo a delete: bring the note back and refresh the list.

    Calls: set_archived:repository.py:src/app/features/notes,
           list_context:routes.py:src/app/features/notes, render:ui.py:src/app/shared
    """
    note = repository.set_archived(session, note_id, archived=False)
    if note is None:
        raise HTTPException(status_code=404)
    ctx = list_context(session, "")
    ctx["flash"] = f"Restored “{note.title}”."
    return render(request, "notes_restored.html", ctx)
