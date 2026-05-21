# tasks/job_update_fx_rates.py
import datetime
import os
from typing import Dict, Optional, Tuple

import akshare as ak
from sqlalchemy import text


def _extract_bank_buy_rate(row) -> Optional[float]:
    try:
        buy = row.get("银行买入价")
        if buy is None:
            buy = row.get("买入价")
        if buy is None:
            return None
        return float(buy)
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


def _extract_currency_latest_rate(df) -> Optional[float]:
    if df is None or df.empty:
        return None
    if "currency" in df.columns:
        row = df.loc[df["currency"] == "CNY"]
        if row.empty:
            return None
        series = row.iloc[0]
        for key in ("rates", "rate", "value"):
            if key in series:
                try:
                    return float(series[key])
                except (TypeError, ValueError):
                    return None
    for key in ("rates", "rate", "value"):
        if key in df.columns:
            try:
                return float(df.iloc[0][key])
            except (TypeError, ValueError):
                return None
    return None


def fetch_fx_rates() -> Tuple[Dict[str, float], Optional[str]]:
    wanted = {"USD", "EUR", "HKD"}
    rates: Dict[str, float] = {}
    errors = []

    try:
        df = ak.fx_spot_quote()
        if df is not None and not df.empty:
            for _, row in df.iterrows():
                base, quote = _parse_pair(row.get("货币对"))
                if base not in wanted:
                    continue
                if quote not in {"CNY", "CNH"}:
                    continue
                rate = _extract_bank_buy_rate(row)
                if rate is None:
                    continue
                rates[base] = rate
            if rates:
                return rates, None
        errors.append("fx_spot_quote returned empty")
    except Exception as exc:
        errors.append(f"fx_spot_quote failed: {exc}")

    api_key = os.getenv("PB_CURRENCY_SCOOP_API_KEY", "")
    if api_key:
        for base in wanted:
            try:
                df = ak.currency_latest(base=base, symbols="CNY", api_key=api_key)
                rate = _extract_currency_latest_rate(df)
                if rate is not None:
                    rates[base] = rate
            except Exception as exc:
                errors.append(f"currency_latest {base} failed: {exc}")
        if rates:
            return rates, None
    else:
        errors.append("PB_CURRENCY_SCOOP_API_KEY not set")

    return {}, "; ".join(errors) if errors else "no data"


def update_fx_rates(session):
    today = datetime.date.today()
    rates, reason = fetch_fx_rates()
    if not rates:
        return {"status": "empty", "date": str(today), "reason": reason}

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
