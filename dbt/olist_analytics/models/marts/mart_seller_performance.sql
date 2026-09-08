with items as (
    select * from {{ ref('fct_order_items') }}
),

order_context as (
    select order_id, customer_id, avg_review_score
    from {{ ref('fct_orders') }}
),

seller as (
    select * from {{ ref('dim_sellers') }}
)

select
    s.seller_id,
    s.seller_city,
    s.seller_state,
    count(distinct i.order_id)                          as orders,
    count(*)                                            as items_sold,
    count(distinct oc.customer_id)                      as unique_customers,
    round(sum(i.price), 2)                              as product_revenue,
    round(sum(i.freight_value), 2)                      as freight_revenue,
    round(sum(i.line_total), 2)                         as gross_revenue,
    round(sum(i.price) / nullif(count(distinct i.order_id), 0), 2)
                                                        as avg_revenue_per_order,
    round(100.0 * count(*) filter (where i.is_late_delivery)
          / nullif(count(*) filter (where i.is_delivered), 0), 2)
                                                        as late_delivery_pct,
    round(avg(oc.avg_review_score), 2)                  as avg_review_score,
    round(avg(i.delivery_days), 2)                      as avg_delivery_days,
    min(i.purchase_date)                                as first_sale_date,
    max(i.purchase_date)                                as last_sale_date
from items i
join order_context oc on oc.order_id = i.order_id
join seller s on s.seller_id = i.seller_id
group by s.seller_id, s.seller_city, s.seller_state