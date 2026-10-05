"""Create the note table (kit example feature).
REQ-IDs: none - kit example feature

Revision ID: 0001_notes
Revises:
Create Date: 2026-10-03
"""

import sqlalchemy as sa
from alembic import op

revision = "0001_notes"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create the table and its index.

    Calls: none
    """
    op.create_table(
        "note",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("body", sa.String(length=2000), nullable=False, server_default=""),
        sa.Column("archived", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_note_archived", "note", ["archived"])


def downgrade() -> None:
    """Drop the table.

    Calls: none
    """
    op.drop_index("ix_note_archived", table_name="note")
    op.drop_table("note")
