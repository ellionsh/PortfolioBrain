# db/db.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from contextlib import contextmanager
import config

DATABASE_URL = (
    f"mysql+pymysql://{config.DB_USER}:{config.DB_PASS}"
    f"@{config.DB_HOST}:{config.DB_PORT}/{config.DB_NAME}?charset=utf8mb4"
)

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=False
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def get_engine():
    return engine

def get_session():
    return SessionLocal()

@contextmanager
def session_scope():
    session = get_session()
    try:
        yield session
    finally:
        session.close()
