from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from backend.database import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False)  # "student", "teacher", "admin"
    status = Column(String(50), nullable=False, default="active")

    student = relationship("Student", back_populates="user", uselist=False)
    teacher = relationship("Teacher", back_populates="user", uselist=False)


class Department(Base):
    __tablename__ = "departments"

    dept_id = Column(Integer, primary_key=True, index=True)
    dept_name = Column(String(255), unique=True, nullable=False)

    classes = relationship("Class", back_populates="department")
    subjects = relationship("Subject", back_populates="department")


class Batch(Base):
    __tablename__ = "batches"

    batch_id = Column(Integer, primary_key=True, index=True)
    start_year = Column(Integer, nullable=False)
    end_year = Column(Integer, nullable=False)

    classes = relationship("Class", back_populates="batch")


class Class(Base):
    __tablename__ = "classes"

    class_id = Column(String(10), primary_key=True, index=True)
    dept_id = Column(Integer, ForeignKey("departments.dept_id"), nullable=False)
    batch_id = Column(Integer, ForeignKey("batches.batch_id"), nullable=False)
    year = Column(Integer, nullable=False)  # 1..4
    section = Column(String(10), nullable=False)

    department = relationship("Department", back_populates="classes")
    batch = relationship("Batch", back_populates="classes")
    students = relationship("Student", back_populates="class_")
    sessions = relationship("AttendanceSession", back_populates="class_")

    __table_args__ = (
        UniqueConstraint("dept_id", "batch_id", "year", "section", name="uq_class_per_section"),
    )


class Student(Base):
    __tablename__ = "students"

    student_id = Column(Integer, primary_key=True, index=True)
    reg_no = Column(String(50), unique=True, nullable=False)
    name = Column(String(255), nullable=False)
    dept_id = Column(Integer, ForeignKey("departments.dept_id"), nullable=False)
    batch_id = Column(Integer, ForeignKey("batches.batch_id"), nullable=False)
    class_id = Column(String(10), ForeignKey("classes.class_id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.user_id"), nullable=False, unique=True)

    user = relationship("User", back_populates="student")
    department = relationship("Department")
    batch = relationship("Batch")
    submissions = relationship("Submission", back_populates="student")
    face_images = relationship("FaceImage", back_populates="student")
    profile = relationship("StudentProfile", back_populates="student", uselist=False, cascade="all, delete-orphan")
    class_ = relationship("Class", back_populates="students")
    face_profile = relationship("FaceProfile", back_populates="student", uselist=False)
    subjects = relationship("StudentSubjectMap", back_populates="student")
    attendance_records = relationship("AttendanceRecord", back_populates="student")


class StudentProfile(Base):
    __tablename__ = "student_profiles"
    
    profile_id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.student_id"), unique=True, nullable=False)
    
    personal_email = Column(String, nullable=True)
    student_mobile = Column(String, nullable=True)
    father_mobile = Column(String, nullable=True)
    mother_mobile = Column(String, nullable=True)
    address = Column(String, nullable=True)
    state = Column(String, nullable=True)
    tenth_mark = Column(String, nullable=True)
    twelfth_mark = Column(String, nullable=True)
    
    student = relationship("Student", back_populates="profile", uselist=False)


class Teacher(Base):
    __tablename__ = "teachers"

    teacher_id = Column(Integer, primary_key=True, index=True)
    employee_no = Column(String(50), unique=True, nullable=False)
    name = Column(String(255), nullable=False)  # Teacher name
    dept_id = Column(Integer, ForeignKey("departments.dept_id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.user_id"), nullable=False, unique=True)

    user = relationship("User", back_populates="teacher")
    department = relationship("Department")
    subjects = relationship("TeacherSubjectMap", back_populates="teacher")
    sessions = relationship("AttendanceSession", back_populates="teacher")


class Subject(Base):
    __tablename__ = "subjects"

    subject_code = Column(String(50), primary_key=True, index=True)
    subject_name = Column(String(255), nullable=False)
    credits = Column(Integer, nullable=False)
    dept_id = Column(Integer, ForeignKey("departments.dept_id"), nullable=False)
    semester = Column(Integer, nullable=False)

    department = relationship("Department", back_populates="subjects")
    teacher_mappings = relationship("TeacherSubjectMap", back_populates="subject")
    student_mappings = relationship("StudentSubjectMap", back_populates="subject")
    sessions = relationship("AttendanceSession", back_populates="subject")


class TeacherSubjectMap(Base):
    __tablename__ = "teacher_subject_map"

    teacher_id = Column(Integer, ForeignKey("teachers.teacher_id"), primary_key=True)
    subject_code = Column(String(50), ForeignKey("subjects.subject_code"), primary_key=True)

    teacher = relationship("Teacher", back_populates="subjects")
    subject = relationship("Subject", back_populates="teacher_mappings")


