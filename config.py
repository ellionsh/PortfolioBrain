# config.py
import os
from dotenv import load_dotenv

# 自动加载 .env 文件
load_dotenv()

# ============================
# Database Configuration
# ============================
DB_HOST = os.getenv("PB_DB_HOST", "localhost")
DB_PORT = os.getenv("PB_DB_PORT", "3306")
DB_USER = os.getenv("PB_DB_USER", "investment")
DB_PASS = os.getenv("PB_DB_PASS", "")
DB_NAME = os.getenv("PB_DB_NAME", "portfolio")

# ============================
# DeepSeek API Configuration
# ============================
DEEPSEEK_API_KEY = os.getenv("PB_DEEPSEEK_API_KEY", "")
DEEPSEEK_BASE_URL = os.getenv("PB_DEEPSEEK_BASE_URL", "https://api.deepseek.com")
DEEPSEEK_MODEL = os.getenv("PB_DEEPSEEK_MODEL", "deepseek-v4-flash")

# ============================
# Web Server Configuration
# ============================
API_HOST = os.getenv("PB_API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("PB_API_PORT", "5000"))
DEBUG = os.getenv("PB_DEBUG", "true").lower() == "true"

# ============================
# Auth Configuration
# ============================
REQUIRE_AUTH = os.getenv("PB_REQUIRE_AUTH", "true").lower() == "true"
ALLOW_REGISTER = os.getenv("PB_ALLOW_REGISTER", "false").lower() == "true"
AUTH_SECRET = os.getenv("PB_AUTH_SECRET", "")
AUTH_ALGORITHM = os.getenv("PB_AUTH_ALGORITHM", "HS256")
AUTH_EXPIRES_MINUTES = int(os.getenv("PB_AUTH_EXPIRES_MINUTES", "720"))
AUTH_REFRESH_EXPIRES_DAYS = int(os.getenv("PB_AUTH_REFRESH_EXPIRES_DAYS", "30"))

# ============================
# Task Configuration
# ============================
FUND_NAV_RETRY_ATTEMPTS = int(os.getenv("PB_FUND_NAV_RETRY_ATTEMPTS", "3"))
FUND_NAV_RETRY_BASE_SECONDS = float(os.getenv("PB_FUND_NAV_RETRY_BASE_SECONDS", "2"))
