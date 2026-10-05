# Data model – star schema

Two fact tables share conformed dimensions (a small *fact constellation*). `fact_sales` is the main fact; `fact_payment` exists because payments belong to the receipt, not to individual product lines.

```mermaid
erDiagram
    dim_date          ||--o{ fact_sales   : date_key
    dim_weather       ||--o{ fact_sales   : weather_key
    dim_store         ||--o{ fact_sales   : store_key
    dim_product       ||--o{ fact_sales   : product_key
    dim_campaign      ||--o{ fact_sales   : campaign_key
    dim_discount_type ||--o{ fact_sales   : discount_type_key
    dim_date          ||--o{ fact_payment : date_key
    dim_store         ||--o{ fact_payment : store_key
    dim_payment_type  ||--o{ fact_payment : payment_type_key

    fact_sales {
        bigint sales_line_id PK
        int date_key FK
        bigint weather_key FK
        int store_key FK
        int product_key FK
        int campaign_key FK
        smallint discount_type_key FK
        varchar receipt_id "degenerate"
        timestamp sale_ts
        smallint sale_hour
        boolean has_loyalty_card
        numeric quantity
        numeric sales_amount
        numeric regular_price
        numeric discount_amount
        numeric vat_rate
    }
    fact_payment {
        bigint payment_line_id PK
        int date_key FK
        int store_key FK
        smallint payment_type_key FK
        varchar receipt_id "degenerate"
        smallint payment_line_no
        timestamp payment_ts
        numeric amount
    }
    dim_product {
        int product_key PK
        varchar product_code "business key"
        varchar product_name
        varchar segment_code
        varchar segment_name
        date valid_from
        date valid_to
        boolean is_current
    }
    dim_store {
        int store_key PK
        int store_id "business key"
        varchar store_format
        varchar region
        numeric sales_area_m2
    }
    dim_date {
        int date_key PK
        date full_date
        smallint day_of_week
        boolean is_weekend
        boolean is_public_holiday
        boolean is_day_before_holiday
    }
    dim_weather {
        bigint weather_key PK
        timestamp observation_ts
        numeric air_temp_c
        numeric precipitation_mm
        boolean is_rainy
    }
    dim_campaign {
        int campaign_key PK
        varchar campaign_code
        varchar campaign_type
        boolean is_campaign
    }
    dim_discount_type {
        smallint discount_type_key PK
        varchar discount_type_name
    }
    dim_payment_type {
        smallint payment_type_key PK
        varchar payment_type_name
        varchar payment_group
    }
```

## Grain

- **fact_sales:** one row = **one product line on one receipt** (one scan event at the till). This is the lowest level available in the POS file, so any aggregate (receipt, hour, day, segment) can be derived from it.
- **fact_payment:** one row = **one payment line of a receipt** (payment method + amount). A receipt has one or more rows: in the sample day 2,610 receipts produced 2,714 payment lines, because some receipts were paid with several methods (e.g. card + gift card).
- The two facts are linked through the degenerate dimension `receipt_id` (store–till–receipt number–date), which also lets us compute basket size and basket value.

## Slowly Changing Dimensions

| Dimension | SCD type | Reasoning |
|---|---|---|
| `dim_product` | **Type 2** | Products are regularly renamed and moved between segments (category management). Sales must be reported under the segment that was valid *at the time of sale*, otherwise historical category trends would change retroactively. Tracked attributes: `product_name`, `segment_code`, `segment_name`. The regular price changes too often to be an SCD attribute; it is stored as a measure in the fact (`regular_price`). |
| `dim_store` | **Type 1** | Store attributes (area, number of self-checkouts, opening hours) change rarely and are mostly corrections. With a single store, keeping history adds no analytical value, so changes are overwritten. |
| `dim_campaign` | **Type 1** | A campaign's status changes from *active* to *ended/cancelled* (XSD classifier); only the latest status matters, so it is overwritten. The campaign period itself is visible through the sales dates. |
| `dim_date` | **Static** | Generated calendar; values never change. Holiday flags come from the public holiday list. |
| `dim_weather` | **Static** | Historical observations do not change after they are recorded. |
| `dim_discount_type` | **Static** | Fixed list of generic discount categories (free-text names are mapped during anonymisation). New categories add rows. |
| `dim_payment_type` | **Static** | Fixed code list from the XSD. A new XSD version would add rows, not change existing ones. |
