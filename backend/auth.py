"""
Supabase JWT verification dependency for FastAPI.

How it works:
1. The iOS app signs in via Supabase (email/password or Google OAuth).
2. Supabase returns a JWT (access token) signed with our project's JWT secret.
3. The app sends this token as: Authorization: Bearer <token>
4. This dependency decodes the token, verifies the signature, and extracts
   the user's Supabase UUID ("sub") and email — no database call needed.
5. If the token is missing, expired, or tampered with, we return 401.
"""

import os

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    secret = os.getenv("SUPABASE_JWT_SECRET")
    if not secret:
        raise HTTPException(500, "SUPABASE_JWT_SECRET not configured")

    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            secret,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")

    return {
        "user_id": payload["sub"],
        "email": payload.get("email", ""),
    }
