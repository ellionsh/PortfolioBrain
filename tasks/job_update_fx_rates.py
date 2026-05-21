# tasks/job_update_fx_rates.py
import datetime
from typing import Dict, Optional

import akshare as ak
from sqlalchemy import text


def _extract_mid_rate(row) -> Optional[float]:
    try:
        bid = row.get("买报价")
        ask = row.get("卖报价")
        if bid is None and ask is None:
            return None
        if bid is None:
            return float(ask)
        if ask is None:
            return float(bid)
        return (float(bid) + float(ask)) / 2
    except Exception:
        return None


def _parse_pair(pair: str):
    if not pair:
        return None, None
    cleaned = str(pair).strip().upper().replace(" ", "")
    if "/" in cleaned:
        base, quote = cleaned.split("/", 1)
        return base, quote
    return None, None


def fetch_fx_rates() -> Dict[str, float]:
    df = ak.fx_spot_quote()
    if df is None or df.empty:
        return {}

    wanted = {"USD", "EUR", "HKD"}
    rates: Dict[str, float] = {}

    for _, row in df.iterrows():
        base, quote = _parse_pair(row.get("货币对"))
        if base not in wanted:
            continue
        if quote not in {"CNY", "CNH"}:
            continue
        rate = _extract_mid_rate(row)
        if rate is None:
            continue
        rates[base] = rate

    return rates


def update_fx_rates(session):
    today = datetime.date.today()
    rates = fetch_fx_rates()
    if not rates:
        return {"status": "empty", "date": str(today)}

    with session.begin():
        for base_currency, rate in rates.items():
            session.execute(
                text(
                    """
                    INSERT INTO fx_rates (date, base_currency, quote_currency, rate)
                    VALUES (:d, :base, 'CNY', :rate)
                    ON DUPLICATE KEY UPDATE rate=:rate
                    """
                ),
                {"d": today, "base": base_currency, "rate": rate},
            )

    return {"status": "success", "date": str(today), "updated": list(rates.keys())}
