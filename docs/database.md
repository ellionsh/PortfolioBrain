# 数据库结构（MySQL · 12 张表）
PortfolioBrain 使用 MySQL 作为数据底座，包含 12 张核心表：
## 1. accounts（账户表）
存储银行账户、券商账户、保险账户等。
## 2. bank_deposits（银行存款）
支持活期、定期、通知存款、结构性存款。
## 3. financial_products（理财产品）
支持净值型、固定收益型、结构化产品。
## 4. financial_transactions（理财交易）
记录买入、卖出、分红、费用等。
## 5. financial_navs（净值）
存储净值型理财的每日净值。
## 6. insurance_products（保险产品）
支持寿险、重疾、年金、万能、医疗。
## 7. cashflows（现金流）
系统自动生成的未来现金流。
## 8. assets（资产主数据）
股票、基金、债券、商品等。
## 9. positions（每日持仓快照）
用于 Dashboard 可视化。
## 10. transactions（通用交易记录）
股票、基金等通用资产的交易。
## 11. prices（历史价格）
股票、基金等资产的历史价格。
## 12. fx_rates（汇率）
多币种资产估值所需。

完整建表语句见：
db/schema_mysql.sql