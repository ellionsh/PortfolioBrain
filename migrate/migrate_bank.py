# migrate/migrate_bank.py
import pandas as pd
from migrate.mapping import normalize_columns

def migrate_bank(conn, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    cur = conn.cursor()

    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO bank_deposits (
                account_id, deposit_type, currency, principal,
                interest_rate, start_date, end_date, status
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, 'active')
        """, (
            row.get("account_id"),
            row.get("deposit_type", "fixed"),
            row.get("currency", "CNY"),
            row.get("principal"),
            row.get("interest_rate"),
            row.get("start_date"),
            row.get("end_date"),
        ))

    conn.commit()
    return {"status": "success", "rows": len(df)}
