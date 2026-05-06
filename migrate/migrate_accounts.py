# migrate/migrate_accounts.py
import pandas as pd
from migrate.mapping import normalize_columns

def migrate_accounts(engine, path):
    df = pd.read_excel(path)
    df = normalize_columns(df)

    required_cols = [
        "name",
        "type",
        "currency",
        "institution",
        "created_at"
    ]
    df = df[required_cols]

    df.to_sql(
        "accounts",
        engine,
        if_exists="append",
        index=False
    )

    return {"status": "success", "rows": len(df)}
