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
            raise SystemExit("User already exists.")
        conn.execute(
            text(
                "INSERT INTO users (username, password_hash, is_active, is_admin) "
                "VALUES (:username, :password_hash, 1, 1)"
            ),
            {"username": username, "password_hash": password_hash},
        )
    print("Admin user created.")


def list_users():
    engine = get_engine()
    with engine.begin() as conn:
        rows = conn.execute(
            text(
                "SELECT id, username, is_admin, is_active, created_at "
                "FROM users ORDER BY id"
            )
        ).mappings().all()
    if not rows:
        print("No users found.")
        return
    for row in rows:
        print(
            f"id={row['id']} username={row['username']} "
            f"admin={int(row['is_admin'])} active={int(row['is_active'])} "
            f"created_at={row['created_at']}"
        )


def set_active(username: str, is_active: bool):
    engine = get_engine()
    with engine.begin() as conn:
        result = conn.execute(
            text(
                "UPDATE users SET is_active = :is_active "
                "WHERE username = :username"
            ),
            {"username": username, "is_active": 1 if is_active else 0},
        )
    if result.rowcount == 0:
        raise SystemExit("User not found.")
    print("User updated.")


def set_admin(username: str, is_admin: bool):
    engine = get_engine()
    with engine.begin() as conn:
        result = conn.execute(
            text(
                "UPDATE users SET is_admin = :is_admin "
                "WHERE username = :username"
            ),
            {"username": username, "is_admin": 1 if is_admin else 0},
        )
    if result.rowcount == 0:
        raise SystemExit("User not found.")
    print("User updated.")


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


def _prompt_password(label: str):
    password = getpass.getpass(label)
    if len(password) < 6:
        raise SystemExit("Password must be at least 6 characters.")
    return password


def main():
    parser = argparse.ArgumentParser(description="Admin CLI for users.")
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("create-admin", help="Create an admin user")
    create.add_argument("--username", required=True)
    create.add_argument("--password", help="Admin password (omit to prompt)")

    sub.add_parser("list", help="List all users")

    deactivate = sub.add_parser("deactivate", help="Deactivate a user")
    deactivate.add_argument("--username", required=True)

    activate = sub.add_parser("activate", help="Activate a user")
    activate.add_argument("--username", required=True)

    promote = sub.add_parser("promote", help="Grant admin to a user")
    promote.add_argument("--username", required=True)

    demote = sub.add_parser("demote", help="Revoke admin from a user")
    demote.add_argument("--username", required=True)

    reset = sub.add_parser("reset-password", help="Reset a user's password")
    reset.add_argument("--username", required=True)
    reset.add_argument("--password", help="New password (omit to prompt)")

    args = parser.parse_args()

    if args.command == "create-admin":
        password = args.password or _prompt_password("Admin password: ")
        create_admin(args.username.strip(), password)
    elif args.command == "list":
        list_users()
    elif args.command == "deactivate":
        set_active(args.username, False)
    elif args.command == "activate":
        set_active(args.username, True)
    elif args.command == "promote":
        set_admin(args.username, True)
    elif args.command == "demote":
        set_admin(args.username, False)
    elif args.command == "reset-password":
        password = args.password or _prompt_password("New password: ")
        reset_password(args.username.strip(), password)


if __name__ == "__main__":
    main()
