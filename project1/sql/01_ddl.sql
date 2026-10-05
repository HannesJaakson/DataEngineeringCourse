-- =====================================================================
-- Project 1 – Store POS sales data warehouse (PostgreSQL 16)
-- Layers: staging (1:1 from parsed XML / API)  ->  dw (star schema)
-- Physical implementation follows in Project 2; this DDL documents the design.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS dw;

-- ---------------------------------------------------------------------
-- STAGING: one row per parsed XML element / API record, no business logic
-- ---------------------------------------------------------------------

-- Sales line from POS (VSP) XML file, already anonymised
CREATE TABLE IF NOT EXISTS staging.stg_pos_sales_line (
    src_line_id        BIGINT        NOT NULL,          -- line id in source file
    src_file_name      VARCHAR(255)  NOT NULL,          -- daily XML file name
    xsd_version        SMALLINT      NOT NULL,          -- XSD version used to validate
    store_id           INTEGER       NOT NULL,          -- anonymised store id
    till_no            INTEGER       NOT NULL,
    receipt_no         INTEGER       NOT NULL,
    sale_ts            TIMESTAMP     NOT NULL,
    customer_hash      VARCHAR(16),                     -- HMAC of loyalty card, NULL = no card
    product_code       VARCHAR(16)   NOT NULL,
    sku_id             VARCHAR(50),
    product_name       VARCHAR(255),
    segment_code       VARCHAR(50),
    segment_name       VARCHAR(100),
    quantity           NUMERIC(16,4) NOT NULL,
    sales_amount       NUMERIC(16,4) NOT NULL,
    regular_price      NUMERIC(16,4),
    discount_amount    NUMERIC(16,4),
    vat_rate           NUMERIC(5,2),
    campaign_code      VARCHAR(30),
    discount_type_id   SMALLINT,                        -- XSD code (manual / employee)
    discount_category  VARCHAR(50),                     -- generic category of the discount
    loaded_at          TIMESTAMP     NOT NULL DEFAULT now(),
    PRIMARY KEY (src_file_name, src_line_id)
);

-- Payment lines of a receipt (raha_kaive); a receipt can have several (e.g. card + gift card)
CREATE TABLE IF NOT EXISTS staging.stg_pos_payment (
    src_file_name      VARCHAR(255)  NOT NULL,
    payment_line_no    SMALLINT      NOT NULL,          -- 1..n within the receipt
    store_id           INTEGER       NOT NULL,
    till_no            INTEGER       NOT NULL,
    receipt_no         INTEGER       NOT NULL,
    payment_ts         TIMESTAMP     NOT NULL,
    payment_type_id    SMALLINT      NOT NULL,
    amount             NUMERIC(16,4) NOT NULL,
    loaded_at          TIMESTAMP     NOT NULL DEFAULT now(),
    PRIMARY KEY (src_file_name, till_no, receipt_no, payment_line_no)
);

-- Hourly weather observations (Estonian Environment Agency open data)
CREATE TABLE IF NOT EXISTS staging.stg_weather_hourly (
    station_code       VARCHAR(20)   NOT NULL,
    observation_ts     TIMESTAMP     NOT NULL,
    air_temp_c         NUMERIC(5,2),
    precipitation_mm   NUMERIC(6,2),
    wind_speed_ms      NUMERIC(5,2),
    wind_gust_ms       NUMERIC(5,2),
    rel_humidity_pct   NUMERIC(5,2),
    air_pressure_hpa   NUMERIC(6,1),
    snow_depth_cm      NUMERIC(5,1),
    loaded_at          TIMESTAMP     NOT NULL DEFAULT now(),
    PRIMARY KEY (station_code, observation_ts)
);

-- Estonian public holidays
CREATE TABLE IF NOT EXISTS staging.stg_public_holiday (
    holiday_date       DATE          PRIMARY KEY,
    holiday_name       VARCHAR(100)  NOT NULL
);

-- Classifiers read from the XSD (fixed code lists)
CREATE TABLE IF NOT EXISTS staging.ref_payment_type   (code SMALLINT PRIMARY KEY, name VARCHAR(50) NOT NULL);
CREATE TABLE IF NOT EXISTS staging.ref_discount_type  (code SMALLINT PRIMARY KEY, name VARCHAR(100) NOT NULL);
CREATE TABLE IF NOT EXISTS staging.ref_campaign_type  (code SMALLINT PRIMARY KEY, name VARCHAR(100) NOT NULL);
CREATE TABLE IF NOT EXISTS staging.ref_campaign_subtype (code SMALLINT PRIMARY KEY, name VARCHAR(100) NOT NULL);

