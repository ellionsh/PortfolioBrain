import argparse
import getpass

from sqlalchemy import text
from werkzeug.security import generate_password_hash

from db.db import get_engine


def create_admin(username: str, password: str):
    engine = get_engine()
    password_hash = generate_password_hash(password)
    with engine.begin() as conn:
        exists = conn.execute(
            text("SELECT 1 FROM users WHERE username = :username LIMIT 1"),
            {"username": username},
        ).first()
        if exists:
            return False
        conn.execute(
            text(
                "INSERT INTO users (username, password_hash, is_active, is_admin) "
                "VALUES (:username, :password_hash, 1, 1)"
            ),
            {"username": username, "password_hash": password_hash},
        )
    return True


def main():
    parser = argparse.ArgumentParser(description="Create an admin user.")
    parser.add_argument("--username", required=True, help="Admin username")
    parser.add_argument("--password", help="Admin password (omit to prompt)")
    args = parser.parse_args()

    password = args.password or getpass.getpass("Admin password: ")
    if len(password) < 6:
        raise SystemExit("Password must be at least 6 characters.")

    ok = create_admin(args.username.strip(), password)
    if not ok:
        raise SystemExit("User already exists.")
    print("Admin user created.")


if __name__ == "__main__":
    main()
