import datetime
from functools import wraps

import jwt as _jwt
from flask import request, jsonify, g
from sqlalchemy import text
from werkzeug.security import generate_password_hash, check_password_hash

import config
from db.db import get_engine


def _get_jwt():
    if not hasattr(_jwt, "encode") or not hasattr(_jwt, "decode"):
        raise RuntimeError(
            "PyJWT is required for auth tokens. "
            "The installed 'jwt' package does not provide encode/decode. "
            "Uninstall 'jwt' and install 'PyJWT'."
        )
    return _jwt


def _require_secret():
    if config.REQUIRE_AUTH and not config.AUTH_SECRET:
        raise RuntimeError("PB_AUTH_SECRET is required when PB_REQUIRE_AUTH=true")


def ensure_auth_ready():
    if not config.REQUIRE_AUTH:
        return
    _require_secret()
    _get_jwt()


def _get_engine():
    return get_engine()


def _parse_bearer_token():
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None
    return auth_header.split(" ", 1)[1].strip()


def auth_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not config.REQUIRE_AUTH:
            return fn(*args, **kwargs)

        _require_secret()
        jwt = _get_jwt()
        token = _parse_bearer_token()
        if not token:
            return jsonify({"error": "缺少认证令牌"}), 401
        try:
            payload = jwt.decode(
                token,
                config.AUTH_SECRET,
                algorithms=[config.AUTH_ALGORITHM],
            )
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "认证令牌已过期"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "认证令牌无效"}), 401

        g.current_user = {
            "id": payload.get("sub"),
            "username": payload.get("username"),
        }
        return fn(*args, **kwargs)

    return wrapper


def authenticate_user(username: str, password: str):
    engine = _get_engine()
    with engine.begin() as conn:
        row = conn.execute(
            text(
                "SELECT id, username, password_hash, is_active "
                "FROM users WHERE username = :username LIMIT 1"
            ),
            {"username": username},
        ).mappings().first()

    if not row or not row.get("is_active"):
        return None
    if not check_password_hash(row["password_hash"], password):
        return None
    return {"id": row["id"], "username": row["username"]}


def create_user(username: str, password: str):
    engine = _get_engine()
    password_hash = generate_password_hash(password)
    with engine.begin() as conn:
        exists = conn.execute(
            text("SELECT 1 FROM users WHERE username = :username LIMIT 1"),
            {"username": username},
        ).first()
        if exists:
            return None
        conn.execute(
            text(
                "INSERT INTO users (username, password_hash, is_active, is_admin) "
                "VALUES (:username, :password_hash, 1, 0)"
            ),
            {"username": username, "password_hash": password_hash},
        )
        row = conn.execute(
            text(
                "SELECT id, username FROM users WHERE username = :username LIMIT 1"
            ),
            {"username": username},
        ).mappings().first()
    return {"id": row["id"], "username": row["username"]}


def issue_token(user):
    _require_secret()
    jwt = _get_jwt()
    now = datetime.datetime.utcnow()
    exp = now + datetime.timedelta(minutes=config.AUTH_EXPIRES_MINUTES)
    payload = {
        "sub": user["id"],
        "username": user["username"],
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
    }
    return jwt.encode(payload, config.AUTH_SECRET, algorithm=config.AUTH_ALGORITHM)
