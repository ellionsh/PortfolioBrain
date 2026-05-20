# core/cashflow_engine.py
from sqlalchemy import text
from dateutil.relativedelta import relativedelta


class CashflowEngine:
    """
    PortfolioBrain 现金流引擎（Cashflow Engine）
    自动生成：
    - 银行存款利息 + 到期兑付
    - 固定收益理财付息 + 到期兑付
    - 净值型理财分红 + 赎回
    - 保险缴费
    """

    def __init__(self, session):
        self.session = session

    # ============================
    # 主入口
    # ============================
    def generate_all(self, dry_run: bool = False):
        try:
            self.generate_bank_deposit()
            self.generate_fixed_financial()
            self.generate_nav_financial()
            self.generate_fund()
            self.generate_insurance()
            if dry_run:
                self.session.rollback()
                return {"status": "success", "dry_run": True}
            self.session.commit()
            return {"status": "success"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

    # ============================
    # 1. 银行存款现金流
    # ============================
    def generate_bank_deposit(self):
        rows = self.session.execute(text("""
            SELECT id, account_id, principal, interest_rate,
                   start_date, end_date, deposit_type
            FROM bank_deposits
            WHERE status='active'
        """)).fetchall()

        for r in rows:
            id, account_id, principal, rate, start, end, dtype = r

            if dtype == "demand":
                continue
            if start is None or end is None:
                continue

            days = (end - start).days
            interest = principal * rate * days / 365

            # 幂等检查
            exists = self.session.execute(text("""
                SELECT COUNT(*) FROM cashflows
                WHERE source_type='bank'
                AND source_id=:id
                AND date=:d
            """), {"id": id, "d": end}).scalar()

            if exists > 0:
                continue

            # 到期兑付
            self.session.execute(text("""
                INSERT INTO cashflows (
                    source_type, source_id, account_id, date,
                    amount, currency, direction, description
                ) VALUES ('bank', :id, :aid, :d, :amt, 'CNY', 'inflow', '银行存款到期兑付')
            """), {
                "id": id,
                "aid": account_id,
                "d": end,
                "amt": principal + interest
            })

    # ============================
    # 2. 固定收益理财现金流
    # ============================
    def generate_fixed_financial(self):
        rows = self.session.execute(text("""
            SELECT id, account_id, principal, expected_yield,
                   start_date, end_date, pay_freq
            FROM financial_products
            WHERE is_nav_based=0 AND status='active'
        """)).fetchall()

        for r in rows:
            pid, account_id, principal, rate, start, end, freq = r

            if start is None or end is None:
                continue
            days = (end - start).days
            interest = principal * rate * days / 365

            # 到期兑付幂等检查
            exists = self.session.execute(text("""
                SELECT COUNT(*) FROM cashflows
                WHERE source_type='financial'
                AND source_id=:id
                AND date=:d
            """), {"id": pid, "d": end}).scalar()

            if exists == 0:
                self.session.execute(text("""
                    INSERT INTO cashflows (
                        source_type, source_id, account_id, date,
                        amount, currency, direction, description
                    ) VALUES ('financial', :id, :aid, :d, :amt, 'CNY', 'inflow', '固定收益理财到期兑付')
                """), {
                    "id": pid,
                    "aid": account_id,
                    "d": end,
                    "amt": principal + interest
                })

            # 按月/季付息
            if freq in ("monthly", "quarterly"):
                delta = relativedelta(months=1 if freq == "monthly" else 3)
                d = start + delta
                pay = principal * rate / (12 if freq == "monthly" else 4)

                while d < end:
                    exists = self.session.execute(text("""
                        SELECT COUNT(*) FROM cashflows
                        WHERE source_type='financial'
                        AND source_id=:id
                        AND date=:d
                    """), {"id": pid, "d": d}).scalar()

                    if exists == 0:
                        self.session.execute(text("""
                            INSERT INTO cashflows (
                                source_type, source_id, account_id, date,
                                amount, currency, direction, description
                            ) VALUES ('financial', :id, :aid, :d, :amt, 'CNY', 'inflow', '理财产品付息')
                        """), {
                            "id": pid,
                            "aid": account_id,
                            "d": d,
                            "amt": pay
                        })

                    d += delta

    # ============================
    # 3. 净值型理财现金流（分红 + 赎回）
    # ============================
    def generate_nav_financial(self):
        rows = self.session.execute(text("""
            SELECT id, product_id, account_id, trade_date, trade_type, amount
            FROM financial_transactions
            WHERE trade_type IN ('sell', 'dividend')
        """)).fetchall()

        for tx_id, pid, account_id, date, ttype, amount in rows:
            if date is None:
                continue
            exists = self.session.execute(text("""
                SELECT COUNT(*) FROM cashflows
                WHERE source_type='financial'
                AND source_id=:id
                AND date=:d
                AND amount=:amt
            """), {"id": pid, "d": date, "amt": amount}).scalar()

            if exists > 0:
                continue

            desc = "净值型理财赎回" if ttype == "sell" else "净值型理财分红"

            self.session.execute(text("""
                INSERT INTO cashflows (
                    source_type, source_id, account_id, date,
                    amount, currency, direction, description
                ) VALUES ('financial', :id, :aid, :d, :amt, 'CNY', 'inflow', :desc)
            """), {
                "id": pid,
                "aid": account_id,
                "d": date,
                "amt": amount,
                "desc": desc
            })

    # ============================
    # 4. 保险产品现金流（缴费）
    # ============================
    def generate_insurance(self):
        rows = self.session.execute(text("""
            SELECT id, account_id, premium, premium_freq,
                   premium_years, start_date
            FROM insurance_products
            WHERE status='active'
        """)).fetchall()

        for pid, account_id, premium, freq, years, start in rows:
            if start is None:
                continue
            if freq == "once":
                exists = self.session.execute(text("""
                    SELECT COUNT(*) FROM cashflows
                    WHERE source_type='insurance'
                    AND source_id=:id
                    AND date=:d
                """), {"id": pid, "d": start}).scalar()

                if exists == 0:
                    self.session.execute(text("""
                        INSERT INTO cashflows (
                            source_type, source_id, account_id, date,
                            amount, currency, direction, description
                        ) VALUES ('insurance', :id, :aid, :d, :amt, 'CNY', 'outflow', '保险一次性缴费')
                    """), {
                        "id": pid,
                        "aid": account_id,
                        "d": start,
                        "amt": -premium
                    })
                continue

            # 年缴/月缴
            delta = relativedelta(years=1) if freq == "annual" else relativedelta(months=1)
            count = years if freq == "annual" else years * 12

            d = start
            for _ in range(count):
                exists = self.session.execute(text("""
                    SELECT COUNT(*) FROM cashflows
                    WHERE source_type='insurance'
                    AND source_id=:id
                    AND date=:d
                """), {"id": pid, "d": d}).scalar()

                if exists == 0:
                    self.session.execute(text("""
                        INSERT INTO cashflows (
                            source_type, source_id, account_id, date,
                            amount, currency, direction, description
                        ) VALUES ('insurance', :id, :aid, :d, :amt, 'CNY', 'outflow', '保险缴费')
                    """), {
                        "id": pid,
                        "aid": account_id,
                        "d": d,
                        "amt": -premium
                    })

                d += delta

    # ============================
    # 5. 基金现金流（申购/赎回/分红/费用）
    # ============================
    def generate_fund(self):
        rows = self.session.execute(text("""
            SELECT id, fund_id, account_id, trade_date, trade_type,
                   amount, fee, currency
            FROM fund_transactions
        """)).fetchall()

        for tx_id, fund_id, account_id, date, ttype, amount, fee, currency in rows:
            if date is None:
                continue
            exists = self.session.execute(text("""
                SELECT COUNT(*) FROM cashflows
                WHERE source_type='fund'
                AND source_id=:id
            """), {"id": tx_id}).scalar()

            if exists > 0:
                continue

            try:
                amount_value = float(amount) if amount is not None else 0.0
            except (TypeError, ValueError):
                amount_value = 0.0
            try:
                fee_value = float(fee) if fee is not None else 0.0
            except (TypeError, ValueError):
                fee_value = 0.0

            total = None
            direction = None
            description = None

            if ttype == "buy":
                total = -abs(amount_value) - fee_value
                direction = "outflow"
                description = "基金申购"
            elif ttype == "sell":
                total = abs(amount_value) - fee_value
                direction = "inflow"
                description = "基金赎回"
            elif ttype == "dividend":
                total = abs(amount_value) - fee_value
                direction = "inflow"
                description = "基金分红"
            elif ttype == "fee":
                total = -abs(amount_value) - fee_value
                direction = "outflow"
                description = "基金费用"

            if total is None:
                continue

            self.session.execute(text("""
                INSERT INTO cashflows (
                    source_type, source_id, account_id, date,
                    amount, currency, direction, description
                ) VALUES ('fund', :id, :aid, :d, :amt, :cur, :dir, :desc)
            """), {
                "id": tx_id,
                "aid": account_id,
                "d": date,
                "amt": total,
                "cur": currency or "CNY",
                "dir": direction,
                "desc": description
            })
