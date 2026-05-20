# tasks/job_generate_cashflows.py
from core.cashflow_engine import CashflowEngine

def generate_cashflows(session):
    engine = CashflowEngine(session)
    return engine.generate_all()
