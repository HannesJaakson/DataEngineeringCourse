# Testing the demo queries

The existing practice PostgreSQL and pgAdmin containers are used. The database
`project1_demo` contains the project schema and synthetic sample data: 16 sales
lines, 8 receipts, 4 dates and 8 payment lines. These are learning examples, not
real store records or the datasets required for submission.

## In pgAdmin

1. Open http://localhost:5052 and log in with your practice pgAdmin credentials.
2. Expand your existing PostgreSQL server, then **Databases**. Right-click
   **Databases** and choose **Refresh** if `project1_demo` is missing.
3. Right-click **project1_demo** and choose **Query Tool**.
4. Paste one query from [04_demo_queries.sql](sql/04_demo_queries.sql), then run
   it with **Execute/Refresh** (F5). If you paste multiple queries, select the
   complete query you want to run first. For a `WITH` query, select both the
   `WITH` block and the final `SELECT` through its semicolon.
5. Read the results under **Data Output**.

Start with:

```sql
SELECT current_database();

SELECT COUNT(*) AS sales_lines,
       COUNT(DISTINCT receipt_id) AS receipts,
       SUM(sales_amount) AS total_sales_eur
FROM dw.fact_sales;
```

Expected: `project1_demo`, then **16 lines, 8 receipts, EUR 51.70**.

To inspect the tables, expand **project1_demo > Schemas > dw > Tables**.

If there is no saved server connection, register one with host `db`, port `5432`,
maintenance database `postgres`, username `data_engineer`, and your practice
PostgreSQL password. The browser-based pgAdmin container uses Docker's internal
host and port. A database client running directly on your computer instead uses
`localhost:5434`.

Your practice configuration folder is
`/home/hannesja/OneDrive/UT/Data Engineering/data_engineering_2026/02_Star_Schema/praks2/`.
The `.env` file there contains the configured login values. The pgAdmin login and
PostgreSQL connection credentials are separate.

## Expected query results

| Query | Check |
|---|---|
| 1. Daily sales | June 21: EUR 17.50, 3 receipts, average basket EUR 5.83 |
| 2. Product segments | Alcohol EUR 22.00; Dairy EUR 12.00; Bakery EUR 11.70; Fresh bakery EUR 6.00 |
| 3. Campaigns | Campaign sales EUR 12.00 (23.21%), discounts EUR 3.00; non-campaign discounts EUR 0.30 |
| 4. Holidays | Other day EUR 17.50; day before holiday EUR 14.40; public holidays EUR 9.90 average |
| 5. Weather | Dry: 4 hours, EUR 6.05 average; rainy: 3 hours, EUR 9.17 average |

Bread changes segment on June 23, demonstrating the historical product join.
June 23 is both a holiday and the day before another holiday, demonstrating
`CASE` priority. One weather hour has no sales and is excluded from query 5.

## Files and restarting

- [01_ddl.sql](sql/01_ddl.sql): original project table definitions.
- [03_demo_seed.sql](sql/03_demo_seed.sql): synthetic sample data; already loaded.
- [04_demo_queries.sql](sql/04_demo_queries.sql): the five queries, ready to copy.

You can rerun the queries freely. Do not rerun the sample loader; it rejects a
database that already contains sales.

If Docker is running but the containers are stopped:

```bash
docker start star-schema-practice-db-1 star-schema-practice-pgadmin-1
```

The database is stored in the existing PostgreSQL data volume and survives
ordinary container stops and starts.
