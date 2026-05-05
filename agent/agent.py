import json
from openai import OpenAI
from db.db import get_conn
from skills.sql_skill import SQLSkill
from skills.operation_skill import OperationSkill
from agent.prompts import AGENT_SYSTEM_PROMPT

import config
from deepseek import DeepSeekClient

client = DeepSeekClient(
    api_key=config.DEEPSEEK_API_KEY,
    base_url=config.DEEPSEEK_BASE_URL
)


# DeepSeek API
#client = OpenAI(
#    api_key="sk-24e6d75c061c4c9bb3fd30f2a93ebe7c",
#    base_url="https://api.deepseek.com"
#)

# 初始化数据库连接
conn = get_conn()
sql_skill = SQLSkill(conn)
op_skill = OperationSkill(conn)

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
            "description": "执行资产操作（买入/卖出/更新净值/更新状态/更新保险现金价值）",
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
            for call in msg.tool_calls:
                name = call.function.name
                args = json.loads(call.function.arguments)
                result = call_tool(name, args)

                messages.append({
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": json.dumps(result, ensure_ascii=False),
                })
            continue

        # 最终回答
        return msg.content
