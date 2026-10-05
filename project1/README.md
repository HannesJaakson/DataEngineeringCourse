# Project 1 – Store POS sales data warehouse

Design of a data warehouse combining store POS sales, hourly weather observations,
and Estonian public holidays. Project 1 documents the architecture and dimensional
model; the full pipeline will be implemented in Project 2.

| File | Report section |
|---|---|
| [01_datasets.md](01_datasets.md) | Datasets (sources, size, update frequency, anonymisation) |
| [02_star_schema.md](02_star_schema.md) | Data model – ER diagram (Mermaid), grain, SCD justification |
| [03_data_dictionary.md](03_data_dictionary.md) | Data dictionary – all `dw` tables and columns with types |
| [04_architecture.md](04_architecture.md) | Proposed tools and architecture. Data flow, loading schedules, data quality checks, and failure handling |
| [05_business_brief.md](05_business_brief.md) | Business Brief |
| [06_demo_queries.md](06_demo_queries.md) | Demo Queries |
| [TESTING.md](TESTING.md) | Local query testing with synthetic data |
| [sql/01_ddl.sql](sql/01_ddl.sql) | DDL – staging + star schema (PostgreSQL 16, tested) |
| [sql/02_scd2_dim_product.sql](sql/02_scd2_dim_product.sql) | SCD Type 2 load for `dim_product` (tested) |

Run from the `project1` directory against a PostgreSQL database:

`psql -v ON_ERROR_STOP=1 -f sql/01_ddl.sql`

SCD2 load for one day: `psql -v load_date=2026-09-01 -f sql/02_scd2_dim_product.sql`

The 3-page report should summarise the architecture, tools, quality checks, ER
diagram, grain, and SCD choices alongside the other required sections. Link to
this repository for the detailed documentation and SQL.
