# 2. Datasets

| # | Dataset | Source & ingestion | Size | Update frequency |
|---|---|---|---|---|
| D1 | **Store POS sales** – every product line scanned at the tills of one grocery store | Daily VSP XML files exported from the retailer's POS system; structure defined by an XSD (v26). File load (batch). Data is anonymised before it enters our pipeline. | Sample day: 2,610 receipts, 16,435 sales lines, 2,714 payments → ~0.5–1.5 M lines for 1–3 months; 20 columns per sales line | Daily (one file per store per day) |
| D2 | **Hourly weather observations** | Estonian Environment Agency (Keskkonnaagentuur / ilmateenistus.ee) open data, nearest station to the store. API pull. | 24 rows/day → ~2,200 rows per quarter; 9 columns | Hourly (we load daily) |
| D3 | **Estonian public holidays** | Public calendar (riigipühad), used to enrich the date dimension. File load. | ~15 rows/year | Yearly |

**D1 – main attributes (per sales line):** store, till, receipt number, timestamp, product code / SKU, product name, segment code and name, quantity, sales amount, regular price, discount amount, VAT rate, campaign code, discount type, loyalty card used (yes/no). Code lists (payment type, discount type, campaign type/sub-type, VAT rates) are read from the XSD.


**Anonymisation (done locally, before the data enters the pipeline):** store, customer and cashier identifiers are removed or pseudonymised, and only sales and campaign data are kept.

**Why these datasets:** D1 is high-granularity, transactional data with a real daily update cycle, which lets us build a realistic incremental pipeline in Project 2. D2 and D3 are external, independently sourced datasets that let us explain *why* sales change (weather, holidays), and they are joined to D1 through time (date / hour).
