-- Personal Finance Hub - DDL
-- PostgreSQL implementation

DROP SCHEMA IF EXISTS reporting CASCADE;
DROP SCHEMA IF EXISTS audit CASCADE;
DROP SCHEMA IF EXISTS plans CASCADE;
DROP SCHEMA IF EXISTS finance CASCADE;
DROP SCHEMA IF EXISTS ref CASCADE;
DROP SCHEMA IF EXISTS auth CASCADE;

CREATE SCHEMA auth;
CREATE SCHEMA ref;
CREATE SCHEMA finance;
CREATE SCHEMA plans;
CREATE SCHEMA audit;
CREATE SCHEMA reporting;

CREATE TABLE auth.users (
    user_id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(160) NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user','stakeholder','admin')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ref.categories (
    category_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    kind VARCHAR(10) NOT NULL CHECK (kind IN ('income','expense')),
    parent_category_id BIGINT REFERENCES ref.categories(category_id),
    UNIQUE(name, kind)
);

CREATE TABLE ref.merchants (
    merchant_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL UNIQUE,
    default_category_id BIGINT REFERENCES ref.categories(category_id)
);

CREATE TABLE finance.accounts (
    account_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES auth.users(user_id) ON DELETE CASCADE,
    name VARCHAR(80) NOT NULL,
    account_type VARCHAR(20) NOT NULL CHECK (account_type IN ('cash','checking','savings','credit','investment')),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    opening_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, name)
);

CREATE TABLE finance.transactions (
    txn_id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES finance.accounts(account_id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES ref.categories(category_id),
    merchant_id BIGINT REFERENCES ref.merchants(merchant_id),
    txn_date DATE NOT NULL,
    description VARCHAR(250),
    amount NUMERIC(14,2) NOT NULL CHECK (amount <> 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE finance.budgets (
    budget_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES auth.users(user_id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES ref.categories(category_id),
    month_start DATE NOT NULL,
    limit_amount NUMERIC(14,2) NOT NULL CHECK (limit_amount > 0),
    CHECK (date_trunc('month', month_start)::date = month_start),
    UNIQUE(user_id, category_id, month_start)
);

CREATE TABLE plans.recurring_rules (
    rule_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES auth.users(user_id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL REFERENCES finance.accounts(account_id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES ref.categories(category_id),
    merchant_id BIGINT REFERENCES ref.merchants(merchant_id),
    amount NUMERIC(14,2) NOT NULL CHECK (amount <> 0),
    frequency VARCHAR(20) NOT NULL CHECK (frequency IN ('weekly','monthly','yearly')),
    next_run_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE plans.goals (
    goal_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES auth.users(user_id) ON DELETE CASCADE,
    goal_name VARCHAR(120) NOT NULL,
    target_amount NUMERIC(14,2) NOT NULL CHECK (target_amount > 0),
    current_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (current_amount >= 0),
    deadline DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','paused','cancelled'))
);

CREATE TABLE plans.loans (
    loan_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES auth.users(user_id) ON DELETE CASCADE,
    lender VARCHAR(120) NOT NULL,
    principal NUMERIC(14,2) NOT NULL CHECK (principal > 0),
    interest_rate NUMERIC(6,3) NOT NULL CHECK (interest_rate >= 0),
    start_date DATE NOT NULL,
    due_date DATE
);

CREATE TABLE plans.loan_payments (
    payment_id BIGSERIAL PRIMARY KEY,
    loan_id BIGINT NOT NULL REFERENCES plans.loans(loan_id) ON DELETE CASCADE,
    txn_id BIGINT REFERENCES finance.transactions(txn_id) ON DELETE SET NULL,
    paid_date DATE NOT NULL,
    paid_amount NUMERIC(14,2) NOT NULL CHECK (paid_amount > 0)
);

CREATE TABLE audit.audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(120) NOT NULL,
    operation VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    row_pk BIGINT,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(160),
    old_data JSONB,
    new_data JSONB
);

CREATE OR REPLACE VIEW reporting.monthly_cashflow AS
SELECT u.user_id, u.full_name, date_trunc('month', t.txn_date)::date AS month_start,
       SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END) AS income,
       SUM(CASE WHEN t.amount < 0 THEN -t.amount ELSE 0 END) AS expenses,
       SUM(t.amount) AS net_cashflow
FROM auth.users u
JOIN finance.accounts a ON a.user_id = u.user_id
JOIN finance.transactions t ON t.account_id = a.account_id
GROUP BY u.user_id, u.full_name, date_trunc('month', t.txn_date)::date;

CREATE OR REPLACE VIEW reporting.budget_vs_actual AS
SELECT b.user_id, b.month_start, c.name AS category,
       b.limit_amount,
       COALESCE(SUM(-t.amount),0) AS actual_spending,
       b.limit_amount - COALESCE(SUM(-t.amount),0) AS remaining_amount
FROM finance.budgets b
JOIN ref.categories c ON c.category_id = b.category_id
LEFT JOIN finance.accounts a ON a.user_id = b.user_id
LEFT JOIN finance.transactions t ON t.account_id = a.account_id
    AND t.category_id = b.category_id
    AND t.amount < 0
    AND date_trunc('month', t.txn_date)::date = b.month_start
GROUP BY b.user_id, b.month_start, c.name, b.limit_amount;
