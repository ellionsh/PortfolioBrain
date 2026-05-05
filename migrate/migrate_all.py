# migrate/migrate_all.py
import os
from db.db import get_conn
from migrate.migrate_bank import migrate_bank
from migrate.migrate_financial import migrate_financial_products, migrate_financial_transactions
from migrate.migrate_insurance import migrate_insurance

DATA_DIR = "data"

def migrate_all():
    conn = get_conn()

    results = {}

    for file in os.listdir(DATA_DIR):
        path = os.path.join(DATA_DIR, file)

        if file.startswith("bank_"):
            results[file] = migrate_bank(conn, path)

        elif file.startswith("financial_products_"):
            results[file] = migrate_financial_products(conn, path)

        elif file.startswith("financial_transactions_"):
            results[file] = migrate_financial_transactions(conn, path)

        elif file.startswith("insurance_"):
            results[file] = migrate_insurance(conn, path)

    return results


if __name__ == "__main__":
    print("开始迁移 Excel 数据...")
    res = migrate_all()
    print("迁移完成：")
    print(res)
