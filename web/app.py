# web/app.py

import datetime
import math

import pandas as pd
from skills.operation_skill import OperationSkill
from services.fund_nav_fetcher import FundNavFetcher
from sqlalchemy import text

def serialize(obj):
    if obj is None:
        return None
    try:
        if pd.isna(obj):
            return None
    except Exception:
        pass
    if isinstance(obj, float) and math.isnan(obj):
        return None
    if isinstance(obj, (datetime.date, datetime.datetime)):
        return obj.isoformat()
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

from flask import Flask, request, jsonify
from flask_cors import CORS
import config

from agent.agent import agent_chat
from core.cashflow_engine import CashflowEngine
from db.db import session_scope
from web.auth import auth_required, authenticate_user, create_user, issue_token, ensure_auth_ready

app = Flask(__name__)
CORS(app)

# 必要的认证配置检查
if config.REQUIRE_AUTH and not config.AUTH_SECRET:
    raise RuntimeError("PB_AUTH_SECRET is required when PB_REQUIRE_AUTH=true")
ensure_auth_ready()



@app.route("/")
def index():
    return {
        "status": "ok",
        "message": "PortfolioBrain API is running",
        "endpoints": [
            "/chat",
            "/summary",
            "/positions",
            "/cashflows",
            "/products",
            "/fund_products",
            "/nav/<product_code>",
            "/operate"
        ]
    }


@app.route("/login", methods=["POST"])
def login():
    data = request.json or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""
    if not username or not password:
        return jsonify({"error": "缺少用户名或密码"}), 400
    user = authenticate_user(username, password)
    if not user:
        return jsonify({"error": "用户名或密码错误"}), 401
    token = issue_token(user)
    return jsonify({
        "access_token": token,
        "token_type": "Bearer",
        "expires_in_minutes": config.AUTH_EXPIRES_MINUTES,
        "user": user,
    })


@app.route("/register", methods=["POST"])
def register():
    if not config.ALLOW_REGISTER:
        return jsonify({"error": "注册功能未开启"}), 403
    data = request.json or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""
    if not username or not password:
        return jsonify({"error": "缺少用户名或密码"}), 400
    if len(username) < 3 or len(password) < 6:
        return jsonify({"error": "用户名至少3位，密码至少6位"}), 400
    user = create_user(username, password)
    if not user:
        return jsonify({"error": "用户名已存在"}), 409
    token = issue_token(user)
    return jsonify({
        "access_token": token,
        "token_type": "Bearer",
        "expires_in_minutes": config.AUTH_EXPIRES_MINUTES,
        "user": user,
    })


@app.route("/me", methods=["GET"])
@auth_required
def me():
    from flask import g
    return jsonify({"user": g.current_user})

# ============================
# 1. Flutter API 接口（返回 JSON 数据）
# ============================

@app.route("/accounts", methods=["GET"])
@auth_required
def get_accounts():
    with session_scope() as session:
        df = pd.read_sql(text("SELECT * FROM accounts ORDER BY id"), session.bind)
        data = df.to_dict(orient="records")
        return jsonify(serialize(data))

@app.route("/bank_deposits", methods=["GET"])
@auth_required
def get_bank_deposits():
    with session_scope() as session:
        df = pd.read_sql(text("""
        SELECT id, account_id, deposit_type, principal, interest_rate,
               start_date, end_date, status
        FROM bank_deposits
        ORDER BY id DESC
    """), session.bind)
        data = df.to_dict(orient="records")
        return jsonify(serialize(data))

@app.route("/cashflows", methods=["GET"])
@auth_required
def get_cashflows_api():
    with session_scope() as session:
        df = pd.read_sql(text("""
            SELECT id, source_type, source_id, account_id,
                   date, amount, currency, direction, description
            FROM cashflows
            WHERE date >= CURDATE()
            ORDER BY date
        """), session.bind)
        data = df.to_dict(orient="records")
        return jsonify(serialize(data))

@app.route("/insurance_products", methods=["GET"])
@auth_required
def get_insurance_products():
    with session_scope() as session:
        df = pd.read_sql(text("""
        SELECT id, account_id, product_name, company, type,
               premium, premium_freq, premium_years,
               coverage_amount, start_date, end_date, cash_value,
               status, remark
        FROM insurance_products
        ORDER BY id DESC
    """), session.bind)
        data = df.to_dict(orient="records")
        return jsonify(serialize(data))

