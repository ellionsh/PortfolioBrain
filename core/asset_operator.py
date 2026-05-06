# core/asset_operator.py
from sqlalchemy import text

class AssetOperator:
    """
    PortfolioBrain 资产操作层（Trading Engine）
    支持：
    - 买入（buy）
    - 卖出（sell）
    - 更新净值（update_nav）
    - 更新状态（update_status）
    - 更新保险现金价值（update_cash_value）
    """

    def __init__(self, session):
        self.session = session

    # ============================
    # 1. 买入（Buy）
    # ============================
    def buy(self, asset_type: str, **kwargs):
        try:
            if asset_type == "nav_financial":
                return self._buy_nav_financial(**kwargs)
            elif asset_type == "fixed_financial":
                return self._buy_fixed_financial(**kwargs)
            elif asset_type == "bank_deposit":
                return self._buy_bank_deposit(**kwargs)
            elif asset_type == "insurance":
                return self._buy_insurance(**kwargs)
            else:
                return {"error": f"不支持的资产类型：{asset_type}"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

    # --- 净值型理财买入 ---
    def _buy_nav_financial(self, product_id, account_id, amount, nav, date):
        shares = amount / nav

        self.session.execute(text("""
            INSERT INTO financial_transactions (
                product_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (:pid, :aid, :date, 'buy', :shares, :amount, :nav, 'CNY')
        """), {
            "pid": product_id,
            "aid": account_id,
            "date": date,
            "shares": shares,
            "amount": amount,
            "nav": nav
        })

        self.session.commit()
        return {"status": "success", "shares": float(shares)}

    # --- 固定收益理财买入 ---
    def _buy_fixed_financial(self, product_id, account_id, principal, date):
        self.session.execute(text("""
            UPDATE financial_products
            SET principal=:p, start_date=:d, status='active'
            WHERE id=:pid
        """), {
            "p": principal,
            "d": date,
            "pid": product_id
        })

        self.session.commit()
        return {"status": "success"}

    # --- 银行存款买入 ---
    def _buy_bank_deposit(self, account_id, deposit_type, principal, rate, start_date, end_date):
        self.session.execute(text("""
            INSERT INTO bank_deposits (
                account_id, deposit_type, principal, interest_rate,
                start_date, end_date, status
            ) VALUES (:aid, :dtype, :p, :r, :sd, :ed, 'active')
        """), {
            "aid": account_id,
            "dtype": deposit_type,
            "p": principal,
            "r": rate,
            "sd": start_date,
            "ed": end_date
        })

        self.session.commit()
        return {"status": "success"}

    # --- 保险缴费 ---
    def _buy_insurance(self, product_id, account_id, premium, date):
        self.session.execute(text("""
            INSERT INTO cashflows (
                source_type, source_id, account_id, date,
                amount, currency, direction, description
            ) VALUES ('insurance', :pid, :aid, :date, :amt, 'CNY', 'outflow', '保险缴费')
        """), {
            "pid": product_id,
            "aid": account_id,
            "date": date,
            "amt": -premium
        })

        self.session.commit()
        return {"status": "success"}

    # ============================
    # 2. 卖出（Sell）
    # ============================
    def sell(self, asset_type: str, **kwargs):
        try:
            if asset_type == "nav_financial":
                return self._sell_nav_financial(**kwargs)
            elif asset_type == "fixed_financial":
                return self._sell_fixed_financial(**kwargs)
            elif asset_type == "bank_deposit":
                return self._sell_bank_deposit(**kwargs)
            else:
                return {"error": f"不支持的资产类型：{asset_type}"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

    # --- 净值型理财赎回 ---
    def _sell_nav_financial(self, product_id, account_id, shares, nav, date):
        amount = shares * nav

        self.session.execute(text("""
            INSERT INTO financial_transactions (
                product_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (:pid, :aid, :date, 'sell', :shares, :amount, :nav, 'CNY')
        """), {
            "pid": product_id,
            "aid": account_id,
            "date": date,
            "shares": shares,
            "amount": amount,
            "nav": nav
        })

        self.session.commit()
        return {"status": "success", "amount": float(amount)}

    # --- 固定收益理财兑付 ---
    def _sell_fixed_financial(self, product_id, account_id, amount, date):
        self.session.execute(text("""
            UPDATE financial_products
            SET status='redeemed'
            WHERE id=:pid
        """), {"pid": product_id})

        self.session.execute(text("""
            INSERT INTO cashflows (
                source_type, source_id, account_id, date,
                amount, currency, direction, description
            ) VALUES ('financial', :pid, :aid, :date, :amt, 'CNY', 'inflow', '固定收益理财兑付')
        """), {
            "pid": product_id,
            "aid": account_id,
            "date": date,
            "amt": amount
        })

        self.session.commit()
        return {"status": "success"}

    # --- 银行存款支取 ---
    def _sell_bank_deposit(self, deposit_id, account_id, amount, date):
        self.session.execute(text("""
            UPDATE bank_deposits
            SET status='redeemed'
            WHERE id=:id
        """), {"id": deposit_id})

        self.session.execute(text("""
            INSERT INTO cashflows (
                source_type, source_id, account_id, date,
                amount, currency, direction, description
            ) VALUES ('bank', :did, :aid, :date, :amt, 'CNY', 'inflow', '银行存款支取')
        """), {
            "did": deposit_id,
            "aid": account_id,
            "date": date,
            "amt": amount
        })

        self.session.commit()
        return {"status": "success"}

    # ============================
    # 3. 更新净值
    # ============================
    def update_nav(self, product_id, date, nav):
        self.session.execute(text("""
            INSERT INTO financial_navs (product_id, date, nav, currency)
            VALUES (:pid, :date, :nav, 'CNY')
            ON DUPLICATE KEY UPDATE nav=:nav
        """), {
            "pid": product_id,
            "date": date,
            "nav": nav
        })

        self.session.commit()
        return {"status": "success"}

    # ============================
    # 4. 更新状态
    # ============================
    def update_status(self, table, id, status):
        self.session.execute(
            text(f"UPDATE {table} SET status=:s WHERE id=:id"),
            {"s": status, "id": id}
        )
        self.session.commit()
        return {"status": "success"}

    # ============================
    # 5. 更新保险现金价值
    # ============================
    def update_cash_value(self, product_id, cash_value):
        self.session.execute(text("""
            UPDATE insurance_products
            SET cash_value=:cv
            WHERE id=:pid
        """), {
            "cv": cash_value,
            "pid": product_id
        })

        self.session.commit()
        return {"status": "success"}