class StudentSubjectMap(Base):
    __tablename__ = "student_subject_map"

    reg_no = Column(String(50), ForeignKey("students.reg_no"), primary_key=True)
    subject_code = Column(String(50), ForeignKey("subjects.subject_code"), primary_key=True)

    student = relationship("Student", back_populates="subjects", primaryjoin="StudentSubjectMap.reg_no==Student.reg_no")
    subject = relationship("Subject", back_populates="student_mappings")


class ClassSubjectMap(Base):
    """Maps subjects to entire classes - all students in class get this subject"""
    __tablename__ = "class_subject_map"

    class_id = Column(String(10), ForeignKey("classes.class_id"), primary_key=True)
    subject_code = Column(String(50), ForeignKey("subjects.subject_code"), primary_key=True)

    class_ = relationship("Class")
    subject = relationship("Subject")


class FaceProfile(Base):
    __tablename__ = "face_profiles"

    face_id = Column(Integer, primary_key=True, index=True)
    reg_no = Column(String(50), ForeignKey("students.reg_no"), unique=True, nullable=False)
    # store embedding as JSON array of floats for simplicity
    embedding_vector = Column(JSONB, nullable=False)

    student = relationship("Student", back_populates="face_profile", primaryjoin="FaceProfile.reg_no==Student.reg_no")


class FaceImage(Base):
    __tablename__ = "face_images"

    image_id = Column(Integer, primary_key=True, index=True)
    reg_no = Column(String(50), ForeignKey("students.reg_no"), nullable=False)
    image_path = Column(Text, nullable=False)

    student = relationship("Student", back_populates="face_images", primaryjoin="FaceImage.reg_no==Student.reg_no")


class AttendanceSession(Base):
    __tablename__ = "attendance_sessions"

    session_id = Column(Integer, primary_key=True, index=True)
    class_id = Column(String(10), ForeignKey("classes.class_id"), nullable=False)
    subject_code = Column(String(50), ForeignKey("subjects.subject_code"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("teachers.teacher_id"), nullable=False)
    date = Column(Date, nullable=False)
    period = Column(Integer, nullable=False)  # 1..7

    class_ = relationship("Class", back_populates="sessions")
    subject = relationship("Subject", back_populates="sessions")
    teacher = relationship("Teacher", back_populates="sessions")
    records = relationship("AttendanceRecord", back_populates="session")

    __table_args__ = (
        UniqueConstraint(
            "class_id",
            "subject_code",
            "teacher_id",
            "date",
            "period",
            name="uq_attendance_session_per_slot",
        ),
    )


class AttendanceRecord(Base):
    __tablename__ = "attendance_records"

    attendance_id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("attendance_sessions.session_id"), nullable=False)
    reg_no = Column(String(50), ForeignKey("students.reg_no"), nullable=False)
    status = Column(String(2), nullable=False)  # "P", "A", "NT"

    session = relationship("AttendanceSession", back_populates="records")
    student = relationship("Student", back_populates="attendance_records", primaryjoin="AttendanceRecord.reg_no==Student.reg_no")

    __table_args__ = (
        UniqueConstraint("session_id", "reg_no", name="uq_attendance_per_student_per_session"),
    )


class LeaveRequest(Base):
    __tablename__ = "leave_requests"

    request_id = Column(Integer, primary_key=True, index=True)
    student_reg_no = Column(String(50), ForeignKey("students.reg_no"), nullable=False)
    request_type = Column(String(10), nullable=False)  # "OD", "ML"
    from_date = Column(Date, nullable=False)
    to_date = Column(Date, nullable=False)
    periods = Column(String(20), nullable=False)  # "1,2,3" or "All"
    reason = Column(String(255), nullable=True)
    proof_file_path = Column(Text, nullable=True)
    created_at = Column(Date, nullable=False)  # Simplification: just date for now

    student = relationship("Student")
    approvals = relationship("LeaveRequestApproval", back_populates="request")


