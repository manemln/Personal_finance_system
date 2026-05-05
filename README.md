# Personal_finance_system
Personal Finance Hub (PostgreSQL)
The Personal Finance Hub is a PostgreSQL-based database system designed to help users
manage and analyze their financial data. It provides a structured way to store and process
information about accounts, transactions, budgets, savings goals, recurring payments, and loans.
This project focuses on data modeling, integrity, and analytical querying rather than UI
development. All interactions are performed through SQL queries.
The system enables tracking income and expenses, managing multiple financial accounts, setting
and monitoring budgets, handling recurring transactions, managing loans, and generating analytical
financial reports.
ERD (Entity Relationship Diagram)
The ERD is provided as an image file (ERD.png), which visually represents all entities, their
relationships, and cardinalities. No XML file is included, as the diagram is finalized and not intended
for further modification.
Core Functionality
User and Account Management: Each user can own multiple accounts, and accounts store
balances and are linked to transactions.
Transaction System: Records all financial activity, including income and expenses. Each
transaction is linked to an account, a category, and optionally a merchant.
Budgeting System: Users can define monthly budgets per category, allowing comparison between
planned and actual spending.
Recurring Transactions: Supports automation logic for repeating financial operations such as rent,
subscriptions, and salaries.
Goals and Savings: Users can define savings goals with target amounts and track their progress
over time.
Loan Management: Stores loan details such as principal and interest rate and tracks repayments
through linked transactions.
Audit System: Tracks INSERT, UPDATE, and DELETE operations to ensure accountability and
maintain historical records.
Usage Notes
This project is not UI-based. It is intended to be explored through SQL queries using any SQL
environment such as pgAdmin, DBeaver, DataGrip, or VS Code SQL extensions.
The main interaction with the system is done through the DQL file, which contains independent
query blocks. Each block represents a specific business or analytical task and can be executed
individually.
Query Capabilities
The system supports analytical queries such as monthly spending by category, budget versus
actual comparisons, top merchants, and loan repayment progress.
It also supports business logic queries including overspending detection, high-value transactions,
and user financial summaries.
Advanced SQL features are used, including different types of JOINs, subqueries, aggregations, and
indexing for performance optimization.
Data Volume
The database is populated with large datasets to simulate real-world usage. This includes
approximately 1000 users, 2000 or more accounts, over 10,000 transactions, and significant data
across all supporting tables.
Performance Considerations
Indexes are implemented to optimize performance for transaction filtering, category-based analysis,
and budget queries. Performance improvements can be observed using EXPLAIN ANALYZE in
supported SQL environments.
