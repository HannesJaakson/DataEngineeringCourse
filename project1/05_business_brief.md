# 1. Business Brief

**Objective:** Design a data warehouse combining one grocery store's sales, local weather and public holidays to support stock planning and promotion decisions.

**Stakeholders:** The store manager, category managers and marketing team.

## Key metrics (KPIs)

- **Total sales (EUR):** Sum of sales amounts after discounts, including VAT.
- **Receipt count:** Number of distinct receipts.
- **Average basket value (EUR):** Total sales divided by receipt count.

## Business questions

1. What are the daily total sales, receipt count and average basket value?
2. Which product segments generate the most sales?
3. What share of sales comes from campaign products, and how much discount is given on campaign and non-campaign sales?
4. How do average daily sales differ between public holidays, days before holidays and other days?
5. How do average hourly sales differ between rainy and dry hours with recorded sales?

The analysis covers the loaded period for one store. Weather and holiday comparisons describe patterns; they do not establish what caused sales to change.

Bonus questions (no sql queries for these yet):
 1. How does average basket value differ between purchases with and without a loyalty card?
 2. How does the share of alcohol sales differ between weekdays and weekends?