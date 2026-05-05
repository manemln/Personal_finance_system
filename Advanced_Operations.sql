-- Personal Finance Hub - Advanced Operations
-- Functions, triggers, transactions, indexes

CREATE OR REPLACE FUNCTION auth.register_user(p_full_name text, p_email text, p_role text DEFAULT 'user')
RETURNS BIGINT AS $$
DECLARE v_user_id BIGINT;
BEGIN
    INSERT INTO auth.users(full_name, email, role)
    VALUES (p_full_name, lower(p_email), p_role)
    RETURNING user_id INTO v_user_id;
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finance.create_account(p_user_id bigint, p_name text, p_type text, p_currency char(3), p_opening numeric DEFAULT 0)
RETURNS BIGINT AS $$
DECLARE v_account_id BIGINT;
BEGIN
    INSERT INTO finance.accounts(user_id, name, account_type, currency, opening_balance)
    VALUES (p_user_id, p_name, p_type, upper(p_currency), p_opening)
    RETURNING account_id INTO v_account_id;
    RETURN v_account_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finance.add_transaction(p_account_id bigint, p_category_id bigint, p_merchant_id bigint, p_txn_date date, p_description text, p_amount numeric)
RETURNS BIGINT AS $$
DECLARE v_txn_id BIGINT;
BEGIN
    INSERT INTO finance.transactions(account_id, category_id, merchant_id, txn_date, description, amount)
    VALUES (p_account_id, p_category_id, p_merchant_id, p_txn_date, p_description, p_amount)
    RETURNING txn_id INTO v_txn_id;
    RETURN v_txn_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finance.transfer_between_accounts(p_from_account bigint, p_to_account bigint, p_amount numeric, p_transfer_date date)
RETURNS void AS $$
DECLARE v_transfer_cat BIGINT;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Transfer amount must be positive';
    END IF;
    SELECT category_id INTO v_transfer_cat FROM ref.categories WHERE name = 'Transfer' LIMIT 1;
    IF v_transfer_cat IS NULL THEN
        INSERT INTO ref.categories(name, kind) VALUES ('Transfer','expense') RETURNING category_id INTO v_transfer_cat;
    END IF;
    INSERT INTO finance.transactions(account_id, category_id, txn_date, description, amount)
    VALUES (p_from_account, v_transfer_cat, p_transfer_date, 'Transfer out', -p_amount);
    INSERT INTO finance.transactions(account_id, category_id, txn_date, description, amount)
    VALUES (p_to_account, v_transfer_cat, p_transfer_date, 'Transfer in', p_amount);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION plans.run_recurring(p_run_date date)
RETURNS integer AS $$
DECLARE r RECORD; v_count integer := 0;
BEGIN
    FOR r IN SELECT * FROM plans.recurring_rules WHERE is_active AND next_run_date <= p_run_date LOOP
        INSERT INTO finance.transactions(account_id, category_id, merchant_id, txn_date, description, amount)
        VALUES (r.account_id, r.category_id, r.merchant_id, r.next_run_date, 'Recurring transaction', r.amount);
        UPDATE plans.recurring_rules
        SET next_run_date = CASE frequency
            WHEN 'weekly' THEN next_run_date + INTERVAL '7 days'
            WHEN 'monthly' THEN next_run_date + INTERVAL '1 month'
            WHEN 'yearly' THEN next_run_date + INTERVAL '1 year'
        END
        WHERE rule_id = r.rule_id;
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finance.prevent_income_budget()
RETURNS trigger AS $$
DECLARE v_kind text;
BEGIN
    SELECT kind INTO v_kind FROM ref.categories WHERE category_id = NEW.category_id;
    IF v_kind <> 'expense' THEN
        RAISE EXCEPTION 'Budgets can only be created for expense categories';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_budget_expense_only
BEFORE INSERT OR UPDATE ON finance.budgets
FOR EACH ROW EXECUTE FUNCTION finance.prevent_income_budget();

CREATE OR REPLACE FUNCTION audit.log_transaction_change()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit.audit_log(table_name, operation, row_pk, old_data)
        VALUES (TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, TG_OP, OLD.txn_id, to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit.audit_log(table_name, operation, row_pk, old_data, new_data)
        VALUES (TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, TG_OP, NEW.txn_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSE
        INSERT INTO audit.audit_log(table_name, operation, row_pk, new_data)
        VALUES (TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, TG_OP, NEW.txn_id, to_jsonb(NEW));
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transactions_audit
AFTER INSERT OR UPDATE OR DELETE ON finance.transactions
FOR EACH ROW EXECUTE FUNCTION audit.log_transaction_change();

CREATE OR REPLACE FUNCTION plans.validate_recurring_rule()
RETURNS trigger AS $$
BEGIN
    IF NEW.is_active AND NEW.next_run_date < CURRENT_DATE - INTERVAL '5 years' THEN
        NEW.is_active := FALSE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recurring_rule_validate
BEFORE INSERT OR UPDATE ON plans.recurring_rules
FOR EACH ROW EXECUTE FUNCTION plans.validate_recurring_rule();

CREATE INDEX IF NOT EXISTS idx_transactions_account_date ON finance.transactions(account_id, txn_date);
CREATE INDEX IF NOT EXISTS idx_transactions_category_date ON finance.transactions(category_id, txn_date);
CREATE INDEX IF NOT EXISTS idx_budgets_user_month ON finance.budgets(user_id, month_start);
CREATE INDEX IF NOT EXISTS idx_active_recurring_next_run ON plans.recurring_rules(next_run_date) WHERE is_active;
