-- Replaces dbt_utils.unique_combination_of_columns with a zero-dependency
-- singular test. mart_sales grain: one row per month per category.

select
    month_start,
    product_category,
    count(*) as row_count
from {{ ref('mart_sales') }}
group by month_start, product_category
having count(*) > 1