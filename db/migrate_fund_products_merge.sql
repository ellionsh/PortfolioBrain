START TRANSACTION;

CREATE TEMPORARY TABLE fund_products_merge AS
SELECT
    account_id,
    fund_code,
    MIN(id) AS keep_id,
    MIN(fund_name) AS fund_name,
    MIN(currency) AS currency,
    SUM(COALESCE(shares, 0)) AS total_shares,
    SUM(COALESCE(principal, 0)) AS total_principal,
    MIN(start_date) AS min_start_date,
    MAX(end_date) AS max_end_date,
    CASE
        WHEN SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) > 0 THEN 'active'
        ELSE MIN(status)
    END AS status,
    NULLIF(TRIM(BOTH ';' FROM GROUP_CONCAT(DISTINCT remark SEPARATOR '; ')), '') AS remark
FROM fund_products
GROUP BY account_id, fund_code;

INSERT INTO fund_transactions (
    fund_id, account_id, trade_date, trade_type,
    shares, amount, nav, fee, currency
)
SELECT
    m.keep_id,
    f.account_id,
    COALESCE(f.start_date, CURDATE()),
    'buy',
    f.shares,
    f.principal,
    NULL,
    0,
    f.currency
FROM fund_products f
JOIN fund_products_merge m
  ON f.account_id = m.account_id
 AND f.fund_code = m.fund_code
WHERE COALESCE(f.principal, 0) <> 0 OR COALESCE(f.shares, 0) <> 0;

UPDATE fund_products fp
JOIN fund_products_merge m
  ON fp.id = m.keep_id
SET fp.fund_name = m.fund_name,
    fp.currency = m.currency,
    fp.shares = m.total_shares,
    fp.principal = m.total_principal,
    fp.start_date = m.min_start_date,
    fp.end_date = m.max_end_date,
    fp.status = m.status,
    fp.remark = m.remark;

DELETE fp
FROM fund_products fp
JOIN fund_products_merge m
  ON fp.account_id = m.account_id
 AND fp.fund_code = m.fund_code
WHERE fp.id <> m.keep_id;

DROP TEMPORARY TABLE fund_products_merge;

COMMIT;
