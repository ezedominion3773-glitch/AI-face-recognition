"""
Pydantic request / response schemas for the API.
"""

from datetime import datetime
from typing import Any, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


# ── Authentication ───────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    """Credentials for admin login."""
    email: str
    password: str


class UserResponse(BaseModel):
    """Public representation of a user."""
    id: UUID
    full_name: str
    email: Optional[str] = None
    staff_id: Optional[str] = None
    role: str
    created_at: datetime

    model_config = {"from_attributes": True}


class LoginResponse(BaseModel):
    """JWT token + user info returned after successful login."""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


# ── User Management ─────────────────────────────────────────────────────────

class UserCreateRequest(BaseModel):
    """Form fields for enrolling a new user (image handled separately)."""
    full_name: str = Field(..., min_length=1, max_length=255)
    email: Optional[str] = None
    staff_id: Optional[str] = None


# ── Access Verification ─────────────────────────────────────────────────────

class AccessVerifyResponse(BaseModel):
    """Result of a face-verification attempt."""
    result: Literal["granted", "denied"]
    user_name: Optional[str] = None
    confidence_score: Optional[float] = None
    reason: str


# ── Access Logs ──────────────────────────────────────────────────────────────

class AccessLogResponse(BaseModel):
    """Single access-log entry for the admin dashboard."""
    id: UUID
    user_id: Optional[UUID] = None
    user_name: Optional[str] = None
    timestamp: datetime
    result: str
    confidence_score: Optional[float] = None
    reason: Optional[str] = None

    model_config = {"from_attributes": True}


class AccessStatsResponse(BaseModel):
    """Aggregate statistics for the admin dashboard."""
    total_users: int
    total_attempts: int
    today_attempts: int
    granted_count: int
    denied_count: int
    granted_percentage: float
    recent_attempts: list[AccessLogResponse]


# ── Pagination ───────────────────────────────────────────────────────────────

class PaginatedResponse(BaseModel):
    """Generic paginated wrapper."""
    items: list[Any]
    total: int
    page: int
    page_size: int
