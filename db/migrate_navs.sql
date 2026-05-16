-- 迁移 financial_navs / fund_navs 从 *_id 到 *_code
-- 1) 新增 code 列
ALTER TABLE financial_navs ADD COLUMN product_code VARCHAR(100);
ALTER TABLE fund_navs ADD COLUMN fund_code VARCHAR(100);

-- 2) 回填 code
UPDATE financial_navs fn
JOIN financial_products fp ON fn.product_id = fp.id
SET fn.product_code = fp.product_code;

UPDATE fund_navs fn
JOIN fund_products fp ON fn.fund_id = fp.id
SET fn.fund_code = fp.fund_code;

-- 3) 重建主键（如存在旧主键）
ALTER TABLE financial_navs DROP PRIMARY KEY;
ALTER TABLE fund_navs DROP PRIMARY KEY;

-- 4) 删除旧列
ALTER TABLE financial_navs DROP COLUMN product_id;
ALTER TABLE fund_navs DROP COLUMN fund_id;

-- 5) 新主键
ALTER TABLE financial_navs ADD PRIMARY KEY (product_code, date);
ALTER TABLE fund_navs ADD PRIMARY KEY (fund_code, date);

-- 6) 视图重建（如已存在）
DROP VIEW IF EXISTS asset_summary_view;

CREATE OR REPLACE VIEW asset_summary_view AS
SELECT
    (SELECT COALESCE(SUM(principal),0) 
     FROM bank_deposits 
     WHERE status='active') AS bank_assets,

    (SELECT COALESCE(SUM(fp.shares * fn.nav),0)
     FROM financial_products fp
     JOIN (
         SELECT product_code, MAX(date) AS latest_date
         FROM financial_navs
         GROUP BY product_code
     ) latest ON fp.product_code = latest.product_code
     JOIN financial_navs fn 
       ON fn.product_code = latest.product_code AND fn.date = latest.latest_date
     WHERE fp.status='active') AS financial_assets,

    (SELECT COALESCE(SUM(f.shares * fn.nav),0)
     FROM fund_products f
     JOIN (
         SELECT fund_code, MAX(date) AS latest_date
         FROM fund_navs
         GROUP BY fund_code
     ) latest ON f.fund_code = latest.fund_code
     JOIN fund_navs fn 
       ON fn.fund_code = latest.fund_code AND fn.date = latest.latest_date
     WHERE f.status='active') AS fund_assets,

    (SELECT COALESCE(SUM(cash_value),0) 
     FROM insurance_products 
     WHERE status='active') AS insurance_assets,

    (
      (SELECT COALESCE(SUM(principal),0) FROM bank_deposits WHERE status='active')
      +
      (SELECT COALESCE(SUM(fp.shares * fn.nav),0)
       FROM financial_products fp
       JOIN (
           SELECT product_code, MAX(date) AS latest_date
           FROM financial_navs
           GROUP BY product_code
       ) latest ON fp.product_code = latest.product_code
       JOIN financial_navs fn 
         ON fn.product_code = latest.product_code AND fn.date = latest.latest_date
       WHERE fp.status='active')
      +
      (SELECT COALESCE(SUM(f.shares * fn.nav),0)
       FROM fund_products f
       JOIN (
           SELECT fund_code, MAX(date) AS latest_date
           FROM fund_navs
           GROUP BY fund_code
       ) latest ON f.fund_code = latest.fund_code
       JOIN fund_navs fn 
         ON fn.fund_code = latest.fund_code AND fn.date = latest.latest_date
       WHERE f.status='active')
      +
      (SELECT COALESCE(SUM(cash_value),0) FROM insurance_products WHERE status='active')
    ) AS total_assets;
