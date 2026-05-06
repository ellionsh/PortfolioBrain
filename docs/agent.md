# DeepSeek Agent（智能资产管理）
PortfolioBrain 使用 DeepSeek Chat + Tool Calling 实现智能资产管理。
---
## Agent 能做什么？
- 自动写 SQL
- 自动查询数据库
- 自动执行买入/卖出/更新净值
- 自动解释结果
- 自动分析现金流
- 自动分析风险
- 自动分析期限结构
---
## 工具（Tools）
| 工具名 | 功能 |
|--------|------|
| run_sql | 执行 SELECT SQL |
| operate | 执行资产操作 |
---
## Agent 工作流程
1. 用户输入自然语言  
2. Agent 判断是否需要查询数据库  
3. 如果需要 → 自动生成 SQL → 调用 run_sql  
4. 如果是操作 → 调用 operate  
5. Agent 解释结果并返回自然语言回答  
---
## 代码位置
agent/agent.py
agent/prompts.py
skills/sql_skill.py
skills/operation_skill.py