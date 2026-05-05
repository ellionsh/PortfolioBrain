# core/cashflow_engine.py
import datetime
from dateutil.relativedelta import relativedelta
import pymysql


class CashflowEngine:
    """
    PortfolioBrain 现金流引擎（Cashflow Engine）
    自动生成：
    - 银行存款利息 + 到期兑付
    - 固定收益理财付息 + 到期兑付
    - 净值型理财分红 + 赎回
    - 保险缴费
    """

    def __init__(self, conn: pymysql.connections.Connection):
        self.conn = conn
        self.cur = conn.cursor()

    # ============================
    # 主入口
    # ============================
    def generate_all(self):
        self.generate_bank_deposit()
        self.generate_fixed_financial()
        self.generate_nav_financial()
        self.generate_insurance()
        self.conn.commit()
        return {"status": "success"}

    # ============================
    # 1. 银行存款现金流
    # ============================
    def generate_bank_deposit(self):
        self.cur.execute("""
            SELECT id, account_id, principal, interest_rate,
                   start_date, end_date, deposit_type
            FROM bank_deposits
            WHERE status='active'
        """)
        rows = self.cur.fetchall()

        for r in rows:
            deposit_id, account_id, principal, rate, start, end, dtype = r

            if dtype == "demand":
                continue  # 活期不生成现金流

            days = (end - start).days
            interest = principal * rate * days / 365

            # 幂等：检查是否已生成
            self.cur.execute("""
                SELECT COUNT(*) FROM cashflows
                WHERE source_type='bank'
                AND source_id=%s
                AND date=%s
            """, (deposit_id, end))
            if self.cur.fetchone()[0] > 0:
                continue

            # 到期兑付（本金 + 利息）
            self.cur.execute("""
                INSERT INTO cashflows (
                    source_type, source_id, account_id, date,
                    amount, currency, direction, description
                ) VALUES ('bank', %s, %s, %s, %s, 'CNY', 'inflow', '银行存款到期兑付')
            """, (deposit_id, account_id, end, principal + interest))

    # ============================
    # 2. 固定收益理财现金流
    # ============================
    def generate_fixed_financial(self):
        self.cur.execute("""
            SELECT id, account_id, principal, expected_yield,
                   start_date, end_date, pay_freq
            FROM financial_products
            WHERE is_nav_based=0 AND status='active'
        """)
        rows = self.cur.fetchall()

        for r in rows:
            pid, account_id, principal, rate, start, end, freq = r

            # 到期兑付
            days = (end - start).days
            interest = principal * rate * days / 365

            # 幂等检查
            self.cur.execute("""
                SELECT COUNT(*) FROM cashflows
                WHERE source_type='financial'
                AND source_id=%s
                AND date=%s
            """, (pid, end))
            if self.cur.fetchone()[0] == 0:
                self.cur.execute("""
                    INSERT INTO cashflows (
                        source_type, source_id, account_id, date,
                        amount, currency, direction, description
                    ) VALUES ('financial', %s, %s, %s, %s, 'CNY', 'inflow', '固定收益理财到期兑付')
                """, (pid, account_id, end, principal + interest))

            # 按月/季付息
            if freq in ("monthly", "quarterly"):
                delta = relativedelta(months=1 if freq == "monthly" else 3)
                d = start + delta
                pay = principal * rate / (12 if freq == "monthly" else 4)

                while d < end:
                    self.cur.execute("""
                        SELECT COUNT(*) FROM cashflows
                        WHERE source_type='financial'
                        AND source_id=%s
                        AND date=%s
                    """, (pid, d))
                    if self.cur.fetchone()[0] == 0:
                        self.cur.execute("""
                            INSERT INTO cashflows (
                                source_type, source_id, account_id, date,
                                amount, currency, direction, description
                            ) VALUES ('financial', %s, %s, %s, %s, 'CNY', 'inflow', '理财产品付息')
                        """, (pid, account_id, d, pay))
                    d += delta

    # ============================
    # 3. 净值型理财现金流（分红 + 赎回）
    # ============================
    def generate_nav_financial(self):
        self.cur.execute("""
            SELECT id, product_id, account_id, trade_date, trade_type, amount
            FROM financial_transactions
            WHERE trade_type IN ('sell', 'dividend')
        """)
        rows = self.cur.fetchall()

        for tx_id, pid, account_id, date, ttype, amount in rows:
            # 幂等检查
            self.cur.execute("""
                SELECT COUNT(*) FROM cashflows
                WHERE source_type='financial'
                AND source_id=%s
                AND date=%s
                AND amount=%s
            """, (pid, date, amount))
            if self.cur.fetchone()[0] > 0:
                continue

            desc = "净值型理财赎回" if ttype == "sell" else "净值型理财分红"

            self.cur.execute("""
                INSERT INTO cashflows (
                    source_type, source_id, account_id, date,
                    amount, currency, direction, description
                ) VALUES ('financial', %s, %s, %s, %s, 'CNY', 'inflow', %s)
            """, (pid, account_id, date, amount, desc))

    # ============================
    # 4. 保险产品现金流（缴费）
    # ============================
    def generate_insurance(self):
        self.cur.execute("""
            SELECT id, account_id, premium, premium_freq,
                   premium_years, start_date
            FROM insurance_products
            WHERE status='active'
        """)
        rows = self.cur.fetchall()

        for pid, account_id, premium, freq, years, start in rows:
            if freq == "once":
                # 幂等检查
                self.cur.execute("""
                    SELECT COUNT(*) FROM cashflows
                    WHERE source_type='insurance'
                    AND source_id=%s
                    AND date=%s
                """, (pid, start))
                if self.cur.fetchone()[0] == 0:
                    self.cur.execute("""
                        INSERT INTO cashflows (
                            source_type, source_id, account_id, date,
                            amount, currency, direction, description
                        ) VALUES ('insurance', %s, %s, %s, %s, 'CNY', 'outflow', '保险一次性缴费')
                    """, (pid, account_id, start, -premium))
                continue

            # 年缴/月缴
            delta = relativedelta(years=1) if freq == "annual" else relativedelta(months=1)
            count = years if freq == "annual" else years * 12

            d = start
            for _ in range(count):
                self.cur.execute("""
                    SELECT COUNT(*) FROM cashflows
                    WHERE source_type='insurance'
                    AND source_id=%s
                    AND date=%s
                """, (pid, d))
                if self.cur.fetchone()[0] == 0:
                    self.cur.execute("""
                        INSERT INTO cashflows (
                            source_type, source_id, account_id, date,
                            amount, currency, direction, description
                        ) VALUES ('insurance', %s, %s, %s, %s, 'CNY', 'outflow', '保险缴费')
                    """, (pid, account_id, d, -premium))
                d += delta
