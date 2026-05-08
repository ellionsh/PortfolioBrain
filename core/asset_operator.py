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

    # ============================
    # 6. 新增账户
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
    def update_bank_deposit_principal(self, id, new_principal):
        """更新银行存款的本金（余额）"""
        try:
            self.session.execute(text("""
                UPDATE bank_deposits
                SET principal=:p
                WHERE id=:id
            """), {
                "p": new_principal,
                "id": id
            })
            self.session.commit()
            return {"status": "success", "message": f"银行存款 ID={id} 本金已更新为 {new_principal}"}
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
    def withdraw_bank_deposit(self, id, withdraw_amount):
        """提取银行存款（更新本金）"""
        try:
            # 先获取当前本金
            result = self.session.execute(text("""
                SELECT principal FROM bank_deposits WHERE id=:id
            """), {"id": id}).fetchone()

            if not result:
                return {"error": f"银行存款 ID={id} 不存在"}

            current_principal = float(result[0])
            new_principal = current_principal - withdraw_amount

            if new_principal < 0:
                return {"error": f"提取金额 {withdraw_amount} 超过当前本金 {current_principal}"}

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
                "message": f"提取成功，提取金额：{withdraw_amount}，余额：{new_principal}"
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
