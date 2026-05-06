# agent/agent.py
import json
from openai import OpenAI

from db.db import get_engine, get_session
from skills.sql_skill import SQLSkill
from skills.operation_skill import OperationSkill
from agent.prompts import AGENT_SYSTEM_PROMPT
import config

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


# 工具定义
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
            "description": "执行资产操作（买入/卖出/更新净值/更新状态/更新保险现金价值/新增账户/删除账户/更新账户）",
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

    while True:
        resp = client.chat.completions.create(
            model="deepseek-chat",
            messages=messages,
            tools=tools,
        )

        msg = resp.choices[0].message

        # 工具调用
        if msg.tool_calls:
            # 先把 assistant 的 tool_calls 消息加入 messages
            messages.append({
                "role": "assistant",
                "content": None,
                "tool_calls": msg.tool_calls
            })

            # 执行每个工具
            for call in msg.tool_calls:
                name = call.function.name
                args = json.loads(call.function.arguments)
                result = call_tool(name, args)

                # 工具返回消息
                messages.append({
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": json.dumps(result, ensure_ascii=False),
                })

            # 继续下一轮
            continue

        # 最终回答
        return msg.content



