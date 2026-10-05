# Project 1 – Store POS sales data warehouse (Priit's part)

| File | Report section |
|---|---|
| `01_datasets.md` | 2. Datasets (sources, size, update frequency, anonymisation) |
| `02_star_schema.md` | 5. Data model – ER diagram (Mermaid), grain, SCD justification |
| `03_data_dictionary.md` | 6. Data dictionary – all `dw` tables and columns with types |
| `sql/01_ddl.sql` | DDL – staging + star schema (PostgreSQL 16, tested) |
| `sql/02_scd2_dim_product.sql` | SCD Type 2 load for `dim_product` (tested) |

Run: `psql -v ON_ERROR_STOP=1 -f sql/01_ddl.sql`
SCD2 load for one day: `psql -v load_date=2026-09-01 -f sql/02_scd2_dim_product.sql`

Note: the 3-page report should contain the ER diagram, grain and SCD table; the full data dictionary fits better in the GitHub repo (link from the report).
