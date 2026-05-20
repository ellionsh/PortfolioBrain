# agent/agent_v2.py

import json
import asyncio
import time
from openai import OpenAI

from db.db import session_scope
from skills.sql_skill import SQLSkill
from skills.operation_skill import OperationSkill
from agent.prompts import AGENT_SYSTEM_PROMPT
import config
import datetime


# ---------- 工具函数 ----------

def serialize(obj):
    if isinstance(obj, (datetime.date, datetime.datetime)):
        return obj.isoformat()
    if isinstance(obj, dict):
        return {k: serialize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [serialize(v) for v in obj]
    return obj


def compress_result(result, max_items=5):
    """防止 tool 返回过大"""
    if isinstance(result, list) and len(result) > max_items:
        return result[:max_items] + [{"...": f"{len(result)} rows total"}]
    return result


# ---------- 初始化 ----------

client = OpenAI(
    api_key=config.DEEPSEEK_API_KEY,
    base_url=config.DEEPSEEK_BASE_URL
)

sql_skill = SQLSkill()


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
            "description": "资产操作（账户 / 存款 / 理财 / 保险）",
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
        query = args["query"]
        if "limit" not in query.lower():
            query += " LIMIT 10"
        return sql_skill.run_sql(query)

    if name == "operate":
        with session_scope() as session:
            op_skill = OperationSkill(session)
            return op_skill.operate(args["action"], args["params"])

    return {"error": "unknown tool"}


# ---------- 核心 Agent ----------

def agent_chat(user_query: str) -> str:
    start_total = time.time()

    messages = [
        {"role": "system", "content": AGENT_SYSTEM_PROMPT},
        {"role": "user", "content": user_query},
    ]

    # ========= STEP 1: 让模型决定是否调用工具 =========
    t0 = time.time()
    resp = client.chat.completions.create(
        model=config.DEEPSEEK_MODEL,
        messages=messages,
        tools=tools,
        tool_choice="auto",
        extra_body={"thinking": {"type": "disabled"}}
    )
    print("LLM Step1耗时:", time.time() - t0)

    msg = resp.choices[0].message

    # ========= 如果不需要 tool，直接返回 =========
    if not msg.tool_calls:
        print("总耗时:", time.time() - start_total)
        return msg.content

    # ========= STEP 2: 并发执行工具 =========
    async def run_tools():
        async def one_call(call):
            name = call.function.name
            args = json.loads(call.function.arguments)

            t1 = time.time()
            result = call_tool(name, args)
            print(f"{name}耗时:", time.time() - t1)

            result = serialize(result)
            result = compress_result(result)

            return {
                "role": "tool",
                "tool_call_id": call.id,
                "content": json.dumps(result, ensure_ascii=False),
            }

        return await asyncio.gather(*[one_call(c) for c in msg.tool_calls])

    tool_results = asyncio.run(run_tools())

    # ========= STEP 3: 二次 LLM 总结 =========
    messages.append({
        "role": "assistant",
        "content": msg.content,
        "tool_calls": msg.tool_calls
    })
    messages.extend(tool_results)

    # 控制上下文长度（关键优化）
    #messages = messages[-10:]

    t2 = time.time()
    final_resp = client.chat.completions.create(
        model=config.DEEPSEEK_MODEL,
        messages=messages,
        extra_body={"thinking": {"type": "disabled"}}
    )
    print("LLM Step2耗时:", time.time() - t2)

    print("总耗时:", time.time() - start_total)

    return final_resp.choices[0].message.content
