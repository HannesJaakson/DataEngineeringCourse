-- Synthetic learning data, not real store records or homework source data.
-- Run once in project1_demo after 01_ddl.sql. All inserts form one transaction.
BEGIN;
DO $$
BEGIN
    IF current_database() <> 'project1_demo' THEN
        RAISE EXCEPTION 'Select project1_demo before running this file';
    END IF;
    IF EXISTS (SELECT 1 FROM dw.fact_sales) THEN
        RAISE EXCEPTION 'Sales already exist; this sample loader must run only once';
    END IF;
END $$;

INSERT INTO dw.dim_date
    (date_key, full_date, year, quarter, month, month_name, iso_week,
     day_of_month, day_of_week, day_name, is_weekend, is_public_holiday,
     holiday_name, is_day_before_holiday)
SELECT to_char(d, 'YYYYMMDD')::int, d::date,
       2026, 2, 6, 'June', extract(week FROM d)::int,
       extract(day FROM d)::int, extract(isodow FROM d)::int,
       trim(to_char(d, 'Day')), extract(isodow FROM d) IN (6, 7),
       d::date IN (DATE '2026-06-23', DATE '2026-06-24'),
       CASE d::date WHEN DATE '2026-06-23' THEN 'Victory Day'
                    WHEN DATE '2026-06-24' THEN 'Midsummer Day' END,
       d::date IN (DATE '2026-06-22', DATE '2026-06-23')
FROM generate_series(TIMESTAMP '2026-06-21', TIMESTAMP '2026-06-24', INTERVAL '1 day') AS dates(d);

INSERT INTO dw.dim_store (store_id, store_name, store_format, region)
VALUES (1, 'Demo Store', 'Grocery store', 'Demo region');

INSERT INTO dw.dim_product
    (product_code, product_name, segment_code, segment_name, valid_from, valid_to, is_current)
VALUES ('MILK', 'Milk', 'DAIRY', 'Dairy', '2026-01-01', '9999-12-31', true),
       ('BREAD', 'Bread', 'BAKERY', 'Bakery', '2026-01-01', '2026-06-22', false),
       ('BREAD', 'Bread', 'FRESH', 'Fresh bakery', '2026-06-23', '9999-12-31', true),
       ('BEER', 'Beer', 'ALCOHOL', 'Alcohol', '2026-01-01', '9999-12-31', true);

INSERT INTO dw.dim_campaign (campaign_code, campaign_type, is_campaign)
VALUES ('DEMO_WEEKLY', 'Weekly promotion', true);

INSERT INTO dw.dim_weather
    (weather_key, observation_ts, station_code, air_temp_c, precipitation_mm, is_rainy)
SELECT to_char(d.full_date, 'YYYYMMDD')::bigint * 100 + h.hour,
       d.full_date + h.hour * INTERVAL '1 hour', 'DEMO',
       18, CASE WHEN h.hour = 14 THEN 1.5 ELSE 0 END, h.hour = 14
FROM dw.dim_date d CROSS JOIN (VALUES (10), (14)) AS h(hour);

-- Eight receipts, each with two lines. Receipt C shares an hour with B.
-- Includes campaign discounts, an employee discount without a campaign,
-- repeated pseudonymous customers, and both historical product versions.
WITH receipts(receipt_id, sale_ts, customer_hash) AS (
    VALUES ('DEMO-A', TIMESTAMP '2026-06-21 10:15', 'demo-customer-1'),
           ('DEMO-B', TIMESTAMP '2026-06-21 14:15', NULL),
           ('DEMO-C', TIMESTAMP '2026-06-21 14:30', 'demo-customer-2'),
           ('DEMO-D', TIMESTAMP '2026-06-22 10:15', 'demo-customer-1'),
           ('DEMO-E', TIMESTAMP '2026-06-22 14:15', NULL),
           ('DEMO-F', TIMESTAMP '2026-06-23 10:15', 'demo-customer-2'),
           ('DEMO-G', TIMESTAMP '2026-06-24 10:15', 'demo-customer-1'),
           ('DEMO-H', TIMESTAMP '2026-06-24 14:15', NULL)
), lines(receipt_id, line_no, product_code, sales_amount, discount_amount, campaign_code, discount_type_key) AS (
    VALUES ('DEMO-A', 1, 'MILK', 2.40, 0.00, 'NONE', 0),
           ('DEMO-A', 2, 'BREAD', 3.00, 0.00, 'NONE', 0),
           ('DEMO-B', 1, 'BEER', 4.00, 1.00, 'DEMO_WEEKLY', 1),
           ('DEMO-B', 2, 'BREAD', 3.00, 0.00, 'NONE', 0),
           ('DEMO-C', 1, 'MILK', 2.40, 0.00, 'NONE', 0),
           ('DEMO-C', 2, 'BREAD', 2.70, 0.30, 'NONE', 8),
           ('DEMO-D', 1, 'BEER', 4.00, 1.00, 'DEMO_WEEKLY', 1),
           ('DEMO-D', 2, 'MILK', 2.40, 0.00, 'NONE', 0),
           ('DEMO-E', 1, 'BEER', 5.00, 0.00, 'NONE', 0),
           ('DEMO-E', 2, 'BREAD', 3.00, 0.00, 'NONE', 0),
           ('DEMO-F', 1, 'MILK', 2.40, 0.00, 'NONE', 0),
           ('DEMO-F', 2, 'BREAD', 3.00, 0.00, 'NONE', 0),
           ('DEMO-G', 1, 'BEER', 4.00, 1.00, 'DEMO_WEEKLY', 1),
           ('DEMO-G', 2, 'BREAD', 3.00, 0.00, 'NONE', 0),
           ('DEMO-H', 1, 'BEER', 5.00, 0.00, 'NONE', 0),
           ('DEMO-H', 2, 'MILK', 2.40, 0.00, 'NONE', 0)
)
INSERT INTO dw.fact_sales
    (date_key, weather_key, store_key, product_key, campaign_key, discount_type_key,
     receipt_id, till_no, sale_ts, sale_hour, customer_hash, has_loyalty_card,
     quantity, sales_amount, regular_price, discount_amount, src_file_name, src_line_id)
SELECT to_char(r.sale_ts, 'YYYYMMDD')::int,
       to_char(r.sale_ts, 'YYYYMMDDHH24')::bigint,
       st.store_key, p.product_key, c.campaign_key, l.discount_type_key,
       r.receipt_id, 1, r.sale_ts, extract(hour FROM r.sale_ts)::int,
       r.customer_hash, r.customer_hash IS NOT NULL,
       1, l.sales_amount, l.sales_amount + l.discount_amount, l.discount_amount,
       'synthetic_demo', row_number() OVER (ORDER BY r.receipt_id, l.line_no)
FROM receipts r
JOIN lines l ON l.receipt_id = r.receipt_id
JOIN dw.dim_product p ON p.product_code = l.product_code
    AND r.sale_ts::date BETWEEN p.valid_from AND p.valid_to
JOIN dw.dim_campaign c ON c.campaign_code = l.campaign_code
JOIN dw.dim_store st ON st.store_id = 1;

INSERT INTO dw.fact_payment
    (date_key, store_key, payment_type_key, receipt_id, payment_line_no, payment_ts, amount)
SELECT date_key, store_key, 2, receipt_id, 1, min(sale_ts), sum(sales_amount)
FROM dw.fact_sales
GROUP BY date_key, store_key, receipt_id;

COMMIT;
