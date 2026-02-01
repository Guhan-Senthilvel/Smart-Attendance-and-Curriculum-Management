from fastapi import APIRouter

from backend.routers import auth, admin, attendance, student, teacher, ebook, tasks, marks, profiles

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(attendance.router, prefix="/attendance", tags=["attendance"])
api_router.include_router(student.router, prefix="/student", tags=["student"])
api_router.include_router(teacher.router, prefix="/teacher", tags=["teacher"])
api_router.include_router(ebook.router, prefix="/ebook", tags=["ebook"])
api_router.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
api_router.include_router(marks.router, prefix="/marks", tags=["marks"])
api_router.include_router(profiles.router, prefix="/profiles", tags=["profiles"])
