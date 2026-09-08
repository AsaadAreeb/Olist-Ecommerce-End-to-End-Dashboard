with source as (
    select * from {{ source('olist_raw', 'order_items') }}
)

select
    cast(order_id as text)                       as order_id,
    cast(order_item_id as integer)              as order_item_id,
    cast(product_id as text)                     as product_id,
    cast(seller_id as text)                      as seller_id,
    cast(shipping_limit_date as timestamp)       as shipping_limit_at,
    cast(price as numeric(12,2))                 as price,
    cast(freight_value as numeric(12,2))         as freight_value,
    cast(price as numeric(12,2))
      + cast(freight_value as numeric(12,2))    as line_total
from source