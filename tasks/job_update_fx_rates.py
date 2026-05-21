# tasks/job_update_fx_rates.py
import datetime
from typing import Dict, Optional, Tuple

import akshare as ak
from sqlalchemy import text


def _latest_boc_rate(symbol_cn: str, start_date: str, end_date: str) -> Optional[Tuple[datetime.date, float]]:
    df = ak.currency_boc_sina(symbol=symbol_cn, start_date=start_date, end_date=end_date)
    if df is None or df.empty:
        return None
    df = df.sort_values("日期")
    row = df.iloc[-1]
    rate = row.get("中行汇买价")
    if rate is None:
        return None
    try:
        fx_date = datetime.datetime.strptime(str(row.get("日期")), "%Y-%m-%d").date()
    except Exception:
        try:
            fx_date = datetime.datetime.strptime(str(row.get("日期")), "%Y%m%d").date()
        except Exception:
            fx_date = datetime.date.today()
    try:
        rate_value = float(rate) / 100.0
    except Exception:
        return None
    return fx_date, rate_value


def fetch_fx_rates() -> Dict[str, Tuple[datetime.date, float]]:
    today = datetime.date.today()
    end_date = today.strftime("%Y%m%d")
    start_date = (today - datetime.timedelta(days=200)).strftime("%Y%m%d")

    mapping = {
        "USD": "美元",
        "EUR": "欧元",
        "HKD": "港币",
    }

    results: Dict[str, Tuple[datetime.date, float]] = {}
    for code, symbol_cn in mapping.items():
        latest = _latest_boc_rate(symbol_cn, start_date, end_date)
        if latest is None:
            continue
        results[code] = latest
    return results


def update_fx_rates(session):
    rates = fetch_fx_rates()
    if not rates:
        return {"status": "empty", "date": str(datetime.date.today())}

    with session.begin():
        for base_currency, (fx_date, rate) in rates.items():
            session.execute(
                text(
                    """
                    INSERT INTO fx_rates (date, base_currency, quote_currency, rate)
                    VALUES (:d, :base, 'CNY', :rate)
                    ON DUPLICATE KEY UPDATE rate=:rate
                    """
                ),
                {"d": fx_date, "base": base_currency, "rate": rate},
            )

    return {"status": "success", "date": str(datetime.date.today()), "updated": list(rates.keys())}
