# tasks/job_generate_cashflows.py
from core.cashflow_engine import CashflowEngine

def generate_cashflows(conn):
    engine = CashflowEngine(conn)
    engine.generate_all()
    return {"status": "success"}
