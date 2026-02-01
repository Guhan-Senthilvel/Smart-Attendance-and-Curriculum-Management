from backend.database import SessionLocal
from backend.models import SubjectGradingConfig

def check_configs():
    db = SessionLocal()
    try:
        configs = db.query(SubjectGradingConfig).all()
        print(f"Total Configs in DB: {len(configs)}")
        for c in configs:
            print(f" - {c.subject_code}: Int={c.internal_weight}, Ext={c.external_weight}, Lab={c.has_lab}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    check_configs()
