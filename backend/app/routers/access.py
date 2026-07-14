"""
Access-control router – face verification, access logs, and dashboard stats.
"""

import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_admin
from app.models import AccessLog, FaceEnrollment, User
from app.schemas import (
    AccessLogResponse,
    AccessStatsResponse,
    AccessVerifyResponse,
    PaginatedResponse,
)
from app.services.face_recognition_service import face_service
from app.services.liveness_service import liveness_service

router = APIRouter(prefix="/access", tags=["Access Control"])


# ── POST /access/verify ─────────────────────────────────────────────────────

@router.post("/verify", response_model=AccessVerifyResponse)
async def verify_access(
    request: Request,
    image: UploadFile = File(None),
    frames: list[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db),
):
    """
    Face-verification pipeline for access control.

    Accepts either a single ``image`` or multiple ``frames`` (for liveness
    detection). The pipeline:

    1. **Liveness check** – texture analysis (+ multi-frame if provided).
    2. **Face detection** – ensure exactly one face is present.
    3. **Embedding extraction** – compute 128-d descriptor.
    4. **Database matching** – compare against all enrolled faces.
    5. **Audit logging** – record the outcome.
    """
    # ── Collect frame bytes ──
    frame_bytes_list: list[bytes] = []

    if frames:
        for frame in frames:
            data = await frame.read()
            if data:
                frame_bytes_list.append(data)

    if image and not frame_bytes_list:
        data = await image.read()
        if data:
            frame_bytes_list.append(data)

    if not frame_bytes_list:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No image or frames provided",
        )

    # ── 1. Liveness Check ──
    is_live, liveness_reason = liveness_service.check_liveness(frame_bytes_list)
    if not is_live:
        log = AccessLog(
            id=uuid.uuid4(),
            result="denied",
            confidence_score=None,
            reason=f"liveness:{liveness_reason}",
        )
        db.add(log)
        await db.commit()
        return AccessVerifyResponse(
            result="denied",
            reason=f"Liveness check failed: {liveness_reason}",
        )

    # Use the first frame for face recognition
    primary_image = frame_bytes_list[0]

    # ── 2. Face Detection ──
    try:
        face_service.detect_faces(primary_image)
    except ValueError as exc:
        log = AccessLog(
            id=uuid.uuid4(),
            result="denied",
            confidence_score=None,
            reason="detection_fail",
        )
        db.add(log)
        await db.commit()
        return AccessVerifyResponse(
            result="denied",
            reason=str(exc),
        )

    # ── 3. Embedding Extraction ──
    try:
        embedding = face_service.extract_embedding(primary_image)
    except ValueError as exc:
        log = AccessLog(
            id=uuid.uuid4(),
            result="denied",
            confidence_score=None,
            reason="embedding_fail",
        )
        db.add(log)
        await db.commit()
        return AccessVerifyResponse(
            result="denied",
            reason=str(exc),
        )

    # ── 4. Match Against Database ──
    enrollments_result = await db.execute(select(FaceEnrollment))
    stored_enrollments = enrollments_result.scalars().all()

    matched_user_id, confidence, match_reason = face_service.match_against_database(
        embedding,
        stored_enrollments,
        settings.MATCH_THRESHOLD,
    )

    # ── Determine result ──
    if matched_user_id:
        user_result = await db.execute(
            select(User).where(User.id == matched_user_id)
        )
        matched_user = user_result.scalars().first()
        user_name = matched_user.full_name if matched_user else "Unknown"
        result = "granted"
        reason = "match"
    else:
        user_name = None
        result = "denied"
        reason = match_reason

    # ── 5. Audit Log ──
    log = AccessLog(
        id=uuid.uuid4(),
        user_id=matched_user_id,
        result=result,
        confidence_score=confidence,
        reason=reason,
    )
    db.add(log)
    await db.commit()

    return AccessVerifyResponse(
        result=result,
        user_name=user_name,
        confidence_score=confidence,
        reason=reason,
    )


# ── GET /access/logs ─────────────────────────────────────────────────────────

@router.get("/logs", response_model=PaginatedResponse)
async def get_access_logs(
    date_from: Optional[datetime] = Query(None),
    date_to: Optional[datetime] = Query(None),
    result: Optional[str] = Query(None),
    user_id: Optional[uuid.UUID] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """
    Query access logs with optional filters for the admin dashboard.
    Supports date range, result type, and user filtering with pagination.
    """
    query = select(AccessLog).options(joinedload(AccessLog.user))
    count_query = select(func.count(AccessLog.id))

    # ── Apply filters ──
    if date_from:
        query = query.where(AccessLog.timestamp >= date_from)
        count_query = count_query.where(AccessLog.timestamp >= date_from)
    if date_to:
        query = query.where(AccessLog.timestamp <= date_to)
        count_query = count_query.where(AccessLog.timestamp <= date_to)
    if result:
        query = query.where(AccessLog.result == result)
        count_query = count_query.where(AccessLog.result == result)
    if user_id:
        query = query.where(AccessLog.user_id == user_id)
        count_query = count_query.where(AccessLog.user_id == user_id)

    # ── Total count ──
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # ── Paginated results ──
    offset = (page - 1) * page_size
    query = query.order_by(desc(AccessLog.timestamp)).offset(offset).limit(page_size)
    result_rows = await db.execute(query)
    logs = result_rows.unique().scalars().all()

    items = [
        AccessLogResponse(
            id=log.id,
            user_id=log.user_id,
            user_name=log.user.full_name if log.user else None,
            timestamp=log.timestamp,
            result=log.result,
            confidence_score=log.confidence_score,
            reason=log.reason,
        )
        for log in logs
    ]

    return PaginatedResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


# ── GET /access/logs/stats ───────────────────────────────────────────────────

@router.get("/logs/stats", response_model=AccessStatsResponse)
async def get_access_stats(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """
    Return aggregate access statistics for the admin dashboard:
    total attempts, granted/denied counts, percentage, and last 10 attempts.
    """
    # ── Counts ──
    users_result = await db.execute(select(func.count(User.id)).where(User.role != "admin"))
    total_users = users_result.scalar() or 0

    total_result = await db.execute(select(func.count(AccessLog.id)))
    total = total_result.scalar() or 0

    granted_result = await db.execute(
        select(func.count(AccessLog.id)).where(AccessLog.result == "granted")
    )
    granted = granted_result.scalar() or 0

    denied = total - granted
    granted_pct = round((granted / total) * 100, 2) if total > 0 else 0.0

    # ── Recent attempts ──
    recent_query = (
        select(AccessLog)
        .options(joinedload(AccessLog.user))
        .order_by(desc(AccessLog.timestamp))
        .limit(10)
    )
    recent_result = await db.execute(recent_query)
    recent_logs = recent_result.unique().scalars().all()

    recent_items = [
        AccessLogResponse(
            id=log.id,
            user_id=log.user_id,
            user_name=log.user.full_name if log.user else None,
            timestamp=log.timestamp,
            result=log.result,
            confidence_score=log.confidence_score,
            reason=log.reason,
        )
        for log in recent_logs
    ]

    return AccessStatsResponse(
        total_users=total_users,
        total_attempts=total,
        granted_count=granted,
        denied_count=denied,
        granted_percentage=granted_pct,
        recent_attempts=recent_items,
    )
