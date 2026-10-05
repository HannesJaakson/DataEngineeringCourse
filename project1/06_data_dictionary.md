# 6. Data dictionary (schema `dw`)

Types are PostgreSQL types. Staging tables (`staging.*`) mirror the sources 1:1 and are documented in `sql/01_ddl.sql`.

## fact_sales

Grain: one product line on one receipt.

| Column | Type | Key | Null | Description |
|---|---|---|---|---|
| `sales_line_id` | BIGINT | PK | no | Surrogate key |
| `date_key` | INTEGER | FK | no | FK → dim_date |
| `weather_key` | BIGINT | FK | yes | FK → dim_weather (sale hour) |
| `store_key` | INTEGER | FK | no | FK → dim_store |
| `product_key` | INTEGER | FK | no | FK → dim_product (version valid at sale time) |
| `campaign_key` | INTEGER | FK | no | FK → dim_campaign |
| `discount_type_key` | SMALLINT | FK | no | FK → dim_discount_type |
| `receipt_id` | VARCHAR(40) |  | no | Degenerate dim: store-till-receipt-date |
| `till_no` | INTEGER |  | no | Till number |
| `sale_ts` | TIMESTAMP |  | no | Timestamp of sale |
| `sale_hour` | SMALLINT |  | no | Hour of sale 0–23 |
| `customer_hash` | VARCHAR(16) |  | yes | Pseudonymous customer id (HMAC-SHA256 of loyalty card), NULL = no card |
| `has_loyalty_card` | BOOLEAN |  | no | Loyalty card presented on receipt |
| `quantity` | NUMERIC(16,4) |  | no | Quantity sold (pcs or kg) |
| `sales_amount` | NUMERIC(16,4) |  | no | Amount paid incl. VAT, € |
| `regular_price` | NUMERIC(16,4) |  | yes | Regular unit price before discount, € |
| `discount_amount` | NUMERIC(16,4) |  | no | Discount on the line, € |
| `vat_rate` | NUMERIC(5,2) |  | yes | VAT rate, % |
| `src_file_name` | VARCHAR(255) |  | no | Lineage: source XML file |
| `src_line_id` | BIGINT |  | no | Lineage: line id in source file |

## fact_payment

Grain: one payment line of a receipt (payment method + amount); a receipt has 1..n rows.

| Column | Type | Key | Null | Description |
|---|---|---|---|---|
| `payment_line_id` | BIGINT | PK | no | Surrogate key |
| `date_key` | INTEGER | FK | no | FK → dim_date |
| `store_key` | INTEGER | FK | no | FK → dim_store |
| `payment_type_key` | SMALLINT | FK | no | FK → dim_payment_type |
| `receipt_id` | VARCHAR(40) |  | no | Degenerate dim: store-till-receipt-date |
| `payment_line_no` | SMALLINT |  | no | Payment line number within the receipt (1..n) |
| `payment_ts` | TIMESTAMP |  | no | Payment timestamp |
| `amount` | NUMERIC(16,4) |  | no | Paid amount, € |

## dim_date

Calendar dimension, one row per day (static).

| Column | Type | Key | Null | Description |
|---|---|---|---|---|
| `date_key` | INTEGER | PK | no | Surrogate key, yyyymmdd |
| `full_date` | DATE |  | no | Calendar date |
| `year` | SMALLINT |  | no | Year |
| `quarter` | SMALLINT |  | no | Quarter 1–4 |
| `month` | SMALLINT |  | no | Month 1–12 |
| `month_name` | VARCHAR(10) |  | no | Month name |
| `iso_week` | SMALLINT |  | no | ISO week number |
| `day_of_month` | SMALLINT |  | no | Day of month |
| `day_of_week` | SMALLINT |  | no | ISO day of week, 1 = Monday |
| `day_name` | VARCHAR(10) |  | no | Day name |
| `is_weekend` | BOOLEAN |  | no | Saturday or Sunday |
| `is_public_holiday` | BOOLEAN |  | no | Estonian public holiday |
| `holiday_name` | VARCHAR(100) |  | yes | Name of the holiday, if any |
| `is_day_before_holiday` | BOOLEAN |  | no | Day before a public holiday (shopping peak) |

## dim_weather

Hourly weather at the station nearest to the store (static).

