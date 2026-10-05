-- The five queries from 07_demo_queries.md. Run in project1_demo.

-- Query 1
SELECT d.full_date,
       ROUND(SUM(s.sales_amount), 2) AS total_sales_eur,
       COUNT(DISTINCT s.receipt_id) AS receipt_count,
       ROUND(SUM(s.sales_amount)
             / NULLIF(COUNT(DISTINCT s.receipt_id), 0), 2) AS avg_basket_value_eur
FROM dw.fact_sales s
JOIN dw.dim_date d ON d.date_key = s.date_key
GROUP BY d.full_date
ORDER BY d.full_date;

-- Query 2
SELECT p.segment_code,
       COALESCE(p.segment_name, 'Unknown') AS segment_name,
       ROUND(SUM(s.sales_amount), 2) AS total_sales_eur
FROM dw.fact_sales s
JOIN dw.dim_product p ON p.product_key = s.product_key
GROUP BY p.segment_code, p.segment_name
ORDER BY total_sales_eur DESC;

-- Query 3
SELECT c.is_campaign,
       ROUND(SUM(s.sales_amount), 2) AS total_sales_eur,
       ROUND(100.0 * SUM(s.sales_amount)
             / NULLIF(SUM(SUM(s.sales_amount)) OVER (), 0), 2) AS sales_share_pct,
       ROUND(SUM(s.discount_amount), 2) AS total_discount_eur
FROM dw.fact_sales s
JOIN dw.dim_campaign c ON c.campaign_key = s.campaign_key
GROUP BY c.is_campaign
ORDER BY c.is_campaign DESC;

-- Query 4
WITH daily_sales AS (
    SELECT d.full_date,
           CASE
               WHEN d.is_public_holiday THEN 'Public holiday'
               WHEN d.is_day_before_holiday THEN 'Day before holiday'
               ELSE 'Other day'
           END AS day_type,
           SUM(s.sales_amount) AS sales_eur
    FROM dw.fact_sales s
    JOIN dw.dim_date d ON d.date_key = s.date_key
    GROUP BY d.full_date, d.is_public_holiday, d.is_day_before_holiday
)
SELECT day_type,
       COUNT(*) AS days_with_sales,
       ROUND(AVG(sales_eur), 2) AS avg_daily_sales_eur
FROM daily_sales
GROUP BY day_type
ORDER BY day_type;

-- Query 5
WITH hourly_sales AS (
    SELECT w.observation_ts,
           CASE WHEN w.precipitation_mm > 0 THEN 'Rainy' ELSE 'Dry' END AS weather,
           SUM(s.sales_amount) AS sales_eur
    FROM dw.fact_sales s
    JOIN dw.dim_weather w ON w.weather_key = s.weather_key
    WHERE w.precipitation_mm IS NOT NULL
    GROUP BY w.observation_ts, w.precipitation_mm
)
SELECT weather,
       COUNT(*) AS hours_with_sales,
       ROUND(AVG(sales_eur), 2) AS avg_hourly_sales_eur
FROM hourly_sales
GROUP BY weather
ORDER BY weather;
