#!/usr/bin/env python3
# scripts/generate_positions_snapshot.py
import argparse
import datetime as dt
import math
from decimal import Decimal

from sqlalchemy import text

from db.db import session_scope


def _xnpv(rate, cashflows):
    t0 = cashflows[0][0]
    total = 0.0
    for d, amt in cashflows:
        days = (d - t0).days / 365
        total += amt / ((1 + rate) ** days)
    return total


def xirr(cashflows):
    if not cashflows or len(cashflows) < 2:
        return None
    cashflows = sorted(cashflows, key=lambda x: x[0])
    amounts = [amt for _, amt in cashflows]
    if all(a >= 0 for a in amounts) or all(a <= 0 for a in amounts):
        return None

    guess = 0.1
    for _ in range(100):
        f = _xnpv(guess, cashflows)
        if abs(f) < 1e-6:
            return guess
        t0 = cashflows[0][0]
        df = 0.0
        for d, amt in cashflows:
            days = (d - t0).days / 365
            df -= (days * amt) / ((1 + guess) ** (days + 1))
        if df == 0:
            break
        guess = guess - f / df
        if guess <= -0.999999:
            guess = -0.999999

    low, high = -0.9999, 10.0
    f_low = _xnpv(low, cashflows)
    f_high = _xnpv(high, cashflows)
    if f_low == 0:
        return low
    if f_high == 0:
        return high
    if f_low * f_high > 0:
        return None
    mid = None
    for _ in range(100):
        mid = (low + high) / 2
        f_mid = _xnpv(mid, cashflows)
        if abs(f_mid) < 1e-6:
            return mid
        if f_low * f_mid < 0:
            high = mid
            f_high = f_mid
        else:
            low = mid
            f_low = f_mid
    return mid


def parse_date(value: str) -> dt.date:
    return dt.date.fromisoformat(value)


def fetch_latest_nav_map(session, table: str, code_col: str, snap_date: dt.date):
    sql = f"""
        SELECT t.{code_col} AS code, t.nav AS nav
        FROM {table} t
        JOIN (
            SELECT {code_col} AS code, MAX(date) AS max_date
            FROM {table}
            WHERE date <= :snap_date
            GROUP BY {code_col}
        ) m ON t.{code_col} = m.code AND t.date = m.max_date
    """
    rows = session.execute(text(sql), {"snap_date": snap_date}).fetchall()
    return {r.code: Decimal(str(r.nav)) for r in rows if r.nav is not None}


