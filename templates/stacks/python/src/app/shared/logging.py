"""Structured JSON logs with one request ID per request (checklist O3).
REQ-IDs: none - starter app
"""

import json
import logging
import time
import uuid
from contextvars import ContextVar

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

request_id: ContextVar[str] = ContextVar("request_id", default="-")
log = logging.getLogger("app")


class JsonFormatter(logging.Formatter):
    """One JSON object per line: easy to search, never mixes two events."""

    def format(self, record: logging.LogRecord) -> str:
        """Render a log record as JSON with the current request ID.

        Calls: none
        """
        data = {
            "time": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "msg": record.getMessage(),
            "request_id": request_id.get(),
        }
        data.update(getattr(record, "fields", {}))
        if record.exc_info:
            data["error"] = self.formatException(record.exc_info)
        return json.dumps(data)


def setup_logging(level: str) -> None:
    """Send all app logs to stdout as JSON.

    Calls: JsonFormatter:logging.py:src/app/shared
    """
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)


class RequestLogMiddleware(BaseHTTPMiddleware):
    """Give every request an ID, log it once when done, and return the ID in a header."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        """Time the request and write one log line (never with form data or cookies).

        Calls: none
        """
        rid = request.headers.get("X-Request-ID") or uuid.uuid4().hex[:12]
        request.state.request_id = rid  # also readable by the error page outside this middleware
        token = request_id.set(rid)
        start = time.perf_counter()
        try:
            response = await call_next(request)
        finally:
            request_id.reset(token)
        fields = {
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
            "ms": round((time.perf_counter() - start) * 1000, 1),
        }
        token = request_id.set(rid)
        log.info("request", extra={"fields": fields})
        request_id.reset(token)
        response.headers["X-Request-ID"] = rid
        return response
