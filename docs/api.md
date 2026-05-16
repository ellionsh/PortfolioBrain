# Web API 文档
PortfolioBrain 提供 REST API，供 Dashboard、移动端、前端使用。
---
## 1. Agent 对话
**POST /chat**
{ "query": "未来三个月我会缺钱吗" }
## 2. 资产总览
GET /summary
返回：
总资产估值
未来 6 个月净现金流
## 3. 持仓
GET /positions
## 4. 未来现金流
GET /cashflows
## 5. 理财产品
GET /products
## 6. 净值曲线
GET /nav/<product_code>
## 7. 操作接口
POST /operate
{
  "action": "buy",
  "params": { ... }
}
## 8. 重新生成现金流
POST /generate_cashflows
