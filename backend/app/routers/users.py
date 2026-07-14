"""
User management router – enrollment, listing, and deletion (admin-only).
"""

import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_admin
from app.models import FaceEnrollment, User
from app.schemas import PaginatedResponse, UserResponse
from app.services.face_recognition_service import face_service

router = APIRouter(prefix="/users", tags=["Users"])


# ── POST /users/enroll ───────────────────────────────────────────────────────

@router.post("/enroll", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def enroll_user(
    full_name: str = Form(...),
    email: str | None = Form(None),
    staff_id: str | None = Form(None),
    image: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """
    Enrol a new user by uploading a face photo.

    The image is processed to extract a 128-d face embedding, which is
    stored alongside the user record for future access verification.
    """
    # ── Read image bytes ──
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded image is empty",
        )

    # ── Extract face embedding ──
    try:
        embedding = face_service.extract_embedding(image_bytes)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )

    # ── Check for duplicate email / staff_id ──
    if email:
        existing = await db.execute(select(User).where(User.email == email))
        if existing.scalars().first():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A user with email '{email}' already exists",
            )
    if staff_id:
        existing = await db.execute(select(User).where(User.staff_id == staff_id))
        if existing.scalars().first():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A user with staff_id '{staff_id}' already exists",
            )

    # ── Create User ──
    user = User(
        id=uuid.uuid4(),
        full_name=full_name,
        email=email,
        staff_id=staff_id,
        role="user",
    )
    db.add(user)
    await db.flush()  # Assign PK so FK can reference it

    # ── Create FaceEnrollment ──
    enrollment = FaceEnrollment(
        id=uuid.uuid4(),
        user_id=user.id,
        face_embedding=embedding,
    )
    db.add(enrollment)
    await db.commit()
    await db.refresh(user)

    return UserResponse.model_validate(user)


# ── GET /users/ ──────────────────────────────────────────────────────────────

@router.get("/", response_model=PaginatedResponse)
async def list_users(
    page: int = 1,
    page_size: int = 20,
    search: str | None = None,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """
    List all enrolled users with optional search and pagination.
    """
    page = max(1, page)
    page_size = min(max(1, page_size), 100)

    query = select(User).where(User.role != "admin")
    count_query = select(func.count(User.id)).where(User.role != "admin")

    if search:
        search_filter = (
            User.full_name.ilike(f"%{search}%")
            | User.email.ilike(f"%{search}%")
            | User.staff_id.ilike(f"%{search}%")
        )
        query = query.where(search_filter)
        count_query = count_query.where(search_filter)

    # Total count
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Paginated results
    offset = (page - 1) * page_size
    query = query.order_by(User.created_at.desc()).offset(offset).limit(page_size)
    result = await db.execute(query)
    users = result.scalars().all()

    return PaginatedResponse(
        items=[UserResponse.model_validate(u) for u in users],
        total=total,
        page=page,
        page_size=page_size,
    )


# ── DELETE /users/{user_id} ─────────────────────────────────────────────────

@router.delete("/{user_id}")
async def delete_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """
    Delete a user and all cascaded face enrollments.
    """
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if user.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete admin user",
        )

    await db.delete(user)
    await db.commit()

    return {"detail": f"User '{user.full_name}' and all enrollments deleted"}