@app.route("/financial_products", methods=["GET"])
@auth_required
def get_financial_products():
    with session_scope() as session:
        df = pd.read_sql(text("""
            SELECT fp.id, fp.account_id, fp.product_name, fp.product_code, fp.type,
                   fp.currency, fp.is_nav_based, fp.risk_level,
                   fp.min_redeem_unit, fp.shares, fp.principal,
                   fp.expected_yield, fp.start_date, fp.end_date,
                   fp.pay_freq, fp.status, fp.remark,
                   (
                       SELECT fn.nav
                       FROM financial_navs fn
                       WHERE fn.product_code = fp.product_code
                       ORDER BY fn.date DESC
                       LIMIT 1
                   ) AS nav
            FROM financial_products fp
            ORDER BY fp.end_date IS NOT NULL, fp.end_date ASC, fp.id DESC
        """), session.bind)
        data = df.to_dict(orient="records")
        if data:
            product_ids = [row.get("id") for row in data if row.get("id") is not None]
            cashflow_map = {pid: [] for pid in product_ids}
            if product_ids:
                placeholders = ", ".join([f":id{i}" for i in range(len(product_ids))])
                params = {f"id{i}": product_ids[i] for i in range(len(product_ids))}
                rows = session.execute(text(f"""
                    SELECT product_id, trade_date, trade_type, amount, fee
                    FROM financial_transactions
                    WHERE product_id IN ({placeholders})
                """), params).fetchall()
                for product_id, trade_date, trade_type, amount, fee in rows:
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
        return jsonify(serialize(data))

@app.route("/fund_products", methods=["GET"])
@auth_required
def get_fund_products():
    with session_scope() as session:
        df = pd.read_sql(text("""
            SELECT f.id, f.account_id, f.fund_name, f.fund_code, f.currency,
                   f.shares, f.principal, f.start_date, f.end_date,
                   f.status, f.remark,
                   (
                       SELECT fn.nav
                       FROM fund_navs fn
                       WHERE fn.fund_code = f.fund_code
                       ORDER BY fn.date DESC
                       LIMIT 1
                   ) AS nav
            FROM fund_products f
            ORDER BY f.end_date IS NOT NULL, f.end_date ASC, f.id DESC
        """), session.bind)
        data = df.to_dict(orient="records")
        fund_ids = [row.get("id") for row in data if row.get("id") is not None]
        cashflow_map = {fid: [] for fid in fund_ids}
        if fund_ids:
            placeholders = ", ".join([f":id{i}" for i in range(len(fund_ids))])
            params = {f"id{i}": fund_ids[i] for i in range(len(fund_ids))}
            rows = session.execute(text(f"""
                SELECT fund_id, trade_date, trade_type, amount, fee
                FROM fund_transactions
                WHERE fund_id IN ({placeholders})
            """), params).fetchall()
            for fund_id, trade_date, trade_type, amount, fee in rows:
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
        return jsonify(serialize(data))

@app.route("/fund_meta", methods=["GET"])
@auth_required
def fund_meta():
    code = request.args.get("fund_code", "").strip()
    if not code:
        return jsonify({"error": "缺少基金代码"}), 400
    try:
        name = FundNavFetcher.get_fund_name(code)
        nav_info = FundNavFetcher.get_latest_nav(code)
        nav = nav_info.get("nav") if isinstance(nav_info, dict) else None
        date = nav_info.get("date") if isinstance(nav_info, dict) else None
        if not name and nav is None:
            return jsonify({"error": "无法获取基金信息"}), 404
        return jsonify(serialize({
            "fund_name": name,
            "nav": nav,
            "nav_date": date,
        }))
    except Exception as exc:
        return jsonify({"error": f"获取基金信息失败: {exc}"}), 500

@app.route("/financial_transactions", methods=["GET"])
@auth_required
def get_financial_transactions():
    with session_scope() as session:
        df = pd.read_sql(text("""
            SELECT id, product_id, account_id, trade_date,
                   trade_type, shares, amount, nav
            FROM financial_transactions
            ORDER BY trade_date DESC
        """), session.bind)
        data = df.to_dict(orient="records")
        return jsonify(serialize(data))


