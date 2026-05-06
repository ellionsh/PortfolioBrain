# skills/sql_skill.py
import pandas as pd
from db.db import get_engine

class SQLSkill:
    def __init__(self):
        # 统一使用全局 SQLAlchemy engine
        self.engine = get_engine()

    def run_sql(self, query: str):
        # 安全限制：只允许 SELECT
        if not query.strip().lower().startswith("select"):
            return {"error": "只允许执行 SELECT 查询"}

        try:
            df = pd.read_sql(query, self.engine)
            return df.to_dict(orient="records")
        except Exception as e:
            return {"error": str(e)}
