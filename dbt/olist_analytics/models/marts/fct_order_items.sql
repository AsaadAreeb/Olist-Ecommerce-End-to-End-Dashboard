with items as (
    select * from {{ ref('stg_order_items') }}
),

order_context as (
    select
        order_id,
        customer_state,
        order_status,
        purchased_at,
        purchase_date,
        purchase_month_start,
        is_delivered,
        is_cancelled,
        is_late_delivery,
        delivery_days
    from {{ ref('fct_orders') }}
),

products as (select * from {{ ref('dim_products') }}),
sellers  as (select * from {{ ref('dim_sellers') }})

select
    i.order_id,
    i.order_item_id,
    i.order_id || '-' || i.order_item_id        as order_item_key,
    i.product_id,
    i.seller_id,
    i.price,
    i.freight_value,
    i.line_total,
    i.shipping_limit_at,

    p.product_category_english,
    p.product_category_name,
    s.seller_city,
    s.seller_state,

    oc.customer_state,
    oc.order_status,
    oc.purchased_at,
    oc.purchase_date,
    oc.purchase_month_start,
    oc.is_delivered,
    oc.is_cancelled,
    oc.is_late_delivery,
    oc.delivery_days
from items i
join order_context oc on oc.order_id = i.order_id
left join products p  on p.product_id = i.product_id
left join sellers s   on s.seller_id  = i.seller_id