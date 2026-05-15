# migrate/migrate_fund.py
import pandas as pd
from migrate.mapping import normalize_columns

# ============================================
# 迁移 fund_products（基金主数据）
# ============================================
def migrate_fund_products(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    df["currency"] = df.get("currency", "CNY")
    df["status"] = "active"
    df["shares"] = df.get("shares", 0)
    df["principal"] = df.get("principal", 0)
    df["start_date"] = df.get("start_date", None)
    df["end_date"] = df.get("end_date", None)

    required_cols = [
        "account_id",
        "fund_name",
        "fund_code",
        "currency",
        "shares",
        "principal",
        "start_date",
        "end_date",
        "status",
        "remark"
    ]

    for col in required_cols:
        if col not in df.columns:
            df[col] = None

    df = df[required_cols]

    df.to_sql(
        "fund_products",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}


# ============================================
# 迁移 fund_transactions（基金交易记录）
# ============================================
def migrate_fund_transactions(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    df["currency"] = df.get("currency", "CNY")

    required_cols = [
        "fund_id",
        "account_id",
        "trade_date",
        "trade_type",
        "shares",
        "amount",
        "nav",
        "fee",
        "currency"
    ]

    for col in required_cols:
        if col not in df.columns:
            df[col] = None

    df = df[required_cols]

    df.to_sql(
        "fund_transactions",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}


# ============================================
# 迁移 fund_navs（基金净值）
# ============================================
def migrate_fund_navs(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    df["currency"] = df.get("currency", "CNY")

    required_cols = [
        "fund_id",
        "date",
        "nav",
        "currency"
    ]

    for col in required_cols:
        if col not in df.columns:
            df[col] = None

    df = df[required_cols]

    df.to_sql(
        "fund_navs",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}
