import datetime
from decimal import Decimal, InvalidOperation
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
    - 新增账户（create_account）
    - 删除账户（delete_account）
    - 更新账户（update_account）
    - 银行存款操作（bank_deposit 相关）
    """

    def __init__(self, session):
        self.session = session

    def _get_product_code(self, product_id):
        return self.session.execute(
            text("SELECT product_code FROM financial_products WHERE id=:id"),
            {"id": product_id},
        ).scalar()

    def _get_fund_code(self, fund_id):
        return self.session.execute(
            text("SELECT fund_code FROM fund_products WHERE id=:id"),
            {"id": fund_id},
        ).scalar()

    def _upsert_fund_nav_by_code(self, fund_code, date, nav):
        exists = self.session.execute(
            text("SELECT 1 FROM fund_navs WHERE fund_code=:fcode LIMIT 1"),
            {"fcode": fund_code},
        ).scalar()
        if exists:
            self.session.execute(text("""
                UPDATE fund_navs
                SET date=:date, nav=:nav, currency='CNY'
                WHERE fund_code=:fcode
            """), {"fcode": fund_code, "date": date, "nav": nav})
        else:
            self.session.execute(text("""
                INSERT INTO fund_navs (fund_code, date, nav, currency)
                VALUES (:fcode, :date, :nav, 'CNY')
            """), {"fcode": fund_code, "date": date, "nav": nav})

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
            elif asset_type == "fund":
                return self._buy_fund(**kwargs)
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
        # 插入交易记录
        self.session.execute(text("""
            INSERT INTO financial_transactions (
                product_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (:pid, :aid, :date, 'buy', :shares, :amount, :nav, 'CNY')
        """), {"pid": product_id, "aid": account_id, "date": date,
            "shares": shares, "amount": amount, "nav": nav})
        # 更新产品份额
        self.session.execute(text("""
            UPDATE financial_products
            SET shares = COALESCE(shares,0) + :shares,
                principal = COALESCE(principal,0) + :amount,
                start_date = COALESCE(start_date, :date),
                status='active'
            WHERE id=:pid
        """), {"shares": shares, "amount": amount, "date": date, "pid": product_id})
        self.session.commit()
        return {"status": "success", "shares": float(shares)}

    # --- 固定收益理财买入 ---
    def _buy_fixed_financial(self, product_id, account_id, principal, date):
        self.session.execute(text("""
            UPDATE financial_products
            SET principal = COALESCE(principal,0) + :p,
                shares = COALESCE(shares,0) + :p,
                start_date = COALESCE(start_date, :d),
                status='active'
            WHERE id=:pid
        """), {
            "p": principal,
            "d": date,
            "pid": product_id
        })
        self.session.execute(text("""
            INSERT INTO financial_transactions (
                product_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (:pid, :aid, :date, 'buy', :shares, :amount, NULL, 'CNY')
        """), {
            "pid": product_id,
            "aid": account_id,
            "date": date,
            "shares": principal,
            "amount": principal,
        })

        self.session.commit()
        return {"status": "success"}

    def _buy_fund(self, fund_id, account_id, amount, nav, date, shares=None):
        amount_dec = Decimal(str(amount))
        nav_dec = Decimal(str(nav))
        fee = Decimal("0")
        if shares is None:
            shares = amount_dec / nav_dec
        else:
            shares = Decimal(str(shares))
            fee = amount_dec - (shares * nav_dec)
        self.session.execute(text("""
            INSERT INTO fund_transactions (
                fund_id, account_id, trade_date, trade_type,
                shares, amount, nav, fee, currency
            ) VALUES (:fid, :aid, :date, 'buy', :shares, :amount, :nav, :fee, 'CNY')
        """), {
            "fid": fund_id,
            "aid": account_id,
            "date": date,
            "shares": shares,
            "amount": amount_dec,
            "nav": nav_dec,
            "fee": fee,
        })
        self.session.execute(text("""
            UPDATE fund_products
            SET shares = COALESCE(shares,0) + :shares,
                principal = COALESCE(principal,0) + :amount,
                start_date = COALESCE(start_date, :date),
                status='active'
            WHERE id=:fid
        """), {
            "shares": shares,
            "amount": amount_dec,
            "date": date,
            "fid": fund_id,
        })
        fund_code = self._get_fund_code(fund_id)
        if not fund_code:
            self.session.rollback()
            return {"error": "找不到基金代码"}
        self._upsert_fund_nav_by_code(fund_code, date, nav)
        self.session.commit()
        return {"status": "success", "shares": float(shares)}

    # --- 银行存款买入 ---
    def _buy_bank_deposit(self, account_id, deposit_type, principal, rate, start_date, end_date, currency="CNY", **kwargs):
        try:
            self.session.execute(text("""
                INSERT INTO bank_deposits (
                    account_id, deposit_type, currency, principal, interest_rate,
                    start_date, end_date, status, interest_method, notice_days, auto_renew, remark
                ) VALUES (:aid, :dtype, :currency, :p, :r, :sd, :ed, 'active', 
                          :interest_method, :notice_days, :auto_renew, :remark)
            """), {
                "aid": account_id,
                "dtype": deposit_type,
                "currency": currency,
                "p": principal,
                "r": rate,
                "sd": start_date,
                "ed": end_date,
                "interest_method": kwargs.get("interest_method", "at_maturity"),
                "notice_days": kwargs.get("notice_days"),
                "auto_renew": kwargs.get("auto_renew", False),
                "remark": kwargs.get("remark")
            })

            self.session.commit()
            return {"status": "success", "message": f"银行存款已创建，本金：{principal}"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

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
            elif asset_type == "fund":
                return self._sell_fund(**kwargs)
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
        row = self.session.execute(text("""
            SELECT shares, principal
            FROM financial_products
            WHERE id=:pid
            FOR UPDATE
        """), {"pid": product_id}).first()
        current_shares = row[0] if row else None
        current_principal = row[1] if row else None
        principal_reduction = Decimal("0")
        try:
            if current_shares and current_principal is not None:
                current_shares_dec = (
                    current_shares
                    if isinstance(current_shares, Decimal)
                    else Decimal(str(current_shares))
                )
                if current_shares_dec > 0:
                    shares_dec = (
                        shares if isinstance(shares, Decimal) else Decimal(str(shares))
                    )
                    ratio = shares_dec / current_shares_dec
                    if ratio < 0:
                        ratio = Decimal("0")
                    principal_dec = (
                        current_principal
                        if isinstance(current_principal, Decimal)
                        else Decimal(str(current_principal))
                    )
                    principal_reduction = principal_dec * ratio
        except (InvalidOperation, ZeroDivisionError):
            principal_reduction = Decimal("0")
        # 插入交易记录
        self.session.execute(text("""
            INSERT INTO financial_transactions (
                product_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (:pid, :aid, :date, 'sell', :shares, :amount, :nav, 'CNY')
        """), {"pid": product_id, "aid": account_id, "date": date,
            "shares": shares, "amount": amount, "nav": nav})
        # 更新产品份额
        self.session.execute(text("""
            UPDATE financial_products
            SET shares = shares - :shares,
                principal = COALESCE(principal,0) - :principal_reduction
            WHERE id=:pid
        """), {
            "shares": shares,
            "principal_reduction": principal_reduction,
            "pid": product_id,
        })
        self.session.commit()
        return {"status": "success", "amount": float(amount)}

    # --- 固定收益理财兑付 ---
    def _sell_fixed_financial(self, product_id, account_id, amount, date):
        self.session.execute(text("""
            UPDATE financial_products
            SET status='redeemed',
                principal = COALESCE(principal,0) - :amount,
                shares = COALESCE(shares,0) - :amount
            WHERE id=:pid
        """), {"pid": product_id, "amount": amount})

        self.session.execute(text("""
            INSERT INTO financial_transactions (
                product_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (:pid, :aid, :date, 'sell', :shares, :amount, NULL, 'CNY')
        """), {
            "pid": product_id,
            "aid": account_id,
            "date": date,
            "shares": amount,
            "amount": amount,
        })

        self.session.commit()
        return {"status": "success"}
    def _sell_fund(self, fund_id, account_id, shares, nav, date):
        amount = shares * nav
        row = self.session.execute(text("""
            SELECT shares, principal
            FROM fund_products
            WHERE id=:fid
            FOR UPDATE
        """), {"fid": fund_id}).first()
        current_shares = row[0] if row else None
        current_principal = row[1] if row else None
        principal_reduction = Decimal("0")
        try:
            if current_shares and current_principal is not None:
                current_shares_dec = (
                    current_shares
                    if isinstance(current_shares, Decimal)
                    else Decimal(str(current_shares))
                )
                if current_shares_dec > 0:
                    shares_dec = (
                        shares if isinstance(shares, Decimal) else Decimal(str(shares))
                    )
                    ratio = shares_dec / current_shares_dec
                    if ratio < 0:
                        ratio = Decimal("0")
                    principal_dec = (
                        current_principal
                        if isinstance(current_principal, Decimal)
                        else Decimal(str(current_principal))
                    )
                    principal_reduction = principal_dec * ratio
        except (InvalidOperation, ZeroDivisionError):
            principal_reduction = Decimal("0")
        self.session.execute(text("""
            INSERT INTO fund_transactions (
                fund_id, account_id, trade_date, trade_type,
                shares, amount, nav, currency
            ) VALUES (:fid, :aid, :date, 'sell', :shares, :amount, :nav, 'CNY')
        """), {"fid": fund_id, "aid": account_id, "date": date,
            "shares": shares, "amount": amount, "nav": nav})
        self.session.execute(text("""
            UPDATE fund_products
            SET shares = shares - :shares,
                principal = COALESCE(principal,0) - :principal_reduction
            WHERE id=:fid
        """), {
            "shares": shares,
            "principal_reduction": principal_reduction,
            "fid": fund_id,
        })
        fund_code = self._get_fund_code(fund_id)
        if not fund_code:
            self.session.rollback()
            return {"error": "找不到基金代码"}
        self._upsert_fund_nav_by_code(fund_code, date, nav)
        self.session.commit()
        return {"status": "success", "amount": float(amount)}

    # --- 银行存款支取 ---
    def _sell_bank_deposit(self, id, amount, date):
        try:
            self.session.execute(text("""
                UPDATE bank_deposits
                SET status='redeemed'
                WHERE id=:id
            """), {"id": id})

            self.session.commit()
            return {"status": "success", "message": f"银行存款已提取，金额：{amount}"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

    # ============================
    # 3. 更新净值
    # ============================
    def update_nav(self, product_id=None, product_code=None, date=None, nav=None):
        if product_code is None:
            if product_id is None:
                return {"error": "缺少产品代码或ID"}
            product_code = self._get_product_code(product_id)
        if not product_code:
            return {"error": "找不到产品代码"}
        self.session.execute(text("""
            INSERT INTO financial_navs (product_code, date, nav, currency)
            VALUES (:pcode, :date, :nav, 'CNY')
            ON DUPLICATE KEY UPDATE nav=:nav
        """), {
            "pcode": product_code,
            "date": date,
            "nav": nav
        })

        self.session.commit()
        return {"status": "success"}
    
    def update_fund_nav(self, fund_id=None, fund_code=None, date=None, nav=None):
        if fund_code is None:
            if fund_id is None:
                return {"error": "缺少基金代码或ID"}
            fund_code = self._get_fund_code(fund_id)
        if not fund_code:
            return {"error": "找不到基金代码"}
        self._upsert_fund_nav_by_code(fund_code, date, nav)
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

    # ============================
    # 7. 保险产品 CRUD
    # ============================
    def create_insurance_product(
        self,
        account_id,
        product_name,
        company,
        type,
        currency="CNY",
        premium=0,
        premium_freq="annual",
        premium_years=0,
        coverage_amount=0,
        start_date=None,
        end_date=None,
        cash_value=0,
        status="active",
        remark=None,
    ):
        self.session.execute(text("""
            INSERT INTO insurance_products (
                account_id, product_name, company, type, currency,
                premium, premium_freq, premium_years, coverage_amount,
                start_date, end_date, cash_value, status, remark
            ) VALUES (
                :account_id, :product_name, :company, :type, :currency,
                :premium, :premium_freq, :premium_years, :coverage_amount,
                :start_date, :end_date, :cash_value, :status, :remark
            )
        """), {
            "account_id": account_id,
            "product_name": product_name,
            "company": company,
            "type": type,
            "currency": currency,
            "premium": premium,
            "premium_freq": premium_freq,
            "premium_years": premium_years,
            "coverage_amount": coverage_amount,
            "start_date": start_date,
            "end_date": end_date,
            "cash_value": cash_value,
            "status": status,
            "remark": remark,
        })
        self.session.commit()
        return {"status": "success", "message": f"保险产品 {product_name} 已创建"}

    def update_insurance_product(self, id, **kwargs):
        fields = []
        params = {"id": id}
        allowed_fields = [
            "account_id", "product_name", "company", "type", "currency",
            "premium", "premium_freq", "premium_years", "coverage_amount",
            "start_date", "end_date", "cash_value", "status", "remark"
        ]
        for key in allowed_fields:
            if key in kwargs:
                fields.append(f"{key} = :{key}")
                params[key] = kwargs[key]
        if not fields:
            return {"error": "没有需要更新的字段"}
        sql = f"UPDATE insurance_products SET {', '.join(fields)} WHERE id=:id"
        self.session.execute(text(sql), params)
        self.session.commit()
        return {"status": "success", "message": f"保险产品 {id} 已更新"}

    def delete_insurance_product(self, id):
        self.session.execute(text("""
            DELETE FROM insurance_products WHERE id=:id
        """), {"id": id})
        self.session.commit()
        return {"status": "success", "message": f"保险产品 ID={id} 已删除"}

    # ============================
    # 8. 理财产品 CRUD
    # ============================
    def create_financial_product(
        self,
        account_id,
        product_name,
        product_code,
        type,
        currency="CNY",
        is_nav_based=False,
        risk_level=None,
        min_redeem_unit=None,
        principal=None,
        shares=None,
        nav=None,
        expected_yield=None,
        start_date=None,
        end_date=None,
        pay_freq=None,
        status="active",
        remark=None,
    ):
        if start_date == "":
            start_date = None
        if end_date == "":
            end_date = None
        if not is_nav_based and shares is None and principal is not None:
            shares = principal
        self.session.execute(text("""
            INSERT INTO financial_products (
                account_id, product_name, product_code, type, currency,
                is_nav_based, risk_level, min_redeem_unit, principal,
                shares, expected_yield, start_date, end_date, pay_freq,
                status, remark
            ) VALUES (
                :account_id, :product_name, :product_code, :type, :currency,
                :is_nav_based, :risk_level, :min_redeem_unit, :principal,
                :shares, :expected_yield, :start_date, :end_date, :pay_freq,
                :status, :remark
            )
        """), {
            "account_id": account_id,
            "product_name": product_name,
            "product_code": product_code,
            "type": type,
            "currency": currency,
            "is_nav_based": is_nav_based,
            "risk_level": risk_level,
            "min_redeem_unit": min_redeem_unit,
            "principal": principal,
            "shares": shares,
            "expected_yield": expected_yield,
            "start_date": start_date,
            "end_date": end_date,
                "pay_freq": pay_freq,
                "status": status,
                "remark": remark,
        })
        product_id = self.session.execute(text("SELECT LAST_INSERT_ID()")).scalar()
        if principal is not None:
            try:
                principal_value = float(principal)
            except (TypeError, ValueError):
                principal_value = None
            if principal_value is not None and principal_value > 0:
                trade_date = start_date or datetime.date.today()
                self.session.execute(text("""
                    INSERT INTO financial_transactions (
                        product_id, account_id, trade_date, trade_type,
                        shares, amount, nav, currency
                    ) VALUES (:pid, :aid, :date, 'buy', :shares, :amount, :nav, :currency)
                """), {
                    "pid": product_id,
                    "aid": account_id,
                    "date": trade_date,
                    "shares": shares if shares is not None else principal_value,
                    "amount": principal_value,
                    "nav": nav,
                    "currency": currency,
                })
        if nav is not None:
            nav_exists = self.session.execute(text("""
                SELECT 1
                FROM financial_navs
                WHERE product_code=:product_code
                LIMIT 1
            """), {
                "product_code": product_code}).scalar()
            if not nav_exists:
                self.session.execute(text("""
                    INSERT INTO financial_navs (product_code, date, nav, currency)
                    VALUES (:product_code, CURDATE(), :nav, :currency)
                    ON DUPLICATE KEY UPDATE nav=:nav
                """), {
                    "product_code": product_code,
                    "nav": nav,
                    "currency": currency,
                })
        self.session.commit()
        return {
            "status": "success",
            "id": product_id,
            "message": f"理财产品 {product_name} 已创建",
        }

    def update_financial_product(self, id, **kwargs):
        nav = kwargs.pop("nav", None)
        currency = kwargs.get("currency", "CNY")
        if kwargs.get("start_date") == "":
            kwargs["start_date"] = None
        if kwargs.get("end_date") == "":
            kwargs["end_date"] = None
        fields = []
        params = {"id": id}
        allowed_fields = [
            "account_id", "product_name", "product_code", "type", "currency",
            "is_nav_based", "risk_level", "min_redeem_unit", "principal", "shares",
            "expected_yield", "start_date", "end_date", "pay_freq", "status", "remark"
        ]
        for key in allowed_fields:
            if key in kwargs:
                fields.append(f"{key} = :{key}")
                params[key] = kwargs[key]
        if not fields:
            if nav is None:
                return {"error": "没有需要更新的字段"}
        else:
            sql = f"UPDATE financial_products SET {', '.join(fields)} WHERE id=:id"
            self.session.execute(text(sql), params)
        if nav is not None:
            if "product_code" in kwargs:
                product_code = kwargs["product_code"]
            else:
                product_code = self._get_product_code(id)
            if not product_code:
                self.session.rollback()
                return {"error": "找不到产品代码"}
            self.session.execute(text("""
                INSERT INTO financial_navs (product_code, date, nav, currency)
                VALUES (:product_code, CURDATE(), :nav, :currency)
                ON DUPLICATE KEY UPDATE nav=:nav
            """), {
                "product_code": product_code,
                "nav": nav,
                "currency": currency,
            })
        self.session.commit()
        return {"status": "success", "message": f"理财产品 {id} 已更新"}

    def delete_financial_product(self, id):
        self.session.execute(text("""
            DELETE FROM financial_products WHERE id=:id
        """), {"id": id})
        self.session.commit()
        return {"status": "success", "message": f"理财产品 ID={id} 已删除"}

    # ============================
    # 4. CRUD 方法（基金）
    # ============================
    def create_fund_product(self, account_id, fund_name, fund_code, currency="CNY",
                            shares=0, principal=0, nav=None, start_date=None,
                            end_date=None, status="active", remark=None):
        start_date = start_date or None
        end_date = end_date or None
        if isinstance(remark, str) and remark.strip() == "":
            remark = None
        self.session.execute(text("""
            INSERT INTO fund_products (
                account_id, fund_name, fund_code, currency,
                shares, principal, start_date, end_date, status, remark
            ) VALUES (
                :aid, :name, :code, :currency, :shares, :principal,
                :start_date, :end_date, :status, :remark
            )
        """), {"aid": account_id, "name": fund_name, "code": fund_code,
               "currency": currency, "shares": shares, "principal": principal,
               "start_date": start_date, "end_date": end_date,
               "status": status, "remark": remark})
        fund_id = self.session.execute(text("SELECT LAST_INSERT_ID()")).scalar()
        if principal is not None:
            try:
                principal_value = float(principal)
            except (TypeError, ValueError):
                principal_value = None
            if principal_value is not None and principal_value > 0:
                trade_date = start_date or datetime.date.today()
                shares_value = shares if shares not in (None, "", 0) else None
                fee_value = Decimal("0")
                if shares_value is None and nav not in (None, "", 0):
                    try:
                        shares_value = Decimal(str(principal_value)) / Decimal(str(nav))
                    except (InvalidOperation, ZeroDivisionError):
                        shares_value = None
                if shares_value is not None and nav not in (None, ""):
                    try:
                        fee_value = Decimal(str(principal_value)) - (Decimal(str(shares_value)) * Decimal(str(nav)))
                    except (InvalidOperation, ZeroDivisionError):
                        fee_value = Decimal("0")
                self.session.execute(text("""
                    INSERT INTO fund_transactions (
                        fund_id, account_id, trade_date, trade_type,
                        shares, amount, nav, fee, currency
                    ) VALUES (:fid, :aid, :date, 'buy', :shares, :amount, :nav, :fee, :currency)
                """), {
                    "fid": fund_id,
                    "aid": account_id,
                    "date": trade_date,
                    "shares": shares_value,
                    "amount": principal_value,
                    "nav": nav,
                    "fee": fee_value,
                    "currency": currency,
                })
        if nav is not None:
            nav_exists = self.session.execute(text("""
                SELECT 1
                FROM fund_navs
                WHERE fund_code=:fcode
                LIMIT 1
            """), {
                "fcode": fund_code, 
                "start_date": start_date}).scalar()
            if not nav_exists:
                self.session.execute(text("""
                    INSERT INTO fund_navs (fund_code, date, nav, currency)
                    VALUES (:fcode, COALESCE(:start_date, CURDATE()), :nav, :currency)
                    ON DUPLICATE KEY UPDATE nav=:nav
                """), {
                    "fcode": fund_code,
                    "start_date": start_date,
                    "nav": nav,
                    "currency": currency,
                })
        self.session.commit()
        return {
            "status": "success",
            "id": fund_id,
            "message": f"基金产品 {fund_name} 已创建",
        }

    def update_fund_product(self, id, **kwargs):
        nav = kwargs.pop("nav", None)
        currency = kwargs.get("currency", "CNY")
        if kwargs.get("start_date") == "":
            kwargs["start_date"] = None
        if kwargs.get("end_date") == "":
            kwargs["end_date"] = None
        nav_date = kwargs.get("start_date")
        fields, params = [], {"id": id}
        allowed = ["account_id", "fund_name", "fund_code", "currency",
                   "shares", "principal", "start_date", "end_date",
                   "status", "remark"]
        for key in allowed:
            if key in kwargs:
                fields.append(f"{key} = :{key}")
                params[key] = kwargs[key]
        if not fields:
            if nav is None:
                return {"error": "没有需要更新的字段"}
        else:
            sql = f"UPDATE fund_products SET {', '.join(fields)} WHERE id=:id"
            self.session.execute(text(sql), params)
        if nav is not None:
            if "fund_code" in kwargs:
                fund_code = kwargs["fund_code"]
            else:
                fund_code = self._get_fund_code(id)
            if not fund_code:
                self.session.rollback()
                return {"error": "找不到基金代码"}
            self.session.execute(text("""
                INSERT INTO fund_navs (fund_code, date, nav, currency)
                VALUES (:fund_code, COALESCE(:date, CURDATE()), :nav, :currency)
                ON DUPLICATE KEY UPDATE nav=:nav
            """), {
                "fund_code": fund_code,
                "date": nav_date,
                "nav": nav,
                "currency": currency,
            })
        self.session.commit()
        return {"status": "success", "message": f"基金产品 {id} 已更新"}

    def delete_fund_product(self, id):
        self.session.execute(text("DELETE FROM fund_products WHERE id=:id"), {"id": id})
        self.session.commit()
        return {"status": "success", "message": f"基金产品 ID={id} 已删除"}
    
    # ============================
    # 9. 新增账户
    # ============================
    def create_account(self, name, institution, type, currency="CNY"):
        self.session.execute(text("""
            INSERT INTO accounts (name, institution, type, currency)
            VALUES (:name, :institution, :type, :currency)
        """), {
            "name": name,
            "institution": institution,
            "type": type,
            "currency": currency
        })
        self.session.commit()
        return {"status": "success", "message": f"账户 {name} 已创建"}

    # ============================
    # 7. 删除账户
    # ============================
    def delete_account(self, id=None, name=None):
        if id is None and name is None:
            return {"error": "必须提供 id 或 name 中的至少一个"}
        
        try:
            if id is not None:
                self.session.execute(text("""
                    DELETE FROM accounts WHERE id=:id
                """), {"id": id})
                self.session.commit()
                return {"status": "success", "message": f"账户 ID={id} 已删除"}
            else:
                self.session.execute(text("""
                    DELETE FROM accounts WHERE name=:name
                """), {"name": name})
                self.session.commit()
                return {"status": "success", "message": f"账户 {name} 已删除"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

    # ============================
    # 8. 更新账户
    # ============================
    def update_account(self, id, **kwargs):
        fields = []
        params = {"id": id}

        for key in ["name", "institution", "type", "currency"]:
            if key in kwargs:
                fields.append(f"{key} = :{key}")
                params[key] = kwargs[key]

        if not fields:
            return {"error": "没有需要更新的字段"}

        sql = f"UPDATE accounts SET {', '.join(fields)} WHERE id=:id"
        self.session.execute(text(sql), params)
        self.session.commit()

        return {"status": "success", "message": f"账户 {id} 已更新"}

    # ============================
    # 9. 银行存款操作
    # ============================
    
    # --- 9.1 更新银行存款本金（余额） ---
    def update_bank_deposit_principal(self, id, principal):
        """更新银行存款的本金（余额）"""
        try:
            self.session.execute(text("""
                UPDATE bank_deposits
                SET principal=:p
                WHERE id=:id
            """), {
                "p": principal,
                "id": id
            })
            self.session.commit()
            return {"status": "success", "message": f"银行存款 ID={id} 本金已更新为 {principal}"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

    # --- 9.2 增加银行存款 ---
    def add_bank_deposit(self, account_id, deposit_type, principal, interest_rate, 
                        start_date, end_date, currency="CNY", **kwargs):
        """增加一笔银行存款"""
        try:
            self.session.execute(text("""
                INSERT INTO bank_deposits (
                    account_id, deposit_type, currency, principal, interest_rate,
                    start_date, end_date, status, interest_method, notice_days, auto_renew, remark
                ) VALUES (:aid, :dtype, :currency, :p, :r, :sd, :ed, 'active',
                          :interest_method, :notice_days, :auto_renew, :remark)
            """), {
                "aid": account_id,
                "dtype": deposit_type,
                "currency": currency,
                "p": principal,
                "r": interest_rate,
                "sd": start_date,
                "ed": end_date,
                "interest_method": kwargs.get("interest_method", "at_maturity"),
                "notice_days": kwargs.get("notice_days"),
                "auto_renew": kwargs.get("auto_renew", False),
                "remark": kwargs.get("remark")
            })
            self.session.commit()
            return {"status": "success", "message": f"新增银行存款成功，本金：{principal}"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

    # --- 9.3 提取银行存款 ---
    def withdraw_bank_deposit(self, id, amount):
        """提取银行存款（更新本金）"""
        try:
            # 先获取当前本金
            result = self.session.execute(text("""
                SELECT principal FROM bank_deposits WHERE id=:id
            """), {"id": id}).fetchone()

            if not result:
                return {"error": f"银行存款 ID={id} 不存在"}

            current_principal = float(result[0])
            new_principal = current_principal - amount

            if new_principal < 0:
                return {"error": f"提取金额 {amount} 超过当前本金 {current_principal}"}

            self.session.execute(text("""
                UPDATE bank_deposits
                SET principal=:p
                WHERE id=:id
            """), {
                "p": new_principal,
                "id": id
            })
            self.session.commit()
            return {
                "status": "success",
                "message": f"提取成功，提取金额：{amount}，余额：{new_principal}"
            }
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

    # --- 9.4 更新银行存款信息 ---
    def update_bank_deposit(self, id, **kwargs):
        """更新银行存款的各项信息"""
        try:
            fields = []
            params = {"id": id}

            # 允许更新的字段
            allowed_fields = [
                "deposit_type", "currency", "principal", "interest_rate",
                "start_date", "end_date", "interest_method", "notice_days",
                "auto_renew", "status", "remark"
            ]

            for key in allowed_fields:
                if key in kwargs:
                    fields.append(f"{key} = :{key}")
                    params[key] = kwargs[key]

            if not fields:
                return {"error": "没有需要更新的字段"}

            sql = f"UPDATE bank_deposits SET {', '.join(fields)} WHERE id=:id"
            self.session.execute(text(sql), params)
            self.session.commit()

            return {"status": "success", "message": f"银行存款 ID={id} 已更新"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}

    # --- 9.5 获取银行存款信息 ---
    def get_bank_deposit(self, id):
        """获取银行存款详情"""
        try:
            result = self.session.execute(text("""
                SELECT id, account_id, deposit_type, currency, principal, interest_rate,
                       start_date, end_date, interest_method, notice_days, auto_renew, status, remark
                FROM bank_deposits
                WHERE id=:id
            """), {"id": id}).fetchone()

            if not result:
                return {"error": f"银行存款 ID={id} 不存在"}

            columns = [
                "id", "account_id", "deposit_type", "currency", "principal", 
                "interest_rate", "start_date", "end_date", "interest_method", 
                "notice_days", "auto_renew", "status", "remark"
            ]
            deposit_info = dict(zip(columns, result))
            return {"status": "success", "data": deposit_info}
        except Exception as e:
            return {"error": str(e)}

    # --- 9.6 获取账户下所有银行存款 ---
    def get_account_bank_deposits(self, account_id):
        """获取某个账户下的所有银行存款"""
        try:
            results = self.session.execute(text("""
                SELECT id, account_id, deposit_type, currency, principal, interest_rate,
                       start_date, end_date, interest_method, notice_days, auto_renew, status, remark
                FROM bank_deposits
                WHERE account_id=:aid
                ORDER BY start_date DESC
            """), {"aid": account_id}).fetchall()

            if not results:
                return {"status": "success", "data": [], "message": "该账户没有银行存款"}

            columns = [
                "id", "account_id", "deposit_type", "currency", "principal",
                "interest_rate", "start_date", "end_date", "interest_method",
                "notice_days", "auto_renew", "status", "remark"
            ]
            deposits = [dict(zip(columns, row)) for row in results]
            return {"status": "success", "data": deposits, "count": len(deposits)}
        except Exception as e:
            return {"error": str(e)}

    # --- 9.7 删除银行存款 ---
    def delete_bank_deposit(self, id):
        """删除银行存款"""
        try:
            self.session.execute(text("""
                DELETE FROM bank_deposits WHERE id=:id
            """), {"id": id})
            self.session.commit()
            return {"status": "success", "message": f"银行存款 ID={id} 已删除"}
        except Exception as e:
            self.session.rollback()
            return {"error": str(e)}
