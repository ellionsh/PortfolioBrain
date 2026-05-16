# migrate/migrate_financial.py
import pandas as pd
from migrate.mapping import normalize_columns

# ============================================
# 迁移 financial_products（理财产品主数据）
# ============================================
def migrate_financial_products(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    # 默认值处理
    df["type"] = df.get("type", "nav")
    df["currency"] = df.get("currency", "CNY")
    df["is_nav_based"] = df["type"].apply(lambda x: 1 if x == "nav" else 0)
    df["status"] = "active"

    # shares 字段（新增）
    df["shares"] = df.get("shares", 0)

    required_cols = [
        "account_id",
        "product_name",
        "product_code",
        "type",
        "currency",
        "is_nav_based",
        "principal",
        "shares",              # 新增字段
        "expected_yield",
        "start_date",
        "end_date",
        "status"
    ]

    # 缺失字段补齐
    for col in required_cols:
        if col not in df.columns:
            df[col] = None

    df = df[required_cols]

    df.to_sql(
        "financial_products",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}


# ============================================
# 迁移 financial_transactions（理财交易记录）
# ============================================
def migrate_financial_transactions(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

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

    for col in required_cols:
        if col not in df.columns:
            df[col] = None

    df = df[required_cols]

    df.to_sql(
        "financial_transactions",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}


# ============================================
# 迁移 financial_navs（理财净值）
# ============================================
def migrate_financial_navs(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    df["currency"] = df.get("currency", "CNY")

    required_cols = [
        "product_code",
        "date",
        "nav",
        "currency"
    ]

    for col in required_cols:
        if col not in df.columns:
            df[col] = None

    df = df[required_cols]

    df.to_sql(
        "financial_navs",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}
