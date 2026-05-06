# migrate/migrate_insurance.py
import pandas as pd
from migrate.mapping import normalize_columns

def migrate_insurance(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    # 默认值处理
    df["currency"] = df.get("currency", "CNY")
    df["status"] = "active"

    # 只保留数据库需要的字段
    required_cols = [
        "account_id",
        "product_name",
        "company",
        "type",
        "currency",
        "premium",
        "premium_freq",
        "premium_years",
        "coverage_amount",
        "start_date",
        "end_date",
        "status"
    ]
    df = df[required_cols]

    # 批量写入 MySQL（SQLAlchemy + pandas）
    df.to_sql(
        "insurance_products",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}

