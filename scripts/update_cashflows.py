#!/usr/bin/env python3
import argparse
from db.db import session_scope
from core.cashflow_engine import CashflowEngine


def main():
    parser = argparse.ArgumentParser(description="手动更新现金流")
    parser.add_argument(
        "--silent",
        action="store_true",
        help="不输出结果"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只模拟生成，不写入数据库"
    )
    args = parser.parse_args()

    with session_scope() as session:
        engine = CashflowEngine(session)
        result = engine.generate_all(dry_run=args.dry_run)
        if not args.silent:
            print(result)


if __name__ == "__main__":
    main()
