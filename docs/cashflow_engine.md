# 现金流引擎（CashflowEngine）
CashflowEngine 是 PortfolioBrain 的“心脏”，自动生成未来现金流。
---
## 支持的现金流类型
| 资产类型 | 现金流 |
|----------|--------|
| 银行存款 | 利息 + 到期兑付 |
| 固定收益理财 | 付息 + 到期兑付 |
| 净值型理财 | 分红 + 赎回 |
| 保险产品 | 缴费 |
---
## 运行方式
python tasks/job_generate_cashflows.py
或由自动任务系统每日执行。

代码位置
core/cashflow_engine.py
---
## 幂等性
重复运行不会重复生成现金流。
---
