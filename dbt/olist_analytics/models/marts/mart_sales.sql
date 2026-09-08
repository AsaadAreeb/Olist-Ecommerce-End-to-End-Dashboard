with items as (
    select * from {{ ref('fct_order_items') }}
)

select
    items.purchase_month_start                       as month_start,
    items.product_category_english                   as product_category,
    count(distinct items.order_id)                   as orders,
    count(*)                                         as items_sold,
    round(sum(items.price), 2)                       as product_revenue,
    round(sum(items.freight_value), 2)               as freight_revenue,
    round(sum(items.line_total), 2)                  as gross_revenue,
    count(distinct items.seller_id)                  as active_sellers,
    round(avg(items.price), 2)                       as avg_item_price,
    round(100.0 * sum(items.freight_value) / nullif(sum(items.line_total), 0), 2)
                                                    as freight_share_pct
from items
group by items.purchase_month_start, items.product_category_english