# Project 1 - Store POS sales data warehouse

Files follow the section numbers in the homework.

| File | Report section |
|---|---|
| [01_business_brief.md](01_business_brief.md) | 1. Business Brief - objective, stakeholders, KPIs and questions |
| [02_datasets.md](02_datasets.md) | 2. Datasets - sources, size, update frequency and anonymisation |
| [05_data_model.md](05_data_model.md) | 5. Data Model - star schema, grain and SCD justification |
| [06_data_dictionary.md](06_data_dictionary.md) | 6. Data Dictionary - all `dw` tables and columns with types |
| [07_demo_queries.md](07_demo_queries.md) | 7. Demo Queries - SQL answering the business questions |
| [sql/01_ddl.sql](sql/01_ddl.sql) | DDL - staging and star schema (PostgreSQL 16) |
| [sql/02_scd2_dim_product.sql](sql/02_scd2_dim_product.sql) | SCD Type 2 load for `dim_product` |

Sections 3 (Tooling) and 4 (Data Architecture) are still to be added.

Run: `psql -v ON_ERROR_STOP=1 -f sql/01_ddl.sql`

SCD2 load for one day: `psql -v load_date=2026-09-01 -f sql/02_scd2_dim_product.sql`

For the later submission, the report is limited to three pages and must include group members' roles, contribution percentages and links to any AI/LLM chats used. Keep the full data dictionary and demo queries in this repository and reference them from the report.

## Query testing

See [TESTING.md](TESTING.md) to run the demo queries in the existing Docker PostgreSQL and pgAdmin setup. The `project1_demo` database uses small synthetic examples.
