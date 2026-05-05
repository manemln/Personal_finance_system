-- Personal Finance Hub - DQL business queries

-- 1. INNER JOIN: monthly spending by category for each user.
SELECT u.user_id, u.full_name, date_trunc('month', t.txn_date)::date AS month_start,
       c.name AS category, SUM(-t.amount) AS total_spent
FROM auth.users u
INNER JOIN finance.accounts a ON a.user_id = u.user_id
INNER JOIN finance.transactions t ON t.account_id = a.account_id
INNER JOIN ref.categories c ON c.category_id = t.category_id
WHERE t.amount < 0
GROUP BY u.user_id, u.full_name, month_start, c.name
ORDER BY month_start, total_spent DESC;

-- 2. LEFT JOIN: budget vs actual, including categories with no spending.
SELECT b.user_id, b.month_start, c.name AS category, b.limit_amount,
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

-- 3. FULL OUTER JOIN: compare months that have budgets vs months that have spending.
WITH spending AS (
    SELECT a.user_id, t.category_id, date_trunc('month', t.txn_date)::date AS month_start, SUM(-t.amount) AS spent
    FROM finance.accounts a JOIN finance.transactions t ON t.account_id = a.account_id
    WHERE t.amount < 0
    GROUP BY a.user_id, t.category_id, date_trunc('month', t.txn_date)::date
)
SELECT COALESCE(b.user_id, s.user_id) AS user_id,
       COALESCE(b.category_id, s.category_id) AS category_id,
       COALESCE(b.month_start, s.month_start) AS month_start,
       b.limit_amount, s.spent
FROM finance.budgets b
FULL OUTER JOIN spending s
  ON s.user_id = b.user_id AND s.category_id = b.category_id AND s.month_start = b.month_start;

-- 4. Scalar subquery: latest transaction date per user.
SELECT u.user_id, u.full_name,
       (SELECT MAX(t.txn_date)
        FROM finance.accounts a JOIN finance.transactions t ON t.account_id = a.account_id
        WHERE a.user_id = u.user_id) AS latest_transaction_date
FROM auth.users u;

-- 5. EXISTS subquery: users who overspent at least one budget.
SELECT DISTINCT u.user_id, u.full_name
FROM auth.users u
WHERE EXISTS (
    SELECT 1 FROM reporting.budget_vs_actual bva
    WHERE bva.user_id = u.user_id AND bva.actual_spending > bva.limit_amount
);

-- 6. Correlated subquery: transactions above the user's average expense for that month.
SELECT t.txn_id, a.user_id, t.txn_date, t.amount, t.description
FROM finance.transactions t
JOIN finance.accounts a ON a.account_id = t.account_id
WHERE t.amount < 0
AND -t.amount > (
    SELECT AVG(-t2.amount)
    FROM finance.transactions t2
    JOIN finance.accounts a2 ON a2.account_id = t2.account_id
    WHERE a2.user_id = a.user_id
      AND t2.amount < 0
      AND date_trunc('month', t2.txn_date) = date_trunc('month', t.txn_date)
);

-- 7. Top merchants by total spending.
SELECT m.name AS merchant, SUM(-t.amount) AS total_spending, COUNT(*) AS transaction_count
FROM finance.transactions t
JOIN ref.merchants m ON m.merchant_id = t.merchant_id
WHERE t.amount < 0
GROUP BY m.name
ORDER BY total_spending DESC
LIMIT 20;

-- 8. Function demo.
SELECT plans.run_recurring(CURRENT_DATE);

-- 9. Index performance proof examples: run before and after indexes if testing manually.
EXPLAIN ANALYZE
SELECT * FROM finance.transactions
WHERE account_id = 10 AND txn_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';

EXPLAIN ANALYZE
SELECT category_id, SUM(amount) FROM finance.transactions
WHERE txn_date >= DATE '2025-01-01'
GROUP BY category_id;
