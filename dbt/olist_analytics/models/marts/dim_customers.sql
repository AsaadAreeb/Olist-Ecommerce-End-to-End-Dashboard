with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_activity as (
    select
        c.customer_id,
        min(o.purchased_at)          as first_order_at,
        count(o.order_id)             as order_count
    from customers c
    left join orders o on o.customer_id = c.customer_id
    group by c.customer_id
)

select
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    g.latitude                          as customer_latitude,
    g.longitude                         as customer_longitude,
    ca.first_order_at::date             as first_order_date,
    ca.order_count                      as order_count,
    (ca.order_count > 1)                as is_repeat_buyer
from customers c
left join {{ ref('int_geolocation_by_zip') }} g
       on g.zip_code_prefix = c.customer_zip_code_prefix
left join customer_activity ca
       on ca.customer_id = c.customer_id