# Data Assessment Findings — Olist E-Commerce Analytics

**Project:** Brazilian E-Commerce Business Intelligence Solution
**Client:** Brazilian e-commerce marketplace (Olist data)
**Prepared by:** Asaad Areeb — Data & BI Consultant
**Assessment date:** 1 September 2026 — **FINAL (assessment closed, build verified)**
**Source period:** 4 September 2016 – 17 October 2018 (order purchase timestamps)
**Environment:** PostgreSQL `olist_analytics` (raw → staging → intermediate → marts, built with dbt 1.12.3)
**Status:** **COMPLETE.** RAW layer certified; dbt warehouse built (24 models); 70 automated tests executed — 68 PASS, 2 WARN, 0 ERROR, with both warn counts matching their pre-registered baselines exactly; all post-build reconciliations closed. **Warehouse certified for Power BI consumption of the `marts` schema.**

---

## 1. Scope and Method

48 SQL checks were executed across the engagement: 41 in the initial raw-layer assessment (duplicate-key checks 7, NULL checks 5, foreign-key/orphan checks 7, value-validity checks 6, status/date-logic checks 8, financial reconciliation 2, customer-behavior pre-analysis 3, geolocation pre-analysis 3), 4 follow-up verification queries, and 3 post-build reconciliation queries. These were complemented by a 24-model dbt build and 70 automated data tests, whose two warn-level outcomes were pre-registered from the raw assessment **before** the build ran. Every figure in this document is actual output from the database or dbt.

**Severity scale:** High (blocks transformation) · Medium (real defect, handled by documented rule, monitored) · Low (tiny volume or cosmetic, documented) · Info (context or business insight).

## 2. Row Count Verification

### Raw layer

| Table | Rows | Verification |
|---|---|---|
| raw.orders | 99,441 | Confirmed — status counts sum exactly; `fct_orders` built 1:1 |
| raw.customers | 99,441 | Confirmed — `dim_customers` built 1:1 |
| raw.order_reviews | 99,224 | Confirmed — derived from per-order distribution; dedup arithmetic closes (§9) |
| raw.order_items | 112,650 | Confirmed — `fct_order_items` built 112,650 (zero orphan items) |
| raw.products | 32,951 | Confirmed — `dim_products` built 1:1 |
| raw.sellers | 3,095 | Confirmed — `dim_sellers` built 1:1 |
| raw.order_payments | 103,886 | Indirect — all payment quality tests passed; direct count not re-run (optional query in §7.2) |
| raw.geolocation | 1,000,163 | Indirect — `int_geolocation_by_zip` unique-by-zip test passed |
| raw.category_translation | 71 | Indirect — unique-name test passed (+2 manual rows added in staging) |

### Marts layer (dbt build, 1 September 2026)

| Model | Rows | Verified against |
|---|---|---|
| marts.dim_date | 1,096 | Calendar 2016–2018: 366 + 365 + 365 days — exact |
| marts.dim_customers | 99,441 | raw customers, 1:1 |
| marts.dim_products | 32,951 | raw products, 1:1 |
| marts.dim_sellers | 3,095 | raw sellers, 1:1 |
| marts.fct_orders | 99,441 | raw orders, 1:1 |
| marts.fct_order_items | 112,650 | raw order items, 1:1 |
| marts.fct_reviews | 98,410 | 99,224 − 814 removed duplicate rows |
| marts.mart_customer_metrics | 96,096 | unique customers — matches assessment figure exactly |
| marts.mart_seller_performance | 3,095 | all sellers active (consistent with zero orphan items) |
| marts.mart_sales | 1,283 | month × category grain |
| marts.mart_delivery_performance | 565 | month × state grain |

## 3. Executive Summary

The dataset is in **good condition**, and the full pipeline from raw CSVs to a certified star schema is now built and verified. Referential integrity was complete at source (zero orphans across all seven relationship checks), every primary key was unique except `review_id`, and no key column was NULL anywhere. The four genuine issue areas were all handled by documented rules and **verified in the built warehouse**:

