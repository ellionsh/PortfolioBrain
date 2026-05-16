# services/fund_nav_service.py
from services.fund_nav_fetcher import FundNavFetcher

class FundNavService:

    @staticmethod
    def fetch_latest(code: str):
        """获取最新 NAV（业务层）"""
        data = FundNavFetcher.get_latest_nav(code)
        return {
            "date": data["date"],
            "nav": data["nav"]
        }

