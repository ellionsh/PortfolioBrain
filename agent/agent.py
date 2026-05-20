# agent/agent.py
import json
from openai import OpenAI

from db.db import session_scope
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

# 初始化技能
sql_skill = SQLSkill()              # 自动使用 engine


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
                "资产操作工具。严格按用户意图选择 action。\n\n"
                "账户：account_create / account_delete / account_update（仅账户字段）\n"
                "银行存款：bank_deposit_add / bank_deposit_update_principal / "
                "bank_deposit_withdraw / bank_deposit_update / "
                "bank_deposit_get / bank_deposit_list / bank_deposit_delete\n"
                "理财：financial_buy_nav / financial_buy_fixed / "
                "financial_sell_nav / financial_sell_fixed / financial_update_nav\n"
                "保险：insurance_buy / insurance_update_cash_value / "
                "insurance_create / insurance_update / insurance_delete\n"
                "基金：fund_buy / fund_sell / fund_product_create / "
                "fund_product_update / fund_product_delete / fund_update_nav\n\n"
                "规则：\n"
                "- 更新存款本金/余额 -> bank_deposit_update_principal\n"
                "- 提取存款 -> bank_deposit_withdraw\n"
                "- 修改存款信息 -> bank_deposit_update\n"
                "- 银行存款相关操作禁止用 account_update\n"
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
        with session_scope() as session:
            op_skill = OperationSkill(session)
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
