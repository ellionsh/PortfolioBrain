# services/fund_nav_updater.py
import akshare as ak
from db.db import get_session
from sqlalchemy import text

class FundNavUpdater:

    @staticmethod
    def update_all_funds():
        """读取 fund_navs 表中的基金代码并更新所有记录（不新增）"""
        session = get_session()

        try:
            # 1. 获取所有基金代码（distinct）
            rows = session.execute(
                text("SELECT DISTINCT fund_code FROM fund_navs")
            ).fetchall()

            codes = [row[0] for row in rows]
            print(f"发现基金代码: {codes}")

            for code in codes:
                FundNavUpdater.update_single_fund(session, code)

            session.commit()

        except Exception as e:
            session.rollback()
            raise e

        finally:
            session.close()

    @staticmethod
    def update_single_fund(session, code: str):
        """更新某基金代码的所有记录（不新增）"""
        print(f"更新基金 {code} ...")

        # 2. 获取最新净值
        df = ak.fund_open_fund_info_em(symbol=code, indicator="单位净值走势")
        latest = df.iloc[-1]

        new_date = latest["净值日期"]
        new_nav = float(latest["单位净值"])

        # 3. 更新所有记录（不新增）
        result = session.execute(
            text("""
                UPDATE fund_navs
                SET date = :date, nav = :nav
                WHERE fund_code = :code
            """),
            {"date": new_date, "nav": new_nav, "code": code}
        )

        print(f"✔ 更新成功：{code} → {result.rowcount} 条记录已更新为 日期={new_date} NAV={new_nav}")

