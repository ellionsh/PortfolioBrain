# tasks/scheduler.py
import schedule
import time
from db.db import get_conn

from tasks.job_update_nav import update_nav
from tasks.job_generate_cashflows import generate_cashflows
from tasks.job_maturity_alert import maturity_alert

def job_update_nav():
    conn = get_conn()
    print("执行：更新净值")
    print(update_nav(conn))

def job_generate_cf():
    conn = get_conn()
    print("执行：生成现金流")
    print(generate_cashflows(conn))

def job_alert():
    conn = get_conn()
    print("执行：到期提醒")
    print(maturity_alert(conn))

# 每日任务
schedule.every().day.at("06:00").do(job_update_nav)
schedule.every().day.at("06:10").do(job_generate_cf)
schedule.every().day.at("06:20").do(job_alert)

print("任务调度器已启动...")

while True:
    schedule.run_pending()
    time.sleep(1)
