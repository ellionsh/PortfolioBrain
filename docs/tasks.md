# 自动任务系统（Scheduler）
PortfolioBrain 提供每日自动任务：
---
## 每日任务
| 时间 | 任务 |
|------|------|
| 06:00 | 更新净值 |
| 06:05 | 更新基金净值 |
| 06:10 | 生成现金流 |
| 06:20 | 到期提醒 |
---
## 启动任务系统
`python tasks/scheduler.py`
## 任务代码位置
- `tasks/job_update_nav.py`
- `tasks/job_update_fund_navs.py`
- `tasks/job_generate_cashflows.py`
- `tasks/job_maturity_alert.py`
- `tasks/scheduler.py`
---
