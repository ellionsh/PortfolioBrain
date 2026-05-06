# migrate/migrate_financial.py
import pandas as pd
from migrate.mapping import normalize_columns

# ============================================
# 迁移 financial_products
# ============================================
def migrate_financial_products(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    # 默认值处理
    df["type"] = df.get("type", "nav")
    df["currency"] = df.get("currency", "CNY")
    df["is_nav_based"] = df["type"].apply(lambda x: 1 if x == "nav" else 0)
    df["status"] = "active"

    # 只保留数据库需要的字段
    required_cols = [
        "account_id",
        "product_name",
        "product_code",
        "type",
        "currency",
        "is_nav_based",
        "principal",
        "expected_yield",
        "start_date",
        "end_date",
        "status"
    ]
    df = df[required_cols]

    # 批量写入 MySQL
    df.to_sql(
        "financial_products",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}


# ============================================
# 迁移 financial_transactions
# ============================================
def migrate_financial_transactions(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    # 默认值处理
    df["currency"] = df.get("currency", "CNY")

    required_cols = [
        "product_id",
        "account_id",
        "trade_date",
        "trade_type",
        "shares",
        "amount",
        "nav",
        "currency"
    ]
    df = df[required_cols]

    df.to_sql(
        "financial_transactions",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}

