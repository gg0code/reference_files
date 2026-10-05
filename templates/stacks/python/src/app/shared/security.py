"""Security basics: response headers, CSRF protection and a simple rate limit on changes.
REQ-IDs: none - starter app (checklist B3, B4, C2)
"""

import secrets
import time
from collections import defaultdict, deque
from typing import Annotated

from fastapi import Form, HTTPException, Request
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.responses import Response
from starlette.types import ASGIApp

CSRF_COOKIE = "csrftoken"
SAFE_METHODS = {"GET", "HEAD", "OPTIONS"}
CSP = (
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; "
    "form-action 'self'; frame-ancestors 'none'; base-uri 'self'"
)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Add browser security headers to every response, and the CSRF cookie when missing."""

    def __init__(self, app: ASGIApp, *, https_only: bool) -> None:
        """Remember whether we run behind HTTPS (production).

        Calls: none
        """
        super().__init__(app)
        self.https_only = https_only

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        """Set the headers; create a CSRF token for this browser if it has none.

        Calls: none
        """
        token = request.cookies.get(CSRF_COOKIE) or secrets.token_urlsafe(32)
        request.state.csrf_token = token
        response = await call_next(request)
        response.headers.setdefault("Content-Security-Policy", CSP)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "same-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        if self.https_only:
            response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains"
        if CSRF_COOKIE not in request.cookies:
            response.set_cookie(
                CSRF_COOKIE, token, httponly=True, samesite="strict", secure=self.https_only
            )
        return response


async def csrf_protect(request: Request, csrf_token: Annotated[str | None, Form()] = None) -> None:
    """Reject a change (POST, PUT, PATCH, DELETE) whose token does not match the browser's cookie.

    Forms send the token as a hidden field; htmx requests send it as the X-CSRF-Token header.
    Calls: none
    """
    if request.method in SAFE_METHODS:
        return
    expected = request.cookies.get(CSRF_COOKIE, "")
    sent = request.headers.get("X-CSRF-Token") or csrf_token or ""
    if not expected or not secrets.compare_digest(expected, sent):
        raise HTTPException(
            status_code=403, detail="This form expired. Reload the page and try again."
        )


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Limit changes per client and minute, so a script cannot flood forms (checklist C2)."""

    def __init__(self, app: ASGIApp, *, per_minute: int) -> None:
        """Keep the last minute of change timestamps per client address.

        Calls: none
        """
        super().__init__(app)
        self.per_minute = per_minute
        self.hits: dict[str, deque[float]] = defaultdict(deque)

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        """Count unsafe requests; answer 429 with a friendly message above the limit.

        Calls: none
        """
        if request.method not in SAFE_METHODS:
            client = request.client.host if request.client else "unknown"
            now = time.monotonic()
            window = self.hits[client]
            while window and now - window[0] > 60:
                window.popleft()
            if len(window) >= self.per_minute:
                return Response("Too many changes in a minute. Wait a moment and try again.", 429)
            window.append(now)
        return await call_next(request)
