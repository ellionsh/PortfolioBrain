from core.asset_operator import AssetOperator

class OperationSkill:
    def __init__(self, conn):
        self.op = AssetOperator(conn)

    def operate(self, action: str, params: dict):
        if action == "buy":
            return self.op.buy(**params)
        elif action == "sell":
            return self.op.sell(**params)
        elif action == "update_nav":
            return self.op.update_nav(**params)
        elif action == "update_status":
            return self.op.update_status(**params)
        elif action == "update_cash_value":
            return self.op.update_cash_value(**params)
        elif action == "create_account":
            return self.op.create_account(**params)
        elif action == "delete_account":
            return self.op.delete_account(**params)
        elif action == "update_account":
            return self.op.update_account(**params)
        # ============ 银行存款操作 ============
        elif action == "add_bank_deposit":
            return self.op.add_bank_deposit(**params)
        elif action == "withdraw_bank_deposit":
            return self.op.withdraw_bank_deposit(**params)
        elif action == "update_bank_deposit":
            return self.op.update_bank_deposit(**params)
        elif action == "update_bank_deposit_principal":
            return self.op.update_bank_deposit_principal(**params)
        elif action == "get_bank_deposit":
            return self.op.get_bank_deposit(**params)
        elif action == "get_account_bank_deposits":
            return self.op.get_account_bank_deposits(**params)
        elif action == "delete_bank_deposit":
            return self.op.delete_bank_deposit(**params)
        else:
            return {"error": f"未知操作：{action}"}
