"""Templates: the page layout, the UI kit macros and each feature's own templates.
REQ-IDs: none - starter app
"""

from pathlib import Path
from typing import Any

from fastapi import Request
from fastapi.templating import Jinja2Templates
from starlette.responses import HTMLResponse

from app.config import get_settings

APP_DIR = Path(__file__).resolve().parent.parent
TEMPLATE_DIRS = [APP_DIR / "templates", *sorted(APP_DIR.glob("features/*/templates"))]
templates = Jinja2Templates(directory=TEMPLATE_DIRS)


def is_htmx(request: Request) -> bool:
    """True when the request came from htmx (so a page part, not a full page, is wanted).

    Calls: none
    """
    return request.headers.get("HX-Request") == "true"


def render(
    request: Request, name: str, context: dict[str, Any] | None = None, status_code: int = 200
) -> HTMLResponse:
    """Render a template with the values every page needs (settings, CSRF token).

    Calls: get_settings:config.py:src/app
    """
    ctx = {"settings": get_settings(), "csrf_token": getattr(request.state, "csrf_token", "")}
    ctx.update(context or {})
    return templates.TemplateResponse(request, name, ctx, status_code=status_code)


def toast(
    request: Request, message: str, kind: str = "success", undo_url: str = ""
) -> HTMLResponse:
    """A small notification added to the page's toast area (htmx out-of-band swap).

    Calls: render:ui.py:src/app/shared
    """
    return render(
        request, "partials/toast.html", {"message": message, "kind": kind, "undo_url": undo_url}
    )
