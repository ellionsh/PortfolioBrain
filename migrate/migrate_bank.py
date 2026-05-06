# migrate/migrate_bank.py
import pandas as pd
from migrate.mapping import normalize_columns

def migrate_bank(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    # 默认值处理
    df["deposit_type"] = df.get("deposit_type", "fixed")
    df["currency"] = df.get("currency", "CNY")
    df["status"] = "active"

    # 只保留数据库需要的字段
    required_cols = [
        "account_id",
        "deposit_type",
        "currency",
        "principal",
        "interest_rate",
        "start_date",
        "end_date",
        "status"
    ]
    df = df[required_cols]

    # 批量写入 MySQL（SQLAlchemy + pandas）
    df.to_sql(
        "bank_deposits",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}

