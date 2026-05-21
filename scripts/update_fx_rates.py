# scripts/update_fx_rates.py
from db.db import session_scope
from tasks.job_update_fx_rates import update_fx_rates


def main():
    print("开始手动更新汇率...")
    with session_scope() as session:
        result = update_fx_rates(session)
    print(result)


if __name__ == "__main__":
    main()
