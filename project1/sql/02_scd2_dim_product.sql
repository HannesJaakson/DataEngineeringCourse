-- SCD Type 2 load for dw.dim_product (run once per daily batch, :load_date = file date)
-- Source: latest name/segment per product seen in that day's POS lines.

WITH src AS (
    SELECT DISTINCT ON (product_code)
           product_code, sku_id, product_name, segment_code, segment_name
    FROM staging.stg_pos_sales_line
    WHERE sale_ts::date = :'load_date'
    ORDER BY product_code, sale_ts DESC
),
changed AS (                       -- current version differs from source
    SELECT d.product_key
    FROM dw.dim_product d
    JOIN src s USING (product_code)
    WHERE d.is_current
      AND (d.product_name, d.segment_code) IS DISTINCT FROM (s.product_name, s.segment_code)
)
-- 1) close the old version
UPDATE dw.dim_product d
SET valid_to = :'load_date'::date - 1,
    is_current = FALSE
FROM changed c
WHERE d.product_key = c.product_key;

-- 2) insert new products and new versions of changed products
INSERT INTO dw.dim_product (product_code, sku_id, product_name, segment_code, segment_name, valid_from)
SELECT s.product_code, s.sku_id, s.product_name, s.segment_code, s.segment_name, :'load_date'::date
FROM (
    SELECT DISTINCT ON (product_code)
           product_code, sku_id, product_name, segment_code, segment_name
    FROM staging.stg_pos_sales_line
    WHERE sale_ts::date = :'load_date'
    ORDER BY product_code, sale_ts DESC
) s
LEFT JOIN dw.dim_product d
       ON d.product_code = s.product_code AND d.is_current
WHERE d.product_key IS NULL;

-- Fact lookup: the version valid at sale time
-- JOIN dw.dim_product p
--   ON p.product_code = stg.product_code
--  AND stg.sale_ts::date BETWEEN p.valid_from AND p.valid_to
