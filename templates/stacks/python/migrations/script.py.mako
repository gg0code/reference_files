"""${message}
REQ-IDs: <REQ-IDs this schema change serves>

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}
"""

import sqlalchemy as sa
import sqlmodel
from alembic import op
${imports if imports else ""}

revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}


def upgrade() -> None:
    """Apply this change.

    Calls: none
    """
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    """Undo this change.

    Calls: none
    """
    ${downgrades if downgrades else "pass"}
