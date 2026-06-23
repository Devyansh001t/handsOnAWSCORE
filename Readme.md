# Hands-on: AWS Core Services (S3, Glue, CloudWatch, Athena)
**ITCS 6190/8190 – Cloud Computing for Data Analysis, Summer 2026**

---

## Overview

This hands-on demonstrates a serverless data pipeline on AWS to ingest, catalog, and query an e-commerce sales CSV using S3, Glue, CloudWatch, and Athena.

**Dataset:** [Amazon Sales Report – Kaggle](https://www.kaggle.com/datasets/thedevastator/unlock-profits-with-e-commerce-sales-data)  
The dataset contains ~128,000 Amazon India orders with fields for Order ID, Date, Status, Fulfilment method, SKU, Category, Quantity, Amount, and shipping details.

---

## Workflow

### Step 1 – Configure Amazon S3 Buckets

Two S3 buckets were created:
- **`itcs6190-raw-data/`** – holds the uploaded raw CSV (`Amazon Sale Report.csv`)
- **`itcs6190-query-results/`** – used by Athena to store query output files

The raw CSV was uploaded directly via the S3 Console into the `raw/` prefix of the first bucket.

### Step 2 – Create an IAM Role

An IAM role named `GlueCrawlerRole` was created with the following managed policies attached:
- `AmazonS3FullAccess` – allows the crawler to read the raw S3 data
- `AWSGlueServiceRole` – grants Glue the permissions needed to run crawlers and write to the Data Catalog

The trust relationship was set to `glue.amazonaws.com` as the principal.

### Step 3 – Create a Glue Crawler

In AWS Glue Studio, a crawler named `amazon-sales-crawler` was configured:
- **Data source:** S3 path pointing to `s3://itcs6190-raw-data/raw/`
- **IAM role:** `GlueCrawlerRole`
- **Target database:** `ecommerce_db` (created in the Glue Data Catalog)
- **Schedule:** On-demand

The crawler auto-detects the CSV schema and creates a table named `amazon_sale_report` in the `ecommerce_db` database.

### Step 4 – Run the Crawler & Monitor with CloudWatch

The crawler was run manually. AWS Glue automatically publishes crawler metrics and logs to CloudWatch. Under **CloudWatch → Log Groups → `/aws-glue/crawlers`**, the log stream for `amazon-sales-crawler` shows the crawl start time, number of tables created/updated, and completion status.


### Step 5 – Query with Amazon Athena

In the Athena Query Editor, the workgroup was configured to output results to `s3://itcs6190-query-results/`. The database `ecommerce_db` was selected and the table `amazon_sale_report` was queried using the five SQL queries below.

---

## SQL Queries & Results

### Query 1 — Basic Table Exploration

**Goal:** Retrieve the first 10 records to verify the table was crawled correctly.

```sql
SELECT *
FROM amazon_sale_report
LIMIT 10;
```

**Approach:** A simple `SELECT *` with `LIMIT 10` is used to inspect raw data structure, confirm column names, and validate that Glue inferred types correctly (dates, numerics, strings).

**Result file:** `query1_basic_exploration.csv`

---

### Query 2 — Orders by Product Category

**Goal:** Count how many orders belong to each product category.

```sql
SELECT
    category,
    COUNT(*) AS total_orders
FROM amazon_sale_report
GROUP BY category
ORDER BY total_orders DESC
LIMIT 10;
```

**Approach:** Groups all rows by `category` and counts them. No status filter is applied since the question asks for all orders including cancelled ones, giving a complete picture of category demand. Results are sorted descending by order count.

**Key finding:** `Set` and `kurta` dominate with ~50K orders each, together accounting for roughly 78% of all orders.

**Result file:** `query2_orders_by_category.csv`

---

### Query 3 — Revenue and Quantity by Fulfilment Method

**Goal:** Compare Amazon vs. Merchant fulfilment on orders, units sold, and revenue — for completed orders only.

```sql
SELECT
    fulfilment,
    COUNT(*)                  AS total_orders,
    SUM(qty)                  AS total_units_sold,
    ROUND(SUM(amount), 2)     AS total_revenue
FROM amazon_sale_report
WHERE status NOT LIKE '%Cancelled%'
  AND status NOT LIKE '%Pending%'
GROUP BY fulfilment
ORDER BY total_revenue DESC
LIMIT 10;
```

**Approach:** `NOT LIKE '%Cancelled%'` and `NOT LIKE '%Pending%'` use wildcard matching to cover all status variants (e.g. `Pending - Waiting for Pick Up`). Revenue and quantity are aggregated per fulfilment method and sorted highest revenue first.

**Key finding:** Amazon Fulfilment generated ~₹50.3M vs. Merchant's ~₹20.7M — Amazon handles roughly 2.4× more revenue despite only 2.4× more orders, suggesting similar average order values.

**Result file:** `query3_revenue_by_fulfilment.csv`

---

### Query 4 — Monthly Sales Trend

**Goal:** Track orders and revenue month by month for completed orders.

```sql
SELECT
    DATE_FORMAT(DATE_PARSE(date, '%m-%d-%y'), '%Y-%m') AS month,
    COUNT(*)              AS total_orders,
    ROUND(SUM(amount), 2) AS total_revenue
FROM amazon_sale_report
WHERE status NOT LIKE '%Cancelled%'
  AND status NOT LIKE '%Pending%'
GROUP BY DATE_FORMAT(DATE_PARSE(date, '%m-%d-%y'), '%Y-%m')
ORDER BY month ASC
LIMIT 10;
```

**Approach:** Athena uses Presto SQL, so `DATE_PARSE` converts the raw string date (`MM-DD-YY` format) to a proper date, and `DATE_FORMAT` extracts the `YYYY-MM` month key for grouping. Sorted chronologically to reveal the sales trend over time.

**Key finding:** April 2022 had the highest volume (~42K orders, ₹26.2M). Sales gradually declined through May and June 2022, which may reflect end-of-season patterns or dataset truncation.

**Result file:** `query4_monthly_sales_trend.csv`

---

### Query 5 — Top 5 Best-Selling SKUs per Category

**Goal:** Identify the highest-revenue SKUs within each product category.

```sql
WITH ranked AS (
    SELECT
        category,
        sku,
        ROUND(SUM(amount), 2) AS total_revenue,
        SUM(qty)              AS total_units_sold,
        RANK() OVER (
            PARTITION BY category
            ORDER BY SUM(amount) DESC
        ) AS rnk
    FROM amazon_sale_report
    WHERE status NOT LIKE '%Cancelled%'
      AND status NOT LIKE '%Pending%'
      AND qty > 0
    GROUP BY category, sku
)
SELECT category, sku, total_revenue, total_units_sold, rnk
FROM ranked
WHERE rnk <= 5
ORDER BY category, rnk
LIMIT 10;
```

**Approach:** A CTE first aggregates revenue and units per `(category, sku)` pair, applying the three exclusion filters (cancelled, pending, zero-quantity). The `RANK()` window function then ranks SKUs within each category partition. The outer query filters to rank ≤ 5 and orders results by category and rank for readability.

**Key finding:** In the `Blouse` category, size variants of style `J0217` dominate the top 4 spots, suggesting strong brand/style concentration. The `Bottom` category's top SKUs are more varied across styles.

**Result file:** `query5_top5_skus_per_category.csv`

---

## Repository Structure

```
aws-core-services-handson/
├── athena_queries.sql              # All 5 Athena SQL queries
├── query1_basic_exploration.csv
├── query2_orders_by_category.csv
├── query3_revenue_by_fulfilment.csv
├── query4_monthly_sales_trend.csv
├── query5_top5_skus_per_category.csv
└── README.md                      
```

---

## Screenshots

> Add the following screenshots to this section before submitting:
> 1. **CloudWatch** – Log group `/aws-glue/crawlers`, showing the crawler run log with SUCCESS status
> 2. **IAM Role** – `GlueCrawlerRole` with attached policies (`AmazonS3FullAccess`, `AWSGlueServiceRole`)
> 3. **S3 Buckets** – Both buckets listed in the S3 console (`itcs6190-raw-data`, `itcs6190-query-results`)
