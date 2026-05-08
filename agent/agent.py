# agent/agent.py
import json
from openai import OpenAI

from db.db import get_engine, get_session
from skills.sql_skill import SQLSkill
from skills.operation_skill import OperationSkill
from agent.prompts import AGENT_SYSTEM_PROMPT
import config
import datetime
import time

def serialize(obj):
    if isinstance(obj, (datetime.date, datetime.datetime)):
        return obj.isoformat()
    if isinstance(obj, dict):
        return {k: serialize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [serialize(v) for v in obj]
    return obj


# 使用 OpenAI SDK 调用 DeepSeek API（官方推荐方式）
client = OpenAI(
    api_key=config.DEEPSEEK_API_KEY,
    base_url=config.DEEPSEEK_BASE_URL
)

# 全局 SQLAlchemy engine + session
engine = get_engine()
session = get_session()

# 初始化技能
sql_skill = SQLSkill()              # 自动使用 engine
op_skill = OperationSkill(session)  # 使用 SQLAlchemy session


# 工具定义（已合并新版 LLM 友好描述）
tools = [
    {
        "type": "function",
        "function": {
            "name": "run_sql",
            "description": "执行 SELECT SQL 查询",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"}
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "operate",
            "description": (
               "资产操作技能（OperationSkill）。用于执行账户管理、银行存款、理财产品、保险等资产操作。"
                "每个 action 都有明确语义，不可混用。请严格根据用户意图选择正确的 action。\n\n"

                "【1. 账户管理（account_*）】\n"
                "- account_create：创建账户\n"
                "- account_delete：删除账户\n"
                "- account_update：更新账户（只能更新 name、institution、type、currency）\n\n"

                "⚠ account_update 只能用于账户本身，不可用于银行存款。\n\n"

                "【2. 银行存款（bank_deposit_*）】\n"
                "- bank_deposit_add：新增银行存款\n"
                "- bank_deposit_update_principal：更新银行存款本金（余额）\n"
                "- bank_deposit_withdraw：提取银行存款（减少本金）\n"
                "- bank_deposit_update：更新银行存款信息（利率、日期、备注等）\n"
                "- bank_deposit_get：获取单条银行存款\n"
                "- bank_deposit_list：获取账户下所有银行存款\n"
                "- bank_deposit_delete：删除银行存款\n\n"

                "⚠ 更新余额必须使用 bank_deposit_update_principal。\n"
                "⚠ 提取存款必须使用 bank_deposit_withdraw。\n"
                "⚠ 更新存款信息必须使用 bank_deposit_update。\n"
                "⚠ 银行存款相关操作绝不能使用 account_update。\n\n"

                "【3. 理财产品（financial_*）】\n"
                "- financial_buy_nav：买入净值型理财\n"
                "- financial_buy_fixed：买入固定收益理财\n"
                "- financial_sell_nav：赎回净值型理财\n"
                "- financial_sell_fixed：兑付固定收益理财\n"
                "- financial_update_nav：更新净值\n\n"

                "【4. 保险（insurance_*）】\n"
                "- insurance_buy：缴纳保险保费\n"
                "- insurance_update_cash_value：更新保险现金价值\n"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {"type": "string"},
                    "params": {"type": "object"}
                },
                "required": ["action", "params"]
            }
        }
    }
]


def call_tool(name, args):
    if name == "run_sql":
        return sql_skill.run_sql(args["query"])
    if name == "operate":
        return op_skill.operate(args["action"], args["params"])
    return {"error": "unknown tool"}


def agent_chat(user_query: str) -> str:
    messages = [
        {"role": "system", "content": AGENT_SYSTEM_PROMPT},
        {"role": "user", "content": user_query},
    ]
    start_total = time.time()
    while True:
        t0 = time.time()
        resp = client.chat.completions.create(
            model=config.DEEPSEEK_MODEL,
            messages=messages,
            tools=tools,
            extra_body={"thinking": {"type": "disabled"}}
        )
        print("LLM 耗时:", time.time() - t0)

        msg = resp.choices[0].message

        # 工具调用
        if msg.tool_calls:
            assistant_msg = {
                "role": "assistant",
                "content": msg.content,
                "tool_calls": msg.tool_calls
            }
            messages.append(assistant_msg)

            for call in msg.tool_calls:
                name = call.function.name
                args = json.loads(call.function.arguments)
                result = call_tool(name, args)
                result = serialize(result)

                messages.append({
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": json.dumps(result, ensure_ascii=False),
                })

            continue
        print("总耗时:", time.time() - start_total)
        return msg.content