def build_rows(snap_date: dt.date):
    with session_scope() as session:
        now = dt.datetime.now()

        session.execute(
            text("""
                DELETE FROM positions
                WHERE date = :d
                  AND source_type IN ('bank', 'financial', 'insurance', 'fund')
            """),
            {"d": snap_date}
        )

        fin_nav_map = fetch_latest_nav_map(session, "financial_navs", "product_code", snap_date)
        fund_nav_map = fetch_latest_nav_map(session, "fund_navs", "fund_code", snap_date)

        fin_tx_rows = session.execute(text("""
            SELECT product_id, trade_date, trade_type, amount, fee
            FROM financial_transactions
            WHERE trade_date <= :d
        """), {"d": snap_date}).fetchall()

        fund_tx_rows = session.execute(text("""
            SELECT fund_id, trade_date, trade_type, amount, fee
            FROM fund_transactions
            WHERE trade_date <= :d
        """), {"d": snap_date}).fetchall()

        fin_cashflows = {}
        for r in fin_tx_rows:
            if r.trade_date is None:
                continue
            try:
                amount_value = float(r.amount) if r.amount is not None else 0.0
            except (TypeError, ValueError):
                continue
            fee_value = 0.0
            if r.fee is not None:
                try:
                    fee_value = float(r.fee)
                except (TypeError, ValueError):
                    fee_value = 0.0
            if r.trade_type == "buy":
                signed_amount = -abs(amount_value)
            else:
                signed_amount = abs(amount_value) - fee_value
            fin_cashflows.setdefault(r.product_id, []).append((r.trade_date, signed_amount))

        fund_cashflows = {}
        for r in fund_tx_rows:
            if r.trade_date is None:
                continue
            try:
                amount_value = float(r.amount) if r.amount is not None else 0.0
            except (TypeError, ValueError):
                continue
            fee_value = 0.0
            if r.fee is not None:
                try:
                    fee_value = float(r.fee)
                except (TypeError, ValueError):
                    fee_value = 0.0
            if r.trade_type == "buy":
                signed_amount = -abs(amount_value)
            else:
                signed_amount = abs(amount_value) - fee_value
            fund_cashflows.setdefault(r.fund_id, []).append((r.trade_date, signed_amount))

        rows = []

        # 银行存款
        bank_rows = session.execute(text("""
            SELECT id, account_id, deposit_type, currency, principal, interest_rate, start_date, end_date
            FROM bank_deposits
            WHERE status='active'
              AND (start_date IS NULL OR start_date <= :d)
              AND (end_date IS NULL OR end_date >= :d)
        """), {"d": snap_date}).fetchall()

        for r in bank_rows:
            rows.append({
                "date": snap_date,
                "account_id": r.account_id,
                "source_type": "bank",
                "source_id": r.id,
                "asset_code": None,
                "asset_name": f"bank:{r.deposit_type}" if r.deposit_type else "bank",
                "shares": None,
                "cost": r.principal,
                "market_value": r.principal,
                "annual_yield_rate": r.interest_rate,
                "currency": r.currency or "CNY",
                "update_time": now,
            })

        # 理财产品
        fin_rows = session.execute(text("""
            SELECT id, account_id, product_name, product_code, is_nav_based,
                   currency, principal, shares, expected_yield, start_date, end_date
            FROM financial_products
            WHERE status='active'
              AND (start_date IS NULL OR start_date <= :d)
              AND (end_date IS NULL OR end_date >= :d)
        """), {"d": snap_date}).fetchall()

        for r in fin_rows:
            nav = fin_nav_map.get(r.product_code)
            shares = r.shares
            principal = r.principal
            if r.is_nav_based:
                market_value = Decimal(str(shares)) * nav if (shares is not None and nav is not None) else None
            else:
                market_value = Decimal(str(shares)) if shares is not None else None
            cost = principal if principal is not None else market_value
            irr = None
            if market_value is not None:
                cfs = list(fin_cashflows.get(r.id, []))
                cfs.append((snap_date, float(market_value)))
                irr = xirr(cfs)
            rows.append({
                "date": snap_date,
                "account_id": r.account_id,
                "source_type": "financial",
                "source_id": r.id,
                "asset_code": r.product_code,
                "asset_name": r.product_name,
                "shares": shares,
                "cost": cost,
                "market_value": market_value,
                "annual_yield_rate": float(irr) if irr is not None else r.expected_yield,
                "currency": r.currency or "CNY",
                "update_time": now,
            })

        # 基金
        fund_rows = session.execute(text("""
            SELECT id, account_id, fund_name, fund_code, currency, principal, shares,
                   start_date, end_date
            FROM fund_products
            WHERE status='active'
              AND (start_date IS NULL OR start_date <= :d)
              AND (end_date IS NULL OR end_date >= :d)
        """), {"d": snap_date}).fetchall()

        for r in fund_rows:
            nav = fund_nav_map.get(r.fund_code)
            shares = r.shares
            principal = r.principal
            market_value = Decimal(str(shares)) * nav if (shares is not None and nav is not None) else None
            cost = principal if principal is not None else market_value
            irr = None
            if market_value is not None:
                cfs = list(fund_cashflows.get(r.id, []))
                cfs.append((snap_date, float(market_value)))
                irr = xirr(cfs)
            rows.append({
                "date": snap_date,
                "account_id": r.account_id,
                "source_type": "fund",
                "source_id": r.id,
                "asset_code": r.fund_code,
                "asset_name": r.fund_name,
                "shares": shares,
                "cost": cost,
                "market_value": market_value,
                "annual_yield_rate": float(irr) if irr is not None else None,
                "currency": r.currency or "CNY",
                "update_time": now,
            })

        # 保险
        ins_rows = session.execute(text("""
            SELECT id, account_id, product_name, company, type, currency,
                   premium, cash_value, start_date, end_date
            FROM insurance_products
            WHERE status='active'
              AND (start_date IS NULL OR start_date <= :d)
              AND (end_date IS NULL OR end_date >= :d)
        """), {"d": snap_date}).fetchall()

        for r in ins_rows:
            cash_value = r.cash_value
            rows.append({
                "date": snap_date,
                "account_id": r.account_id,
                "source_type": "insurance",
                "source_id": r.id,
                "asset_code": None,
                "asset_name": r.product_name or f"insurance:{r.company}" if r.company else "insurance",
                "shares": None,
                "cost": cash_value if cash_value is not None else r.premium,
                "market_value": cash_value,
                "annual_yield_rate": None,
                "currency": r.currency or "CNY",
                "update_time": now,
            })

        if rows:
            session.execute(text("""
                INSERT INTO positions (
                    date, account_id, source_type, source_id,
                    asset_code, asset_name, shares, cost, market_value, annual_yield_rate,
                    currency, update_time
                ) VALUES (
                    :date, :account_id, :source_type, :source_id,
                    :asset_code, :asset_name, :shares, :cost, :market_value, :annual_yield_rate,
                    :currency, :update_time
                )
            """), rows)

        session.commit()
        return len(rows)


def main():
    parser = argparse.ArgumentParser(description="Generate daily positions snapshot.")
    parser.add_argument("--date", type=parse_date, help="Snapshot date (YYYY-MM-DD). Default: today")
    args = parser.parse_args()
    snap_date = args.date or dt.date.today()
    count = build_rows(snap_date)
    print(f"✔ positions snapshot generated: date={snap_date} rows={count}")


if __name__ == "__main__":
    main()