-- ---------------------------------------------------------------------
-- DW: star schema (2 facts sharing conformed dimensions)
-- ---------------------------------------------------------------------

-- Static: generated calendar, enriched with holidays
CREATE TABLE IF NOT EXISTS dw.dim_date (
    date_key              INTEGER      PRIMARY KEY,      -- yyyymmdd
    full_date             DATE         NOT NULL UNIQUE,
    year                  SMALLINT     NOT NULL,
    quarter               SMALLINT     NOT NULL,
    month                 SMALLINT     NOT NULL,
    month_name            VARCHAR(10)  NOT NULL,
    iso_week              SMALLINT     NOT NULL,
    day_of_month          SMALLINT     NOT NULL,
    day_of_week           SMALLINT     NOT NULL,         -- 1 = Monday
    day_name              VARCHAR(10)  NOT NULL,
    is_weekend            BOOLEAN      NOT NULL,
    is_public_holiday     BOOLEAN      NOT NULL,
    holiday_name          VARCHAR(100),
    is_day_before_holiday BOOLEAN      NOT NULL
);

-- Static: one row per hour of weather observations at the nearest station
CREATE TABLE IF NOT EXISTS dw.dim_weather (
    weather_key        BIGINT        PRIMARY KEY,        -- yyyymmddhh
    observation_ts     TIMESTAMP     NOT NULL UNIQUE,
    station_code       VARCHAR(20)   NOT NULL,
    air_temp_c         NUMERIC(5,2),
    precipitation_mm   NUMERIC(6,2),
    wind_speed_ms      NUMERIC(5,2),
    rel_humidity_pct   NUMERIC(5,2),
    snow_depth_cm      NUMERIC(5,1),
    temp_band          VARCHAR(20),                      -- e.g. '<0', '0-10', '10-20', '>20'
    is_rainy           BOOLEAN       NOT NULL
);

-- SCD Type 1: overwrite
CREATE TABLE IF NOT EXISTS dw.dim_store (
    store_key              SERIAL       PRIMARY KEY,
    store_id               INTEGER      NOT NULL UNIQUE,  -- anonymised business key
    store_name             VARCHAR(50)  NOT NULL,         -- e.g. 'Store A'
    store_format           VARCHAR(50),                   -- supermarket / convenience
    region                 VARCHAR(50),                   -- generic, e.g. 'Region A' (no real location)
    sales_area_m2          NUMERIC(10,2),
    self_checkout_count    SMALLINT,
    opening_time           TIME,
    closing_time           TIME,
    weather_station_code   VARCHAR(20)                    -- set in private config, not published
);

-- SCD Type 2: keeps history of name and segment
CREATE TABLE IF NOT EXISTS dw.dim_product (
    product_key        SERIAL        PRIMARY KEY,
    product_code       VARCHAR(16)   NOT NULL,            -- business key
    sku_id             VARCHAR(50),
    product_name       VARCHAR(255)  NOT NULL,
    segment_code       VARCHAR(50),
    segment_name       VARCHAR(100),
    segment_level1     VARCHAR(100),                      -- derived from segment hierarchy
    valid_from         DATE          NOT NULL,
    valid_to           DATE          NOT NULL DEFAULT DATE '9999-12-31',
    is_current         BOOLEAN       NOT NULL DEFAULT TRUE,
    UNIQUE (product_code, valid_from)
);

-- SCD Type 1: campaign status/type overwritten
CREATE TABLE IF NOT EXISTS dw.dim_campaign (
    campaign_key       SERIAL        PRIMARY KEY,
    campaign_code      VARCHAR(30)   NOT NULL UNIQUE,     -- pseudonymised code; 'NONE' row for non-campaign sales
    campaign_type      VARCHAR(100),
    campaign_subtype   VARCHAR(100),
    is_campaign        BOOLEAN       NOT NULL
);

-- Static: generic discount categories (free-text discount names mapped during anonymisation)
CREATE TABLE IF NOT EXISTS dw.dim_discount_type (
    discount_type_key  SMALLINT      PRIMARY KEY,         -- 0 = no discount
    discount_category  VARCHAR(50)   NOT NULL UNIQUE,
    discount_group     VARCHAR(20)   NOT NULL             -- campaign / price / personal / none
);

