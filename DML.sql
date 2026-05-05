-- Personal Finance Hub - DML population script
-- Creates more than 10,000 rows total using deterministic generated data.

INSERT INTO auth.users(full_name, email, role)
SELECT 'User ' || gs, 'user' || gs || '@financehub.test',
       CASE WHEN gs <= 20 THEN 'admin' WHEN gs <= 80 THEN 'stakeholder' ELSE 'user' END
FROM generate_series(1,1000) AS gs;

INSERT INTO ref.categories(name, kind) VALUES
('Salary','income'), ('Freelance','income'), ('Investment Income','income'), ('Gift','income'),
('Groceries','expense'), ('Rent','expense'), ('Utilities','expense'), ('Transport','expense'),
('Health','expense'), ('Education','expense'), ('Entertainment','expense'), ('Dining','expense'),
('Insurance','expense'), ('Travel','expense'), ('Transfer','expense')
ON CONFLICT DO NOTHING;

INSERT INTO ref.merchants(name, default_category_id)
SELECT 'Merchant ' || gs,
       (SELECT category_id FROM ref.categories WHERE kind='expense' ORDER BY category_id OFFSET (gs % 10) LIMIT 1)
FROM generate_series(1,1000) AS gs;

INSERT INTO finance.accounts(user_id, name, account_type, currency, opening_balance)
SELECT u.user_id, 'Checking Account', 'checking', 'USD', 500 + (u.user_id % 1000)
FROM auth.users u;
INSERT INTO finance.accounts(user_id, name, account_type, currency, opening_balance)
SELECT u.user_id, 'Savings Account', 'savings', 'USD', 1000 + (u.user_id % 2000)
FROM auth.users u;

INSERT INTO finance.transactions(account_id, category_id, merchant_id, txn_date, description, amount)
SELECT a.account_id,
       CASE WHEN gs % 5 = 0 THEN (SELECT category_id FROM ref.categories WHERE name='Salary')
            ELSE (SELECT category_id FROM ref.categories WHERE kind='expense' ORDER BY category_id OFFSET (gs % 10) LIMIT 1) END,
       CASE WHEN gs % 5 = 0 THEN NULL ELSE ((gs % 1000) + 1) END,
       DATE '2025-01-01' + ((gs % 365)::int),
       CASE WHEN gs % 5 = 0 THEN 'Monthly income' ELSE 'Daily expense' END,
       CASE WHEN gs % 5 = 0 THEN 2500 + (gs % 900) ELSE -1 * (10 + (gs % 250)) END
FROM generate_series(1,12000) gs
JOIN finance.accounts a ON a.account_id = ((gs % 2000) + 1);

INSERT INTO finance.budgets(user_id, category_id, month_start, limit_amount)
SELECT u.user_id, c.category_id,
       (DATE '2025-01-01' + ((gs % 12) * INTERVAL '1 month'))::date,
       300 + (gs % 700)
FROM generate_series(1,1200) gs
JOIN auth.users u ON u.user_id = ((gs % 1000) + 1)
JOIN ref.categories c ON c.kind='expense'
WHERE c.category_id = (SELECT category_id FROM ref.categories WHERE kind='expense' ORDER BY category_id OFFSET (gs % 10) LIMIT 1)
ON CONFLICT DO NOTHING;

INSERT INTO plans.recurring_rules(user_id, account_id, category_id, merchant_id, amount, frequency, next_run_date, is_active)
SELECT u.user_id, a.account_id,
       (SELECT category_id FROM ref.categories WHERE kind='expense' ORDER BY category_id OFFSET (gs % 10) LIMIT 1),
       ((gs % 1000) + 1),
       -1 * (20 + (gs % 300)),
       CASE WHEN gs % 3 = 0 THEN 'weekly' WHEN gs % 3 = 1 THEN 'monthly' ELSE 'yearly' END,
       DATE '2025-12-01' + (gs % 60), TRUE
FROM generate_series(1,1000) gs
JOIN auth.users u ON u.user_id = ((gs % 1000) + 1)
JOIN finance.accounts a ON a.user_id = u.user_id AND a.name='Checking Account';

INSERT INTO plans.goals(user_id, goal_name, target_amount, current_amount, deadline, status)
SELECT ((gs % 1000) + 1), 'Goal ' || gs, 1000 + (gs % 9000), gs % 2000,
       DATE '2026-12-31' + (gs % 365), 'active'
FROM generate_series(1,1000) gs;

INSERT INTO plans.loans(user_id, lender, principal, interest_rate, start_date, due_date)
SELECT ((gs % 1000) + 1), 'Lender ' || (gs % 50), 1000 + (gs % 20000), (2 + (gs % 15))::numeric,
       DATE '2024-01-01' + (gs % 400), DATE '2027-01-01' + (gs % 700)
FROM generate_series(1,1000) gs;

INSERT INTO plans.loan_payments(loan_id, txn_id, paid_date, paid_amount)
SELECT ((gs % 1000) + 1), NULL, DATE '2025-01-01' + (gs % 365), 50 + (gs % 500)
FROM generate_series(1,1000) gs;