class LeaveRequestApproval(Base):
    __tablename__ = "leave_request_approvals"

    approval_id = Column(Integer, primary_key=True, index=True)
    request_id = Column(Integer, ForeignKey("leave_requests.request_id"), nullable=False)
    session_id = Column(Integer, ForeignKey("attendance_sessions.session_id"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("teachers.teacher_id"), nullable=False)
    status = Column(String(20), default="Pending")  # "Pending", "Approved", "Rejected"

    request = relationship("LeaveRequest", back_populates="approvals")
    session = relationship("AttendanceSession")
    teacher = relationship("Teacher")

    __table_args__ = (
        UniqueConstraint("request_id", "session_id", name="uq_approval_per_request_session"),
    )


class Timetable(Base):
    __tablename__ = "timetables"

    timetable_id = Column(Integer, primary_key=True, index=True)
    day = Column(String(10), nullable=False) # "Mon", "Tue", etc.
    period = Column(Integer, nullable=False) # 1-7
    class_id = Column(String(10), ForeignKey("classes.class_id"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("teachers.teacher_id"), nullable=False)
    subject_code = Column(String(20), ForeignKey("subjects.subject_code"), nullable=False)

    class_ = relationship("Class")
    teacher = relationship("Teacher")
    subject = relationship("Subject")

    __table_args__ = (
        UniqueConstraint("class_id", "day", "period", name="uq_timetable_class_slot"),
        UniqueConstraint("teacher_id", "day", "period", name="uq_timetable_teacher_slot"),
    )


class EBook(Base):
    __tablename__ = "ebooks"

    material_id = Column(Integer, primary_key=True, index=True)
    subject_code = Column(String(20), ForeignKey("subjects.subject_code"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("teachers.teacher_id"), nullable=False)
    title = Column(String(255), nullable=False)
    file_path = Column(Text, nullable=False)
    file_type = Column(String(50), nullable=False) # "pdf", "image", etc.
    uploaded_at = Column(Date, nullable=False)

    subject = relationship("Subject")
    teacher = relationship("Teacher")


class Task(Base):
    __tablename__ = "tasks"

    task_id = Column(Integer, primary_key=True, index=True)
    teacher_id = Column(Integer, ForeignKey("teachers.teacher_id"), nullable=False)
    class_id = Column(String(10), ForeignKey("classes.class_id"), nullable=False)
    subject_code = Column(String(20), ForeignKey("subjects.subject_code"), nullable=False)
    
    type = Column(String(50), nullable=False) # "Daily", "Assignment"
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    deadline = Column(DateTime, nullable=True)
    max_marks = Column(Integer, nullable=False, default=10)
    file_path = Column(Text, nullable=True) # Attachment
    created_at = Column(DateTime, nullable=False)

    teacher = relationship("Teacher")
    class_ = relationship("Class")
    subject = relationship("Subject")
    submissions = relationship("Submission", back_populates="task")


class Submission(Base):
    __tablename__ = "submissions"

    submission_id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.task_id"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.student_id"), nullable=False)
    
    file_path = Column(Text, nullable=True) # Submission file
    submitted_at = Column(DateTime, nullable=False)
    status = Column(String(50), nullable=False, default="Submitted") # "Submitted", "Late", "Graded"
    marks_obtained = Column(Float, nullable=True)
    remarks = Column(Text, nullable=True)

    task = relationship("Task", back_populates="submissions")
    student = relationship("Student")


class SubjectGradingConfig(Base):
    __tablename__ = "subject_grading_configs"

    config_id = Column(Integer, primary_key=True, index=True)
    subject_code = Column(String(20), ForeignKey("subjects.subject_code"), unique=True, nullable=False)
    
    internal_weight = Column(Integer, default=40) # 40 or 50
    external_weight = Column(Integer, default=60) # 60 or 50
    has_lab = Column(Boolean, default=False)
    is_pure_practical = Column(Boolean, default=False)
    
    # Optional customizable counts if needed later, hardcoded for now in logic
    cia_count = Column(Integer, default=2)
    assignment_count = Column(Integer, default=2)

    subject = relationship("Subject")


class MarkEntry(Base):
    __tablename__ = "mark_entries"

    mark_id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.student_id"), nullable=False)
    subject_code = Column(String(20), ForeignKey("subjects.subject_code"), nullable=False)
    
    cia1_score = Column(Float, nullable=True)
    cia2_score = Column(Float, nullable=True)
    assign1_score = Column(Float, nullable=True)
    assign2_score = Column(Float, nullable=True)
    
    lab_internal_score = Column(Float, nullable=True) # For 50/50 subjects or Pure Practical
    lab_external_score = Column(Float, nullable=True) # For Pure Practical
    
    final_exam_score = Column(Float, nullable=True) # The 100 mark external exam
    
    # Calculated fields (stored for easy retrieval, updated on entry)
    total_internal = Column(Float, nullable=True)
    total_external = Column(Float, nullable=True)
    grand_total = Column(Float, nullable=True)
    grade = Column(String(5), nullable=True)
    status = Column(String(20), nullable=True) # Pass, Fail, Absent

    student = relationship("Student")
    subject = relationship("Subject")