| Column | Type | Key | Null | Description |
|---|---|---|---|---|
| `weather_key` | BIGINT | PK | no | Surrogate key, yyyymmddhh |
| `observation_ts` | TIMESTAMP |  | no | Observation hour |
| `station_code` | VARCHAR(20) |  | no | Weather station id |
| `air_temp_c` | NUMERIC(5,2) |  | yes | Air temperature, °C |
| `precipitation_mm` | NUMERIC(6,2) |  | yes | Precipitation during the hour, mm |
| `wind_speed_ms` | NUMERIC(5,2) |  | yes | Mean wind speed, m/s |
| `rel_humidity_pct` | NUMERIC(5,2) |  | yes | Relative humidity, % |
| `snow_depth_cm` | NUMERIC(5,1) |  | yes | Snow depth, cm |
| `temp_band` | VARCHAR(20) |  | yes | Temperature band for grouping |
| `is_rainy` | BOOLEAN |  | no | precipitation_mm > 0 |

## dim_store

Store dimension, SCD Type 1.

| Column | Type | Key | Null | Description |
|---|---|---|---|---|
| `store_key` | INTEGER | PK | no | Surrogate key |
| `store_id` | INTEGER |  | no | Anonymised business key of the store |
| `store_name` | VARCHAR(50) |  | no | Anonymised name ('Store A') |
| `store_format` | VARCHAR(50) |  | yes | Store format, e.g. supermarket |
| `region` | VARCHAR(50) |  | yes | Generic region label ('Region A'); real location is not published |
| `sales_area_m2` | NUMERIC(10,2) |  | yes | Sales area, m² |
| `self_checkout_count` | SMALLINT |  | yes | Number of self-checkout tills |
| `opening_time` | TIME WITHOUT TIME ZONE |  | yes | Opening time |
| `closing_time` | TIME WITHOUT TIME ZONE |  | yes | Closing time |
| `weather_station_code` | VARCHAR(20) |  | yes | Nearest weather station (kept in private config, not published) |

## dim_product

Product dimension, SCD Type 2 (history of name and segment).

| Column | Type | Key | Null | Description |
|---|---|---|---|---|
| `product_key` | INTEGER | PK | no | Surrogate key (one per product version) |
| `product_code` | VARCHAR(16) |  | no | Business key – product code from POS |
| `sku_id` | VARCHAR(50) |  | yes | SKU id |
| `product_name` | VARCHAR(255) |  | no | Product name |
| `segment_code` | VARCHAR(50) |  | yes | Product segment code |
| `segment_name` | VARCHAR(100) |  | yes | Product segment name |
| `segment_level1` | VARCHAR(100) |  | yes | Top level of the segment hierarchy |
| `valid_from` | DATE |  | no | Version valid from (inclusive) |
| `valid_to` | DATE |  | no | Version valid to (9999-12-31 = open) |
| `is_current` | BOOLEAN |  | no | TRUE for the current version |

## dim_campaign

Campaign dimension, SCD Type 1. Row 'NONE' = no campaign.

| Column | Type | Key | Null | Description |
|---|---|---|---|---|
| `campaign_key` | INTEGER | PK | no | Surrogate key |
| `campaign_code` | VARCHAR(30) |  | no | Business key – pseudonymised campaign code |
| `campaign_type` | VARCHAR(100) |  | yes | Campaign type from XSD classifier |
| `campaign_subtype` | VARCHAR(100) |  | yes | Campaign sub-type (media, display, markdown, expiry markdown) |
| `is_campaign` | BOOLEAN |  | no | FALSE only for the 'NONE' row |

## dim_discount_type

Generic discount categories (static); free-text discount names are mapped to these during anonymisation.

| Column | Type | Key | Null | Description |
|---|---|---|---|---|
| `discount_type_key` | SMALLINT | PK | no | Code (0 = no discount) |
| `discount_category` | VARCHAR(50) |  | no | Generic discount category (weekly campaign, employee discount, …) |
| `discount_group` | VARCHAR(20) |  | no | campaign / price / personal / none |

## dim_payment_type

Payment method code list from XSD (static).

| Column | Type | Key | Null | Description |
|---|---|---|---|---|
| `payment_type_key` | SMALLINT | PK | no | Code |
| `payment_type_name` | VARCHAR(50) |  | no | Payment method |
| `payment_group` | VARCHAR(20) |  | no | Grouping: cash / card / voucher / loyalty / other |
