"""Friendly error pages and messages: users never see a stack trace (checklist C4, O4).
REQ-IDs: none - starter app
"""

import logging

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.responses import Response

from app.shared.logging import request_id
from app.shared.ui import is_htmx, render, toast

log = logging.getLogger("app")
MESSAGES = {
    403: "You do not have access to this, or the form expired.",
    404: "We could not find that page.",
    429: "Too many changes in a minute. Wait a moment and try again.",
    500: "Something went wrong on our side. It has been recorded.",
}


def error_response(request: Request, status: int, detail: str = "") -> Response:
    """A full error page, or a toast when the request came from htmx.

    Calls: render:ui.py:src/app/shared, toast:ui.py:src/app/shared, is_htmx:ui.py:src/app/shared
    """
    message = detail or MESSAGES.get(status, "That did not work.")
    if is_htmx(request):
        response = toast(request, message, kind="error")
        response.status_code = status
        response.headers["HX-Retarget"] = "#toasts"
        response.headers["HX-Reswap"] = "beforeend"
        return response
    reference = getattr(request.state, "request_id", request_id.get())
    context = {"status": status, "message": message, "reference": reference}
    return render(request, "errors/error.html", context, status_code=status)


def install_error_handlers(app: FastAPI) -> None:
    """Register the handlers for HTTP errors, invalid input and unexpected failures.

    Calls: error_response:errors.py:src/app/shared
    """

    @app.exception_handler(StarletteHTTPException)
    async def http_error(request: Request, exc: StarletteHTTPException) -> Response:
        """Known HTTP errors (404, 403, ...).

        Calls: error_response:errors.py:src/app/shared
        """
        detail = exc.detail if isinstance(exc, HTTPException) and exc.status_code != 404 else ""
        return error_response(request, exc.status_code, str(detail or ""))

    @app.exception_handler(RequestValidationError)
    async def invalid_input(request: Request, exc: RequestValidationError) -> Response:
        """Input that does not match what the route expects.

        Calls: error_response:errors.py:src/app/shared
        """
        log.info("invalid input", extra={"fields": {"errors": len(exc.errors())}})
        return error_response(request, 422, "Some of the information sent was not valid.")

    @app.exception_handler(Exception)
    async def unexpected(request: Request, exc: Exception) -> Response:
        """Anything else: log it with the request ID, show a calm page with that ID.

        Calls: error_response:errors.py:src/app/shared
        """
        log.error("unhandled error", exc_info=exc)
        return error_response(request, 500)
