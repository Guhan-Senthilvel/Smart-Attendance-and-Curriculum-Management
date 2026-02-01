from datetime import date
from pathlib import Path
from typing import List, Optional

import cv2
import numpy as np
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from backend import models
#from backend.ai.engine import FaceAttendanceEngine
from backend.database import get_db
from backend.ai.engine import get_engine


router = APIRouter()

#ENGINE = FaceAttendanceEngine()
PROJECT_ROOT = Path(__file__).resolve().parents[2]
ATTENDANCE_PROOF_DIR = PROJECT_ROOT / "storage" / "attendance_proofs"
ATTENDANCE_PROOF_DIR.mkdir(parents=True, exist_ok=True)


class SessionCreate(BaseModel):
    class_id: str
    subject_code: str
    teacher_id: int
    date: date
    period: int


class ManualRecord(BaseModel):
    reg_no: str
    status: str  # "P", "A", "OD", "ML", "NT"


class ManualAttendancePayload(SessionCreate):
    records: List[ManualRecord]


class AttendanceSummary(BaseModel):
    session_id: int
    present: List[str]
    absent: List[str]
    od: List[str] = []
    ml: List[str] = []



def _get_or_create_session(payload: SessionCreate, db: Session) -> models.AttendanceSession:
    # Check if a session already exists for this slot (Class + Date + Period)
    existing_session = (
        db.query(models.AttendanceSession)
        .filter(
            models.AttendanceSession.class_id == payload.class_id,
            models.AttendanceSession.date == payload.date,
            models.AttendanceSession.period == payload.period,
        )
        .first()
    )

    if existing_session:
        # If it exists, check if it was created by the same teacher
        if existing_session.teacher_id == payload.teacher_id:
            # SAME TEACHER: Check if the SUBJECT matches
            if existing_session.subject_code == payload.subject_code:
                return existing_session  # All good, allow update
            else:
                # Same teacher, Same period, BUT Different Subject -> ERROR
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"You already marked this period for a different subject ({existing_session.subject_code}).",
                )
        else:
            # Another teacher already took this period!
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Attendance already marked for this period by another teacher.",
            )

    # Create new session if slot is free
    session = models.AttendanceSession(
        class_id=payload.class_id,
        subject_code=payload.subject_code,
        teacher_id=payload.teacher_id,
        date=payload.date,
        period=payload.period,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


@router.post(
    "/auto",
    response_model=AttendanceSummary,
    summary="Mark attendance from classroom image using AI",
)
async def auto_attendance(
    class_id: str = Form(...),
    subject_code: str = Form(...),
    teacher_id: int = Form(...),
    date_value: date = Form(..., alias="date"),
    period: int = Form(...),
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    # 1. Load students & embeddings for this class
    students = (
        db.query(models.Student)
        .filter(models.Student.class_id == class_id)
        .all()
    )
    if not students:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No students found for this class_id",
        )

    embeddings = {}
    for s in students:
        profile = (
            db.query(models.FaceProfile)
            .filter(models.FaceProfile.reg_no == s.reg_no)
            .first()
        )
        if profile and profile.embedding_vector:
            embeddings[s.reg_no] = np.array(profile.embedding_vector, dtype=np.float32)

    if not embeddings:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No face embeddings found for students in this class. Please enroll faces first.",
        )

    # 2. Read uploaded image into OpenCV
    img_bytes = await image.read()
    np_arr = np.frombuffer(img_bytes, np.uint8)
    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not decode image",
        )

    # 3. Run AI engine
    #present, absent, annotated = ENGINE.mark_attendance(frame, embeddings)
    engine = get_engine()
    present, absent, annotated = engine.mark_attendance(frame, embeddings)


    # 4. Create or fetch session
    session_payload = SessionCreate(
        class_id=class_id,
        subject_code=subject_code,
        teacher_id=teacher_id,
        date=date_value,
        period=period,
    )
    session = _get_or_create_session(session_payload, db)

    # 5. Save annotated proof image (one per session)
    proof_path = ATTENDANCE_PROOF_DIR / f"session_{session.session_id}.jpg"
    cv2.imwrite(str(proof_path), annotated)

    # 6. Upsert attendance records
    existing_records = {
        r.reg_no: r
        for r in db.query(models.AttendanceRecord)
        .filter(models.AttendanceRecord.session_id == session.session_id)
        .all()
    }

    db.commit()

    # Calculate status lists based on AI results
    # Do NOT save records to DB yet - waiting for teacher confirmation
    
    # Get all students in class to ensure everyone is accounted for
    all_students = (
        db.query(models.Student)
        .filter(models.Student.class_id == class_id)
        .all()
    )
    
    # Check for EXISTING OD/ML records (if any were marked beforehand manually)
    # We should respect these if they exist for this session (unlikely if session just created)
    # But if session existed, we might have records.
    existing_records = {
        r.reg_no: r
        for r in db.query(models.AttendanceRecord)
        .filter(models.AttendanceRecord.session_id == session.session_id)
        .all()
    }
    
    present_list = []
    absent_list = []
    od_list = []
    ml_list = []
    
    for student in all_students:
        reg_no = student.reg_no
        
        # Priority 1: Existing Locked Status (OD/ML)
        if reg_no in existing_records and existing_records[reg_no].status in ("OD", "ML"):
            status_val = existing_records[reg_no].status
            if status_val == "OD":
                od_list.append(reg_no)
            else:
                ml_list.append(reg_no)
            continue
            
        # Priority 2: AI Detection
        # If student has embedding and was detected -> Present
        # If student has embedding and NOT detected -> Absent
        # If student has NO embedding -> Absent (or manual check)
        
        if reg_no in present:
            present_list.append(reg_no)
        else:
            absent_list.append(reg_no)

    return AttendanceSummary(
        session_id=session.session_id,
        present=present_list,
        absent=absent_list,
        od=od_list,
        ml=ml_list,
    )


