# tasks/job_update_fund_navs.py
from services.fund_nav_updater import FundNavUpdater


def update_fund_navs():
    FundNavUpdater.update_all_funds()
    return {"status": "success"}
