-- ============================================
-- PortfolioBrain MySQL Schema (15 Tables + 1 View)
-- ============================================

CREATE DATABASE IF NOT EXISTS portfolio
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE portfolio;

-- 1. accounts（账户表）
CREATE TABLE accounts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50),
    currency VARCHAR(10),
    institution VARCHAR(255),
    created_at DATE,
    INDEX idx_accounts_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. bank_deposits（银行存款）
CREATE TABLE bank_deposits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    deposit_type VARCHAR(50),   -- demand/fixed/cd/notice
    currency VARCHAR(10),
    principal DECIMAL(18,2),
    interest_rate DECIMAL(10,4),
    start_date DATE,
    end_date DATE,
    interest_method VARCHAR(50),  -- daily/monthly/quarterly/at_maturity
    notice_days INT,
    auto_renew BOOLEAN,
    status VARCHAR(50),
    remark TEXT,
    INDEX idx_bank_deposits_account (account_id),
    INDEX idx_bank_deposits_end_date (end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. financial_products（理财产品主数据）
CREATE TABLE financial_products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    product_name VARCHAR(255),
    product_code VARCHAR(100),
    type VARCHAR(50),              -- nav/fixed/structured
    currency VARCHAR(10),
    is_nav_based BOOLEAN,
    risk_level INT,
    min_redeem_unit DECIMAL(18,4),
    principal DECIMAL(18,2),       -- 成本
    shares DECIMAL(18,4),          -- 当前份额
    expected_yield DECIMAL(10,4),
    start_date DATE,
    end_date DATE,
    pay_freq VARCHAR(50),
    status VARCHAR(50),
    remark TEXT,
    INDEX idx_fin_products_code (product_code),
    INDEX idx_fin_products_account (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. financial_transactions（理财交易记录）
CREATE TABLE financial_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT,
    account_id INT,
    trade_date DATE,
    trade_type VARCHAR(50),   -- buy/sell/dividend/fee
    shares DECIMAL(18,4),
    amount DECIMAL(18,2),
    nav DECIMAL(18,4),
    fee DECIMAL(18,2),
    currency VARCHAR(10),
    INDEX idx_fin_tx_product (product_id),
    INDEX idx_fin_tx_date (trade_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. financial_navs（理财净值）
CREATE TABLE financial_navs (
    product_id INT,
    date DATE,
    nav DECIMAL(18,4),
    currency VARCHAR(10),
    PRIMARY KEY (product_id, date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. fund_products（基金主数据）
CREATE TABLE fund_products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    fund_name VARCHAR(255),
    fund_code VARCHAR(100),
    currency VARCHAR(10),
    shares DECIMAL(18,4),          -- 当前份额
    principal DECIMAL(18,2),       -- 成本
    status VARCHAR(50),
    remark TEXT,
    INDEX idx_fund_code (fund_code),
    INDEX idx_fund_account (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. fund_transactions（基金交易记录）
CREATE TABLE fund_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fund_id INT,
    account_id INT,
    trade_date DATE,
    trade_type VARCHAR(50),        -- buy/sell/dividend/fee
    shares DECIMAL(18,4),
    amount DECIMAL(18,2),
    nav DECIMAL(18,4),
    fee DECIMAL(18,2),
    currency VARCHAR(10),
    INDEX idx_fund_tx_date (trade_date),
    INDEX idx_fund_tx_fund (fund_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. fund_navs（基金净值）
CREATE TABLE fund_navs (
    fund_id INT,
    date DATE,
    nav DECIMAL(18,4),
    currency VARCHAR(10),
    PRIMARY KEY (fund_id, date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 9. insurance_products（保险产品）
CREATE TABLE insurance_products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    product_name VARCHAR(255),
    company VARCHAR(255),
    type VARCHAR(50),              -- 寿险/重疾/年金/万能/医疗
    currency VARCHAR(10),
    premium DECIMAL(18,2),
    premium_freq VARCHAR(50),      -- annual/monthly/once
    premium_years INT,
    coverage_amount DECIMAL(18,2),
    start_date DATE,
    end_date DATE,
    cash_value DECIMAL(18,2),
    status VARCHAR(50),
    remark TEXT,
    INDEX idx_insurance_account (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 10. cashflows（现金流）
CREATE TABLE cashflows (
    id INT AUTO_INCREMENT PRIMARY KEY,
    source_type VARCHAR(50),   -- financial/insurance/bank/fund
    source_id INT,
    account_id INT,
    date DATE,
    amount DECIMAL(18,2),
    currency VARCHAR(10),
    direction VARCHAR(20),     -- inflow/outflow
    description TEXT,
    INDEX idx_cashflows_date (date),
    INDEX idx_cashflows_account (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 11. assets（资产主数据）
CREATE TABLE assets (
    code VARCHAR(100) PRIMARY KEY,
    name VARCHAR(255),
    type VARCHAR(50),          -- equity/bond/fund/cash/alt/commodity
    currency VARCHAR(10),
    exchange VARCHAR(50),
    risk_level INT,
    remark TEXT,
    INDEX idx_assets_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 12. positions（每日持仓快照）
CREATE TABLE positions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE,
    account_id INT,
    asset_code VARCHAR(100),
    shares DECIMAL(18,4),
    cost DECIMAL(18,2),
    market_value DECIMAL(18,2),
    currency VARCHAR(10),
    update_time DATETIME,
    INDEX idx_positions_date (date),
    INDEX idx_positions_account (account_id),
    INDEX idx_positions_asset (asset_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 13. transactions（通用交易记录）
CREATE TABLE transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    asset_code VARCHAR(100),
    trade_date DATE,
    trade_type VARCHAR(50),
    quantity DECIMAL(18,4),
    price DECIMAL(18,4),
    amount DECIMAL(18,2),
    fee DECIMAL(18,2),
    currency VARCHAR(10),
    INDEX idx_tx_date (trade_date),
    INDEX idx_tx_asset (asset_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 14. prices（历史价格）
CREATE TABLE prices (
    asset_code VARCHAR(100),
    date DATE,
    price DECIMAL(18,4),
    currency VARCHAR(10),
    PRIMARY KEY (asset_code, date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 15. fx_rates（汇率）
CREATE TABLE fx_rates (
    date DATE,
    base_currency VARCHAR(10),
    quote_currency VARCHAR(10),
    rate DECIMAL(18,6),
    PRIMARY KEY (date, base_currency, quote_currency)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- 视图：资产总览
-- ============================================
CREATE OR REPLACE VIEW asset_summary_view AS
SELECT
    -- 银行存款本金
    (SELECT COALESCE(SUM(principal),0) 
     FROM bank_deposits 
     WHERE status='active') AS bank_assets,

    -- 理财产品市值（份额 × 最新净值）
    (SELECT COALESCE(SUM(fp.shares * fn.nav),0)
     FROM financial_products fp
     JOIN (
         SELECT product_id, MAX(date) AS latest_date
         FROM financial_navs
         GROUP BY product_id
     ) latest ON fp.id = latest.product_id
     JOIN financial_navs fn 
       ON fn.product_id = latest.product_id AND fn.date = latest.latest_date
     WHERE fp.status='active') AS financial_assets,

    -- 基金市值（份额 × 最新净值）
    (SELECT COALESCE(SUM(f.shares * fn.nav),0)
     FROM fund_products f
     JOIN (
         SELECT fund_id, MAX(date) AS latest_date
         FROM fund_navs
         GROUP BY fund_id
     ) latest ON f.id = latest.fund_id
     JOIN fund_navs fn 
       ON fn.fund_id = latest.fund_id AND fn.date = latest.latest_date
     WHERE f.status='active') AS fund_assets,

    -- 保险现金价值
    (SELECT COALESCE(SUM(cash_value),0) 
     FROM insurance_products 
     WHERE status='active') AS insurance_assets,

    -- 总资产
    (
      (SELECT COALESCE(SUM(principal),0) FROM bank_deposits WHERE status='active')
      +
      (SELECT COALESCE(SUM(fp.shares * fn.nav),0)
       FROM financial_products fp
       JOIN (
           SELECT product_id, MAX(date) AS latest_date
           FROM financial_navs
           GROUP BY product_id
       ) latest ON fp.id = latest.product_id
       JOIN financial_navs fn 
         ON fn.product_id = latest.product_id AND fn.date = latest.latest_date
       WHERE fp.status='active')
      +
      (SELECT COALESCE(SUM(f.shares * fn.nav),0)
       FROM fund_products f
       JOIN (
           SELECT fund_id, MAX(date) AS latest_date
           FROM fund_navs
           GROUP BY fund_id
       ) latest ON f.id = latest.fund_id
       JOIN fund_navs fn 
         ON fn.fund_id = latest.fund_id AND fn.date = latest.latest_date
       WHERE f.status='active')
      +
      (SELECT COALESCE(SUM(cash_value),0) FROM insurance_products WHERE status='active')
    ) AS total_assets;


CREATE TABLE migration_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    file_name VARCHAR(255),
    table_name VARCHAR(255),
    rows INT,
    status VARCHAR(50),
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


