# 数据迁移器（Excel → MySQL）
PortfolioBrain 提供智能迁移器，可自动识别 Excel 列名（中文/英文/混合），并自动导入 MySQL。
---
## 1. Excel 文件放置位置
`data/`
---
## 2. 文件命名规则
| 文件类型 | 命名示例 |
|---------|----------|
| 银行存款 | bank_2024.xlsx |
| 理财产品 | financial_products_2024.xlsx |
| 理财交易 | financial_transactions_2024.xlsx |
| 保险产品 | insurance_2024.xlsx |
---
## 3. 自动识别字段
字段映射见：
`migrate/mapping.py`

支持中文列名：
- 账户 → account_id  
- 本金 → principal  
- 利率 → interest_rate  
- 净值 → nav  
- 交易日期 → trade_date  
- 保费 → premium  
---
## 4. 运行迁移器
`python migrate/migrate_all.py`
系统会自动导入所有 Excel 文件。
## 5. 幂等性
重复运行不会重复导入数据。
---
