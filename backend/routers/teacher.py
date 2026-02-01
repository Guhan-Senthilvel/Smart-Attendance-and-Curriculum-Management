from datetime import date, timedelta
from pathlib import Path
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from backend import models
from backend.database import get_db
from backend.routers.auth import get_current_user, UserInfo


router = APIRouter()

PROJECT_ROOT = Path(__file__).resolve().parents[2]
ATTENDANCE_PROOF_DIR = PROJECT_ROOT / "storage" / "attendance_proofs"


# ---------- Pydantic Schemas ----------


class TeacherSessionSummary(BaseModel):
    session_id: int
    class_id: str
    subject_code: str
    date: date
    period: int
    present_count: int
    total_count: int
    percentage: float


class ClassInfo(BaseModel):
    class_id: str
    dept_name: str
    batch: str
    year: int
    section: str
    subject_code: str
    subject_name: str


class StudentInfo(BaseModel):
    student_id: int
    reg_no: str
    name: str
    has_face_profile: bool


class AttendanceRecordDetail(BaseModel):
    attendance_id: int
    reg_no: str
    name: str
    status: str


class SessionDetail(BaseModel):
    session_id: int
    class_id: str
    subject_code: str
    date: date
    period: int
    records: List[AttendanceRecordDetail]


class AttendanceHistoryRow(BaseModel):
    reg_no: str
    name: str
    records: dict  # date string -> status
    percentage: float


class UpdateRecordRequest(BaseModel):
    reg_no: str
    status: str  # "P", "A", "NT"


# ---------- Routes ----------


