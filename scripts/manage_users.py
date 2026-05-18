import argparse

from sqlalchemy import text

from db.db import get_engine


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


def main():
    parser = argparse.ArgumentParser(description="Manage users.")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="List all users")

    deactivate = sub.add_parser("deactivate", help="Deactivate a user")
    deactivate.add_argument("--username", required=True)

    activate = sub.add_parser("activate", help="Activate a user")
    activate.add_argument("--username", required=True)

    promote = sub.add_parser("promote", help="Grant admin to a user")
    promote.add_argument("--username", required=True)

    demote = sub.add_parser("demote", help="Revoke admin from a user")
    demote.add_argument("--username", required=True)

    args = parser.parse_args()

    if args.command == "list":
        list_users()
    elif args.command == "deactivate":
        set_active(args.username, False)
    elif args.command == "activate":
        set_active(args.username, True)
    elif args.command == "promote":
        set_admin(args.username, True)
    elif args.command == "demote":
        set_admin(args.username, False)


if __name__ == "__main__":
    main()
