CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS intermediate;
CREATE SCHEMA IF NOT EXISTS marts;

COMMENT ON SCHEMA raw IS 'Client CSVs loaded as received - no business logic';
COMMENT ON SCHEMA staging IS 'dbt: standardized, renamed, typed 1:1 source views';
COMMENT ON SCHEMA intermediate IS 'dbt: business logic and pre-join aggregation';
COMMENT ON SCHEMA marts IS 'dbt: client-facing star schema consumed by Power BI';

CREATE TABLE raw.customers (
    customer_id            TEXT NOT NULL,
    customer_unique_id     TEXT,
    customer_zip_code_prefix INTEGER,
    customer_city          TEXT,
    customer_state         TEXT
);

CREATE TABLE raw.geolocation (
    geolocation_zip_code_prefix INTEGER,
    geolocation_lat        DOUBLE PRECISION,
    geolocation_lng        DOUBLE PRECISION,
    geolocation_city       TEXT,
    geolocation_state      TEXT
);

CREATE TABLE raw.order_items (
    order_id               TEXT,
    order_item_id          INTEGER,
    product_id             TEXT,
    seller_id              TEXT,
    shipping_limit_date    TIMESTAMP,
    price                  NUMERIC(12,2),
    freight_value          NUMERIC(12,2)
);

CREATE TABLE raw.order_payments (
    order_id               TEXT,
    payment_sequential     INTEGER,
    payment_type           TEXT,
    payment_installments   INTEGER,
    payment_value          NUMERIC(12,2)
);

