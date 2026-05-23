# agent/agent.py
import json
import httpx
from openai import OpenAI, APITimeoutError, APIConnectionError, RateLimitError, APIStatusError

from db.db import session_scope
from skills.sql_skill import SQLSkill
from skills.operation_skill import OperationSkill
from agent.prompts import AGENT_SYSTEM_PROMPT
import config
import datetime
import time
from sqlalchemy import text
from sqlalchemy.exc import OperationalError, InterfaceError, DBAPIError
from decimal import Decimal

class LLMRequestError(Exception):
    pass

class LLMTimeoutError(LLMRequestError):
    pass

def serialize(obj):
    if isinstance(obj, (datetime.date, datetime.datetime)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, dict):
        return {k: serialize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [serialize(v) for v in obj]
    return obj


def _xnpv(rate, cashflows):
    t0 = cashflows[0][0]
    total = 0.0
    for d, amt in cashflows:
        days = (d - t0).days / 365
        total += amt / ((1 + rate) ** days)
    return total


def _xirr(cashflows):
    if len(cashflows) < 2:
        return None
    cashflows = sorted(cashflows, key=lambda x: x[0])
    amounts = [amt for _, amt in cashflows]
    if all(a >= 0 for a in amounts) or all(a <= 0 for a in amounts):
        return None

    guess = 0.1
    for _ in range(100):
        f = _xnpv(guess, cashflows)
        if abs(f) < 1e-6:
            return guess
        t0 = cashflows[0][0]
        df = 0.0
        for d, amt in cashflows:
            days = (d - t0).days / 365
            df -= (days * amt) / ((1 + guess) ** (days + 1))
        if df == 0:
            break
        guess = guess - f / df
        if guess <= -0.999999:
            guess = -0.999999

    low, high = -0.9999, 10.0
    f_low = _xnpv(low, cashflows)
    f_high = _xnpv(high, cashflows)
    if f_low == 0:
        return low
    if f_high == 0:
        return high
    if f_low * f_high > 0:
        return None
    mid = None
    for _ in range(100):
        mid = (low + high) / 2
        f_mid = _xnpv(mid, cashflows)
        if abs(f_mid) < 1e-6:
            return mid
        if f_low * f_mid < 0:
            high = mid
            f_high = f_mid
        else:
            low = mid
            f_low = f_mid
    return mid


def _financial_annualized_yield(session, product_id=None, product_code=None, product_name=None):
    def _fetch(where_clause, params):
        rows = session.execute(text(f"""
        SELECT fp.id, fp.product_name, fp.product_code, fp.type,
               fp.currency, fp.is_nav_based, fp.shares,
               (
                   SELECT fn.nav
                   FROM financial_navs fn
                   WHERE fn.product_code = fp.product_code
                   ORDER BY fn.date DESC
                   LIMIT 1
               ) AS nav
        FROM financial_products fp
        {where_clause}
        ORDER BY fp.end_date IS NOT NULL, fp.end_date ASC, fp.id DESC
    """), params).mappings().all()
        return [dict(row) for row in rows]

    params = {}
    where_parts = []
    if product_id is not None:
        where_parts.append("fp.id = :pid")
        params["pid"] = product_id
    if product_code:
        where_parts.append("fp.product_code = :pcode")
        params["pcode"] = product_code
    if product_name:
        where_parts.append("fp.product_name = :pname")
        params["pname"] = product_name
    where_clause = f"WHERE {' AND '.join(where_parts)}" if where_parts else ""
    data = _fetch(where_clause, params)
    if not data and product_id is None and (product_code or product_name):
        params = {}
        where_parts = []
        if product_code:
            where_parts.append("fp.product_code LIKE :pcode")
            params["pcode"] = f"%{product_code}%"
        if product_name:
            where_parts.append("fp.product_name LIKE :pname")
            params["pname"] = f"%{product_name}%"
        where_clause = f"WHERE {' AND '.join(where_parts)}" if where_parts else ""
        data = _fetch(where_clause, params)
    if not data:
        return []
    product_ids = [row.get("id") for row in data if row.get("id") is not None]
    cashflow_map = {pid: [] for pid in product_ids}
    if product_ids:
        placeholders = ", ".join([f":id{i}" for i in range(len(product_ids))])
        params = {f"id{i}": product_ids[i] for i in range(len(product_ids))}
        tx_rows = session.execute(text(f"""
            SELECT product_id, trade_date, trade_type, amount, fee
            FROM financial_transactions
            WHERE product_id IN ({placeholders})
        """), params).fetchall()
        for product_id, trade_date, trade_type, amount, fee in tx_rows:
            try:
                amount_value = float(amount) if amount is not None else 0.0
            except (TypeError, ValueError):
                continue
            fee_value = 0.0
            if fee is not None:
                try:
                    fee_value = float(fee)
                except (TypeError, ValueError):
                    fee_value = 0.0
            if trade_type == "buy":
                signed_amount = -abs(amount_value) - fee_value
            else:
                signed_amount = abs(amount_value) - fee_value
            cashflow_map.setdefault(product_id, []).append((trade_date, signed_amount))

    today = datetime.date.today()
    for row in data:
        pid = row.get("id")
        cashflows = list(cashflow_map.get(pid, []))
        is_nav_based = row.get("is_nav_based") in (1, True) or row.get("type") == "nav"
        shares = row.get("shares")
        nav = row.get("nav")
        market_value = None
        try:
            if is_nav_based:
                if shares is not None and nav is not None:
                    market_value = float(shares) * float(nav)
            else:
                if shares is not None:
                    market_value = float(shares)
        except (TypeError, ValueError):
            market_value = None
        if market_value is not None:
            cashflows.append((today, market_value))
        row["annualized_yield"] = _xirr(cashflows) if cashflows else None
    return data


def _fund_annualized_yield(session, fund_id=None, fund_code=None, fund_name=None):
    def _fetch(where_clause, params):
        rows = session.execute(text(f"""
        SELECT f.id, f.fund_name, f.fund_code, f.currency, f.shares,
               (
                   SELECT fn.nav
                   FROM fund_navs fn
                   WHERE fn.fund_code = f.fund_code
                   ORDER BY fn.date DESC
                   LIMIT 1
               ) AS nav
        FROM fund_products f
        {where_clause}
        ORDER BY f.end_date IS NOT NULL, f.end_date ASC, f.id DESC
    """), params).mappings().all()
        return [dict(row) for row in rows]

    params = {}
    where_parts = []
    if fund_id is not None:
        where_parts.append("f.id = :fid")
        params["fid"] = fund_id
    if fund_code:
        where_parts.append("f.fund_code = :fcode")
        params["fcode"] = fund_code
    if fund_name:
        where_parts.append("f.fund_name = :fname")
        params["fname"] = fund_name
    where_clause = f"WHERE {' AND '.join(where_parts)}" if where_parts else ""
    data = _fetch(where_clause, params)
    if not data and fund_id is None and (fund_code or fund_name):
        params = {}
        where_parts = []
        if fund_code:
            where_parts.append("f.fund_code LIKE :fcode")
            params["fcode"] = f"%{fund_code}%"
        if fund_name:
            where_parts.append("f.fund_name LIKE :fname")
            params["fname"] = f"%{fund_name}%"
        where_clause = f"WHERE {' AND '.join(where_parts)}" if where_parts else ""
        data = _fetch(where_clause, params)
    if not data:
        return []
    fund_ids = [row.get("id") for row in data if row.get("id") is not None]
    cashflow_map = {fid: [] for fid in fund_ids}
    if fund_ids:
        placeholders = ", ".join([f":id{i}" for i in range(len(fund_ids))])
        params = {f"id{i}": fund_ids[i] for i in range(len(fund_ids))}
        tx_rows = session.execute(text(f"""
            SELECT fund_id, trade_date, trade_type, amount, fee
            FROM fund_transactions
            WHERE fund_id IN ({placeholders})
        """), params).fetchall()
        for fund_id, trade_date, trade_type, amount, fee in tx_rows:
            if trade_date is None:
                continue
            try:
                amount_value = float(amount) if amount is not None else 0.0
            except (TypeError, ValueError):
                continue
            fee_value = 0.0
            if fee is not None:
                try:
                    fee_value = float(fee)
                except (TypeError, ValueError):
                    fee_value = 0.0
            if trade_type == "buy":
                signed_amount = -abs(amount_value) - fee_value
            else:
                signed_amount = abs(amount_value) - fee_value
            cashflow_map.setdefault(fund_id, []).append((trade_date, signed_amount))

    today = datetime.date.today()
    for row in data:
        fid = row.get("id")
        cashflows = list(cashflow_map.get(fid, []))
        shares = row.get("shares")
        nav = row.get("nav")
        market_value = None
        try:
            if shares is not None and nav is not None:
                market_value = float(shares) * float(nav)
        except (TypeError, ValueError):
            market_value = None
        if market_value is not None:
            cashflows.append((today, market_value))
        row["annualized_yield"] = _xirr(cashflows) if cashflows else None
    return data


# 使用 OpenAI SDK 调用 DeepSeek API（官方推荐方式）
client = OpenAI(
    api_key=config.DEEPSEEK_API_KEY,
    base_url=config.DEEPSEEK_BASE_URL,
    timeout=httpx.Timeout(config.LLM_TIMEOUT_SECONDS),
    max_retries=config.LLM_MAX_RETRIES,
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
    },
    {
        "type": "function",
        "function": {
            "name": "calc_annualized_yield",
            "description": "计算基金或理财产品年化收益率（按现金流 XIRR 方法）",
            "parameters": {
                "type": "object",
                "properties": {
                    "product_type": {"type": "string", "description": "fund 或 financial"},
                    "product_id": {"type": "integer", "description": "产品 ID，可选"},
                    "product_code": {"type": "string", "description": "理财产品代码，可选"},
                    "product_name": {"type": "string", "description": "理财产品名称，可选"},
                    "fund_code": {"type": "string", "description": "基金代码，可选"},
                    "fund_name": {"type": "string", "description": "基金名称，可选"}
                },
                "required": ["product_type"]
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
    if name == "calc_annualized_yield":
        product_type = args.get("product_type")
        product_id = args.get("product_id")
        product_code = args.get("product_code")
        product_name = args.get("product_name")
        fund_code = args.get("fund_code")
        fund_name = args.get("fund_name")
        with session_scope() as session:
            if product_type == "financial":
                return _financial_annualized_yield(
                    session,
                    product_id=product_id,
                    product_code=product_code,
                    product_name=product_name,
                )
            if product_type == "fund":
                return _fund_annualized_yield(
                    session,
                    fund_id=product_id,
                    fund_code=fund_code,
                    fund_name=fund_name,
                )
        return {"error": "unsupported product_type"}
    return {"error": "unknown tool"}

def _is_db_connection_error(exc: Exception) -> bool:
    if isinstance(exc, (OperationalError, InterfaceError)):
        return True
    if isinstance(exc, DBAPIError) and exc.connection_invalidated:
        return True
    msg = str(exc).lower()
    indicators = [
        "can't connect",
        "connection refused",
        "connection timed out",
        "lost connection",
        "server has gone away",
        "unknown server host",
        "name or service not known",
        "host is unreachable",
        "connection error",
    ]
    return any(indicator in msg for indicator in indicators)


def _db_connection_tip() -> str:
    return (
        "当前数据库连接出现了问题。若 MySQL 与服务不在同一台服务器，"
        "请确认 PB_DB_HOST/PB_DB_PORT 配置正确，并确保 MySQL 允许远程连接"
        "（bind-address、用户授权）。"
    )


def agent_chat(user_query: str) -> str:
    messages = [
        {"role": "system", "content": AGENT_SYSTEM_PROMPT},
        {"role": "user", "content": user_query},
    ]
    start_total = time.time()
    while True:
        t0 = time.time()
        try:
            resp = client.chat.completions.create(
                model=config.DEEPSEEK_MODEL,
                messages=messages,
                tools=tools,
                # extra_body={"thinking": {"type": "disabled"}}
            )
        except APITimeoutError as exc:
            raise LLMTimeoutError("LLM 请求超时，请稍后重试。") from exc
        except (APIConnectionError, RateLimitError) as exc:
            raise LLMRequestError("LLM 连接失败，请稍后重试。") from exc
        except APIStatusError as exc:
            raise LLMRequestError(f"LLM 接口错误: {exc.status_code}") from exc
        print("LLM 耗时:", time.time() - t0)

        msg = resp.choices[0].message

        # 工具调用
        if msg.tool_calls:
            assistant_msg = {
                "role": "assistant",
                "content": msg.content,
                "tool_calls": msg.tool_calls
            }
            reasoning_content = getattr(msg, "reasoning_content", None)
            if reasoning_content:
                assistant_msg["reasoning_content"] = reasoning_content
            reasoning = getattr(msg, "reasoning", None)
            if reasoning:
                assistant_msg["reasoning"] = reasoning
            messages.append(assistant_msg)

            for call in msg.tool_calls:
                name = call.function.name
                args = json.loads(call.function.arguments)
                try:
                    result = call_tool(name, args)
                except Exception as exc:
                    if _is_db_connection_error(exc):
                        result = {"error": _db_connection_tip()}
                    else:
                        result = {"error": f"工具调用失败: {exc}"}
                result = serialize(result)

                messages.append({
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": json.dumps(result, ensure_ascii=False),
                })

            continue
        print("总耗时:", time.time() - start_total)
        return msg.content
