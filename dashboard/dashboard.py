# dashboard/dashboard.py
import streamlit as st
import pandas as pd
import pymysql
import plotly.express as px
import plotly.figure_factory as ff

# ============================
# 数据库连接
# ============================
def get_conn():
    return pymysql.connect(
        host="localhost",
        user="root",
        password="123456",
        database="portfolio",
        charset="utf8mb4"
    )

conn = get_conn()

st.set_page_config(page_title="PortfolioBrain Dashboard", layout="wide")
st.title("📊 PortfolioBrain Dashboard")


# ============================
# 1. 资产结构（饼图）
# ============================
st.header("资产结构（按资产类型）")

df_assets = pd.read_sql("""
    SELECT type, SUM(market_value) AS value
    FROM positions
    GROUP BY type
""", conn)

if len(df_assets) > 0:
    fig = px.pie(df_assets, names="type", values="value", title="资产结构")
    st.plotly_chart(fig, use_container_width=True)
else:
    st.info("暂无资产结构数据")


# ============================
# 2. 币种敞口（柱状图）
# ============================
st.header("币种敞口（Currency Exposure）")

df_fx = pd.read_sql("""
    SELECT currency, SUM(market_value) AS value
    FROM positions
    GROUP BY currency
""", conn)

if len(df_fx) > 0:
    fig = px.bar(df_fx, x="currency", y="value", title="币种敞口")
    st.plotly_chart(fig, use_container_width=True)
else:
    st.info("暂无币种敞口数据")


# ============================
# 3. 未来现金流（折线图）
# ============================
st.header("未来现金流预测（Future Cashflows）")

df_cf = pd.read_sql("""
    SELECT date, SUM(amount) AS net
    FROM cashflows
    WHERE date >= CURDATE()
    GROUP BY date
    ORDER BY date
""", conn)

if len(df_cf) > 0:
    fig = px.line(df_cf, x="date", y="net", title="未来现金流")
    st.plotly_chart(fig, use_container_width=True)
else:
    st.info("暂无未来现金流数据")


# ============================
# 4. 理财期限结构（甘特图）
# ============================
st.header("理财产品期限结构（Gantt Chart）")

df_maturity = pd.read_sql("""
    SELECT product_name, start_date, end_date
    FROM financial_products
    WHERE end_date IS NOT NULL
""", conn)

if len(df_maturity) > 0:
    df_maturity["Task"] = df_maturity["product_name"]
    df_maturity["Start"] = df_maturity["start_date"]
    df_maturity["Finish"] = df_maturity["end_date"]

    fig = ff.create_gantt(
        df_maturity[["Task", "Start", "Finish"]],
        index_col="Task",
        show_colorbar=False,
        group_tasks=True,
        title="理财期限结构"
    )
    st.plotly_chart(fig, use_container_width=True)
else:
    st.info("暂无理财期限结构数据")


# ============================
# 5. 净值曲线（折线图）
# ============================
st.header("净值型理财净值曲线（NAV Curve）")

df_nav = pd.read_sql("""
    SELECT product_id, date, nav
    FROM financial_navs
    ORDER BY date
""", conn)

if len(df_nav) > 0:
    fig = px.line(
        df_nav,
        x="date",
        y="nav",
        color="product_id",
        title="净值曲线（按产品）"
    )
    st.plotly_chart(fig, use_container_width=True)
else:
    st.info("暂无净值数据")

