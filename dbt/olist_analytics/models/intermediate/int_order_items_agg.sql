with items as (
    select * from {{ ref('stg_order_items') }}
)

select
    order_id,
    count(*)                                   as item_count,        -- one row = one unit
    count(distinct product_id)                 as product_count,
    count(distinct seller_id)                 as seller_count,
    sum(price)                                 as product_revenue,
    sum(freight_value)                         as freight_revenue,
    sum(price + freight_value)                as order_value_from_items
from items
group by order_id