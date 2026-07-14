"""
Seed script – creates the initial admin user if one does not already exist.

Usage:
    python seed_admin.py
"""

import asyncio
import sys

from sqlalchemy import select

from app.auth import hash_password
from app.config import settings
from app.database import async_session, init_db
from app.models import User


async def seed_admin() -> None:
    """Create the admin user defined in settings if absent."""
    await init_db()

    async with async_session() as db:
        result = await db.execute(
            select(User).where(User.email == settings.ADMIN_EMAIL)
        )
        existing = result.scalars().first()

        if existing:
            print(f"[INFO] Admin user already exists: {existing.email}")
            return

        admin = User(
            full_name="System Administrator",
            email=settings.ADMIN_EMAIL,
            role="admin",
            hashed_password=hash_password(settings.ADMIN_PASSWORD),
        )
        db.add(admin)
        await db.commit()
        await db.refresh(admin)

        print("[SUCCESS] Admin user created successfully!")
        print(f"    Email:    {settings.ADMIN_EMAIL}")
        print(f"    Password: {settings.ADMIN_PASSWORD}")
        print(f"    ID:       {admin.id}")
        print()
        print("[WARNING] Change the default password in production!")


if __name__ == "__main__":
    asyncio.run(seed_admin())