@router.get("/inbox/proof/{request_id}")
def get_request_proof(
    request_id: int,
    db: Session = Depends(get_db),
):
    """Get the proof file for a request. 
    NOTE: Values this high up to avoid conflict with /{teacher_id}/... routes.
    """
    req = db.query(models.LeaveRequest).filter(models.LeaveRequest.request_id == request_id).first()
    if not req or not req.proof_file_path:
        raise HTTPException(status_code=404, detail="Proof not found")
        
    path = Path(req.proof_file_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing on server")
        
    return FileResponse(str(path))


@router.get("/{teacher_id}/classes", response_model=List[ClassInfo])
def get_teacher_classes(teacher_id: int, db: Session = Depends(get_db)):
    """Get all classes assigned to a teacher through teacher-subject mappings."""
    # Verify teacher exists
    teacher = db.query(models.Teacher).filter(models.Teacher.teacher_id == teacher_id).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    
    # Get subjects taught by this teacher
    subject_mappings = (
        db.query(models.TeacherSubjectMap)
        .filter(models.TeacherSubjectMap.teacher_id == teacher_id)
        .all()
    )
    if not subject_mappings:
        return []
    
    # Get classes that have those subjects
    subject_codes = [m.subject_code for m in subject_mappings]
    class_subject_mappings = (
        db.query(models.ClassSubjectMap)
        .filter(models.ClassSubjectMap.subject_code.in_(subject_codes))
        .all()
    )
    
    classes_info = []
    seen = set()
    
    for mapping in class_subject_mappings:
        key = (mapping.class_id, mapping.subject_code)
        if key in seen:
            continue
        seen.add(key)
        
        cls = db.query(models.Class).filter(models.Class.class_id == mapping.class_id).first()
        if not cls:
            continue
        
        subject = db.query(models.Subject).filter(models.Subject.subject_code == mapping.subject_code).first()
        dept = db.query(models.Department).filter(models.Department.dept_id == cls.dept_id).first()
        batch = db.query(models.Batch).filter(models.Batch.batch_id == cls.batch_id).first()
        
        classes_info.append(ClassInfo(
            class_id=cls.class_id,
            dept_name=dept.dept_name if dept else "Unknown",
            batch=f"{batch.start_year}-{batch.end_year}" if batch else "Unknown",
            year=cls.year,
            section=cls.section,
            subject_code=mapping.subject_code,
            subject_name=subject.subject_name if subject else "Unknown",
        ))
    
    print(f"DEBUG_TEACHER_CLASSES: {[c.model_dump() for c in classes_info]}")
    return classes_info


@router.get("/{teacher_id}/students/{class_id}", response_model=List[StudentInfo])
def get_students_by_class(
    teacher_id: int,
    class_id: str,
    db: Session = Depends(get_db),
):
    """Get all students in a class with face profile status."""
    students = (
        db.query(models.Student)
        .filter(models.Student.class_id == class_id)
        .order_by(models.Student.reg_no)
        .all()
    )
    
    result = []
    for s in students:
        profile = (
            db.query(models.FaceProfile)
            .filter(models.FaceProfile.reg_no == s.reg_no)
            .first()
        )
        result.append(StudentInfo(
            student_id=s.student_id,
            reg_no=s.reg_no,
            name=s.name,
            has_face_profile=profile is not None and profile.embedding_vector is not None,
        ))
    
    return result


@router.get("/students/{class_id}", response_model=List[StudentInfo])
def get_students_for_class_wrapper(
    class_id: str,
    db: Session = Depends(get_db),
    current_user: UserInfo = Depends(get_current_user),
):
    """Wrapper to get students without needing teacher_id in path."""
    if current_user.role != "teacher":
        raise HTTPException(status_code=403, detail="Not a teacher")
    # Reuse logic
    return get_students_by_class(0, class_id, db)


@router.get("/{teacher_id}/sessions", response_model=List[TeacherSessionSummary])
def list_teacher_sessions(
    teacher_id: int,
    day: date,
    db: Session = Depends(get_db),
):
    """Get attendance sessions for a teacher on a specific day."""
    sessions = (
        db.query(models.AttendanceSession)
        .filter(
            models.AttendanceSession.teacher_id == teacher_id,
            models.AttendanceSession.date == day,
        )
        .all()
    )

    results: List[TeacherSessionSummary] = []
    for ses in sessions:
        records = (
            db.query(models.AttendanceRecord)
            .filter(models.AttendanceRecord.session_id == ses.session_id)
            .all()
        )
        total = len([r for r in records if r.status != "NT"])
        present = len([r for r in records if r.status == "P"])
        percentage = (present / total * 100) if total > 0 else 0.0
        results.append(
            TeacherSessionSummary(
                session_id=ses.session_id,
                class_id=ses.class_id,
                subject_code=ses.subject_code,
                date=ses.date,
                period=ses.period,
                present_count=present,
                total_count=total,
                percentage=round(percentage, 1),
            )
        )

    return results


# Simple attendance history endpoint using JWT auth
@router.get("/attendance-history")
def get_simple_attendance_history(
    subject_code: str = Query(...),
    start_date: Optional[date] = Query(default=None),
    end_date: Optional[date] = Query(default=None),
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get attendance history for a subject taught by the logged-in teacher."""
    if current_user.role != "teacher":
        raise HTTPException(status_code=403, detail="Only teachers can access this endpoint")
    
    # Get teacher_id from user
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    
    teacher_id = user.teacher.teacher_id
    
    # Default date range - last 7 days
    if not end_date:
        end_date = date.today()
    if not start_date:
        start_date = end_date - timedelta(days=7)
    
    # Get sessions for this subject by this teacher
    sessions = (
        db.query(models.AttendanceSession)
        .filter(
            models.AttendanceSession.teacher_id == teacher_id,
            models.AttendanceSession.subject_code == subject_code,
            models.AttendanceSession.date >= start_date,
            models.AttendanceSession.date <= end_date,
        )
        .order_by(models.AttendanceSession.date.desc())
        .all()
    )
    
    results = []
    for ses in sessions:
        # Count present/absent for each session
        records = (
            db.query(models.AttendanceRecord)
            .filter(models.AttendanceRecord.session_id == ses.session_id)
            .all()
        )
        present = sum(1 for r in records if r.status == "P")
        total = len(records)
        
        results.append({
            "session_id": ses.session_id,
            "date": ses.date.isoformat(),
            "period_no": ses.period,
            "class_id": ses.class_id,
            "subject_code": ses.subject_code,
            "present_count": present,
            "total_count": total,
        })
    
    return results

@router.get("/{teacher_id}/attendance-history/{class_id}")
def get_attendance_history(
    teacher_id: int,
    class_id: str,
    subject_code: str = Query(...),
    days: int = Query(default=7, le=30),
    db: Session = Depends(get_db),
):
    """Get attendance history for a class over the past N days."""
    today = date.today()
    start_date = today - timedelta(days=days - 1)
    
    # Get sessions for this class/subject by this teacher
    sessions = (
        db.query(models.AttendanceSession)
        .filter(
            models.AttendanceSession.teacher_id == teacher_id,
            models.AttendanceSession.class_id == class_id,
            models.AttendanceSession.subject_code == subject_code,
            models.AttendanceSession.date >= start_date,
            models.AttendanceSession.date <= today,
        )
        .order_by(models.AttendanceSession.date)
        .all()
    )
    
    # Get all students in this class
    students = (
        db.query(models.Student)
        .filter(models.Student.class_id == class_id)
        .order_by(models.Student.reg_no)
        .all()
    )
    
    # Build history matrix
    # date_list = [(start_date + timedelta(days=i)).isoformat() for i in range(days)]
    session_dates = sorted(set(s.date for s in sessions))
    
    history = []
    for student in students:
        records = {}
        total_working = 0
        present_count = 0
        
        for ses in sessions:
            record = (
                db.query(models.AttendanceRecord)
                .filter(
                    models.AttendanceRecord.session_id == ses.session_id,
                    models.AttendanceRecord.reg_no == student.reg_no,
                )
                .first()
            )
            date_key = ses.date.isoformat()
            if record and record.status != "NT":
                records[date_key] = record.status
                total_working += 1
                if record.status == "P":
                    present_count += 1
            else:
                records[date_key] = "NT"
        
        percentage = (present_count / total_working * 100) if total_working > 0 else 0.0
        
        history.append({
            "reg_no": student.reg_no,
            "name": student.name,
            "records": records,
            "percentage": round(percentage, 1),
        })
    
    return {
        "dates": [d.isoformat() for d in session_dates],
        "students": history,
    }


@router.get("/{teacher_id}/session/{session_id}", response_model=SessionDetail)
def get_session_detail(
    teacher_id: int,
    session_id: int,
    db: Session = Depends(get_db),
):
    """Get detailed attendance records for a session."""
    session = (
        db.query(models.AttendanceSession)
        .filter(
            models.AttendanceSession.session_id == session_id,
            models.AttendanceSession.teacher_id == teacher_id,
        )
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    records = (
        db.query(models.AttendanceRecord)
        .filter(models.AttendanceRecord.session_id == session_id)
        .all()
    )
    
    record_details = []
    for r in records:
        student = db.query(models.Student).filter(models.Student.reg_no == r.reg_no).first()
        record_details.append(AttendanceRecordDetail(
            attendance_id=r.attendance_id,
            reg_no=r.reg_no,
            name=student.name if student else "Unknown",
            status=r.status,
        ))
    
    return SessionDetail(
        session_id=session.session_id,
        class_id=session.class_id,
        subject_code=session.subject_code,
        date=session.date,
        period=session.period,
        records=record_details,
    )


@router.put("/{teacher_id}/session/{session_id}/edit")
def edit_session_attendance(
    teacher_id: int,
    session_id: int,
    updates: List[UpdateRecordRequest],
    db: Session = Depends(get_db),
):
    """Edit attendance records for a session."""
    session = (
        db.query(models.AttendanceSession)
        .filter(
            models.AttendanceSession.session_id == session_id,
            models.AttendanceSession.teacher_id == teacher_id,
        )
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Check if editing is allowed (within 7 days)
    days_ago = (date.today() - session.date).days
    if days_ago > 7:
        raise HTTPException(
            status_code=400,
            detail="Cannot edit attendance older than 7 days",
        )
    
    for update in updates:
        if update.status not in ("P", "A", "OD", "ML", "NT"):
            raise HTTPException(
                status_code=400,
                detail=f"Invalid status: {update.status}",
            )
        
        record = (
            db.query(models.AttendanceRecord)
            .filter(
                models.AttendanceRecord.session_id == session_id,
                models.AttendanceRecord.reg_no == update.reg_no,
            )
            .first()
        )
        if record:
            record.status = update.status
        else:
            db.add(models.AttendanceRecord(
                session_id=session_id,
                reg_no=update.reg_no,
                status=update.status,
            ))
    
    db.commit()
    return {"message": "Attendance updated successfully"}


@router.get("/{teacher_id}/proof/{session_id}")
def get_proof_image(
    teacher_id: int,
    session_id: int,
    db: Session = Depends(get_db),
):
    """Get the proof image for an attendance session."""
    session = (
        db.query(models.AttendanceSession)
        .filter(
            models.AttendanceSession.session_id == session_id,
            models.AttendanceSession.teacher_id == teacher_id,
        )
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    proof_path = ATTENDANCE_PROOF_DIR / f"session_{session_id}.jpg"
    if not proof_path.exists():
        raise HTTPException(status_code=404, detail="Proof image not found")
    
    return FileResponse(str(proof_path), media_type="image/jpeg")


class WeeklyAttendanceRow(BaseModel):
    reg_no: str
    name: str
    attendance: dict  # session_key (date_period) -> {"status": "P/A/-", "session_id": int|None}
    percentage: float


class WeeklyAttendanceResponse(BaseModel):
    sessions: List[dict]  # [{"key": "29/1(P2)", "date": "29/1", "period": 2, "session_id": 123}, ...]
    students: List[WeeklyAttendanceRow]


@router.get("/{teacher_id}/weekly-attendance")
def get_weekly_attendance(
    teacher_id: int,
    class_id: str = Query(...),
    subject_code: str = Query(...),
    db: Session = Depends(get_db),
):
    """Get 7-day attendance for ALL sessions (any period) for a class/subject."""
    try:
        # Verify teacher
        teacher = db.query(models.Teacher).filter(models.Teacher.teacher_id == teacher_id).first()
        if not teacher:
            raise HTTPException(status_code=404, detail="Teacher not found")
        
        # Calculate date range (last 7 days including today)
        today = date.today()
        start_date = today - timedelta(days=6)
        
        # Get all students in the class
        students = (
            db.query(models.Student)
            .filter(models.Student.class_id == class_id)
            .order_by(models.Student.reg_no)
            .all()
        )
        
        if not students:
            return {"sessions": [], "students": []}
        
        # Get ALL sessions for this class/subject in date range (any period)
        sessions = (
            db.query(models.AttendanceSession)
            .filter(
                models.AttendanceSession.class_id == class_id,
                models.AttendanceSession.subject_code == subject_code,
                models.AttendanceSession.teacher_id == teacher_id,
                models.AttendanceSession.date >= start_date,
                models.AttendanceSession.date <= today,
            )
            .order_by(models.AttendanceSession.date, models.AttendanceSession.period)
            .all()
        )
        
        if not sessions:
            return {"sessions": [], "students": []}
        
        # Build session list with keys like "29/1(P2)"
        session_list = []
        for s in sessions:
            date_str = s.date.strftime("%d/%m")
            if s.date == today:
                date_str = "Today"
            key = f"{date_str}(P{s.period})"
            session_list.append({
                "key": key,
                "date": s.date.strftime("%d/%m"),
                "period": s.period,
                "session_id": s.session_id
            })
        
        # Get all records for these sessions
        session_id_list = [s.session_id for s in sessions]
        records = (
            db.query(models.AttendanceRecord)
            .filter(models.AttendanceRecord.session_id.in_(session_id_list))
            .all()
        )
        
        # Build lookup: (session_id, reg_no) -> status
        record_lookup = {(r.session_id, r.reg_no): r.status for r in records}
        
        # Build response
        result = []
        for student in students:
            # Student model has name field directly
            name = student.name
            
            attendance = {}
            present_count = 0
            total_sessions = len(sessions)
            
            for i, s in enumerate(sessions):
                key = session_list[i]["key"]
                status = record_lookup.get((s.session_id, student.reg_no), "A")
                attendance[key] = {
                    "status": status,
                    "session_id": s.session_id
                }
                if status == "P":
                    present_count += 1
            
            percentage = (present_count / total_sessions * 100) if total_sessions > 0 else 0.0
            
            result.append({
                "reg_no": student.reg_no,
                "name": name,
                "attendance": attendance,
                "percentage": round(percentage, 1)
            })
        
        return {
            "sessions": session_list,
            "students": result
        }
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}\n{traceback.format_exc()}")
# ---------- Inbox / Message Endpoints ----------

class InboxItem(BaseModel):
    approval_id: int # Kept for reference (first ID)
    approval_ids: List[int] # All IDs in this group
    request_id: int
    student_name: str
    student_reg_no: str
    date_sent: date
    requested_dates: str # "Jan-30" (The date of these sessions)
    request_type: str # "OD", "ML"
    status: str
    session_info: str # "Jan-30 Periods: 1, 2 (Maths)"
    proof_available: bool


class BulkActionRequest(BaseModel):
    approval_ids: List[int]


@router.get("/{teacher_id}/inbox", response_model=List[InboxItem])
def get_teacher_inbox(
    teacher_id: int,
    db: Session = Depends(get_db),
):
    """Get pending leave requests for this teacher, grouped by Request and Date."""
    # Query pending approvals for this teacher
    approvals = (
        db.query(models.LeaveRequestApproval)
        .filter(
            models.LeaveRequestApproval.teacher_id == teacher_id,
            models.LeaveRequestApproval.status == "Pending"
        )
        .all()
    )
    
    # Group by (request_id, session_date)
    grouped = {}
    
    for app in approvals:
        req = app.request
        session = app.session
        key = (req.request_id, session.date)
        
        if key not in grouped:
            grouped[key] = {
                "request": req,
                "student": req.student,
                "date": session.date,
                "approval_ids": [],
                "periods": [],
                "subjects": set()
            }
        
        grouped[key]["approval_ids"].append(app.approval_id)
        grouped[key]["periods"].append(session.period)
        grouped[key]["subjects"].add(session.subject_code)

    result = []
    for key, data in grouped.items():
        req = data["request"]
        student = data["student"]
        
        # Format session info
        periods_str = ", ".join(map(str, sorted(data["periods"])))
        subjects_str = ", ".join(data["subjects"])
        date_str = data["date"].strftime('%b-%d')
        
        session_str = f"{date_str} Periods: {periods_str} ({subjects_str})"
        
        result.append(InboxItem(
            approval_id=data["approval_ids"][0],
            approval_ids=data["approval_ids"],
            request_id=req.request_id,
            student_name=student.name,
            student_reg_no=student.reg_no,
            date_sent=req.created_at,
            requested_dates=date_str,
            request_type=req.request_type,
            status="Pending",
            session_info=session_str,
            proof_available=bool(req.proof_file_path)
        ))
        
    return result


@router.post("/{teacher_id}/inbox/bulk-approve")
def bulk_approve_requests(
    teacher_id: int,
    action: BulkActionRequest,
    db: Session = Depends(get_db),
):
    """Approve multiple leave request items at once."""
    success_count = 0
    
    # Process each approval ID
    approvals = (
        db.query(models.LeaveRequestApproval)
        .filter(
            models.LeaveRequestApproval.approval_id.in_(action.approval_ids),
            models.LeaveRequestApproval.teacher_id == teacher_id
        )
        .all()
    )
    
    for approval in approvals:
        if approval.status != "Pending":
            continue
            
        # 1. Update Approval Status
        approval.status = "Approved"
        
        # 2. Update Attendance Record
        req = approval.request
        record = (
            db.query(models.AttendanceRecord)
            .filter(
                models.AttendanceRecord.session_id == approval.session_id,
                models.AttendanceRecord.reg_no == req.student_reg_no
            )
            .first()
        )
        
        if record:
            record.status = req.request_type
        else:
            db.add(models.AttendanceRecord(
                session_id=approval.session_id,
                reg_no=req.student_reg_no,
                status=req.request_type
            ))
        success_count += 1
        
    db.commit()
    return {"message": f"Approved {success_count} requests"}


@router.post("/{teacher_id}/inbox/bulk-reject")
def bulk_reject_requests(
    teacher_id: int,
    action: BulkActionRequest,
    db: Session = Depends(get_db),
):
    """Reject multiple leave request items at once."""
    approvals = (
        db.query(models.LeaveRequestApproval)
        .filter(
            models.LeaveRequestApproval.approval_id.in_(action.approval_ids),
            models.LeaveRequestApproval.teacher_id == teacher_id
        )
        .all()
    )
    
    count = 0
    for approval in approvals:
        if approval.status == "Pending":
            approval.status = "Rejected"
            count += 1
            
    db.commit()
    return {"message": f"Rejected {count} requests"}


@router.post("/{teacher_id}/inbox/{approval_id}/approve")
def approve_request(
    teacher_id: int,
    approval_id: int,
    db: Session = Depends(get_db),
):
    """Approve a leave request item and update attendance (Single)."""
    # Reuse bulk logic or keep simple (keeping simple for backward compat if needed, but bulk is preferred)
    return bulk_approve_requests(teacher_id, BulkActionRequest(approval_ids=[approval_id]), db)


@router.post("/{teacher_id}/inbox/{approval_id}/reject")
def reject_request(
    teacher_id: int,
    approval_id: int,
    db: Session = Depends(get_db),
):
    """Reject a leave request item (Single)."""
    return bulk_reject_requests(teacher_id, BulkActionRequest(approval_ids=[approval_id]), db)




# ---------- Timetable ----------

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


@router.get("/timetable", response_model=List[TimetableEntryRead])
def get_my_timetable(
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get timetable for the logged-in teacher."""
    if current_user.role != "teacher":
        raise HTTPException(status_code=403, detail="Only teachers can access this endpoint")
    
    # Get teacher_id
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    
    teacher_id = user.teacher.teacher_id
    
    entries = (
        db.query(models.Timetable)
        .filter(models.Timetable.teacher_id == teacher_id)
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

@router.get("/timetable/today", response_model=List[TimetableEntryRead])
def get_my_today_timetable(
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get today's timetable for the logged-in teacher."""
    if current_user.role != "teacher":
        raise HTTPException(status_code=403, detail="Only teachers can access this endpoint")
    
    # Get teacher_id
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    
    today_date = date.today()
    day_short = today_date.strftime("%a") # "Mon"
    day_long = today_date.strftime("%A")  # "Monday"
    teacher_id = user.teacher.teacher_id # RESTORED
    
    print(f"DEBUG: Fetching timetable for Teacher {teacher_id} on {day_short}/{day_long}")
    
    entries = (
        db.query(models.Timetable)
        .filter(
            models.Timetable.teacher_id == teacher_id,
            models.Timetable.day.in_([day_short, day_long])
        )
        .order_by(models.Timetable.period)
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