# ============================
# 1. Agent 对话接口
# ============================
@app.route("/chat", methods=["POST"])
@auth_required
def chat():
    q = request.json.get("query", "")
    return jsonify({"response": agent_chat(q)})


# ============================
# 2. 资产总览
# ============================
@app.route("/summary", methods=["GET"])
@auth_required
def summary():
    with session_scope() as session:
        df_summary = pd.read_sql(text("SELECT * FROM asset_summary_view"), session.bind)

        bank_value = float(df_summary["bank_assets"][0] or 0)
        financial_value = float(df_summary["financial_assets"][0] or 0)
        fund_value = float(df_summary["fund_assets"][0] or 0)
        insurance_value = float(df_summary["insurance_assets"][0] or 0)
        total_assets = float(df_summary["total_assets"][0] or 0)

        df_cf = pd.read_sql(text("""
            SELECT COALESCE(SUM(amount),0) AS v 
            FROM cashflows
            WHERE date >= CURDATE()
            AND date < DATE_ADD(CURDATE(), INTERVAL 180 DAY)
        """), session.bind)
        future_6m_cf = float(df_cf["v"][0] or 0)

        return {
            "total_assets": total_assets,
            "bank_assets": bank_value,
            "financial_assets": financial_value,
            "fund_assets": fund_value,
            "insurance_assets": insurance_value,
            "future_6m_cf": future_6m_cf
        }




# ============================
# 3. 持仓列表
# ============================
@app.route("/positions", methods=["GET"])
@auth_required
def positions():
    with session_scope() as session:
        df = pd.read_sql(text("""
            SELECT date, account_id, asset_code, shares, cost, market_value, currency
            FROM positions
            ORDER BY date DESC
            LIMIT 200
        """), session.bind)
        return df.to_dict(orient="records")


# ============================
# 4. 未来现金流
# ============================
@app.route("/cashflows", methods=["GET"])
@auth_required
def cashflows():
    with session_scope() as session:
        df = pd.read_sql(text("""
            SELECT date, amount, currency, direction, description
            FROM cashflows
            WHERE date >= CURDATE()
            ORDER BY date
        """), session.bind)
        return df.to_dict(orient="records")


# ============================
# 5. 理财产品列表
# ============================
@app.route("/products", methods=["GET"])
@auth_required
def products():
    with session_scope() as session:
        df = pd.read_sql(text("""
            SELECT id, product_name, product_code, type, currency,
                   principal, expected_yield, start_date, end_date, status
            FROM financial_products
            ORDER BY id DESC
        """), session.bind)
        return df.to_dict(orient="records")


# ============================
# 6. 净值曲线
# ============================
@app.route("/nav/<product_code>", methods=["GET"])
@auth_required
def nav_curve(product_code):
    with session_scope() as session:
        df = pd.read_sql(text("""
            SELECT date, nav
            FROM financial_navs
            WHERE product_code=:code
            ORDER BY date
        """), session.bind, params={"code": product_code})
        return df.to_dict(orient="records")


# ============================
# 7. 理财期限结构
# ============================
@app.route("/maturity", methods=["GET"])
@auth_required
def maturity():
    with session_scope() as session:
        df = pd.read_sql(text("""
            SELECT product_name, start_date, end_date
            FROM financial_products
            WHERE end_date IS NOT NULL
        """), session.bind)
        return df.to_dict(orient="records")


# ============================
# 8. 资产操作接口（买入/卖出/更新净值）
# ============================
@app.route("/operate", methods=["POST"])
@auth_required
def operate():
    data = request.json
    action = data.get("action")
    params = data.get("params", {})
    with session_scope() as session:
        op_skill = OperationSkill(session)
        result = op_skill.operate(action, params)
        return jsonify(result)


# ============================
# 9. 重新生成现金流
# ============================
@app.route("/generate_cashflows", methods=["POST"])
@auth_required
def generate_cashflows():
    with session_scope() as session:
        cf_engine = CashflowEngine(session)
        cf_engine.generate_all()
        return {"status": "success"}


# ============================
# 启动服务
# ============================
if __name__ == "__main__":
    app.run(
        host=config.API_HOST,
        port=config.API_PORT,
        debug=config.DEBUG
    )
