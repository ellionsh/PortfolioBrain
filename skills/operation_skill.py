# skills/operation_skill.py
from core.asset_operator import AssetOperator
from services.fund_nav_fetcher import FundNavFetcher
class OperationSkill:
    def __init__(self, session):

        self.op = AssetOperator(session)

    def operate(self, action: str, params: dict):
        """
        统一操作入口，根据 action 调用 AssetOperator 的对应方法。
        所有 action 名称均为强语义，避免 LLM 误判。
        """

        # ============================
        # 1. 账户操作（Account）
        # ============================
        if action == "account_create":
            return self.op.create_account(**params)

        elif action == "account_delete":
            return self.op.delete_account(**params)

        elif action == "account_update":
            return self.op.update_account(**params)

        # ============================
        # 2. 银行存款（Bank Deposit）
        # ============================
        elif action == "bank_deposit_add":
            return self.op.add_bank_deposit(**params)

        elif action == "bank_deposit_update_principal":
            return self.op.update_bank_deposit_principal(**params)

        elif action == "bank_deposit_withdraw":
            return self.op.withdraw_bank_deposit(**params)

        elif action == "bank_deposit_update":
            return self.op.update_bank_deposit(**params)

        elif action == "bank_deposit_get":
            return self.op.get_bank_deposit(**params)

        elif action == "bank_deposit_list":
            return self.op.get_account_bank_deposits(**params)

        elif action == "bank_deposit_delete":
            return self.op.delete_bank_deposit(**params)

        # ============================
        # 3. 理财产品（Financial）
        # ============================
        elif action == "financial_buy_nav":
            return self.op.buy("nav_financial", **params)

        elif action == "financial_buy_fixed":
            return self.op.buy("fixed_financial", **params)

        elif action == "financial_sell_nav":
            return self.op.sell("nav_financial", **params)

        elif action == "financial_sell_fixed":
            return self.op.sell("fixed_financial", **params)

        elif action == "financial_update_nav":
            return self.op.update_nav(**params)

        # ============================
        # 4. 保险（Insurance）
        # ============================
        elif action == "insurance_buy":
            return self.op.buy("insurance", **params)

        elif action == "insurance_update_cash_value":
            return self.op.update_cash_value(**params)

        elif action == "insurance_create":
            return self.op.create_insurance_product(**params)

        elif action == "insurance_update":
            return self.op.update_insurance_product(**params)

        elif action == "insurance_delete":
            return self.op.delete_insurance_product(**params)

        elif action == "financial_product_create":
            return self.op.create_financial_product(**params)

        elif action == "financial_product_update":
            return self.op.update_financial_product(**params)

        elif action == "financial_product_delete":
            return self.op.delete_financial_product(**params)

        # ============================
        # 5. 基金（Fund）
        # ============================
        elif action == "fund_buy":
            return self.op.buy("fund", **params)

        elif action == "fund_sell":
            return self.op.sell("fund", **params)

        elif action == "fund_product_create":
            fund_code = params.get("fund_code")
            if not fund_code:
                return {"error": "缺少基金代码"}

            fund_name = params.get("fund_name")
            if not fund_name or str(fund_name).strip() == "":
                try:
                    fund_name = FundNavFetcher.get_fund_name(fund_code)
                except Exception as exc:
                    return {"error": f"获取基金名称失败: {exc}"}
                if not fund_name:
                    return {"error": "无法获取基金名称"}

            nav = params.get("nav")
            if nav is None:
                try:
                    nav_info = FundNavFetcher.get_latest_nav(fund_code)
                    nav = nav_info.get("nav")
                except Exception as exc:
                    return {"error": f"获取基金净值失败: {exc}"}
                if nav is None:
                    return {"error": "无法获取基金净值"}

            new_params = dict(params)
            new_params["fund_name"] = fund_name
            if nav is not None:
                new_params["nav"] = nav
            return self.op.create_fund_product(**new_params)

        elif action == "fund_product_update":
            return self.op.update_fund_product(**params)

        elif action == "fund_product_delete":
            return self.op.delete_fund_product(**params)

        elif action == "fund_update_nav":
            return self.op.update_fund_nav(**params)

        # ============================
        # 未知操作
        # ============================
        else:
            return {"error": f"未知操作：{action}"}
