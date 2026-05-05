# config.py
import os

# ============================
# Database Configuration
# ============================
DB_HOST = os.getenv("PB_DB_HOST", "localhost")
DB_PORT = os.getenv("PB_DB_PORT", "3306")
DB_USER = os.getenv("PB_DB_USER", "your_username_here")
DB_PASS = os.getenv("PB_DB_PASS", "your_password_here")
DB_NAME = os.getenv("PB_DB_NAME", "portfolio")

# ============================
# DeepSeek API Configuration
# ============================
DEEPSEEK_API_KEY = os.getenv("PB_DEEPSEEK_API_KEY", "your_deepseek_api_key_here")
DEEPSEEK_BASE_URL = os.getenv("PB_DEEPSEEK_BASE_URL", "https://api.deepseek.com")

# ============================
# Web Server Configuration
# ============================
API_HOST = os.getenv("PB_API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("PB_API_PORT", "5000"))

# ============================
# Other Settings
# ============================
DEBUG = os.getenv("PB_DEBUG", "true").lower() == "true"

