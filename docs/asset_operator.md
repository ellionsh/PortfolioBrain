# 资产操作层（AssetOperator）
AssetOperator 是 PortfolioBrain 的交易引擎，负责：
- 买入
- 卖出
- 更新净值
- 更新状态
- 更新保险现金价值
所有操作会自动写入数据库，并与 DeepSeek Agent 完全兼容。
---
## 支持的资产类型
| 类型 | 描述 |
|------|------|
| nav_financial | 净值型理财 |
| fixed_financial | 固定收益理财 |
| bank_deposit | 银行存款 |
| insurance | 保险产品 |
---
## 代码位置
core/asset_operator.py
---
## 与 Agent 的关系
Agent 的 Operation Skill 会调用 AssetOperator：
operate(action="buy", params={...})
---
## 与 Dashboard 的关系
AssetOperator 写入的数据会被 Dashboard 读取并可视化。