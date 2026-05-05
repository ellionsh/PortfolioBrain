# web/app.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import pymysql

from agent.agent import agent_chat
from core.asset_operator import AssetOperator
from core.cashflow_engine import CashflowEngine
from db.db import get_conn

app = Flask(__name__)
CORS(app)  # 允许前端/移动端跨域访问

# 全局数据库连接
conn = get_conn()
op = AssetOperator(conn)
cf_engine = CashflowEngine(conn)


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
    df_assets = pd.read_sql("SELECT SUM(market_value) AS v FROM positions", conn)
    df_cf = pd.read_sql("""
        SELECT SUM(amount) AS v FROM cashflows
        WHERE date >= CURDATE()
        AND date < DATE_ADD(CURDATE(), INTERVAL 180 DAY)
    """, conn)

    return {
        "total_assets": float(df_assets["v"][0] or 0),
        "future_6m_cf": float(df_cf["v"][0] or 0)
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
    """, conn)
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
    """, conn)
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
    """, conn)
    return df.to_dict(orient="records")


# ============================
# 6. 净值曲线
# ============================
@app.route("/nav/<int:pid>", methods=["GET"])
def nav_curve(pid):
    df = pd.read_sql("""
        SELECT date, nav
        FROM financial_navs
        WHERE product_id=%s
        ORDER BY date
    """, conn, params=[pid])
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
    """, conn)
    return df.to_dict(orient="records")


# ============================
# 8. 资产操作接口（买入/卖出/更新净值）
# ============================
@app.route("/operate", methods=["POST"])
def operate():
    data = request.json
    action = data.get("action")
    params = data.get("params", {})

    result = op.operate(action, params)
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
    app.run(port=5000, debug=True)

