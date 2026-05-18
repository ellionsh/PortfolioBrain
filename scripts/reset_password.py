import argparse
import getpass

from sqlalchemy import text
from werkzeug.security import generate_password_hash

from db.db import get_engine


def reset_password(username: str, new_password: str):
    engine = get_engine()
    password_hash = generate_password_hash(new_password)
    with engine.begin() as conn:
        result = conn.execute(
            text(
                "UPDATE users SET password_hash = :password_hash "
                "WHERE username = :username"
            ),
            {"username": username, "password_hash": password_hash},
        )
    if result.rowcount == 0:
        raise SystemExit("User not found.")
    print("Password updated.")


def main():
    parser = argparse.ArgumentParser(description="Reset user password.")
    parser.add_argument("--username", required=True, help="Username")
    parser.add_argument("--password", help="New password (omit to prompt)")
    args = parser.parse_args()

    password = args.password or getpass.getpass("New password: ")
    if len(password) < 6:
        raise SystemExit("Password must be at least 6 characters.")

    reset_password(args.username.strip(), password)


if __name__ == "__main__":
    main()
