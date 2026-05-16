# tasks/job_update_nav.py
import datetime
import random
import pymysql

def update_nav(conn):
    cur = conn.cursor()

    # 获取所有净值型产品
    cur.execute("""
        SELECT product_code FROM financial_products
        WHERE is_nav_based=1 AND status='active'
    """)
    products = cur.fetchall()

    today = datetime.date.today()

    for (product_code,) in products:
        # 模拟净值（未来可替换为真实 API）
        nav = round(1 + random.uniform(-0.01, 0.01), 4)

        cur.execute("""
            INSERT INTO financial_navs (product_code, date, nav, currency)
            VALUES (%s, %s, %s, 'CNY')
            ON DUPLICATE KEY UPDATE nav=%s
        """, (product_code, today, nav, nav))

    conn.commit()
    return {"status": "success", "updated": len(products)}
