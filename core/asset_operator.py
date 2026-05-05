# core/asset_operator.py
import datetime
from dateutil.relativedelta import relativedelta
import pymysql

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

    def __init__(self, conn: pymysql.connections.Connection):
        self.conn = conn
        self.cur = conn.cursor()

    # ============================
    # 1. 买入（Buy）
    # ============================
    def buy(self, asset_type: str, **kwargs):
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

    # --- 净值型理财买入 ---
    def _buy_nav_financial(self, product_id, account_id, amount, nav, date):
        shares = amount / nav

        self.cur.execute("""
            INSERT INTO financial_transactions (
                product_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (%s, %s, %s, 'buy', %s, %s, %s, 'CNY')
        """, (product_id, account_id, date, shares, amount, nav))

        self.conn.commit()
        return {"status": "success", "shares": float(shares)}

    # --- 固定收益理财买入 ---
    def _buy_fixed_financial(self, product_id, account_id, principal, date):
        self.cur.execute("""
            UPDATE financial_products
            SET principal=%s, start_date=%s, status='active'
            WHERE id=%s
        """, (principal, date, product_id))

        self.conn.commit()
        return {"status": "success"}

    # --- 银行存款买入 ---
    def _buy_bank_deposit(self, account_id, deposit_type, principal, rate, start_date, end_date):
        self.cur.execute("""
            INSERT INTO bank_deposits (
                account_id, deposit_type, principal, interest_rate,
                start_date, end_date, status
            ) VALUES (%s, %s, %s, %s, %s, %s, 'active')
        """, (account_id, deposit_type, principal, rate, start_date, end_date))

        self.conn.commit()
        return {"status": "success"}

    # --- 保险缴费 ---
    def _buy_insurance(self, product_id, account_id, premium, date):
        self.cur.execute("""
            INSERT INTO cashflows (
                source_type, source_id, account_id, date,
                amount, currency, direction, description
            ) VALUES ('insurance', %s, %s, %s, %s, 'CNY', 'outflow', '保险缴费')
        """, (product_id, account_id, date, -premium))

        self.conn.commit()
        return {"status": "success"}

    # ============================
    # 2. 卖出（Sell）
    # ============================
    def sell(self, asset_type: str, **kwargs):
        if asset_type == "nav_financial":
            return self._sell_nav_financial(**kwargs)
        elif asset_type == "fixed_financial":
            return self._sell_fixed_financial(**kwargs)
        elif asset_type == "bank_deposit":
            return self._sell_bank_deposit(**kwargs)
        else:
            return {"error": f"不支持的资产类型：{asset_type}"}

    # --- 净值型理财赎回 ---
    def _sell_nav_financial(self, product_id, account_id, shares, nav, date):
        amount = shares * nav

        self.cur.execute("""
            INSERT INTO financial_transactions (
                product_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (%s, %s, %s, 'sell', %s, %s, %s, 'CNY')
        """, (product_id, account_id, date, shares, amount, nav))

        self.conn.commit()
        return {"status": "success", "amount": float(amount)}

    # --- 固定收益理财兑付 ---
    def _sell_fixed_financial(self, product_id, account_id, amount, date):
        self.cur.execute("""
            UPDATE financial_products
            SET status='redeemed'
            WHERE id=%s
        """, (product_id,))

        self.cur.execute("""
            INSERT INTO cashflows (
                source_type, source_id, account_id, date,
                amount, currency, direction, description
            ) VALUES ('financial', %s, %s, %s, %s, 'CNY', 'inflow', '固定收益理财兑付')
        """, (product_id, account_id, date, amount))

        self.conn.commit()
        return {"status": "success"}

    # --- 银行存款支取 ---
    def _sell_bank_deposit(self, deposit_id, account_id, amount, date):
        self.cur.execute("""
            UPDATE bank_deposits
            SET status='redeemed'
            WHERE id=%s
        """, (deposit_id,))

        self.cur.execute("""
            INSERT INTO cashflows (
                source_type, source_id, account_id, date,
                amount, currency, direction, description
            ) VALUES ('bank', %s, %s, %s, %s, 'CNY', 'inflow', '银行存款支取')
        """, (deposit_id, account_id, date, amount))

        self.conn.commit()
        return {"status": "success"}

    # ============================
    # 3. 更新净值
    # ============================
    def update_nav(self, product_id, date, nav):
        self.cur.execute("""
            INSERT INTO financial_navs (product_id, date, nav, currency)
            VALUES (%s, %s, %s, 'CNY')
            ON DUPLICATE KEY UPDATE nav=%s
        """, (product_id, date, nav, nav))

        self.conn.commit()
        return {"status": "success"}

    # ============================
    # 4. 更新状态
    # ============================
    def update_status(self, table, id, status):
        self.cur.execute(
            f"UPDATE {table} SET status=%s WHERE id=%s",
            (status, id)
        )
        self.conn.commit()
        return {"status": "success"}

    # ============================
    # 5. 更新保险现金价值
    # ============================
    def update_cash_value(self, product_id, cash_value):
        self.cur.execute("""
            UPDATE insurance_products
            SET cash_value=%s
            WHERE id=%s
        """, (cash_value, product_id))

        self.conn.commit()
        return {"status": "success"}

