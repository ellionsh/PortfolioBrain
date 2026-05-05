# migrate/mapping.py

COLUMN_MAP = {
    # 通用字段
    "账户": "account_id",
    "账号": "account_id",
    "账户ID": "account_id",
    "账户id": "account_id",

    "产品名称": "product_name",
    "名称": "product_name",
    "产品": "product_name",

    "产品代码": "product_code",
    "代码": "product_code",
    "编号": "product_code",

    "币种": "currency",
    "货币": "currency",

    "本金": "principal",
    "金额": "principal",
    "投资金额": "principal",

    "利率": "interest_rate",
    "年化利率": "interest_rate",

    "开始日期": "start_date",
    "起息日": "start_date",

    "结束日期": "end_date",
    "到期日": "end_date",

    "净值": "nav",
    "单位净值": "nav",

    "份额": "shares",

    "交易日期": "trade_date",
    "日期": "trade_date",

    "交易类型": "trade_type",
    "类型": "trade_type",

    "保费": "premium",
    "缴费": "premium",

    "缴费频率": "premium_freq",
    "缴费方式": "premium_freq",

    "缴费年限": "premium_years",
}

def normalize_columns(df):
    """自动识别 Excel 列名并映射到数据库字段"""
    new_cols = {}
    for col in df.columns:
        key = col.strip().replace(" ", "")
        new_cols[col] = COLUMN_MAP.get(key, key.lower())
    return df.rename(columns=new_cols)
