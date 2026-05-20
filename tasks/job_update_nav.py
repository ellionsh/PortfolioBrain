# tasks/job_update_nav.py
import datetime
import random
from sqlalchemy import text

def update_nav(session):
    with session.begin():
        rows = session.execute(text("""
            SELECT product_code FROM financial_products
            WHERE is_nav_based=1 AND status='active'
        """)).fetchall()

        products = [row[0] for row in rows]
        today = datetime.date.today()

        for product_code in products:
            nav = round(1 + random.uniform(-0.01, 0.01), 4)
            session.execute(text("""
                INSERT INTO financial_navs (product_code, date, nav, currency)
                VALUES (:code, :d, :nav, 'CNY')
                ON DUPLICATE KEY UPDATE nav=:nav
            """), {"code": product_code, "d": today, "nav": nav})

    return {"status": "success", "updated": len(products)}
