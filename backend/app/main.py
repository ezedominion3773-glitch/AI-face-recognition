"""
FastAPI application entry point.

Assembles routers, middleware, rate limiting, and startup hooks.
"""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.config import settings
from app.database import init_db
from app.routers import access, auth, users

# ── Rate Limiter ─────────────────────────────────────────────────────────────
limiter = Limiter(key_func=get_remote_address)


# ── Lifespan ─────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown lifecycle hook."""
    # ── Startup ──
    await init_db()
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    print("[SUCCESS] Database initialised & uploads directory ready")
    yield
    # ── Shutdown ──
    print("[INFO] Shutting down...")


# ── Application ──────────────────────────────────────────────────────────────
app = FastAPI(
    title="AI Face Recognition Access Control API",
    description=(
        "Backend API for biometric face-recognition access control. "
        "Provides user enrollment, real-time face verification with "
        "liveness detection, access logging, and admin dashboard endpoints."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# Attach rate-limiter state
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── CORS (permissive for development) ────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Apply rate limits to sensitive endpoints ─────────────────────────────────
# SlowAPI decorators are applied directly on the router handlers, but we can
# also layer them at the app level for specific paths.  Here we use the
# on-handler approach by decorating the original functions post-import.

# Rate-limit: 10 requests/minute on verify, 5 requests/minute on login
@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    """Pass-through middleware; actual limits are set via decorators."""
    response = await call_next(request)
    return response


# Apply decorators to the route functions
auth.router.routes[0].endpoint = limiter.limit("5/minute")(
    auth.router.routes[0].endpoint
)
access.router.routes[0].endpoint = limiter.limit("10/minute")(
    access.router.routes[0].endpoint
)


# ── Include Routers ──────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(access.router)


# ── Root Endpoint ────────────────────────────────────────────────────────────
@app.get("/", tags=["Health"])
async def root():
    """API health check and metadata."""
    return {
        "name": "AI Face Recognition Access Control API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
        "endpoints": {
            "auth": "/auth/login",
            "enroll": "/users/enroll",
            "verify": "/access/verify",
            "logs": "/access/logs",
            "stats": "/access/logs/stats",
        },
    }