CREATE TABLE raw.order_reviews (
    review_id              TEXT,
    order_id               TEXT,
    review_score           INTEGER,
    review_comment_title   TEXT,
    review_comment_message TEXT,
    review_creation_date   TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

CREATE TABLE raw.orders (
    order_id                       TEXT,
    customer_id                    TEXT,
    order_status                   TEXT,
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE raw.products (
    product_id                 TEXT,
    product_category_name      TEXT,
    product_name_lenght        INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty         INTEGER,
    product_weight_g           INTEGER,
    product_length_cm          NUMERIC(10,2),
    product_height_cm          NUMERIC(10,2),
    product_width_cm           NUMERIC(10,2)
);

CREATE TABLE raw.sellers (
    seller_id               TEXT,
    seller_zip_code_prefix INTEGER,
    seller_city            TEXT,
    seller_state           TEXT
);

CREATE TABLE raw.category_translation (
    product_category_name         TEXT,
    product_category_name_english TEXT
);



SELECT 'orders'      AS table_name, COUNT(*) AS row_count FROM raw.orders
UNION ALL SELECT 'customers',          COUNT(*) FROM raw.customers
UNION ALL SELECT 'order_items',        COUNT(*) FROM raw.order_items
UNION ALL SELECT 'order_payments',     COUNT(*) FROM raw.order_payments
UNION ALL SELECT 'order_reviews',      COUNT(*) FROM raw.order_reviews
UNION ALL SELECT 'products',           COUNT(*) FROM raw.products
UNION ALL SELECT 'sellers',            COUNT(*) FROM raw.sellers
UNION ALL SELECT 'geolocation',        COUNT(*) FROM raw.geolocation
UNION ALL SELECT 'category_translation', COUNT(*) FROM raw.category_translation
ORDER BY row_count DESC;




-- Data quality assessment


--Primary key / duplicate checks
-- orders: order_id must be unique
SELECT order_id, COUNT(*) AS occurrences
FROM raw.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- customers: customer_id must be unique
SELECT customer_id, COUNT(*) AS occurrences
FROM raw.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- order_items: grain is (order_id, order_item_id)
SELECT order_id, order_item_id, COUNT(*) AS occurrences
FROM raw.order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- order_payments: grain is (order_id, payment_sequential)
SELECT order_id, payment_sequential, COUNT(*) AS occurrences
FROM raw.order_payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;

-- reviews: review_id is the natural key
SELECT review_id, COUNT(*) AS occurrences
FROM raw.order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

-- products: product_id must be unique
SELECT product_id, COUNT(*) AS occurrences
FROM raw.products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- sellers: seller_id must be unique
SELECT seller_id, COUNT(*) AS occurrences
FROM raw.sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- NULL checks on keys
-- orders: any order without a customer?
SELECT COUNT(*) AS orders_missing_customer
FROM raw.orders
WHERE customer_id IS NULL;

-- order_items: missing keys?
SELECT
    COUNT(*) FILTER (WHERE order_id   IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE seller_id  IS NULL) AS null_seller_id
FROM raw.order_items;

-- order_payments: missing keys or values?
SELECT
    COUNT(*) FILTER (WHERE order_id       IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE payment_type   IS NULL) AS null_payment_type,
    COUNT(*) FILTER (WHERE payment_value  IS NULL) AS null_payment_value
FROM raw.order_payments;

-- reviews: reviews with no order link
SELECT COUNT(*) AS reviews_missing_order_id
FROM raw.order_reviews
WHERE order_id IS NULL;

-- products: missing descriptive columns
SELECT
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS missing_category,
    COUNT(*) FILTER (WHERE product_weight_g        IS NULL) AS missing_weight,
    COUNT(*) FILTER (WHERE product_photos_qty      IS NULL) AS missing_photos_qty
FROM raw.products;

-- Foreign-key / orphan checks
-- orders pointing at a customer that doesn't exist
SELECT COUNT(*) AS orphaned_orders
FROM raw.orders o
LEFT JOIN raw.customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;

-- order_items pointing at a nonexistent order
SELECT COUNT(*) AS orphaned_items
FROM raw.order_items i
LEFT JOIN raw.orders o ON o.order_id = i.order_id
WHERE o.order_id IS NULL;

-- order_items pointing at a nonexistent product
SELECT COUNT(*) AS items_with_missing_product
FROM raw.order_items i
LEFT JOIN raw.products p ON p.product_id = i.product_id
WHERE p.product_id IS NULL;

-- order_items pointing at a nonexistent seller
SELECT COUNT(*) AS items_with_missing_seller
FROM raw.order_items i
LEFT JOIN raw.sellers s ON s.seller_id = i.seller_id
WHERE s.seller_id IS NULL;

-- payments pointing at a nonexistent order
SELECT COUNT(*) AS orphaned_payments
FROM raw.order_payments pay
LEFT JOIN raw.orders o ON o.order_id = pay.order_id
WHERE o.order_id IS NULL;

-- reviews pointing at a nonexistent order (expected: small number)
SELECT COUNT(*) AS orphaned_reviews
FROM raw.order_reviews r
LEFT JOIN raw.orders o ON o.order_id = r.order_id
WHERE o.order_id IS NULL;

-- product categories not covered by the translation file
SELECT p.product_category_name, COUNT(*) AS products
FROM raw.products p
LEFT JOIN raw.category_translation t
       ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
GROUP BY p.product_category_name;

-- Value validity checks
-- negative or zero prices / freight
SELECT
    COUNT(*) FILTER (WHERE price         <= 0) AS bad_price,
    COUNT(*) FILTER (WHERE freight_value <  0) AS bad_freight
FROM raw.order_items;

-- payment values
SELECT
    COUNT(*) FILTER (WHERE payment_value <= 0) AS zero_or_negative_payments,
    COUNT(*) FILTER (WHERE payment_installments < 0) AS negative_installments,
    COUNT(*) FILTER (WHERE payment_type NOT IN
        ('credit_card','boleto','voucher','debit_card','not_defined')) AS unexpected_payment_types
FROM raw.order_payments;

-- review scores outside 1-5
SELECT review_score, COUNT(*) AS reviews
FROM raw.order_reviews
WHERE review_score NOT BETWEEN 1 AND 5
GROUP BY review_score;

-- geolocation coordinates outside Brazil's bounding box
SELECT COUNT(*) AS bad_coordinates
FROM raw.geolocation
WHERE geolocation_lat NOT BETWEEN -34 AND 6
   OR geolocation_lng NOT BETWEEN -75 AND -30;

-- product dimensions that are physically impossible
SELECT COUNT(*) AS zero_weight_products
FROM raw.products
WHERE product_weight_g <= 0 OR product_weight_g IS NULL;

SELECT COUNT(*) AS zero_dimension_products
FROM raw.products
WHERE product_length_cm <= 0 OR product_height_cm <= 0 OR product_width_cm <= 0;

-- Status and date logic checks
-- what statuses exist and in what volume?
SELECT order_status, COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM raw.orders
GROUP BY order_status
ORDER BY orders DESC;

-- date range of the data
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp)  AS last_order
FROM raw.orders;

-- delivered orders missing a delivery date
SELECT COUNT(*) AS delivered_but_no_delivery_date
FROM raw.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- delivered orders where the recorded carrier date is missing
SELECT COUNT(*) AS delivered_but_no_carrier_date
FROM raw.orders
WHERE order_status = 'delivered'
  AND order_delivered_carrier_date IS NULL;

-- logical impossibilities: delivered before purchase / before carrier pickup
SELECT COUNT(*) AS delivered_before_purchase
FROM raw.orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp;

SELECT COUNT(*) AS delivered_before_pickup
FROM raw.orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date < order_delivered_carrier_date;

-- canceled orders that were still delivered (data anomaly)
SELECT COUNT(*) AS canceled_but_delivered
FROM raw.orders
WHERE order_status = 'canceled'
  AND order_delivered_customer_date IS NOT NULL;

-- how many orders have NO delivery date at all (pipeline statuses)
SELECT order_status, COUNT(*) AS orders
FROM raw.orders
WHERE order_delivered_customer_date IS NULL
GROUP BY order_status
ORDER BY orders DESC;

-- Cross-table reconciliation: payments vs order items
-- The two financial sources of truth per order must agree
WITH item_totals AS (
    SELECT order_id,
           SUM(price + freight_value) AS items_total
    FROM raw.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS payments_total
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS mismatched_orders,
    ROUND(SUM(ABS(pt.payments_total - COALESCE(it.items_total,0))), 2) AS total_absolute_gap
FROM payment_totals pt
LEFT JOIN item_totals it ON it.order_id = pt.order_id
WHERE ABS(pt.payments_total - COALESCE(it.items_total,0)) > 0.01;

-- how many orders exist in orders but have NO items at all?
SELECT COUNT(*) AS orders_without_items
FROM raw.orders o
LEFT JOIN (SELECT DISTINCT order_id FROM raw.order_items) i
       ON i.order_id = o.order_id
WHERE i.order_id IS NULL;

-- and their statuses (expected: mostly canceled/unavailable)
SELECT o.order_status, COUNT(*) AS orders
FROM raw.orders o
LEFT JOIN (SELECT DISTINCT order_id FROM raw.order_items) i
       ON i.order_id = o.order_id
WHERE i.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders DESC;

-- Customer behavior pre-analysis
-- customer_id is one per order; customer_unique_id identifies the real person
SELECT
    COUNT(*)                     AS customer_id_count,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM raw.customers;

-- repeat buyers at the person level
SELECT COUNT(*) AS repeat_unique_customers
FROM (
    SELECT customer_unique_id
    FROM raw.customers c
    JOIN raw.orders o ON o.customer_id = c.customer_id
    GROUP BY customer_unique_id
    HAVING COUNT(*) > 1
) t;

-- reviews per order (should be 1 almost always)
SELECT review_rows, COUNT(*) AS orders
FROM (
    SELECT order_id, COUNT(*) AS review_rows
    FROM raw.order_reviews
    GROUP BY order_id
) t
GROUP BY review_rows
ORDER BY review_rows;

-- Geolocation pre-analysis
-- geolocation is NOT one row per zip: check duplication
SELECT geolocation_zip_code_prefix, COUNT(*) AS rows_per_zip
FROM raw.geolocation
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(*) > 1
ORDER BY rows_per_zip DESC
LIMIT 10;

-- are all customer zips present in geolocation?
SELECT COUNT(*) AS customer_zips_missing_from_geolocation
FROM (SELECT DISTINCT customer_zip_code_prefix FROM raw.customers) cz
LEFT JOIN (SELECT DISTINCT geolocation_zip_code_prefix FROM raw.geolocation) gz
       ON gz.geolocation_zip_code_prefix = cz.customer_zip_code_prefix
WHERE gz.geolocation_zip_code_prefix IS NULL;

-- do customer states agree with geolocation states for the same zip?
SELECT COUNT(*) AS conflicting_states
FROM (SELECT DISTINCT customer_zip_code_prefix, customer_state FROM raw.customers) cz
JOIN (SELECT DISTINCT geolocation_zip_code_prefix, geolocation_state FROM raw.geolocation) gz
  ON gz.geolocation_zip_code_prefix = cz.customer_zip_code_prefix
WHERE gz.geolocation_state <> cz.customer_state;

-- Record the reconciliation baseline
SELECT COUNT(*)                                       AS delivered_orders_with_item_value_gaps,
       ROUND(SUM(ABS(pt.payments_total - it.items_total)), 2) AS gap_total
FROM (SELECT order_id, SUM(payment_value) AS payments_total
      FROM raw.order_payments GROUP BY order_id) pt
JOIN (SELECT order_id, SUM(price + freight_value) AS items_total
      FROM raw.order_items GROUP BY order_id) it
  ON it.order_id = pt.order_id
JOIN raw.orders o ON o.order_id = pt.order_id
WHERE o.order_status = 'delivered'
  AND ABS(pt.payments_total - it.items_total) > 1.00;

-- Confirm payment coverage of orders
SELECT COUNT(*) AS orders_without_payments
FROM raw.orders o
LEFT JOIN (SELECT DISTINCT order_id FROM raw.order_payments) p
       ON p.order_id = o.order_id
WHERE p.order_id IS NULL;

-- Quantify customers affected by missing geolocation
SELECT COUNT(*) AS customers_without_geo
FROM raw.customers c
LEFT JOIN (SELECT DISTINCT geolocation_zip_code_prefix FROM raw.geolocation) g
       ON g.geolocation_zip_code_prefix = c.customer_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;

-- The cross-grain revenue sanity check
SELECT
    (SELECT round(sum(product_revenue), 2) FROM marts.fct_orders)      AS order_grain_revenue,
    (SELECT round(sum(price), 2)         FROM marts.fct_order_items)  AS item_grain_revenue;

-- Revenue share of the 'uncategorized' bucket (expect small)
SELECT round(100.0 * sum(price)
        / (SELECT sum(price) FROM marts.fct_order_items), 2) AS uncategorized_revenue_pct
FROM marts.fct_order_items
WHERE product_category_english = 'uncategorized';

-- Reconciliation gap as % of the affected delivered orders' value
SELECT round(100.0 * sum(abs(payment_item_gap)) / sum(order_value), 4) AS gap_pct_of_order_value
FROM marts.fct_orders
WHERE order_status = 'delivered'
  AND has_items = true
  AND abs(coalesce(payment_item_gap, 0)) > 1.00;