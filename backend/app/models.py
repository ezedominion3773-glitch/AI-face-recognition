"""
SQLAlchemy ORM models for Users, Face Enrollments, and Access Logs.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    String,
    Uuid,
    text,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base, VectorType


class User(Base):
    """Registered user / staff member."""

    __tablename__ = "users"

    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, nullable=True)
    staff_id = Column(String(100), unique=True, nullable=True)
    role = Column(String(10), nullable=False, default="user")
    hashed_password = Column(String(255), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    face_enrollments = relationship(
        "FaceEnrollment",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    access_logs = relationship(
        "AccessLog",
        back_populates="user",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return f"<User {self.full_name} ({self.email})>"


class FaceEnrollment(Base):
    """Stored 128-d face embedding for a user."""

    __tablename__ = "face_enrollments"

    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    # 128-dimensional embedding from dlib's face_recognition model
    face_embedding = Column(VectorType(128), nullable=False)
    enrolled_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="face_enrollments")

    def __repr__(self) -> str:
        return f"<FaceEnrollment user_id={self.user_id}>"


class AccessLog(Base):
    """Audit trail of every access-verification attempt."""

    __tablename__ = "access_logs"

    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    result = Column(String(10), nullable=False)  # 'granted' | 'denied'
    confidence_score = Column(Float, nullable=True)
    reason = Column(String(50), nullable=True)

    # Relationships
    user = relationship("User", back_populates="access_logs")

    # Index for efficient time-range queries on the dashboard
    __table_args__ = (
        Index("ix_access_logs_timestamp_desc", timestamp.desc()),
    )

    def __repr__(self) -> str:
        return f"<AccessLog {self.result} @ {self.timestamp}>"
