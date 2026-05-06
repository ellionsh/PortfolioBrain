# tasks/job_maturity_alert.py
import datetime
import pandas as pd

def maturity_alert(conn):
    today = datetime.date.today()
    alert_date = today + datetime.timedelta(days=7)

    df = pd.read_sql("""
        SELECT product_name, end_date
        FROM financial_products
        WHERE end_date IS NOT NULL
    """, conn)

    alerts = df[df["end_date"] <= alert_date]

    if len(alerts) == 0:
        return {"status": "no_alerts"}

    print("=== 理财产品到期提醒（未来 7 天） ===")
    for _, row in alerts.iterrows():
        print(f"- {row['product_name']} 将于 {row['end_date']} 到期")

    return {"status": "success", "count": len(alerts)}
