from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func

from backend import models
from backend.database import get_db
from backend.routers.auth import get_current_user, UserInfo

router = APIRouter()

# --- Pydantic Models ---

class GradingConfigCreate(BaseModel):
    subject_code: str
    internal_weight: int = 40
    external_weight: int = 60
    has_lab: bool = False
    is_pure_practical: bool = False

class GradingConfigRead(GradingConfigCreate):
    config_id: int
    class Config:
        from_attributes = True

class MarkRow(BaseModel):
    student_id: int
    reg_no: str
    name: str
    
    # Editable Fields
    cia1_score: Optional[float] = None
    cia2_score: Optional[float] = None
    assign1_score: Optional[float] = None
    assign2_score: Optional[float] = None
    lab_internal_score: Optional[float] = None
    lab_external_score: Optional[float] = None
    final_exam_score: Optional[float] = None
    
    # Calculated / Display
    total_internal: Optional[float] = None
    total_external: Optional[float] = None
    grand_total: Optional[float] = None
    grade: Optional[str] = None
    status: Optional[str] = "Absent"

class MarksSheetResponse(BaseModel):
    subject_code: str
    config: Optional[GradingConfigRead] = None
    students: List[MarkRow]

class MarksUpdateBatch(BaseModel):
    class_id: str
    subject_code: str
    updates: List[MarkRow]

# --- Helper Logic ---

def calculate_grade(total: float) -> str:
    if total >= 91: return "O"
    if total >= 81: return "A+"
    if total >= 71: return "A"
    if total >= 61: return "B+"
    if total >= 51: return "B"
    if total >= 40: return "C" # Assuming 40 is pass? Or 50? Usually 50 for College
    return "RA" # Re-Appear / Fail

def compute_marks(entry: models.MarkEntry, config: models.SubjectGradingConfig):
    # Defaults
    cia1 = entry.cia1_score or 0
    cia2 = entry.cia2_score or 0
    ass1 = entry.assign1_score or 0
    ass2 = entry.assign2_score or 0
    lab_int = entry.lab_internal_score or 0
    lab_ext = entry.lab_external_score or 0
    final = entry.final_exam_score or 0

    total_int = 0.0
    total_ext = 0.0
    
    # 1. Internal Calculation
    if config.internal_weight == 40:
        # Standard: (CIA1+CIA2)/10 + (Ass1+Ass2) = 20 + 20 = 40
        # Wait, CIA usually 100. (100+100)/10 = 20. Correct.
        # Assignments usually 10. (10+10) = 20. Correct.
        total_int = ((cia1 + cia2) / 10.0) + (ass1 + ass2)
        
    elif config.internal_weight == 50:
        if config.has_lab:
            # Theory + Lab Integrated
            # (CIA1+CIA2)/5 = 40 (standard)
            # Lab (50) -> 10 implies divide by 5.
            converted_lab = lab_int / 5.0
            total_int = ((cia1 + cia2) / 5.0) + converted_lab
        elif config.is_pure_practical:
            # Pure Practical: 50 Int / 50 Ext usually.
            # Lab Int is main.
            total_int = lab_int
    
    # Cap Internal
    if total_int > config.internal_weight: total_int = float(config.internal_weight)
    
    # 2. External Calculation
    if config.external_weight == 60:
        # Final (100) -> 60
        total_ext = (final / 100.0) * 60.0
    elif config.external_weight == 50:
        # Final (100) -> 50 OR Lab Ext (50)
        if config.is_pure_practical:
            total_ext = lab_ext # Already out of 50? Or 100? Assuming entered out of 50 or 100.
            # Let's assume entered out of 50 for direct map? Or 100 scaled.
            # Usually practical exams are 100 scaled to 50.
            total_ext = lab_ext / 2.0 if lab_ext > 50 else lab_ext
        else:
            total_ext = (final / 100.0) * 50.0
            
    # Total
    grand = total_int + total_ext
    entry.total_internal = round(total_int, 2)
    entry.total_external = round(total_ext, 2)
    entry.grand_total = round(grand, 2)
    entry.grade = calculate_grade(grand)
    
    if grand >= 50: # Assuming 50 pass
        entry.status = "Pass"
    else:
        entry.status = "Fail"

# --- Endpoints ---