-- Static (code list from XSD)
CREATE TABLE IF NOT EXISTS dw.dim_payment_type (
    payment_type_key   SMALLINT      PRIMARY KEY,
    payment_type_name  VARCHAR(50)   NOT NULL,
    payment_group      VARCHAR(20)   NOT NULL             -- cash / card / voucher / loyalty
);

-- FACT 1 – grain: one product line on one receipt
CREATE TABLE IF NOT EXISTS dw.fact_sales (
    sales_line_id      BIGSERIAL     PRIMARY KEY,
    date_key           INTEGER       NOT NULL REFERENCES dw.dim_date,
    weather_key        BIGINT        REFERENCES dw.dim_weather,
    store_key          INTEGER       NOT NULL REFERENCES dw.dim_store,
    product_key        INTEGER       NOT NULL REFERENCES dw.dim_product,
    campaign_key       INTEGER       NOT NULL REFERENCES dw.dim_campaign,
    discount_type_key  SMALLINT      NOT NULL REFERENCES dw.dim_discount_type,
    receipt_id         VARCHAR(40)   NOT NULL,            -- degenerate: store-till-receipt-date
    till_no            INTEGER       NOT NULL,
    sale_ts            TIMESTAMP     NOT NULL,
    sale_hour          SMALLINT      NOT NULL,
    customer_hash      VARCHAR(16),                       -- pseudonymous customer, NULL = no card
    has_loyalty_card   BOOLEAN       NOT NULL,
    quantity           NUMERIC(16,4) NOT NULL,
    sales_amount       NUMERIC(16,4) NOT NULL,            -- paid, incl. VAT
    regular_price      NUMERIC(16,4),                     -- unit price before discount
    discount_amount    NUMERIC(16,4) NOT NULL DEFAULT 0,
    vat_rate           NUMERIC(5,2),
    src_file_name      VARCHAR(255)  NOT NULL,
    src_line_id        BIGINT        NOT NULL,
    UNIQUE (src_file_name, src_line_id)
);

-- FACT 2 – grain: one payment line of a receipt (payment method + amount).
-- A receipt has 1..n rows, e.g. card 20 EUR + gift card 10 EUR = 2 rows.
CREATE TABLE IF NOT EXISTS dw.fact_payment (
    payment_line_id    BIGSERIAL     PRIMARY KEY,
    date_key           INTEGER       NOT NULL REFERENCES dw.dim_date,
    store_key          INTEGER       NOT NULL REFERENCES dw.dim_store,
    payment_type_key   SMALLINT      NOT NULL REFERENCES dw.dim_payment_type,
    receipt_id         VARCHAR(40)   NOT NULL,            -- degenerate: links to fact_sales
    payment_line_no    SMALLINT      NOT NULL,            -- 1..n within the receipt
    payment_ts         TIMESTAMP     NOT NULL,
    amount             NUMERIC(16,4) NOT NULL,
    UNIQUE (receipt_id, payment_line_no)
);

CREATE INDEX IF NOT EXISTS ix_fact_sales_date    ON dw.fact_sales (date_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_product ON dw.fact_sales (product_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_receipt ON dw.fact_sales (receipt_id);
CREATE INDEX IF NOT EXISTS ix_fact_payment_receipt ON dw.fact_payment (receipt_id);

-- ---------------------------------------------------------------------
-- Static seed rows (from XSD v26 classifiers)
-- ---------------------------------------------------------------------
INSERT INTO dw.dim_payment_type VALUES
 (1,'Cash','cash'),(2,'Card','card'),(3,'Invoice','other'),(4,'Bottle deposit voucher','voucher'),
 (5,'Gift card','voucher'),(6,'Bonus points','loyalty'),(7,'Säästukaart+','loyalty'),(14,'Cash withdrawal','cash'),
 (17,'Other (code 17)','other'),(18,'Other (code 18)','other'),(19,'Other (code 19)','other')
ON CONFLICT DO NOTHING;

INSERT INTO dw.dim_discount_type VALUES
 (0,'No discount','none'),(1,'Weekly campaign','campaign'),(2,'Monthly campaign','campaign'),
 (3,'Promotional price','campaign'),(4,'Digital offer','campaign'),(5,'Supplier promotion','campaign'),
 (6,'Permanent low price','price'),(7,'Line discount','price'),(8,'Employee discount','personal'),
 (9,'Loyalty personal offer','personal'),(10,'Other promotion','campaign')
ON CONFLICT DO NOTHING;

INSERT INTO dw.dim_campaign (campaign_code, campaign_type, campaign_subtype, is_campaign)
VALUES ('NONE', NULL, NULL, FALSE)
ON CONFLICT DO NOTHING;