1. **Review duplication** — 789 duplicated `review_id` values (99,224 rows). Deduplicated in staging: 814 duplicate rows removed, `marts.fct_reviews` = 98,410 rows.
2. **Product master-data gaps** — 610 products (1.85%) with no category and no photo count, 2 missing weights, 4 zero weights, 2 untranslated categories. Handled by the `'uncategorized'` bucket (confirmed at just **1.32% of product revenue**), the `has_weight_data` flag, and two explicit translation mappings.
3. **Financial reconciliation gap** — 1,075 orders mismatched at the R$0.01 threshold, but the material gap on delivered orders with items is **246 orders / R$3,224.33 = 0.024% of total product revenue** (11.67% of the affected orders' own value). Revenue KPIs come from order items; the gap stays auditable in `payment_item_gap`; the warn-level test returned exactly 246.
4. **Geolocation structure** — 1M+ rows over ~19k zips, 31 bad coordinates, 278 customers (0.28%) without coordinates, 7 state conflicts. Collapsed per zip in intermediate; customer state authoritative; report maps at state level.

**Headline warehouse figures (for the client memo):** product revenue **R$13,591,643.70** (excludes freight, which is reported separately) — identical at order grain and item grain; 99,441 orders; 96,096 unique customers of whom 2,997 (3.12%) are repeat buyers; 3,095 sellers; 112,650 items sold; 98,410 unique reviews.

### Quality scorecard (final)

| Dimension | Result | Verdict |
|---|---|---|
| Primary-key uniqueness | 6 of 7 tables clean at source; reviews deduplicated in staging | Pass — verified in build |
| Referential integrity | 0 orphans in all 7 checks | Pass |
| Key completeness (NULLs) | 0 missing keys in every table | Pass |
| Value validity | Prices/freight/scores fully valid; 9 structural zero-value payment rows | Pass |
| Payment coverage | 99,440 of 99,441 orders have payment rows | Pass |
| Date logic | 39 anomalous rows across 4 checks, all retained and documented | Pass with documented handling |
| Master data | 610 uncategorized products = 1.32% of revenue; 2 categories translated manually | Pass with fallback rules |
| Financial reconciliation | 246 delivered orders, R$3,224.33 = 0.024% of product revenue | Documented and verified — immaterial |
| Review coverage | 98,673 of 99,441 orders reviewed (99.23%) | Pass |
| Geolocation coverage | 278 of 99,441 customers (0.28%) lack coordinates | Pass — report maps at state level |
| Build verification | 24/24 models; 68 PASS + 2 WARN (246, 8) + 0 ERROR on 70 tests; revenue identical across grains | **Certified** |

## 4. Findings Register

All dispositions below were implemented in the 1 September 2026 dbt build and, where a number was pre-registered, verified against it.

| # | Area | Finding (actual result) | Severity | Disposition (status) |
|---|---|---|---|---|
| 1 | Key uniqueness | `orders`, `customers`, `order_items`, `order_payments`, `products`, `sellers` — 0 duplicates | Pass | None needed |
| 2 | Key uniqueness | 789 `review_id` values duplicated (99,224 rows) | Medium | Dedup in `stg_order_reviews` — **verified: 814 rows removed, `fct_reviews` = 98,410** |
| 3 | Reviews | 543 orders with 2 reviews, 4 orders with 3 | Low | Score averaged at order grain in `int_order_reviews_agg` — implemented |
| 4 | Referential integrity | 0 orphans in all 7 checks | Pass | Inner joins safe; `fct_reviews` LEFT join kept as defensive design |
| 5 | Product master data | 610 products (1.85%) missing category (and photo count) | Medium | `'uncategorized'` bucket in `dim_products` — **verified: 1.32% of product revenue** |
| 6 | Product master data | 2 missing weights + 4 zero/negative weights; 610 missing photos (same population as #5) | Low | `has_weight_data` flag; photos unused in dashboards |
| 7 | Translation coverage | `pc_gamer` (3 products), `portateis_cozinha_e_preparadores_de_alimentos` (10) missing from file | Low | Explicit mappings added in `stg_category_translation` — applied |
| 8 | Order completeness | 775 orders (0.78%) with no items: 603 unavailable, 164 canceled, 5 created, 2 invoiced, 1 shipped | Medium | Kept with `has_items = FALSE`, item revenue 0; AOV definition documented (§6.4) |
| 9 | Financial reconciliation | 1,075 orders (1.08%) mismatch at R$0.01; material gap = 246 delivered orders / R$3,224.33 | Medium | Revenue from items; `payment_item_gap` column; warn test — **verified at exactly 246**; gap = 0.024% of product revenue |
| 10 | Payment validity | 9 rows with `payment_value` ≤ 0 (structural split rows) | Info | Retained; only `SUM(payment_value)` used |
| 11 | Delivery dates | 8 delivered orders missing delivery date | Low | Retained; metrics NULL for them — **verified: warn test returns exactly 8** |
| 12 | Delivery dates | 2 delivered orders missing carrier date | Low | `days_to_ship` NULL for those |
| 13 | Date logic | 23 orders delivered before carrier pickup | Low | Retained as recorded; documented anomaly |
| 14 | Status logic | 6 canceled orders that were delivered | Low | `order_status` authoritative |
| 15 | Status mix | delivered 96,478 (97.02%); canceled 625 (0.63%); unavailable 609 (0.61%); in-flight 1,729 (1.74%) | Info | Status flags in `fct_orders` |
| 16 | Date range | 2016-09-04 → 2018-10-17 | Info | `dim_date` covers 2016-01-01 → 2018-12-31 (1,096 days verified) |
| 17 | Geolocation grain | Up to 1,146 rows per zip prefix | Medium | Collapsed per zip in `int_geolocation_by_zip` — implemented, unique test passes |
| 18 | Geolocation quality | 31 bad coordinates; 157 unmatched zips (278 customers, 0.28%); 7 state conflicts | Low | Bad coords filtered; customer state authoritative; state-level maps unaffected |
| 19 | Customer identity | 99,441 order identities → 96,096 persons; 2,997 repeat (3.12%) | Info | Person-grain analysis — **verified: `mart_customer_metrics` = 96,096** |
| 20 | Review coverage | 98,673 orders (99.23%) reviewed | Info | Satisfaction analysis representative |
| 21 | Payment coverage | 1 order of 99,441 with no payment row | Low | LEFT JOIN leaves payment columns NULL; payment-mix KPIs cover 99,440 orders |

## 5. Finding Details and Dispositions

### 5.1 Review duplication (Findings 2–3) — implemented and verified

99,224 source rows carried 789 duplicated `review_id` values; `stg_order_reviews` keeps one row per id (most recent wins), removing 814 rows and leaving **98,410 unique reviews** — the small excess of removed rows over duplicated ids (814 vs 789) confirms roughly 25 ids appeared three times. The 547 multi-review orders are collapsed to one row per order with the mean score in `int_order_reviews_agg`, so `fct_orders` joins safely at order grain. The `unique` tests on `review_id` (staging and marts) passed on the built models.

### 5.2 Product master data (Findings 5–7) — implemented and quantified

The 610 products with no category also lack photo counts — one incomplete-master-data population. They are mapped to `'uncategorized'`, which post-build measurement confirms contributes only **1.32% of product revenue**, so the bucket is visible but immaterial in category visuals. Six products fail the weight rule and are excluded from any weight-based analysis via `has_weight_data`. The two untranslated categories were given explicit English names (`pc_gamer`, `portable_kitchen_food_preparers`), so no category renders as a Portuguese fallback string.

### 5.3 Financial reconciliation (Findings 8–9, 21) — closed as immaterial

At the strict R\$0.01 threshold, payments and items disagree for 1,075 orders — but 775 of those have no items at all (their full payment value inflated the raw R\$165,861.17 figure). The material population is **246 delivered orders with items, gaps above R\$1.00, totaling R\$3,224.33** — an average gap of about R\$13 per affected order, equal to 11.67% of those orders' own value but only **0.024% of total product revenue (R\$13,591,643.70)**. Design in force: product revenue and freight KPIs from order items; payment behavior from payments; both stored on `fct_orders` with `payment_item_gap` keeping the difference auditable. The warn-level test reproduced the 246 baseline exactly on first run.

### 5.4 Delivery timestamp anomalies (Findings 11–14) — retained and documented

39 rows in total: 8 delivered without a delivery date, 2 without a carrier date, 23 delivered before carrier pickup, 6 canceled-but-delivered. All retained as received; `order_status` is authoritative; date differences return NULL when a timestamp is missing. The 8 missing delivery dates are enforced as a warn-level baseline (verified: exactly 8).

### 5.5 Geolocation (Findings 17–18) — implemented

`int_geolocation_by_zip` collapses the point cloud to one row per zip prefix (mean coordinates, modal city/state) — its unique-by-zip test passes. 31 out-of-bounds coordinates were filtered in staging. 278 customers (0.28%) have no coordinates; the delivered report maps at state level, so nothing in the dashboard set is affected.

### 5.6 Customer identity and repeat behavior (Finding 19) — verified

99,441 order-level identities collapse to 96,096 real customers (built exactly in `mart_customer_metrics`), of whom 2,997 (3.12%) placed more than one order. This one-time-buyer profile is the dataset's most important commercial insight and drives the acquisition-vs-repeat framing of the customer dashboard.

## 6. Downstream Adjustments (all applied 1 September 2026)

1. **Payments reconciliation test set to warn severity** with pre-registered baseline 246 — applied; first run returned exactly 246.
2. **Two missing category translations added** in `stg_category_translation` — applied.
3. **Delivered-dates test set to warn severity** with baseline 8 (finding #11) — applied; first run returned exactly 8.
4. **dbt 1.12 modernization** — all generic tests nested under `arguments:`, `tests:` renamed to `data_tests:`, three dim→fact `relationships` tests reversed to the correct fact→dim direction, and the `dbt_utils` grain test replaced with a zero-dependency singular test (`assert_mart_sales_grain_is_unique`, passing). Final parse is clean: zero deprecation warnings, zero unused configuration paths.
5. **KPI definitions in force:** Revenue = sum of item `price` (freight separate; combined only in gross revenue). Late delivery = delivered date strictly after estimated date, delivered orders only. Repeat customer = more than one order per `customer_unique_id`. AOV exists in two variants (all orders; orders with items) — difference immaterial at 0.78%. 2016 opening weeks are thin; trend visuals use full calendar months; no rows deleted.

## 7. Open Items — all closed

**7.1 — CLOSED.** Product NULLs confirmed 610 / 2 / 610; photos unused in dashboards.
**7.2 — CLOSED.** Six of nine raw tables confirmed by direct build counts (§2); order_payments, geolocation, and category_translation verified indirectly (all their quality tests pass). For the record only, the optional count query:

```sql
SELECT 'order_payments' AS table_name, COUNT(*) FROM raw.order_payments
UNION ALL SELECT 'geolocation',          COUNT(*) FROM raw.geolocation
UNION ALL SELECT 'category_translation', COUNT(*) FROM raw.category_translation;
```

**7.3 — CLOSED.** Payment coverage 99,440 of 99,441 (1 order without payments; payment columns NULL for it).
**7.4 — CLOSED.** 278 customers (0.28%) lack coordinates; state-level maps unaffected.
**7.5 — CLOSED. Post-build records (all filled):**

| Metric | Value |
|---|---|
| Delivered orders with item-value gaps > R$1.00 | **246 orders / R$3,224.33** |
| dbt warn count — `assert_payments_reconcile_to_items` | **246 — verified, exact match to baseline** |
| dbt warn count — `assert_delivered_orders_have_delivery_dates` | **8 — verified, exact match to finding #11** |
| `marts.fct_reviews` after dedup | **98,410 rows (814 duplicates removed)** |
| Revenue share of `'uncategorized'` category | **1.32% of product revenue** |
| Gap as % of affected orders' own value | **11.67%** |
| Gap as % of total product revenue | **0.024%** |

## 8. Build Verification Record (dbt, 1 September 2026)

- **Environment:** dbt 1.12.3 / dbt-postgres 1.11.0 / Python 3.13 / PostgreSQL `olist_analytics`, target `dev`, 4 threads.
- **Parse:** 24 models, 70 data tests, 9 sources — clean, zero deprecation warnings, zero unused configuration paths.
- **`dbt run`:** Completed successfully — 11 tables + 13 views in 9.49s. Row counts in §2, all matching their independent derivations.
- **`dbt test`:** PASS=68 WARN=2 ERROR=0 in 4.41s. The two warnings are the pre-registered baselines: payments reconciliation (246) and delivered-dates (8). Both matching on first run is the proof that the transformation layer reproduces the certified raw data with no logic drift.
- **Cross-grain revenue check:** order grain R$13,591,643.70 = item grain R$13,591,643.70 — identical to the cent.
- **Affected-order analysis:** 246 delivered orders with gaps, combined value ≈ R$27,620, average gap ≈ R$13 per order.
- **Certified headline figures:** product revenue R$13,591,643.70; 99,441 orders; 112,650 items; 96,096 customers (3.12% repeat); 3,095 sellers; 98,410 unique reviews; 1,283 month×category rows; 565 month×state rows.

## 9. Internal Consistency Cross-Checks

Every derivation below closes exactly:

- Status counts sum to 99,441, matching customers 1:1.
- Canceled orders reconcile: 625 = 619 without delivery date + 6 delivered.
- Review rows derive exactly: 98,126×1 + 543×2 + 4×3 = 99,224.
- Delivery-date arithmetic closes: 99,441 − 2,965 = 96,476 = (96,478 − 8) + 6.
- Customer identity reconciles: 99,441 − 96,096 = 3,345 excess orders explained by 2,997 repeat buyers.
- Item-less orders reconcile: 603 + 164 + 5 + 2 + 1 = 775, 99% in unavailable/canceled statuses.
- Reconciliation decomposes cleanly: 1,075 − 775 item-less ≈ 300 with items, of which 246 delivered >R$1.00 (R$3,224.33); residual ≈54 non-delivered or sub-R$1.
- Geolocation impact scales consistently: 157 zips → 278 customers (≈1.8 per zip), 0.28% of the base.
- Payment coverage closes: 99,441 − 1 = 99,440.
- **Revenue reconciles across grains: R$13,591,643.70 at order grain = R$13,591,643.70 at item grain.**
- **Review dedup closes: 99,224 − 814 = 98,410; 814 removed rows over 789 duplicated ids implies most appeared twice and ~25 appeared three times.**
- **Both warn counts equal their pre-registered baselines (246, 8).**
- **`mart_customer_metrics` = 96,096 = the assessment's unique-customer count.**

## 10. Sign-Off

The raw layer was a faithful, complete representation of the client's nine files; every defect carried a documented, auditable disposition; the dbt build implemented all of them; and the built warehouse reproduced every pre-registered number exactly. The `marts` schema is certified as the single source of truth for business intelligence. **Cleared to proceed to Power BI (connect to `marts` only).**

| Role | Name | Date |
|---|---|---|
| Prepared by | Asaad Areeb, Data & BI Consultant | 2026-09-01 |
| Follow-up verification (7.1, 7.3, 7.4 + baseline) | Closed | 2026-09-01 |
| dbt build + 70 tests (24 models; 68 PASS / 2 WARN / 0 ERROR) | Verified against pre-registered baselines | 2026-09-01 |
| Post-build reconciliations (revenue, uncategorized, gap %) | Closed — all figures recorded in §7.5 and §8 | 2026-09-01 |
| **Final certification — warehouse cleared for BI consumption** | **Complete** | **2026-09-01** |
