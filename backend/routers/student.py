from datetime import date
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status, File, UploadFile, Form
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload

from backend import models
from backend.database import get_db
from backend.routers.auth import get_current_user, UserInfo


router = APIRouter()


class PeriodInfo(BaseModel):
    period_no: int
    subject_name: Optional[str] = None
    subject_code: Optional[str] = None
    status: str  # "present", "absent", "not_taken"


class TodayResponse(BaseModel):
    overall_percentage: float
    periods: List[PeriodInfo]
    subjects: List[dict]


class TodayAttendanceResponse(BaseModel):
    date: date
    periods: List[str]
    percentage: float


class FullSheetRow(BaseModel):
    date: date
    p1: str
    p2: str
    p3: str
    p4: str
    p5: str
    p6: str
    p7: str


class FullSheetResponse(BaseModel):
    rows: List[FullSheetRow]
    percentage: float


# New /today endpoint using JWT auth
@router.get("/today")
def get_my_today_attendance(
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get today's attendance for the logged-in student."""
    if current_user.role != "student":
        raise HTTPException(status_code=403, detail="Only students can access this endpoint")
    
    # Get student's reg_no from user
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    reg_no = user.student.reg_no
    today = date.today()
    
    # Fetch all records for this student for today
    records = (
        db.query(models.AttendanceRecord, models.AttendanceSession)
        .join(
            models.AttendanceSession,
            models.AttendanceRecord.session_id == models.AttendanceSession.session_id,
        )
        .filter(
            models.AttendanceRecord.reg_no == reg_no,
            models.AttendanceSession.date == today,
        )
        .all()
    )
    
    # Build period info
    periods_data = []
    present_count = 0
    total_working = 0
    
    for period_no in range(1, 8):
        # Find record for this period
        period_record = None
        session_info = None
        for rec, ses in records:
            if ses.period == period_no:
                period_record = rec
                session_info = ses
                break
        
        if period_record and period_record.status != "NT":
            subject = db.query(models.Subject).filter(
                models.Subject.subject_code == session_info.subject_code
            ).first() if session_info else None
            
            # Allow raw status (P, A, OD, ML) to pass to frontend
            # Or map it? Frontend likely expects lowercase 'present'/'absent' based on existing code.
            # But for OD/ML distinct display, we should send specific codes.
            # I will send raw status map: P->present, A->absent, OD->od, ML->ml
            
            raw_status = period_record.status
            status_str = "absent"
            if raw_status == "P":
                status_str = "present"
            elif raw_status == "OD":
                status_str = "od"
            elif raw_status == "ML":
                status_str = "medical_leave"

            total_working += 1
            # OD is considered present
            if raw_status == "P" or raw_status == "OD":
                present_count += 1
            
            periods_data.append(PeriodInfo(
                period_no=period_no,
                subject_name=subject.subject_name if subject else None,
                subject_code=session_info.subject_code if session_info else None,
                status=status_str,
            ))
        else:
            periods_data.append(PeriodInfo(
                period_no=period_no,
                status="not_taken",
            ))
    
    # Calculate overall percentage
    overall_percentage = (present_count / total_working * 100) if total_working > 0 else 0.0
    
    # Get subject-wise attendance (dummy for now, can be expanded)
    subjects_data = []
    
    return {
        "overall_percentage": round(overall_percentage, 1),
        "periods": [p.model_dump() for p in periods_data],
        "subjects": subjects_data,
    }


@router.get("/weekly")
def get_my_weekly_attendance(
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get 7-day attendance grid for the logged-in student."""
    from datetime import timedelta
    
    if current_user.role != "student":
        raise HTTPException(status_code=403, detail="Only students can access this endpoint")
    
    # Get student's reg_no from user
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    reg_no = user.student.reg_no
    today = date.today()
    start_date = today - timedelta(days=6)  # 7 days including today
    
    # Fetch all records for this student for past 7 days
    records = (
        db.query(models.AttendanceRecord, models.AttendanceSession)
        .join(
            models.AttendanceSession,
            models.AttendanceRecord.session_id == models.AttendanceSession.session_id,
        )
        .filter(
            models.AttendanceRecord.reg_no == reg_no,
            models.AttendanceSession.date >= start_date,
            models.AttendanceSession.date <= today,
        )
        .all()
    )
    
    # Group by date then by period
    grouped = {}
    total_present = 0
    total_working = 0
    total_ml = 0
    
    for rec, ses in records:
        d = ses.date
        if d not in grouped:
            grouped[d] = {p: "-" for p in range(1, 8)}  # "-" means no class
        status_value = rec.status
        if status_value == "NT":
            continue
        grouped[d][ses.period] = status_value
        total_working += 1
        
        # P and OD are present
        if status_value == "P" or status_value == "OD":
            total_present += 1
        
        # Track ML for condonation logic
        if status_value == "ML":
            total_ml += 1
    
    # Build rows for past 7 days (in order)
    rows = []
    for i in range(7):
        d = start_date + timedelta(days=i)
        row_periods = grouped.get(d, {p: "-" for p in range(1, 8)})
        rows.append({
            "date": d.strftime("%b-%d"),
            "date_raw": d.isoformat(),
            "p1": row_periods.get(1, "-"),
            "p2": row_periods.get(2, "-"),
            "p3": row_periods.get(3, "-"),
            "p4": row_periods.get(4, "-"),
            "p5": row_periods.get(5, "-"),
            "p6": row_periods.get(6, "-"),
            "p7": row_periods.get(7, "-"),
        })
    
    percentage = (total_present / total_working * 100) if total_working > 0 else 0.0
    
    return {
        "rows": rows,
        "percentage": round(percentage, 1),
        "total_present": total_present,
        "total_working": total_working,
        "total_ml": total_ml,
    }


@router.get("/{reg_no}/today", response_model=TodayAttendanceResponse)
def get_today_attendance(
    reg_no: str,
    db: Session = Depends(get_db),
):
    today = date.today()

    # fetch all records for this student for today (all subjects / teachers)
    records = (
        db.query(models.AttendanceRecord, models.AttendanceSession)
        .join(
            models.AttendanceSession,
            models.AttendanceRecord.session_id == models.AttendanceSession.session_id,
        )
        .filter(
            models.AttendanceRecord.reg_no == reg_no,
            models.AttendanceSession.date == today,
        )
        .all()
    )

    # Initialize all 7 periods as "NT"
    period_status = {p: "NT" for p in range(1, 8)}
    present_count = 0
    total_working = 0

    for rec, ses in records:
        status_value = rec.status
        if status_value == "NT":
            continue
        period_status[ses.period] = status_value
        total_working += 1
        if status_value == "P":
            present_count += 1

    percentage = (
        (present_count / total_working) * 100 if total_working > 0 else 0.0
    )

    # Map periods to ordered list P1..P7
    ordered = [period_status[p] for p in range(1, 8)]

    return TodayAttendanceResponse(
        date=today,
        periods=ordered,
        percentage=round(percentage, 1),
    )


@router.get("/{reg_no}/sheet", response_model=FullSheetResponse)
def get_full_attendance_sheet(
    reg_no: str,
    from_date: date = Query(...),
    to_date: date = Query(...),
    db: Session = Depends(get_db),
):
    if from_date > to_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="from_date must be before to_date",
        )

    records = (
        db.query(models.AttendanceRecord, models.AttendanceSession)
        .join(
            models.AttendanceSession,
            models.AttendanceRecord.session_id == models.AttendanceSession.session_id,
        )
        .filter(
            models.AttendanceRecord.reg_no == reg_no,
            models.AttendanceSession.date >= from_date,
            models.AttendanceSession.date <= to_date,
        )
        .all()
    )

    # Group by date then by period
    grouped = {}
    total_present = 0
    total_working = 0

    for rec, ses in records:
        d = ses.date
        if d not in grouped:
            grouped[d] = {p: "NT" for p in range(1, 8)}
        status_value = rec.status
        if status_value == "NT":
            continue
        grouped[d][ses.period] = status_value
        total_working += 1
        if status_value == "P":
            total_present += 1

    rows: List[FullSheetRow] = []
    for d in sorted(grouped.keys()):
        row_periods = grouped[d]
        rows.append(
            FullSheetRow(
                date=d,
                p1=row_periods[1],
                p2=row_periods[2],
                p3=row_periods[3],
                p4=row_periods[4],
                p5=row_periods[5],
                p6=row_periods[6],
                p7=row_periods[7],
            )
        )

    percentage = (
        (total_present / total_working) * 100 if total_working > 0 else 0.0
    )

    return FullSheetResponse(
        rows=rows,
        percentage=round(percentage, 1),
    )

@router.post("/request-leave")
async def request_od_ml(
    request_type: str = Form(...),  # "OD" or "ML"
    from_date: date = Form(...),
    to_date: date = Form(...),
    periods: str = Form(...),       # "1,2,3" or "All"
    proof: UploadFile = File(...),
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Raise a request for OD or Medical Leave."""
    import shutil
    from pathlib import Path
    from datetime import timedelta
    
    if current_user.role != "student":
        raise HTTPException(status_code=403, detail="Only students can access this endpoint")
    
    # Get student's info
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    student = user.student
    
    # 1. Save Proof File
    PROOF_DIR = Path(__file__).parents[2] / "storage" / "leave_proofs"
    PROOF_DIR.mkdir(parents=True, exist_ok=True)
    
    # Simple filename: reg_no_timestamp.ext or generic
    import time
    ext = proof.filename.split('.')[-1] if '.' in proof.filename else "jpg"
    filename = f"{student.reg_no}_{int(time.time())}.{ext}"
    file_path = PROOF_DIR / filename
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(proof.file, buffer)
        
    # 2. Create Base Request
    new_request = models.LeaveRequest(
        student_reg_no=student.reg_no,
        request_type=request_type,
        from_date=from_date,
        to_date=to_date,
        periods=periods,
        proof_file_path=str(file_path),
        created_at=date.today(),
    )
    db.add(new_request)
    db.flush()  # To get request_id
    
    # 3. Create Approval Items for RELEVANT Sessions
    # Logic: Iterate dates -> periods -> find session -> create item
    
    # Parse periods
    target_periods = []
    if periods.lower() == "all":
        target_periods = [1, 2, 3, 4, 5, 6, 7]
    else:
        try:
            target_periods = [int(p.strip()) for p in periods.split(',')]
        except:
            pass # Handle error or assume all?
            
    # Iterate dates
    delta = (to_date - from_date).days
    approval_count = 0
    
    for i in range(delta + 1):
        d = from_date + timedelta(days=i)
        
        # Find sessions for this class on this date matching periods
        sessions = (
            db.query(models.AttendanceSession)
            .filter(
                models.AttendanceSession.class_id == student.class_id,
                models.AttendanceSession.date == d,
                models.AttendanceSession.period.in_(target_periods)
            )
            .all()
        )
        
        for ses in sessions:
            # Create Approval Item
            approval = models.LeaveRequestApproval(
                request_id=new_request.request_id,
                session_id=ses.session_id,
                teacher_id=ses.teacher_id,
                status="Pending"
            )
            db.add(approval)
            approval_count += 1
            
    db.commit()
    
    return {
        "message": "Request submitted successfully",
        "approvals_created": approval_count
    }


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
    """Get timetable for the logged-in student's class."""
    if current_user.role != "student":
        raise HTTPException(status_code=403, detail="Only students can access this endpoint")
    
    # Get student's class_id
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    class_id = user.student.class_id
    
    entries = (
        db.query(models.Timetable)
        .options(joinedload(models.Timetable.subject))
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

@router.get("/subjects")
def get_my_subjects(
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get list of subjects for the logged-in student."""
    if current_user.role != "student":
        raise HTTPException(status_code=403, detail="Only students can access this endpoint")
    
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    class_id = user.student.class_id
    
    # Fetch subjects mapped to this class
    mappings = db.query(models.ClassSubjectMap).filter(models.ClassSubjectMap.class_id == class_id).all()
    
    subjects = []
    for m in mappings:
        sub = db.query(models.Subject).filter(models.Subject.subject_code == m.subject_code).first()
        if sub:
            subjects.append({
                "subject_code": sub.subject_code,
                "subject_name": sub.subject_name
            })
            
    return subjects
