from datetime import date
from pathlib import Path
from typing import List, Optional

import cv2
import numpy as np
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from backend import models
from backend.database import get_db
from backend.database import get_db
from backend.routers.auth import get_password_hash, get_current_active_admin


router = APIRouter()

# Storage paths
PROJECT_ROOT = Path(__file__).resolve().parents[2]
FACE_IMAGES_DIR = PROJECT_ROOT / "storage" / "face_images"
FACE_IMAGES_DIR.mkdir(parents=True, exist_ok=True)


# ---------- Pydantic Schemas ----------


class DepartmentCreate(BaseModel):
    dept_name: str


class DepartmentRead(BaseModel):
    dept_id: int
    dept_name: str

    class Config:
        from_attributes = True


class BatchCreate(BaseModel):
    start_year: int
    end_year: int


class BatchRead(BaseModel):
    batch_id: int
    start_year: int
    end_year: int

    class Config:
        from_attributes = True


class ClassCreate(BaseModel):
    class_id: str  # User provides class_id manually (e.g. "CSE-4-A")
    dept_id: int
    batch_id: int
    year: int
    section: str


class ClassRead(BaseModel):
    class_id: str
    dept_id: int
    batch_id: int
    year: int
    section: str

    class Config:
        from_attributes = True


class UserCreate(BaseModel):
    email: str
    password: str
    role: str  # "student", "teacher", "admin"
    status: str = "active"


class UserRead(BaseModel):
    user_id: int
    email: str
    role: str
    status: str

    class Config:
        from_attributes = True


class StudentCreate(BaseModel):
    reg_no: str
    name: str
    dept_id: int
    batch_id: int
    class_id: str
    email: str
    password: str


class StudentRead(BaseModel):
    student_id: int
    reg_no: str
    name: str
    dept_id: int
    batch_id: int
    class_id: str
    user_id: int

    class Config:
        from_attributes = True


class TeacherCreate(BaseModel):
    employee_no: str
    name: str  # Teacher name
    dept_id: int
    email: str
    password: str


class TeacherRead(BaseModel):
    teacher_id: int
    employee_no: str
    name: str
    dept_id: int
    user_id: int

    class Config:
        from_attributes = True


class SubjectCreate(BaseModel):
    subject_code: str
    subject_name: str
    credits: int
    dept_id: int
    semester: int


class SubjectRead(BaseModel):
    subject_code: str
    subject_name: str
    credits: int
    dept_id: int
    semester: int

    class Config:
        from_attributes = True


class TeacherSubjectMapCreate(BaseModel):
    teacher_id: int
    subject_code: str


class TeacherSubjectMapRead(BaseModel):
    teacher_id: int
    subject_code: str

    class Config:
        from_attributes = True


class StudentSubjectMapCreate(BaseModel):
    reg_no: str
    subject_code: str


class StudentSubjectMapRead(BaseModel):
    reg_no: str
    subject_code: str

    class Config:
        from_attributes = True


class FaceProfileRead(BaseModel):
    face_id: int
    reg_no: str
    has_embedding: bool

    class Config:
        from_attributes = True


class FaceImageRead(BaseModel):
    image_id: int
    reg_no: str
    image_path: str

    class Config:
        from_attributes = True


class ClassSubjectMapCreate(BaseModel):
    class_id: str
    subject_code: str


class ClassSubjectMapRead(BaseModel):
    class_id: str
    subject_code: str

    class Config:
        from_attributes = True


# ---------- Departments ----------


@router.post("/departments", response_model=DepartmentRead, dependencies=[Depends(get_current_active_admin)])
def create_department(payload: DepartmentCreate, db: Session = Depends(get_db)):
    existing = (
        db.query(models.Department)
        .filter(models.Department.dept_name == payload.dept_name)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Department with this name already exists",
        )
    dept = models.Department(dept_name=payload.dept_name)
    db.add(dept)
    db.commit()
    db.refresh(dept)
    return dept


@router.get("/departments", response_model=List[DepartmentRead], dependencies=[Depends(get_current_active_admin)])
def list_departments(db: Session = Depends(get_db)):
    return db.query(models.Department).order_by(models.Department.dept_name).all()


# ---------- Batches ----------


@router.post("/batches", response_model=BatchRead, dependencies=[Depends(get_current_active_admin)])
def create_batch(payload: BatchCreate, db: Session = Depends(get_db)):
    batch = models.Batch(
        start_year=payload.start_year,
        end_year=payload.end_year,
    )
    db.add(batch)
    db.commit()
    db.refresh(batch)
    return batch