@router.post(
    "/manual",
    response_model=AttendanceSummary,
    summary="Manually mark attendance for a session",
)
def manual_attendance(
    payload: ManualAttendancePayload,
    db: Session = Depends(get_db),
):
    session = _get_or_create_session(payload, db)

    existing_records = {
        r.reg_no: r
        for r in db.query(models.AttendanceRecord)
        .filter(models.AttendanceRecord.session_id == session.session_id)
        .all()
    }

    for rec in payload.records:
        if rec.status not in ("P", "A", "OD", "ML", "NT"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid status {rec.status} for {rec.reg_no}. Must be P, A, OD, or ML.",
            )
        record = existing_records.get(rec.reg_no)
        if record:
            record.status = rec.status
        else:
            db.add(
                models.AttendanceRecord(
                    session_id=session.session_id,
                    reg_no=rec.reg_no,
                    status=rec.status,
                )
            )

    db.commit()

    present = [
        rec.reg_no
        for rec in db.query(models.AttendanceRecord)
        .filter(
            models.AttendanceRecord.session_id == session.session_id,
            models.AttendanceRecord.status == "P",
        )
        .all()
    ]
    absent = [
        rec.reg_no
        for rec in db.query(models.AttendanceRecord)
        .filter(
            models.AttendanceRecord.session_id == session.session_id,
            models.AttendanceRecord.status == "A",
        )
        .all()
    ]
    od_list = [
        rec.reg_no
        for rec in db.query(models.AttendanceRecord)
        .filter(
            models.AttendanceRecord.session_id == session.session_id,
            models.AttendanceRecord.status == "OD",
        )
        .all()
    ]
    ml_list = [
        rec.reg_no
        for rec in db.query(models.AttendanceRecord)
        .filter(
            models.AttendanceRecord.session_id == session.session_id,
            models.AttendanceRecord.status == "ML",
        )
        .all()
    ]

    return AttendanceSummary(
        session_id=session.session_id,
        present=present,
        absent=absent,
        od=od_list,
        ml=ml_list,
    )