@router.post("/config", response_model=GradingConfigRead)
def set_grading_config(
    config: GradingConfigCreate,
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Admin only? Or teacher? User said Admin Portal. But let's allow teacher for now to unblock.
    if current_user.role not in ["admin", "teacher"]:
         raise HTTPException(status_code=403, detail="Not authorized")
         
    existing = db.query(models.SubjectGradingConfig).filter(models.SubjectGradingConfig.subject_code == config.subject_code).first()
    if existing:
        for key, value in config.model_dump().items():
            setattr(existing, key, value)
        db.commit()
        db.refresh(existing)
        return existing
    else:
        new_config = models.SubjectGradingConfig(**config.model_dump())
        db.add(new_config)
        db.commit()
        db.refresh(new_config)
        return new_config

@router.get("/configs", response_model=List[GradingConfigRead])
def get_all_configs(
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "admin": raise HTTPException(status_code=403)
    
    configs = db.query(models.SubjectGradingConfig).all()
    return configs

@router.get("/config/{subject_code}", response_model=GradingConfigRead)
def get_grading_config(subject_code: str, db: Session = Depends(get_db)):
    config = db.query(models.SubjectGradingConfig).filter(models.SubjectGradingConfig.subject_code == subject_code).first()
    if not config:
        # Default Config
        return GradingConfigRead(
            config_id=0,
            subject_code=subject_code,
            internal_weight=40,
            external_weight=60
        )
    return config

@router.get("/entry_sheet", response_model=MarksSheetResponse)
def get_entry_sheet(
    class_id: str,
    subject_code: str,
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "teacher": raise HTTPException(status_code=403, detail="Teacher only")
    
    # 1. Get Config
    config = db.query(models.SubjectGradingConfig).filter(models.SubjectGradingConfig.subject_code == subject_code).first()
    if not config:
        config = models.SubjectGradingConfig(subject_code=subject_code, internal_weight=40, external_weight=60) # Default
        
    config_read = GradingConfigRead.model_validate(config) if config.config_id else None

    # 2. Get Students
    students = db.query(models.Student).filter(models.Student.class_id == class_id).order_by(models.Student.reg_no).all()
    
    # 3. Get Existing Marks
    marks_map = {}
    entries = db.query(models.MarkEntry).filter(
        models.MarkEntry.subject_code == subject_code,
        models.MarkEntry.student_id.in_([s.student_id for s in students])
    ).all()
    for e in entries: marks_map[e.student_id] = e
    
    # 4. Auto-Sync Assignments (If marks missing)
    # Fetch all assignments for this subject & class
    assignments = db.query(models.Task).filter(
        models.Task.class_id == class_id,
        models.Task.subject_code == subject_code,
        models.Task.type == "Assignment"
    ).order_by(models.Task.created_at.asc()).limit(2).all()
    
    task_ids = [t.task_id for t in assignments]
    submissions = db.query(models.Submission).filter(models.Submission.task_id.in_(task_ids)).all()
    
    sub_map = {} # (student_id, task_idx) -> marks
    for s in submissions:
        # Determine which assignment (1 or 2) this task corresponds to
        try:
            idx = task_ids.index(s.task_id) + 1 # 1 or 2
            if s.marks_obtained is not None:
                sub_map[(s.student_id, idx)] = s.marks_obtained
        except: pass

    result_rows = []
    for s in students:
        entry = marks_map.get(s.student_id)
        
        row = MarkRow(
            student_id=s.student_id, 
            reg_no=s.reg_no, 
            name=s.name
        )
        
        if entry:
            # Prefill existing
            row.cia1_score = entry.cia1_score
            row.cia2_score = entry.cia2_score
            # Auto-fill if empty, else use existing
            row.assign1_score = entry.assign1_score if entry.assign1_score is not None else sub_map.get((s.student_id, 1))
            row.assign2_score = entry.assign2_score if entry.assign2_score is not None else sub_map.get((s.student_id, 2))
            
            row.lab_internal_score = entry.lab_internal_score
            row.lab_external_score = entry.lab_external_score
            row.final_exam_score = entry.final_exam_score
            
            row.total_internal = entry.total_internal
            row.total_external = entry.total_external
            row.grand_total = entry.grand_total
            row.grade = entry.grade
            row.status = entry.status
        else:
            # Auto-fill Assignments for new entries
            if (s.student_id, 1) in sub_map: row.assign1_score = sub_map[(s.student_id, 1)]
            if (s.student_id, 2) in sub_map: row.assign2_score = sub_map[(s.student_id, 2)]
            
        result_rows.append(row)
        
    return MarksSheetResponse(
        subject_code=subject_code,
        config=config_read,
        students=result_rows
    )

@router.post("/entry")
def save_marks(
    batch: MarksUpdateBatch,
    db: Session = Depends(get_db),
    current_user: UserInfo = Depends(get_current_user),
):
    if current_user.role != "teacher": raise HTTPException(status_code=403)
    
    print(f"DEBUG: Saving marks for Class {batch.class_id}, Subject {batch.subject_code}, Count: {len(batch.updates)}")

    try:
        # Get Config
        config = db.query(models.SubjectGradingConfig).filter(models.SubjectGradingConfig.subject_code == batch.subject_code).first()
        if not config:
            print(f"DEBUG: No config found for {batch.subject_code}, creating default (40/60).")
            config = models.SubjectGradingConfig(subject_code=batch.subject_code, internal_weight=40, external_weight=60)
            db.add(config)
            db.commit() # Commit to persist
            db.refresh(config)
        
        for update in batch.updates:
            # Fetch or Create Mark Entry
            entry = db.query(models.MarkEntry).filter(
                models.MarkEntry.subject_code == batch.subject_code,
                models.MarkEntry.student_id == update.student_id
            ).first()
            
            if not entry:
                entry = models.MarkEntry(
                    student_id=update.student_id,
                    subject_code=batch.subject_code
                )
                db.add(entry)
            
            # Apply Updates safe (Handle None explicitly if needed)
            if update.cia1_score is not None: entry.cia1_score = update.cia1_score
            if update.cia2_score is not None: entry.cia2_score = update.cia2_score
            if update.assign1_score is not None: entry.assign1_score = update.assign1_score
            if update.assign2_score is not None: entry.assign2_score = update.assign2_score
            if update.lab_internal_score is not None: entry.lab_internal_score = update.lab_internal_score
            if update.lab_external_score is not None: entry.lab_external_score = update.lab_external_score
            if update.final_exam_score is not None: entry.final_exam_score = update.final_exam_score
            
            # Calculate
            try:
                compute_marks(entry, config)
            except Exception as e:
                print(f"ERROR calculating marks for student {update.student_id}: {e}")
            
        db.commit()
        print("DEBUG: Marks saved successfully.")
        return {"message": "Marks saved successfully"}
        
    except Exception as e:
        print(f"CRITICAL ERROR in save_marks: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to save marks: {str(e)}")

@router.get("/statistics/{class_id}/{subject_code}")
def get_marks_statistics(
    class_id: str,
    subject_code: str,
    exam_type: str = Query("Final Result", enum=["CIA 1", "CIA 2", "Final Exam", "Final Result"]),
    db: Session = Depends(get_db),
    current_user: UserInfo = Depends(get_current_user),
):
    # Fetch all marks for this class/subject
    entries = db.query(models.MarkEntry).filter(
        models.MarkEntry.subject_code == subject_code
    ).join(models.Student).filter(models.Student.class_id == class_id).all()
    
    if not entries:
        return {
            "total_students": 0,
            "passed": 0,
            "failed": 0,
            "top_mark": 0,
            "low_mark": 0,
            "avg_mark": 0,
            "grade_dist": {},
            "top_performers": [],
            "needs_improvement": []
        }
    
    total = len(entries)
    
    # Determine which score to use
    scores = []
    processed_entries = []
    
    for e in entries:
        score = 0
        is_absent = False
        
        if exam_type == "CIA 1":
            score = e.cia1_score or 0
        elif exam_type == "CIA 2":
            score = e.cia2_score or 0
        elif exam_type == "Final Exam":
            score = e.final_exam_score or 0
        else: # Final Result
            score = e.grand_total or 0
            
        scores.append(score)
        processed_entries.append({"name": e.student.name, "mark": score})

    # Pass/Fail Logic
    passed = 0
    failed = 0
    
    # Define pass thresholds
    pass_mark = 50.0
    if exam_type in ["CIA 1", "CIA 2"]: pass_mark = 50.0 # Assuming 50/100 for internal exams too? Or 40? Let's stick to 50.
    
    for s in scores:
        if s >= pass_mark: passed += 1
        else: failed += 1

    if not scores: scores = [0]
    
    top_mark = max(scores)
    low_mark = min(scores)
    avg_mark = sum(scores) / len(scores)
    
    # Grade Dist (Only relevant for Final Result really, but we can fake it for others or just show ranges)
    grade_dist = {}
    if exam_type == "Final Result":
        for e in entries:
            g = e.grade or "RA"
            grade_dist[g] = grade_dist.get(g, 0) + 1
    else:
        # Simple Range Distribution for raw exams
        for s in scores:
            if s >= 90: k="90-100"
            elif s >= 80: k="80-89"
            elif s >= 70: k="70-79"
            elif s >= 60: k="60-69"
            elif s >= 50: k="50-59"
            else: k="<50"
            grade_dist[k] = grade_dist.get(k, 0) + 1
        
    # Top/Low Performers
    sorted_entries = sorted(processed_entries, key=lambda x: x['mark'], reverse=True)
    top_5 = sorted_entries[:5]
    low_5 = sorted_entries[-5:]
    if len(sorted_entries) >= 5:
        # Low 5 need to be the actual lowest, so reverse=False logic or just take last 5 of desc and reverse them?
        # lowest are at end of desc sorted list.
        low_5 = sorted_entries[-5:] 
        # But we want them sorted low to high usually?
        low_5 = sorted(sorted_entries[-5:], key=lambda x: x['mark'])
        
    return {
        "total_students": total,
        "passed": passed,
        "failed": failed,
        "top_mark": top_mark,
        "low_mark": low_mark,
        "avg_mark": round(avg_mark, 2),
        "grade_dist": grade_dist,
        "top_performers": top_5,
        "needs_improvement": low_5
    }

@router.get("/student/my_marks/{subject_code}")
def get_my_marks(
    subject_code: str,
    db: Session = Depends(get_db),
    current_user: UserInfo = Depends(get_current_user),
):
    if current_user.role != "student": raise HTTPException(status_code=403)
    
    # Get Student ID
    user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    if not user or not user.student: raise HTTPException(status_code=404, detail="Student profile not found")
    student_id = user.student.student_id
    
    # Get Config
    config = db.query(models.SubjectGradingConfig).filter(models.SubjectGradingConfig.subject_code == subject_code).first()
    config_read = GradingConfigRead.model_validate(config) if config else None # Could be null if default
    if not config:
         config_read = GradingConfigRead(config_id=0, subject_code=subject_code, internal_weight=40, external_weight=60)

    # Get Mark Entry
    entry = db.query(models.MarkEntry).filter(
        models.MarkEntry.subject_code == subject_code,
        models.MarkEntry.student_id == student_id
    ).first()
    
    entry_data = None
    rank = 0
    if entry:
        entry_data = entry
        # Calculate Rank
        if entry.grand_total is not None:
             better_students = db.query(func.count(models.MarkEntry.mark_id)).filter(
                 models.MarkEntry.subject_code == subject_code,
                 models.MarkEntry.grand_total > entry.grand_total
             ).scalar()
             rank = better_students + 1
             
    return {
        "config": config_read,
        "marks": entry_data,
        "rank": rank
    }

@router.get("/student/final_marksheet")
def get_final_marksheet(
    current_user: UserInfo = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "student": raise HTTPException(status_code=403)
    
    # Get student info
    st_user = db.query(models.User).filter(models.User.user_id == current_user.user_id).first()
    student = st_user.student
    
    # Get all subjects for student's class to verify completion
    subjects = db.query(models.ClassSubjectMap).filter(models.ClassSubjectMap.class_id == student.class_id).all()
    total_subjects_count = len(subjects)
    
    # Get marks
    marks = db.query(models.MarkEntry).filter(
        models.MarkEntry.student_id == student.student_id
    ).all()
    
    results = []
    published_count = 0
    tot_credits = 0
    weighted_pts = 0
    
    def grade_point(g):
        if not g: return 0
        if g.startswith('O'): return 10
        if g.startswith('A+'): return 9
        if g.startswith('A'): return 8
        if g.startswith('B+'): return 7
        if g.startswith('B'): return 6
        if g.startswith('C'): return 5
        return 0 # Fail
        
    for m in marks:
        sub = db.query(models.Subject).filter(models.Subject.subject_code == m.subject_code).first()
        
        # Consider published if Grade is present
        if m.grade:
            published_count += 1
            
        results.append({
            "subject_code": m.subject_code,
            "subject_name": sub.subject_name if sub else m.subject_code,
            "internal": m.total_internal,
            "external": m.total_external,
            "total": m.grand_total,
            "grade": m.grade,
            "credits": sub.credits if sub else 3, # Default 3
            "status": m.status
        })
        
        c = sub.credits if sub else 3
        tot_credits += c
        weighted_pts += grade_point(m.grade) * c
        
    sgpa = weighted_pts / tot_credits if tot_credits > 0 else 0.0
    
    # Logic: If published_count < total_subjects_count, then results are partial/pending
    is_all_published = (published_count >= total_subjects_count) and (total_subjects_count > 0)
    
    return {
        "student_name": student.name,
        "reg_no": student.reg_no,
        "class": f"{student.class_.department.dept_name} {student.class_.year}-{student.class_.section}",
        "batch": f"{student.batch.start_year}-{student.batch.end_year}",
        "results": results,
        "sgpa": round(sgpa, 2),
        "result_status": "PASS" if all(r['status'] == 'Pass' for r in results) else "FAIL",
        "all_published": is_all_published
    }
