import datetime
import logging
from functools import wraps

import jwt as _jwt
from flask import request, jsonify, g
from sqlalchemy import text
from werkzeug.security import generate_password_hash, check_password_hash

import config
from db.db import get_engine

logger = logging.getLogger(__name__)


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
    if config.REQUIRE_AUTH:
        algo = (config.AUTH_ALGORITHM or "").upper()
        if algo.startswith("HS") and len(config.AUTH_SECRET) < 32:
            raise RuntimeError(
                "PB_AUTH_SECRET is too short for HMAC. "
                "Use at least 32 characters for HS* algorithms."
            )


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


def _token_preview(token: str | None) -> str:
    if not token:
        return ""
    if len(token) <= 12:
        return token
    return f"{token[:8]}...{token[-4:]}"


def _safe_len(value: str | None) -> int:
    return len(value) if value else 0


def auth_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not config.REQUIRE_AUTH:
            return fn(*args, **kwargs)

        _require_secret()
        jwt = _get_jwt()
        auth_header = request.headers.get("Authorization", "")
        token = _parse_bearer_token()
        if not token:
            logger.warning(
                "Auth missing token path=%s auth_header=%s",
                request.path,
                auth_header,
            )
            return jsonify({"error": "缺少认证令牌"}), 401
        try:
            payload = jwt.decode(
                token,
                config.AUTH_SECRET,
                algorithms=[config.AUTH_ALGORITHM],
            )
            token_type = payload.get("type")
            if token_type and token_type != "access":
                raise jwt.InvalidTokenError("Invalid token type")
        except jwt.ExpiredSignatureError:
            logger.warning(
                "Auth token expired path=%s token=%s",
                request.path,
                _token_preview(token),
            )
            return jsonify({"error": "认证令牌已过期"}), 401
        except jwt.InvalidTokenError as exc:
            logger.warning(
                "Auth token invalid path=%s token=%s alg=%s auth_len=%s token_len=%s err=%s",
                request.path,
                _token_preview(token),
                config.AUTH_ALGORITHM,
                _safe_len(auth_header),
                _safe_len(token),
                f"{exc.__class__.__name__}: {exc}",
            )
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


def get_user_by_id(user_id: str | int):
    engine = _get_engine()
    with engine.begin() as conn:
        row = conn.execute(
            text(
                "SELECT id, username, is_active "
                "FROM users WHERE id = :id LIMIT 1"
            ),
            {"id": user_id},
        ).mappings().first()
    if not row or not row.get("is_active"):
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
        "sub": str(user["id"]),
        "username": user["username"],
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "type": "access",
    }
    return jwt.encode(payload, config.AUTH_SECRET, algorithm=config.AUTH_ALGORITHM)


def issue_refresh_token(user):
    _require_secret()
    jwt = _get_jwt()
    now = datetime.datetime.utcnow()
    exp = now + datetime.timedelta(days=config.AUTH_REFRESH_EXPIRES_DAYS)
    payload = {
        "sub": str(user["id"]),
        "username": user["username"],
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "type": "refresh",
    }
    return jwt.encode(payload, config.AUTH_SECRET, algorithm=config.AUTH_ALGORITHM)
