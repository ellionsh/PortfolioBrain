# web/app.py

import datetime

from skills.operation_skill import OperationSkill
def serialize(obj):
    if isinstance(obj, (datetime.date, datetime.datetime)):
        return obj.isoformat()
    if isinstance(obj, dict):
        return {k: serialize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [serialize(v) for v in obj]
    return obj

from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import config

from agent.agent import agent_chat
from core.asset_operator import AssetOperator
from core.cashflow_engine import CashflowEngine
from db.db import get_engine, get_session

app = Flask(__name__)
CORS(app)

# 全局 SQLAlchemy engine + session
engine = get_engine()
session = get_session()

# 资产操作器 & 现金流引擎（使用 SQLAlchemy session）
#op = AssetOperator(session)
op_skill = OperationSkill(session)
cf_engine = CashflowEngine(session)


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

# ============================
# 1. Flutter API 接口（返回 JSON 数据）
# ============================

@app.route("/accounts", methods=["GET"])
def get_accounts():
    df = pd.read_sql("SELECT * FROM accounts ORDER BY id", engine)
    data = df.to_dict(orient="records")
    return jsonify(serialize(data))

@app.route("/bank_deposits", methods=["GET"])
def get_bank_deposits():
    df = pd.read_sql("""
        SELECT id, account_id, deposit_type, principal, interest_rate,
               start_date, end_date, status
        FROM bank_deposits
        ORDER BY id DESC
    """, engine)
    data = df.to_dict(orient="records")
    return jsonify(serialize(data))

@app.route("/cashflows", methods=["GET"])
def get_cashflows_api():
    df = pd.read_sql("""
        SELECT id, source_type, source_id, account_id,
               date, amount, currency, direction, description
        FROM cashflows
        ORDER BY date DESC
    """, engine)
    data = df.to_dict(orient="records")
    return jsonify(serialize(data))

@app.route("/insurance_products", methods=["GET"])
def get_insurance_products():
    df = pd.read_sql("""
        SELECT id, account_id, product_name, company, type,
               premium, premium_freq, premium_years,
               coverage_amount, start_date, end_date, cash_value,
               status, remark
        FROM insurance_products
        ORDER BY id DESC
    """, engine)
    data = df.to_dict(orient="records")
    return jsonify(serialize(data))

@app.route("/financial_products", methods=["GET"])
def get_financial_products():
    df = pd.read_sql("""
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
    """, engine)
    data = df.to_dict(orient="records")
    return jsonify(serialize(data))

@app.route("/fund_products", methods=["GET"])
def get_fund_products():
    df = pd.read_sql("""
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
        ORDER BY f.id DESC
    """, engine)
    data = df.to_dict(orient="records")
    return jsonify(serialize(data))

@app.route("/financial_transactions", methods=["GET"])
def get_financial_transactions():
    df = pd.read_sql("""
        SELECT id, product_id, account_id, trade_date,
               trade_type, shares, amount, nav
        FROM financial_transactions
        ORDER BY trade_date DESC
    """, engine)
    data = df.to_dict(orient="records")
    return jsonify(serialize(data))


# ============================
# 1. Agent 对话接口
# ============================
@app.route("/chat", methods=["POST"])
def chat():
    q = request.json.get("query", "")
    return jsonify({"response": agent_chat(q)})


# ============================
# 2. 资产总览
# ============================
@app.route("/summary", methods=["GET"])
def summary():
    # 从视图中直接获取各类资产和总资产
    df_summary = pd.read_sql("SELECT * FROM asset_summary_view", engine)

    # 取出结果
    bank_value = float(df_summary["bank_assets"][0] or 0)
    financial_value = float(df_summary["financial_assets"][0] or 0)
    fund_value = float(df_summary["fund_assets"][0] or 0)
    insurance_value = float(df_summary["insurance_assets"][0] or 0)
    total_assets = float(df_summary["total_assets"][0] or 0)

    # 未来6个月现金流仍然单独查询
    df_cf = pd.read_sql("""
        SELECT COALESCE(SUM(amount),0) AS v 
        FROM cashflows
        WHERE date >= CURDATE()
        AND date < DATE_ADD(CURDATE(), INTERVAL 180 DAY)
    """, engine)
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
def positions():
    df = pd.read_sql("""
        SELECT date, account_id, asset_code, shares, cost, market_value, currency
        FROM positions
        ORDER BY date DESC
        LIMIT 200
    """, engine)
    return df.to_dict(orient="records")


# ============================
# 4. 未来现金流
# ============================
@app.route("/cashflows", methods=["GET"])
def cashflows():
    df = pd.read_sql("""
        SELECT date, amount, currency, direction, description
        FROM cashflows
        WHERE date >= CURDATE()
        ORDER BY date
    """, engine)
    return df.to_dict(orient="records")


# ============================
# 5. 理财产品列表
# ============================
@app.route("/products", methods=["GET"])
def products():
    df = pd.read_sql("""
        SELECT id, product_name, product_code, type, currency,
               principal, expected_yield, start_date, end_date, status
        FROM financial_products
        ORDER BY id DESC
    """, engine)
    return df.to_dict(orient="records")


# ============================
# 6. 净值曲线
# ============================
@app.route("/nav/<product_code>", methods=["GET"])
def nav_curve(product_code):
    df = pd.read_sql("""
        SELECT date, nav
        FROM financial_navs
        WHERE product_code=%s
        ORDER BY date
    """, engine, params=[product_code])
    return df.to_dict(orient="records")


# ============================
# 7. 理财期限结构
# ============================
@app.route("/maturity", methods=["GET"])
def maturity():
    df = pd.read_sql("""
        SELECT product_name, start_date, end_date
        FROM financial_products
        WHERE end_date IS NOT NULL
    """, engine)
    return df.to_dict(orient="records")


# ============================
# 8. 资产操作接口（买入/卖出/更新净值）
# ============================
@app.route("/operate", methods=["POST"])
def operate():
    data = request.json
    action = data.get("action")
    params = data.get("params", {})

    result = op_skill.operate(action, params)
    return jsonify(result)


# ============================
# 9. 重新生成现金流
# ============================
@app.route("/generate_cashflows", methods=["POST"])
def generate_cashflows():
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
