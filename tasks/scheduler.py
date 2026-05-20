# tasks/scheduler.py
import schedule
import time
from db.db import session_scope

from tasks.job_update_nav import update_nav
from tasks.job_update_fund_navs import update_fund_navs
from tasks.job_generate_cashflows import generate_cashflows
from tasks.job_maturity_alert import maturity_alert

def job_update_nav():
    print("执行：更新净值")
    with session_scope() as session:
        print(update_nav(session))

def job_generate_cf():
    print("执行：生成现金流")
    with session_scope() as session:
        print(generate_cashflows(session))

def job_update_fund_navs():
    print("执行：更新基金净值")
    print(update_fund_navs())

def job_alert():
    print("执行：到期提醒")
    with session_scope() as session:
        print(maturity_alert(session))

# 每日任务
schedule.every().day.at("06:00").do(job_update_nav)
schedule.every().day.at("06:05").do(job_update_fund_navs)
schedule.every().day.at("06:10").do(job_generate_cf)
schedule.every().day.at("06:20").do(job_alert)

print("任务调度器已启动...")

while True:
    schedule.run_pending()
    time.sleep(1)
