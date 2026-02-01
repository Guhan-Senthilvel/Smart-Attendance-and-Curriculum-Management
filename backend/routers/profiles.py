from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional

from backend import models
from backend.database import get_db
from backend.routers.auth import get_current_user, UserInfo

router = APIRouter()

# --- Pydantic Models ---

class StudentProfileBase(BaseModel):
    personal_email: Optional[str] = None
    student_mobile: Optional[str] = None
    father_mobile: Optional[str] = None
    mother_mobile: Optional[str] = None
    address: Optional[str] = None
    state: Optional[str] = None
    tenth_mark: Optional[str] = None
    twelfth_mark: Optional[str] = None

class StudentProfileCreate(StudentProfileBase):
    student_id: int

class StudentProfileRead(StudentProfileBase):
    profile_id: int
    student_id: int
    
    # Include basic student info for convenience
    reg_no: Optional[str] = None
    name: Optional[str] = None
    dept_name: Optional[str] = None
    class_name: Optional[str] = None

    class Config:
        from_attributes = True

# --- Endpoints ---

@router.get("/{student_id}", response_model=StudentProfileRead)
def get_student_profile(
    student_id: int,
    db: Session = Depends(get_db),
    current_user: UserInfo = Depends(get_current_user),
):
    # Auth Check: Admin, Teacher, or the Student themselves
    if current_user.role == "student":
        # Get own student_id
        user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
        if not user.student or user.student.student_id != student_id:
            raise HTTPException(status_code=403, detail="Cannot view other profiles")
    
    # 1. Fetch Student Basic Info
    student = db.query(models.Student).filter(models.Student.student_id == student_id).first()
    if not student: raise HTTPException(status_code=404, detail="Student not found")

    # 2. Fetch Profile
    profile = db.query(models.StudentProfile).filter(models.StudentProfile.student_id == student_id).first()
    
    # 3. Construct Response
    data = {}
    if profile:
        for k in StudentProfileBase.model_fields.keys():
            data[k] = getattr(profile, k)
        data["profile_id"] = profile.profile_id
    else:
        # Return empty shell
        data["profile_id"] = 0 
    
    data["student_id"] = student.student_id
    data["reg_no"] = student.reg_no
    data["name"] = student.name
    data["dept_name"] = student.class_.department.dept_name if student.class_ else ""
    data["class_name"] = student.class_id if student.class_id else ""

    return data

@router.post("/", response_model=StudentProfileRead)
def save_student_profile(
    profile_data: StudentProfileCreate,
    db: Session = Depends(get_db),
    current_user: UserInfo = Depends(get_current_user),
):
    # Admin only to create/edit any? Or Teacher too?
    # User said: "details are filled by admin through admin portal... and link it"
    if current_user.role not in ["admin", "teacher"]: 
         # Maybe allow student to edit SOME fields later? For now strict.
         raise HTTPException(status_code=403, detail="Not authorized")

    # Check existence
    existing = db.query(models.StudentProfile).filter(models.StudentProfile.student_id == profile_data.student_id).first()
    
    if existing:
        for key, value in profile_data.model_dump(exclude={"student_id"}).items():
            setattr(existing, key, value)
        db.commit()
        db.refresh(existing)
        return get_student_profile(profile_data.student_id, db, current_user) # Reuse read logic
    else:
        new_profile = models.StudentProfile(**profile_data.model_dump())
        db.add(new_profile)
        db.commit()
        db.refresh(new_profile)
        return get_student_profile(profile_data.student_id, db, current_user)

@router.get("/my/profile", response_model=StudentProfileRead)
def get_my_profile(
    db: Session = Depends(get_db),
    current_user: UserInfo = Depends(get_current_user),
):
    if current_user.role != "student": raise HTTPException(status_code=403)
    
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.student: raise HTTPException(status_code=404, detail="Student record not found")
    
    return get_student_profile(user.student.student_id, db, current_user)
