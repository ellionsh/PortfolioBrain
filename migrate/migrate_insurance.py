# migrate/migrate_insurance.py
import pandas as pd
from migrate.mapping import normalize_columns

def migrate_insurance(conn, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    cur = conn.cursor()

    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO insurance_products (
                account_id, product_name, company, type,
                currency, premium, premium_freq, premium_years,
                coverage_amount, start_date, end_date, status
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'active')
        """, (
            row.get("account_id"),
            row.get("product_name"),
            row.get("company"),
            row.get("type"),
            row.get("currency", "CNY"),
            row.get("premium"),
            row.get("premium_freq"),
            row.get("premium_years"),
            row.get("coverage_amount"),
            row.get("start_date"),
            row.get("end_date"),
        ))

    conn.commit()
    return {"status": "success", "rows": len(df)}
