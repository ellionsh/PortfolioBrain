# services/fund_nav_fetcher.py
import akshare as ak
import pandas as pd

class FundNavFetcher:
    """AkShare 基金净值数据源"""

    @staticmethod
    def get_fund_name(code: str):
        """获取基金名称"""
        def extract_from_df(df, item_col, value_col):
            if df is None or df.empty:
                return None
            if item_col not in df.columns or value_col not in df.columns:
                if df.shape[1] >= 2:
                    items = df.iloc[:, 0]
                    values = df.iloc[:, 1]
                else:
                    return None
            else:
                items = df[item_col]
                values = df[value_col]
            profile = {}
            for item, value in zip(items, values):
                key = str(item).strip()
                profile[key] = value
            for key in ("基金简称", "基金名称", "基金全称", "证券简称", "产品名称"):
                value = profile.get(key)
                if value is not None and str(value).strip():
                    return str(value).strip()
            return None

        try:
            df = ak.fund_individual_basic_info_xq(symbol=code)
            name = extract_from_df(df, "item", "value")
            if name:
                return name
        except Exception:
            pass

        try:
            df = ak.fund_info_ths(symbol=code)
            name = extract_from_df(df, "字段", "值")
            if name:
                return name
        except Exception:
            pass

        try:
            df = ak.fund_open_fund_info_em(symbol=code, indicator="基金档案")
            name = extract_from_df(df, "item", "value")
            if name:
                return name
        except Exception:
            pass

        try:
            df = ak.fund_name_em()
            if df is not None and not df.empty and "基金代码" in df.columns:
                row = df.loc[df["基金代码"] == str(code).zfill(6)]
                if not row.empty:
                    for col in ("基金简称", "基金名称"):
                        if col in row.columns:
                            value = row.iloc[0][col]
                            if value is not None and str(value).strip():
                                return str(value).strip()
        except Exception:
            pass

        return None

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
