from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


from backend import models  # noqa: F401
from backend.database import engine
from backend.routers import api_router


models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Smart Attendance Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api")




@app.get("/")
def root():
    return {"status": "OK", "message": "Smart Attendance Backend running"}

