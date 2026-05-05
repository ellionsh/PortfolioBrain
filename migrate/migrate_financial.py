# migrate/migrate_financial.py
import pandas as pd
from migrate.mapping import normalize_columns

def migrate_financial_products(conn, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    cur = conn.cursor()

    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO financial_products (
                account_id, product_name, product_code, type,
                currency, is_nav_based, principal, expected_yield,
                start_date, end_date, status
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'active')
        """, (
            row.get("account_id"),
            row.get("product_name"),
            row.get("product_code"),
            row.get("type", "nav"),
            row.get("currency", "CNY"),
            1 if row.get("type") == "nav" else 0,
            row.get("principal"),
            row.get("expected_yield"),
            row.get("start_date"),
            row.get("end_date"),
        ))

    conn.commit()
    return {"status": "success", "rows": len(df)}


def migrate_financial_transactions(conn, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    cur = conn.cursor()

    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO financial_transactions (
                product_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, 'CNY')
        """, (
            row.get("product_id"),
            row.get("account_id"),
            row.get("trade_date"),
            row.get("trade_type"),
            row.get("shares"),
            row.get("amount"),
            row.get("nav"),
        ))

    conn.commit()
    return {"status": "success", "rows": len(df)}
