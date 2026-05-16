# services/fund_nav_fetcher.py
import akshare as ak
import pandas as pd

class FundNavFetcher:
    """AkShare 基金净值数据源"""

    @staticmethod
    def get_latest_nav(code: str):
        """获取最新单位净值 + 累计净值"""
        df = ak.fund_open_fund_info_em(symbol=code, indicator="单位净值走势")
        latest = df.iloc[-1]

        return {
            "date": latest["净值日期"],
            "nav": float(latest["单位净值"])
        }

    @staticmethod
    def get_history_nav(code: str) -> pd.DataFrame:
        """获取历史净值曲线"""
        df = ak.fund_open_fund_info_em(symbol=code, indicator="单位净值走势")
        df = df[["净值日期", "单位净值"]]
        df.columns = ["date", "nav"]
        return df

