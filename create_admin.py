from sqlalchemy.orm import Session
from backend.database import SessionLocal, engine
from backend.models import User, Base
from backend.routers.auth import get_password_hash
import sys

def create_admin(email, password):
    db = SessionLocal()
    try:
        # Check if admin exists
        existing_user = db.query(User).filter(User.email == email).first()
        if existing_user:
            print(f"User {email} already exists.")
            return

        # Create admin user
        admin_user = User(
            email=email,
            password=get_password_hash(password),
            role="admin",
            status="active"
        )
        db.add(admin_user)
        db.commit()
        print(f"Admin user created successfully!")
        print(f"Email: {email}")
        print(f"Password: {password}")
        
    except Exception as e:
        print(f"Error creating admin: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    if len(sys.argv) == 3:
        create_admin(sys.argv[1], sys.argv[2])
    else:
        # Default credentials
        create_admin("admin@admin.com", "admin123")
