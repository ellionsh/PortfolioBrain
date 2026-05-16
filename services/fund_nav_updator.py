# services/fund_nav_updater.py
import akshare as ak
from db.session import SessionLocal
from sqlalchemy import select
from db.models import FundNav

class FundNavUpdater:

    @staticmethod
    def update_all_funds():
        """读取 fund_navs 表中的基金代码并更新所有记录（不新增）"""
        session = SessionLocal()

        try:
            # 1. 获取所有基金代码（distinct）
            stmt = select(FundNav.fund_code).distinct()
            codes = [row[0] for row in session.execute(stmt).all()]

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

        # 3. 找到该基金代码的所有记录
        stmt = select(FundNav).where(FundNav.fund_code == code)
        rows = session.execute(stmt).scalars().all()

        if not rows:
            print(f"⚠️ fund_navs 中没有基金 {code} 的记录，跳过")
            return

        # 4. 更新所有记录
        for row in rows:
            row.date = new_date
            row.nav = new_nav

        print(f"✔ 更新成功：{code} → {len(rows)} 条记录已更新为 日期={new_date} NAV={new_nav}")

