from datetime import datetime, date
from pathlib import Path
import shutil
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form, status
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload

from backend import models
from backend.database import get_db
from backend.routers.auth import get_current_user, UserInfo

router = APIRouter()

PROJECT_ROOT = Path(__file__).resolve().parents[2]
TASK_STORAGE_DIR = PROJECT_ROOT / "storage" / "tasks"
SUBMISSION_STORAGE_DIR = PROJECT_ROOT / "storage" / "submissions"

TASK_STORAGE_DIR.mkdir(parents=True, exist_ok=True)
SUBMISSION_STORAGE_DIR.mkdir(parents=True, exist_ok=True)


# --- Pydantic Models ---

class TaskCreate(BaseModel):
    class_id: str
    subject_code: str
    type: str # "Daily", "Assignment"
    title: str
    description: Optional[str] = None
    deadline: Optional[datetime] = None
    max_marks: int = 10

class TaskRead(BaseModel):
    task_id: int
    teacher_id: int
    class_id: str
    subject_code: str
    type: str
    title: str
    description: Optional[str]
    deadline: Optional[datetime]
    max_marks: int
    file_path: Optional[str]
    created_at: datetime
    
    teacher_name: Optional[str] = None
    is_submitted: Optional[bool] = False # For student view

    class Config:
        from_attributes = True

class SubmissionRead(BaseModel):
    submission_id: int
    task_id: int
    student_id: int
    file_path: Optional[str]
    submitted_at: datetime
    status: str
    marks_obtained: Optional[float]
    remarks: Optional[str]
    
    student_name: Optional[str] = None
    reg_no: Optional[str] = None

    class Config:
        from_attributes = True

class EvaluationUpdate(BaseModel):
    marks_obtained: float
    remarks: str


# --- Endpoints ---

