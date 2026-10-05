"""Data shapes for notes: the database table and the cleaned input.
REQ-IDs: none - kit example feature
"""

from dataclasses import dataclass, field
from datetime import UTC, datetime

from sqlmodel import Field, SQLModel


def utc_now() -> datetime:
    """The current time in UTC (stored times are always UTC).

    Calls: none
    """
    return datetime.now(UTC)


class Note(SQLModel, table=True):
    """A note. Deleting archives it, so Undo can bring it back."""

    id: int | None = Field(default=None, primary_key=True)
    title: str = Field(max_length=120)
    body: str = Field(default="", max_length=2000)
    archived: bool = Field(default=False, index=True)
    created_at: datetime = Field(default_factory=utc_now)


@dataclass
class NoteInput:
    """What the user typed, after cleaning, plus any problems to show next to the fields."""

    title: str
    body: str
    errors: dict[str, str] = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        """True when there is nothing to fix.

        Calls: none
        """
        return not self.errors
