from sqlalchemy.orm import Session
from backend.database import SessionLocal, engine
from backend.models import MarkEntry

def clear_marks():
    db = SessionLocal()
    try:
        num_deleted = db.query(MarkEntry).delete()
        db.commit()
        print(f"Successfully deleted {num_deleted} mark entries.")
    except Exception as e:
        print(f"Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    clear_marks()
