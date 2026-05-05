import pandas as pd

class SQLSkill:
    def __init__(self, conn):
        self.conn = conn

    def run_sql(self, query: str):
        if not query.strip().lower().startswith("select"):
            return {"error": "只允许执行 SELECT 查询"}
        df = pd.read_sql(query, self.conn)
        return df.to_dict(orient="records")
