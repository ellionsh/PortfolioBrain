# migrate/migrate_all.py
import os
from migrate.migrate_bank import migrate_bank
from migrate.migrate_financial import (
    migrate_financial_products,
    migrate_financial_transactions,
    migrate_financial_navs
)
from migrate.migrate_insurance import migrate_insurance
from migrate.migrate_fund import (
    migrate_fund_products,
    migrate_fund_transactions,
    migrate_fund_navs
)

DATA_DIR = "data"

def migrate_all(engine):
    results = {}

    for file in os.listdir(DATA_DIR):
        path = os.path.join(DATA_DIR, file)

        # ============================
        # 银行存款
        # ============================
        if file.startswith("bank_"):
            results[file] = migrate_bank(engine, path)

        # ============================
        # 理财产品
        # ============================
        elif file.startswith("financial_products_"):
            results[file] = migrate_financial_products(engine, path)

        elif file.startswith("financial_transactions_"):
            results[file] = migrate_financial_transactions(engine, path)
        elif file.startswith("financial_navs_"):
            results[file] = migrate_financial_navs(engine, path)

        # ============================
        # 保险产品
        # ============================
        elif file.startswith("insurance_"):
            results[file] = migrate_insurance(engine, path)

        # ============================
        # 基金产品
        # ============================
        elif file.startswith("fund_products_"):
            results[file] = migrate_fund_products(engine, path)

        elif file.startswith("fund_transactions_"):
            results[file] = migrate_fund_transactions(engine, path)

        elif file.startswith("fund_navs_"):
            results[file] = migrate_fund_navs(engine, path)

    return results


if __name__ == "__main__":
    from db.db import get_engine
    engine = get_engine()

    print("开始迁移 Excel 数据...")
    res = migrate_all(engine)
    print("迁移完成：")
    print(res)