@router.post("/create", response_model=TaskRead)
def create_task(
    class_id: str = Form(...),
    subject_code: str = Form(...),
    type: str = Form(...),
    title: str = Form(...),
    description: str = Form(None),
    deadline: Optional[str] = Form(None), # Receive as str, parse later
    max_marks: int = Form(10),
    file: Optional[UploadFile] = File(None),
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "teacher":
        raise HTTPException(status_code=403, detail="Only teachers can create tasks")

    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.teacher:
         raise HTTPException(status_code=404, detail="Teacher profile not found")
    teacher_id = user.teacher.teacher_id

    # Handle File Upload
    file_path_str = None
    if file:
        safe_filename = f"task_{class_id}_{subject_code}_{int(datetime.now().timestamp())}_{file.filename}"
        dest_path = TASK_STORAGE_DIR / safe_filename
        with dest_path.open("wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        file_path_str = str(dest_path)

    # Parse Deadline
    deadline_dt = None
    if deadline and deadline != "null":
        try:
            deadline_dt = datetime.fromisoformat(deadline)
        except ValueError:
            pass # Keep None

    task = models.Task(
        teacher_id=teacher_id,
        class_id=class_id,
        subject_code=subject_code,
        type=type,
        title=title,
        description=description,
        deadline=deadline_dt,
        max_marks=max_marks,
        file_path=file_path_str,
        created_at=datetime.now(),
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@router.get("/teacher/list", response_model=List[TaskRead])
def list_tasks_for_teacher(
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "teacher": return []
    
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    teacher_id = user.teacher.teacher_id

    tasks = db.query(models.Task).filter(models.Task.teacher_id == teacher_id).order_by(models.Task.created_at.desc()).all()
    return tasks


@router.get("/student/list", response_model=List[TaskRead])
def list_tasks_for_student(
    subject_code: Optional[str] = None,
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "student": return []
    
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.student:
        return []
    student = user.student
    
    query = db.query(models.Task).filter(models.Task.class_id == student.class_id)
    if subject_code:
        query = query.filter(models.Task.subject_code == subject_code)
        
    tasks = query.order_by(models.Task.created_at.desc()).all()
    
    # Enrich with submission status
    result = []
    for t in tasks:
        item = TaskRead.model_validate(t)
        if t.teacher: item.teacher_name = t.teacher.name
        
        # Check submission
        sub = db.query(models.Submission).filter(
            models.Submission.task_id == t.task_id,
            models.Submission.student_id == student.student_id
        ).first()
        
        item.is_submitted = (sub is not None)
        result.append(item)
        
    return result
        
@router.get("/{task_id}", response_model=TaskRead)
def get_task_details(
    task_id: int,
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task = db.query(models.Task).filter(models.Task.task_id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
        
    result = TaskRead.model_validate(task)
    if task.teacher: result.teacher_name = task.teacher.name
    
    # Check submission status if student
    if current_user.role == "student":
        user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
        if user and user.student:
            student_id = user.student.student_id
            
            sub = db.query(models.Submission).filter(
                models.Submission.task_id == task_id,
                models.Submission.student_id == student_id
            ).first()
            result.is_submitted = (sub is not None)
        
    return result


@router.get("/student/submission/{task_id}", response_model=Optional[SubmissionRead])
def get_my_submission(
    task_id: int,
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "student": return None
    
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    student_id = user.student.student_id
    
    sub = db.query(models.Submission).filter(
        models.Submission.task_id == task_id,
        models.Submission.student_id == student_id
    ).first()
    
    if not sub: return None
    return sub



@router.post("/submit/{task_id}", response_model=SubmissionRead)
def submit_task(
    task_id: int,
    file: UploadFile = File(...),
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "student":
         raise HTTPException(status_code=403, detail="Only students can submit")

    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    student_id = user.student.student_id
    
    # Check if already submitted
    existing = db.query(models.Submission).filter(
        models.Submission.task_id == task_id,
        models.Submission.student_id == student_id
    ).first()
    if existing:
         raise HTTPException(status_code=400, detail="Already submitted")

    # Save File
    safe_filename = f"sub_{task_id}_{student_id}_{file.filename}"
    dest_path = SUBMISSION_STORAGE_DIR / safe_filename
    with dest_path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    submission = models.Submission(
        task_id=task_id,
        student_id=student_id,
        file_path=str(dest_path),
        submitted_at=datetime.now(),
        status="Submitted",
    )
    db.add(submission)
    db.commit()
    db.refresh(submission)
    return submission


@router.get("/{task_id}/submissions", response_model=List[SubmissionRead])
def get_task_submissions(
    task_id: int,
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task = db.query(models.Task).filter(models.Task.task_id == task_id).first()
    if not task: raise HTTPException(status_code=404, detail="Task not found")

    # Get all students in this class
    students = db.query(models.Student).filter(models.Student.class_id == task.class_id).order_by(models.Student.reg_no).all()
    
    # Get existing submissions
    submissions = db.query(models.Submission).filter(models.Submission.task_id == task_id).all()
    sub_map = {s.student_id: s for s in submissions}
    
    result = []
    for student in students:
        sub = sub_map.get(student.student_id)
        if sub:
            item = SubmissionRead.model_validate(sub)
            item.student_name = student.name
            item.reg_no = student.reg_no
            result.append(item)
        else:
            # Create a dummy submission object for "Not Submitted"
            dummy = SubmissionRead(
                submission_id=0, # Dummy ID
                task_id=task_id,
                student_id=student.student_id,
                file_path=None,
                submitted_at=datetime.min, # Distinct value
                status="Not Submitted",
                marks_obtained=None,
                remarks=None,
                student_name=student.name,
                reg_no=student.reg_no
            )
            result.append(dummy)
            
    return result


@router.post("/evaluate/{submission_id}")
def evaluate_submission(
    submission_id: int,
    evaluation: EvaluationUpdate,
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "teacher":
         raise HTTPException(status_code=403, detail="Only teachers can evaluate")
         
    sub = db.query(models.Submission).filter(models.Submission.submission_id == submission_id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Submission not found")
        
    sub.marks_obtained = evaluation.marks_obtained
    sub.remarks = evaluation.remarks
    sub.status = "Graded"
    
    db.commit()
    return {"message": "Evaluation saved"}


@router.get("/download/{type}/{id}")
def download_file(
    type: str, # "task" or "submission"
    id: int,
    db: Session = Depends(get_db),
):
    file_path = None
    if type == "task":
        item = db.query(models.Task).filter(models.Task.task_id == id).first()
        if item: file_path = item.file_path
    elif type == "submission":
        item = db.query(models.Submission).filter(models.Submission.submission_id == id).first()
        if item: file_path = item.file_path
        
    if not file_path or not Path(file_path).exists():
        raise HTTPException(status_code=404, detail="File not found")
        
    return FileResponse(path=file_path, filename=Path(file_path).name)

