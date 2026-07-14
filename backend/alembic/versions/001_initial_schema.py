"""Initial schema – users, face_enrollments, access_logs with pgvector

Revision ID: 001_initial_schema
Revises: None
Create Date: 2024-01-01 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "001_initial_schema"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    is_postgres = bind.dialect.name == "postgresql"

    # ── Enable pgvector extension ──
    if is_postgres:
        op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    # Dynamic UUID type
    uuid_type = UUID(as_uuid=True) if is_postgres else sa.Uuid()

    # ── Users table ──
    op.create_table(
        "users",
        sa.Column("id", uuid_type, primary_key=True),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("email", sa.String(255), unique=True, nullable=True),
        sa.Column("staff_id", sa.String(100), unique=True, nullable=True),
        sa.Column("role", sa.String(10), nullable=False, server_default="user"),
        sa.Column("hashed_password", sa.String(255), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_staff_id", "users", ["staff_id"], unique=True)

    # ── Face Enrollments table ──
    if is_postgres:
        op.create_table(
            "face_enrollments",
            sa.Column("id", uuid_type, primary_key=True),
            sa.Column(
                "user_id",
                uuid_type,
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "enrolled_at",
                sa.DateTime(timezone=True),
                server_default=sa.func.now(),
                nullable=False,
            ),
        )
        # Add the 128-d vector embedding column via raw SQL
        op.execute(
            "ALTER TABLE face_enrollments "
            "ADD COLUMN face_embedding vector(128) NOT NULL"
        )
    else:
        op.create_table(
            "face_enrollments",
            sa.Column("id", uuid_type, primary_key=True),
            sa.Column(
                "user_id",
                uuid_type,
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("face_embedding", sa.Text(), nullable=False),
            sa.Column(
                "enrolled_at",
                sa.DateTime(timezone=True),
                server_default=sa.func.now(),
                nullable=False,
            ),
        )

    op.create_index("ix_face_enrollments_user_id", "face_enrollments", ["user_id"])

    # ── Access Logs table ──
    op.create_table(
        "access_logs",
        sa.Column("id", uuid_type, primary_key=True),
        sa.Column(
            "user_id",
            uuid_type,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "timestamp",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("result", sa.String(10), nullable=False),
        sa.Column("confidence_score", sa.Float, nullable=True),
        sa.Column("reason", sa.String(50), nullable=True),
    )
    op.create_index(
        "ix_access_logs_timestamp_desc",
        "access_logs",
        [sa.text("timestamp DESC")],
    )
    op.create_index("ix_access_logs_user_id", "access_logs", ["user_id"])
    op.create_index("ix_access_logs_result", "access_logs", ["result"])


def downgrade() -> None:
    bind = op.get_bind()
    is_postgres = bind.dialect.name == "postgresql"

    op.drop_table("access_logs")
    op.drop_table("face_enrollments")
    op.drop_table("users")

    if is_postgres:
        op.execute("DROP EXTENSION IF EXISTS vector")
