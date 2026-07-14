"""
Authentication router – admin login via email + password.
"""

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import create_access_token, verify_password
from app.database import get_db
from app.models import User
from app.schemas import LoginRequest, LoginResponse, UserResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=LoginResponse)
async def login(
    body: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Authenticate an admin user with email and password.

    Returns a signed JWT and the user's profile on success.
    """
    # Look up user by email
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalars().first()

    if user is None or user.hashed_password is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not verify_password(body.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    # Create JWT with user ID as the subject claim
    token = create_access_token({"sub": str(user.id), "role": user.role})

    return LoginResponse(
        access_token=token,
        user=UserResponse.model_validate(user),
    )
