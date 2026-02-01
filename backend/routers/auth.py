from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
from sqlalchemy.orm import Session

from backend import models
from backend.config import JWT_SECRET_KEY, JWT_ALGORITHM, JWT_EXPIRATION_HOURS
from backend.database import get_db


router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()


# ---------- Pydantic Schemas ----------


class LoginRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    user_id: int
    role: str
    name: str


class UserInfo(BaseModel):
    user_id: int
    email: str
    role: str
    name: str
    ref_id: Optional[int] = None  # student_id or teacher_id


# ---------- Helper Functions ----------


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> UserInfo:
    """Dependency to get current authenticated user from JWT token."""
    payload = decode_token(credentials.credentials)
    user_id = payload.get("user_id")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )
    
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    
    if user.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive",
        )
    
    # Get name and ref_id based on role
    name = user.email
    ref_id = None
    
    if user.role == "student" and user.student:
        name = user.student.name
        ref_id = user.student.student_id
    elif user.role == "teacher" and user.teacher:
        name = f"Teacher {user.teacher.employee_no}"
        ref_id = user.teacher.teacher_id
    elif user.role == "admin":
        name = "Admin"
    
    return UserInfo(
        user_id=user.user_id,
        email=user.email,
        role=user.role,
        name=name,
        ref_id=ref_id,
    )


def get_current_active_admin(
    current_user: UserInfo = Depends(get_current_user),
) -> UserInfo:
    """Dependency to check if current user is an active admin."""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The user is not an admin",
        )
    return current_user


# ---------- Routes ----------


@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """Authenticate user and return JWT token."""
    user = (
        db.query(models.User)
        .filter(models.User.email == request.email)
        .first()
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    
    if not verify_password(request.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    
    if user.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is inactive. Contact admin.",
        )
    
    # Get name based on role
    name = user.email
    if user.role == "student" and user.student:
        name = user.student.name
    elif user.role == "teacher" and user.teacher:
        name = f"Teacher {user.teacher.employee_no}"
    elif user.role == "admin":
        name = "Admin"
    
    # Create JWT token
    token_data = {
        "user_id": user.user_id,
        "email": user.email,
        "role": user.role,
    }
    access_token = create_access_token(token_data)
    
    return LoginResponse(
        access_token=access_token,
        token_type="bearer",
        user_id=user.user_id,
        role=user.role,
        name=name,
    )


@router.get("/me", response_model=UserInfo)
def get_me(current_user: UserInfo = Depends(get_current_user)):
    """Get current authenticated user info."""
    return current_user