@router.get("/batches", response_model=List[BatchRead], dependencies=[Depends(get_current_active_admin)])
def list_batches(db: Session = Depends(get_db)):
    return (
        db.query(models.Batch)
        .order_by(models.Batch.start_year, models.Batch.end_year)
        .all()
    )


# ---------- Classes ----------


@router.post("/classes", response_model=ClassRead, dependencies=[Depends(get_current_active_admin)])
def create_class(payload: ClassCreate, db: Session = Depends(get_db)):
    # Check if class_id already exists
    existing = db.query(models.Class).filter(models.Class.class_id == payload.class_id).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Class with class_id {payload.class_id} already exists",
        )
    cls = models.Class(
        class_id=payload.class_id,
        dept_id=payload.dept_id,
        batch_id=payload.batch_id,
        year=payload.year,
        section=payload.section,
    )
    db.add(cls)
    db.commit()
    db.refresh(cls)
    return cls


@router.get("/classes", response_model=List[ClassRead], dependencies=[Depends(get_current_active_admin)])
def list_classes(db: Session = Depends(get_db)):
    return (
        db.query(models.Class)
        .order_by(models.Class.dept_id, models.Class.year, models.Class.section)
        .all()
    )


@router.delete("/departments/{dept_id}", dependencies=[Depends(get_current_active_admin)])
def delete_department(dept_id: int, db: Session = Depends(get_db)):
    dept = db.query(models.Department).filter(models.Department.dept_id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")
    db.delete(dept)
    db.commit()
    return {"message": f"Department {dept_id} deleted"}


@router.delete("/batches/{batch_id}", dependencies=[Depends(get_current_active_admin)])
def delete_batch(batch_id: int, db: Session = Depends(get_db)):
    batch = db.query(models.Batch).filter(models.Batch.batch_id == batch_id).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")
    db.delete(batch)
    db.commit()
    return {"message": f"Batch {batch_id} deleted"}


@router.delete("/classes/{class_id}", dependencies=[Depends(get_current_active_admin)])
def delete_class(class_id: str, db: Session = Depends(get_db)):
    cls = db.query(models.Class).filter(models.Class.class_id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found")
    db.delete(cls)
    db.commit()
    return {"message": f"Class {class_id} deleted"}


# ---------- Users ----------



class AdminUserRead(BaseModel):
    user_id: int
    email: str
    role: str
    status: str
    name: Optional[str] = None
    identifier: Optional[str] = None  # reg_no or employee_no
    class_id: Optional[str] = None
    dept_name: Optional[str] = None

    class Config:
        from_attributes = True


class UserCredentialsUpdate(BaseModel):
    email: Optional[str] = None
    password: Optional[str] = None


@router.post("/users", response_model=UserRead, dependencies=[Depends(get_current_active_admin)])
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists",
        )
    user = models.User(
        email=payload.email,
        password=get_password_hash(payload.password),
        role=payload.role,
        status=payload.status,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("/users", response_model=List[AdminUserRead], dependencies=[Depends(get_current_active_admin)])
def list_users(
    role: Optional[str] = None,
    class_id: Optional[str] = None,
    dept_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    # Start with base user query
    query = db.query(models.User)
    
    if role:
        query = query.filter(models.User.role == role)
    
    # We need to join manually to filter by class/dept or just to fetch details
    # This acts as a manual join/enrichment because doing it in one SQL query with polymorphic handling is complex
    # in simple SQLAlchemy without inheritance setup.
    users = query.order_by(models.User.email).all()
    
    result = []
    
    # Pre-fetch departments for lookup
    depts = {d.dept_id: d.dept_name for d in db.query(models.Department).all()}
    
    for u in users:
        item = AdminUserRead(
            user_id=u.user_id,
            email=u.email,
            role=u.role,
            status=u.status
        )
        
        # Enrich based on role
        if u.role == "student":
            student = db.query(models.Student).filter(models.Student.user_id == u.user_id).first()
            if student:
                # Apply filters if params provided
                if class_id and student.class_id != class_id:
                    continue
                if dept_id and student.dept_id != dept_id:
                    continue
                    
                item.name = student.name
                item.identifier = student.reg_no
                item.class_id = student.class_id
                item.dept_name = depts.get(student.dept_id)
            else:
                # If filtered by class/dept but student record missing, skip
                if class_id or dept_id:
                    continue
        
        elif u.role == "teacher":
            # Teachers don't have class_id, but check dept_id
            if class_id: # Specific class requested, skip teachers
                continue
                
            teacher = db.query(models.Teacher).filter(models.Teacher.user_id == u.user_id).first()
            if teacher:
                if dept_id and teacher.dept_id != dept_id:
                    continue
                    
                item.name = teacher.name
                item.identifier = teacher.employee_no
                item.dept_name = depts.get(teacher.dept_id)
            else:
                if dept_id:
                    continue
                    
        elif u.role == "admin":
            if class_id or dept_id: 
                continue
        
        result.append(item)
        
    return result


@router.put("/users/{user_id}/credentials", dependencies=[Depends(get_current_active_admin)])
def update_user_credentials(
    user_id: int, 
    payload: UserCredentialsUpdate, 
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    if payload.email:
        # Check uniqueness
        existing = db.query(models.User).filter(models.User.email == payload.email).first()
        if existing and existing.user_id != user_id:
             raise HTTPException(status_code=400, detail="Email already used by another user")
        user.email = payload.email
        
        # Also update in Student/Teacher table for consistency if applicable
        if user.role == "student":
            student = db.query(models.Student).filter(models.Student.user_id == user_id).first()
            if student: student.email = payload.email
        elif user.role == "teacher":
            teacher = db.query(models.Teacher).filter(models.Teacher.user_id == user_id).first()
            if teacher: teacher.email = payload.email

    if payload.password:
        user.password = get_password_hash(payload.password)
        
    db.commit()
    return {"message": "Credentials updated successfully"}


# ---------- Students ----------


@router.post("/students", response_model=StudentRead, dependencies=[Depends(get_current_active_admin)])
def create_student(payload: StudentCreate, db: Session = Depends(get_db)):
    # Check if reg_no already exists
    existing = (
        db.query(models.Student).filter(models.Student.reg_no == payload.reg_no).first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Student with this registration number already exists",
        )
    
    # Check if email already exists
    existing_user = (
        db.query(models.User).filter(models.User.email == payload.email).first()
    )
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists",
        )
    
    # Create user account first
    user = models.User(
        email=payload.email,
        password=get_password_hash(payload.password),
        role="student",
        status="active",
    )
    db.add(user)
    db.flush()  # Get user_id before commit
    
    # Create student record
    student = models.Student(
        reg_no=payload.reg_no,
        name=payload.name,
        dept_id=payload.dept_id,
        batch_id=payload.batch_id,
        class_id=payload.class_id,
        user_id=user.user_id,
    )
    db.add(student)
    db.commit()
    db.refresh(student)
    return student


@router.get("/students", response_model=List[StudentRead], dependencies=[Depends(get_current_active_admin)])
def list_students(
    class_id: Optional[str] = None,
    dept_id: Optional[int] = None,
    db: Session = Depends(get_db),
):
    query = db.query(models.Student)
    if class_id:
        query = query.filter(models.Student.class_id == class_id)
    if dept_id:
        query = query.filter(models.Student.dept_id == dept_id)
    return query.order_by(models.Student.reg_no).all()


@router.get("/students/{reg_no}", response_model=StudentRead, dependencies=[Depends(get_current_active_admin)])
def get_student(reg_no: str, db: Session = Depends(get_db)):
    student = db.query(models.Student).filter(models.Student.reg_no == reg_no).first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found",
        )
    return student


# ---------- Teachers ----------


@router.post("/teachers", response_model=TeacherRead, dependencies=[Depends(get_current_active_admin)])
def create_teacher(payload: TeacherCreate, db: Session = Depends(get_db)):
    # Check if employee_no already exists
    existing = (
        db.query(models.Teacher)
        .filter(models.Teacher.employee_no == payload.employee_no)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Teacher with this employee number already exists",
        )
    
    # Check if email already exists
    existing_user = (
        db.query(models.User).filter(models.User.email == payload.email).first()
    )
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists",
        )
    
    # Create user account first
    user = models.User(
        email=payload.email,
        password=get_password_hash(payload.password),
        role="teacher",
        status="active",
    )
    db.add(user)
    db.flush()
    
    # Create teacher record
    teacher = models.Teacher(
        employee_no=payload.employee_no,
        name=payload.name,
        dept_id=payload.dept_id,
        user_id=user.user_id,
    )
    db.add(teacher)
    db.commit()
    db.refresh(teacher)
    return teacher


@router.get("/teachers", response_model=List[TeacherRead], dependencies=[Depends(get_current_active_admin)])
def list_teachers(dept_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(models.Teacher)
    if dept_id:
        query = query.filter(models.Teacher.dept_id == dept_id)
    return query.order_by(models.Teacher.employee_no).all()


# ---------- Subjects ----------


@router.post("/subjects", response_model=SubjectRead, dependencies=[Depends(get_current_active_admin)])
def create_subject(payload: SubjectCreate, db: Session = Depends(get_db)):
    existing = (
        db.query(models.Subject)
        .filter(models.Subject.subject_code == payload.subject_code)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Subject with this code already exists",
        )
    subject = models.Subject(
        subject_code=payload.subject_code,
        subject_name=payload.subject_name,
        credits=payload.credits,
        dept_id=payload.dept_id,
        semester=payload.semester,
    )
    db.add(subject)
    db.commit()
    db.refresh(subject)
    return subject


@router.get("/subjects", response_model=List[SubjectRead], dependencies=[Depends(get_current_active_admin)])
def list_subjects(
    dept_id: Optional[int] = None,
    semester: Optional[int] = None,
    db: Session = Depends(get_db),
):
    query = db.query(models.Subject)
    if dept_id:
        query = query.filter(models.Subject.dept_id == dept_id)
    if semester:
        query = query.filter(models.Subject.semester == semester)
    return query.order_by(models.Subject.subject_code).all()


# ---------- Teacher-Subject Mapping ----------


@router.post("/teacher-subjects", response_model=TeacherSubjectMapRead, dependencies=[Depends(get_current_active_admin)])
def create_teacher_subject_map(
    payload: TeacherSubjectMapCreate, db: Session = Depends(get_db)
):
    existing = (
        db.query(models.TeacherSubjectMap)
        .filter(
            models.TeacherSubjectMap.teacher_id == payload.teacher_id,
            models.TeacherSubjectMap.subject_code == payload.subject_code,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This teacher-subject mapping already exists",
        )
    mapping = models.TeacherSubjectMap(
        teacher_id=payload.teacher_id,
        subject_code=payload.subject_code,
    )
    db.add(mapping)
    db.commit()
    db.refresh(mapping)
    return mapping


@router.get("/teacher-subjects", response_model=List[TeacherSubjectMapRead], dependencies=[Depends(get_current_active_admin)])
def list_teacher_subject_maps(
    teacher_id: Optional[int] = None, db: Session = Depends(get_db)
):
    query = db.query(models.TeacherSubjectMap)
    if teacher_id:
        query = query.filter(models.TeacherSubjectMap.teacher_id == teacher_id)
    return query.all()


# ---------- Student-Subject Mapping ----------


@router.post("/student-subjects", response_model=StudentSubjectMapRead, dependencies=[Depends(get_current_active_admin)])
def create_student_subject_map(
    payload: StudentSubjectMapCreate, db: Session = Depends(get_db)
):
    existing = (
        db.query(models.StudentSubjectMap)
        .filter(
            models.StudentSubjectMap.reg_no == payload.reg_no,
            models.StudentSubjectMap.subject_code == payload.subject_code,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This student-subject mapping already exists",
        )
    mapping = models.StudentSubjectMap(
        reg_no=payload.reg_no,
        subject_code=payload.subject_code,
    )
    db.add(mapping)
    db.commit()
    db.refresh(mapping)
    return mapping


@router.get("/student-subjects", response_model=List[StudentSubjectMapRead], dependencies=[Depends(get_current_active_admin)])
def list_student_subject_maps(
    reg_no: Optional[str] = None, db: Session = Depends(get_db)
):
    query = db.query(models.StudentSubjectMap)
    if reg_no:
        query = query.filter(models.StudentSubjectMap.reg_no == reg_no)
    return query.all()


# ---------- Face Enrollment ----------


@router.post("/faces/enroll", dependencies=[Depends(get_current_active_admin)])
async def enroll_face(
    reg_no: str = Form(...),
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Upload face image and generate embedding for a student."""
    # Verify student exists
    student = db.query(models.Student).filter(models.Student.reg_no == reg_no).first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found",
        )
    
    # Read and decode image
    img_bytes = await image.read()
    np_arr = np.frombuffer(img_bytes, np.uint8)
    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not decode image",
        )
    
    # Initialize face analysis (lazy load to avoid startup delay)
    from backend.ai.engine import FaceAttendanceEngine
    engine = FaceAttendanceEngine()
    
    # Detect faces
    faces = engine.app.get(frame)
    if len(faces) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No face detected in the image",
        )
    if len(faces) > 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Multiple faces ({len(faces)}) detected. Please upload an image with only one face.",
        )
    
    # Get embedding
    embedding = faces[0].normed_embedding.tolist()
    
    # Save image to disk
    image_filename = f"{reg_no}_{image.filename}"
    image_path = FACE_IMAGES_DIR / image_filename
    cv2.imwrite(str(image_path), frame)
    
    # Update or create face profile
    face_profile = (
        db.query(models.FaceProfile)
        .filter(models.FaceProfile.reg_no == reg_no)
        .first()
    )
    if face_profile:
        face_profile.embedding_vector = embedding
    else:
        face_profile = models.FaceProfile(
            reg_no=reg_no,
            embedding_vector=embedding,
        )
        db.add(face_profile)
    
    # Save face image record
    face_image = models.FaceImage(
        reg_no=reg_no,
        image_path=str(image_path),
    )
    db.add(face_image)
    
    db.commit()
    
    return {
        "message": "Face enrolled successfully",
        "reg_no": reg_no,
        "image_path": str(image_path),
    }


@router.get("/faces/profiles", response_model=List[FaceProfileRead], dependencies=[Depends(get_current_active_admin)])
def list_face_profiles(db: Session = Depends(get_db)):
    profiles = db.query(models.FaceProfile).all()
    return [
        FaceProfileRead(
            face_id=p.face_id,
            reg_no=p.reg_no,
            has_embedding=p.embedding_vector is not None,
        )
        for p in profiles
    ]


@router.get("/faces/images", response_model=List[FaceImageRead], dependencies=[Depends(get_current_active_admin)])
def list_face_images(reg_no: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(models.FaceImage)
    if reg_no:
        query = query.filter(models.FaceImage.reg_no == reg_no)
    return query.all()


@router.delete("/faces/{reg_no}", dependencies=[Depends(get_current_active_admin)])
def delete_face_profile(reg_no: str, db: Session = Depends(get_db)):
    """Delete face profile and images for a student."""
    profile = (
        db.query(models.FaceProfile)
        .filter(models.FaceProfile.reg_no == reg_no)
        .first()
    )
    if profile:
        db.delete(profile)
    
    images = db.query(models.FaceImage).filter(models.FaceImage.reg_no == reg_no).all()
    for img in images:
        # Delete file from disk
        try:
            Path(img.image_path).unlink(missing_ok=True)
        except Exception:
            pass
        db.delete(img)
    
    db.commit()
    return {"message": f"Face data deleted for {reg_no}"}


# ---------- Delete Routes for Other Entities ----------


@router.delete("/students/{reg_no}", dependencies=[Depends(get_current_active_admin)])
def delete_student(reg_no: str, db: Session = Depends(get_db)):
    student = db.query(models.Student).filter(models.Student.reg_no == reg_no).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    # Delete related user
    if student.user_id:
        user = db.query(models.User).filter(models.User.user_id == student.user_id).first()
        if user:
            db.delete(user)
    db.delete(student)
    db.commit()
    return {"message": f"Student {reg_no} deleted"}


@router.delete("/teachers/{teacher_id}", dependencies=[Depends(get_current_active_admin)])
def delete_teacher(teacher_id: int, db: Session = Depends(get_db)):
    teacher = db.query(models.Teacher).filter(models.Teacher.teacher_id == teacher_id).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    # Delete related user
    if teacher.user_id:
        user = db.query(models.User).filter(models.User.user_id == teacher.user_id).first()
        if user:
            db.delete(user)
    db.delete(teacher)
    db.commit()
    return {"message": f"Teacher {teacher_id} deleted"}


@router.delete("/subjects/{subject_code}", dependencies=[Depends(get_current_active_admin)])
def delete_subject(subject_code: str, db: Session = Depends(get_db)):
    subject = db.query(models.Subject).filter(models.Subject.subject_code == subject_code).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    db.delete(subject)
    db.commit()
    return {"message": f"Subject {subject_code} deleted"}


@router.delete("/teacher-subjects/{teacher_id}/{subject_code}", dependencies=[Depends(get_current_active_admin)])
def delete_teacher_subject_map(teacher_id: int, subject_code: str, db: Session = Depends(get_db)):
    mapping = (
        db.query(models.TeacherSubjectMap)
        .filter(
            models.TeacherSubjectMap.teacher_id == teacher_id,
            models.TeacherSubjectMap.subject_code == subject_code,
        )
        .first()
    )
    if not mapping:
        raise HTTPException(status_code=404, detail="Mapping not found")
    db.delete(mapping)
    db.commit()
    return {"message": "Teacher-subject mapping deleted"}


# ---------- Class-Subject Mapping (Assign subjects to entire class) ----------




# ---------- Timetable ----------

class TimetableEntryCreate(BaseModel):
    day: str
    period: int
    class_id: str
    teacher_id: int
    subject_code: str


class TimetableEntryRead(BaseModel):
    timetable_id: int
    day: str
    period: int
    class_id: str
    teacher_id: int
    subject_code: str
    teacher_name: Optional[str] = None
    subject_name: Optional[str] = None
    class_year: Optional[int] = None
    class_section: Optional[str] = None

    class Config:
        from_attributes = True


@router.get("/timetable/teacher/{teacher_id}", response_model=List[TimetableEntryRead], dependencies=[Depends(get_current_active_admin)])
def get_teacher_timetable(teacher_id: int, db: Session = Depends(get_db)):
    entries = (
        db.query(models.Timetable)
        .filter(models.Timetable.teacher_id == teacher_id)
        .all()
    )
    # Enrich with names (lazy loading or explicit join)
    # SQLAlchemy relationships `subject` and `class_` are defined in model.
    # Pydantic `from_attributes` works if relationships are loaded.
    # To be safe and fast, I'll join. But definitions are simple enough to just return list.
    
    # We need to ensure Pydantic sees `subject.subject_name` etc.
    # Helper to format
    result = []
    for e in entries:
        item = TimetableEntryRead.model_validate(e)
        if e.teacher: item.teacher_name = e.teacher.name
        if e.subject: item.subject_name = e.subject.subject_name
        if e.class_:
             item.class_year = e.class_.year
             item.class_section = e.class_.section
        result.append(item)
    return result


@router.get("/timetable/class/{class_id}", response_model=List[TimetableEntryRead], dependencies=[Depends(get_current_active_admin)])
def get_class_timetable(class_id: str, db: Session = Depends(get_db)):
    entries = (
        db.query(models.Timetable)
        .filter(models.Timetable.class_id == class_id)
        .all()
    )
    result = []
    for e in entries:
        item = TimetableEntryRead.model_validate(e)
        if e.teacher: item.teacher_name = e.teacher.name
        if e.subject: item.subject_name = e.subject.subject_name
        if e.class_:
             item.class_year = e.class_.year
             item.class_section = e.class_.section
        result.append(item)
    return result


@router.post("/timetable", dependencies=[Depends(get_current_active_admin)])
def update_timetable_entry(payload: TimetableEntryCreate, db: Session = Depends(get_db)):
    # 1. Validate Mapping (Teacher <-> Subject)
    # The teacher MUST be mapped to this subject?
    # User said: "use class-subject mapping, teacher-subject mapping for accurate data"
    
    # Check Class-Subject map
    cs_map = (
        db.query(models.ClassSubjectMap)
        .filter(models.ClassSubjectMap.class_id == payload.class_id, models.ClassSubjectMap.subject_code == payload.subject_code)
        .first()
    )
    if not cs_map:
        raise HTTPException(
            status_code=400,
            detail=f"Class {payload.class_id} is not assigned subject {payload.subject_code}",
        )
        
    # Check Teacher-Subject map
    ts_map = (
        db.query(models.TeacherSubjectMap)
        .filter(models.TeacherSubjectMap.teacher_id == payload.teacher_id, models.TeacherSubjectMap.subject_code == payload.subject_code)
        .first()
    )
    if not ts_map:
        raise HTTPException(
            status_code=400,
            detail=f"Teacher {payload.teacher_id} is not assigned subject {payload.subject_code}",
        )
        
    # 2. Check for conflicts
    # Class conflict: Class busy at this slot?
    class_conflict = (
        db.query(models.Timetable)
        .filter(
            models.Timetable.day == payload.day,
            models.Timetable.period == payload.period,
            models.Timetable.class_id == payload.class_id,
        )
        .first()
    )
    
    # Teacher conflict: Teacher busy at this slot?
    teacher_conflict = (
        db.query(models.Timetable)
        .filter(
            models.Timetable.day == payload.day,
            models.Timetable.period == payload.period,
            models.Timetable.teacher_id == payload.teacher_id,
        )
        .first()
    )
    
    # Upsert Logic:
    # If we are overwriting a slot, we delete the old entry.
    # But if conflict is with *another* class (teacher busy elsewhere) or *another* teacher (class busy with someone else), we must handle it.
    
    # Existing entry for THIS class at THIS slot?
    if class_conflict:
        db.delete(class_conflict)
        # Verify if teacher conflict still exists (maybe it was the SAME entry we just deleted?)
        # If teacher_conflict ID != class_conflict ID, then teacher is busy ELSEWHERE.
        if teacher_conflict and teacher_conflict.timetable_id != class_conflict.timetable_id:
             raise HTTPException(status_code=400, detail="Teacher is already busy in another class at this time")
    elif teacher_conflict:
         raise HTTPException(status_code=400, detail="Teacher is already busy in another class at this time")
         
    # Create new entry
    entry = models.Timetable(
        day=payload.day,
        period=payload.period,
        class_id=payload.class_id,
        teacher_id=payload.teacher_id,
        subject_code=payload.subject_code,
    )
    db.add(entry)
    db.commit()
    return {"message": "Timetable updated"}

@router.post("/class-subjects", response_model=ClassSubjectMapRead, dependencies=[Depends(get_current_active_admin)])
def create_class_subject_map(
    payload: ClassSubjectMapCreate, db: Session = Depends(get_db)
):
    """Assign a subject to an entire class."""
    existing = (
        db.query(models.ClassSubjectMap)
        .filter(
            models.ClassSubjectMap.class_id == payload.class_id,
            models.ClassSubjectMap.subject_code == payload.subject_code,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This class-subject mapping already exists",
        )
    mapping = models.ClassSubjectMap(
        class_id=payload.class_id,
        subject_code=payload.subject_code,
    )
    db.add(mapping)
    db.commit()
    db.refresh(mapping)
    return mapping


@router.get("/class-subjects", response_model=List[ClassSubjectMapRead])
def list_class_subject_maps(
    class_id: Optional[str] = None, db: Session = Depends(get_db)
):
    """List all class-subject mappings, optionally filtered by class_id."""
    query = db.query(models.ClassSubjectMap)
    if class_id:
        query = query.filter(models.ClassSubjectMap.class_id == class_id)
    return query.all()


@router.delete("/class-subjects/{class_id}/{subject_code}")
def delete_class_subject_map(class_id: str, subject_code: str, db: Session = Depends(get_db)):
    """Remove a subject from a class."""
    mapping = (
        db.query(models.ClassSubjectMap)
        .filter(
            models.ClassSubjectMap.class_id == class_id,
            models.ClassSubjectMap.subject_code == subject_code,
        )
        .first()
    )
    if not mapping:
        raise HTTPException(status_code=404, detail="Mapping not found")
    db.delete(mapping)
    db.commit()
    return {"message": f"Subject {subject_code} removed from class {class_id}"}


@router.get("/class-subjects/{class_id}/students")
def get_students_for_class_subject(class_id: str, db: Session = Depends(get_db)):
    """Get all students in a class (used for attendance based on class-subject mapping)."""
    students = (
        db.query(models.Student)
        .filter(models.Student.class_id == class_id)
        .order_by(models.Student.reg_no)
        .all()
    )
    return [
        {
            "reg_no": s.reg_no,
            "name": s.name,
            "student_id": s.student_id,
        }
        for s in students
    ]


# ---------- Edit (PUT) Routes ----------


class DepartmentUpdate(BaseModel):
    dept_name: str


class BatchUpdate(BaseModel):
    start_year: int
    end_year: int


class ClassUpdate(BaseModel):
    dept_id: int
    batch_id: int
    year: int
    section: str


class StudentUpdate(BaseModel):
    name: str
    dept_id: int
    batch_id: int
    class_id: str


class TeacherUpdate(BaseModel):
    name: str
    dept_id: int


class SubjectUpdate(BaseModel):
    subject_name: str
    credits: int
    dept_id: int
    semester: int


@router.put("/departments/{dept_id}", response_model=DepartmentRead)
def update_department(dept_id: int, payload: DepartmentUpdate, db: Session = Depends(get_db)):
    dept = db.query(models.Department).filter(models.Department.dept_id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")
    dept.dept_name = payload.dept_name
    db.commit()
    db.refresh(dept)
    return dept


@router.put("/batches/{batch_id}", response_model=BatchRead)
def update_batch(batch_id: int, payload: BatchUpdate, db: Session = Depends(get_db)):
    batch = db.query(models.Batch).filter(models.Batch.batch_id == batch_id).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")
    batch.start_year = payload.start_year
    batch.end_year = payload.end_year
    db.commit()
    db.refresh(batch)
    return batch


@router.put("/classes/{class_id}", response_model=ClassRead)
def update_class(class_id: str, payload: ClassUpdate, db: Session = Depends(get_db)):
    cls = db.query(models.Class).filter(models.Class.class_id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found")
    cls.dept_id = payload.dept_id
    cls.batch_id = payload.batch_id
    cls.year = payload.year
    cls.section = payload.section
    db.commit()
    db.refresh(cls)
    return cls


@router.put("/students/{reg_no}", response_model=StudentRead)
def update_student(reg_no: str, payload: StudentUpdate, db: Session = Depends(get_db)):
    student = db.query(models.Student).filter(models.Student.reg_no == reg_no).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    student.name = payload.name
    student.dept_id = payload.dept_id
    student.batch_id = payload.batch_id
    student.class_id = payload.class_id
    db.commit()
    db.refresh(student)
    return student


@router.put("/teachers/{teacher_id}", response_model=TeacherRead)
def update_teacher(teacher_id: int, payload: TeacherUpdate, db: Session = Depends(get_db)):
    teacher = db.query(models.Teacher).filter(models.Teacher.teacher_id == teacher_id).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    teacher.name = payload.name
    teacher.dept_id = payload.dept_id
    db.commit()
    db.refresh(teacher)
    return teacher


@router.put("/subjects/{subject_code}", response_model=SubjectRead)
def update_subject(subject_code: str, payload: SubjectUpdate, db: Session = Depends(get_db)):
    subject = db.query(models.Subject).filter(models.Subject.subject_code == subject_code).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    subject.subject_name = payload.subject_name
    subject.credits = payload.credits
    subject.dept_id = payload.dept_id
    subject.semester = payload.semester
    db.commit()
    db.refresh(subject)
    return subject


# ---------- Attendance Viewer ----------


class AdminAttendanceRecord(BaseModel):
    attendance_id: int
    date: date
    period: int
    subject_code: str
    status: str
    teacher_name: str

    class Config:
        from_attributes = True


@router.get("/attendance/records/{reg_no}", response_model=List[AdminAttendanceRecord], dependencies=[Depends(get_current_active_admin)])
def list_student_attendance(
    reg_no: str,
    db: Session = Depends(get_db),
):
    student = db.query(models.Student).filter(models.Student.reg_no == reg_no).first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found",
        )

    records = (
        db.query(models.AttendanceRecord)
        .join(models.AttendanceSession)
        .join(models.Teacher, models.AttendanceSession.teacher_id == models.Teacher.teacher_id)
        .filter(models.AttendanceRecord.reg_no == reg_no)
        .order_by(models.AttendanceSession.date.desc(), models.AttendanceSession.period.asc())
        .all()
    )

    result = []
    for rec in records:
        result.append(
            AdminAttendanceRecord(
                attendance_id=rec.attendance_id,
                date=rec.session.date,
                period=rec.session.period,
                subject_code=rec.session.subject_code,
                status=rec.status,
                teacher_name=rec.session.teacher.name,
            )
        )
    return result


class AttendanceUpdate(BaseModel):
    attendance_id: int
    status: str  # P, A, OD, ML, NT


@router.put("/attendance/record", dependencies=[Depends(get_current_active_admin)])
def update_attendance_record(payload: AttendanceUpdate, db: Session = Depends(get_db)):
    record = db.query(models.AttendanceRecord).filter(models.AttendanceRecord.attendance_id == payload.attendance_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Attendance record not found")
    
    if payload.status not in ["P", "A", "OD", "ML", "NT"]:
         raise HTTPException(status_code=400, detail="Invalid status")

    record.status = payload.status
    db.commit()
    return {"message": "Attendance updated"}
