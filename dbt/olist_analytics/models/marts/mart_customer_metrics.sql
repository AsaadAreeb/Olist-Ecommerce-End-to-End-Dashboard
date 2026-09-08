with orders as (
    select * from {{ ref('fct_orders') }}
)

select
    o.customer_unique_id,
    min(o.customer_state)                             as customer_state,
    count(*)                                           as order_count,
    round(sum(o.order_value), 2)                      as lifetime_revenue,
    min(o.purchase_date)                               as first_order_date,
    max(o.purchase_date)                               as last_order_date,
    min(o.purchase_date)
      + interval '1 day' * (max(o.purchase_date) - min(o.purchase_date))
                                                      as _days_span,  -- internal, dropped below
    (count(*) > 1)                                     as is_repeat,
    round(avg(o.avg_review_score), 2)                  as avg_review_given,
    round(avg(o.delivery_days), 2)                     as avg_delivery_days,
    count(*) filter (where o.is_late_delivery)         as late_orders,
    round(100.0 * count(*) filter (where o.is_late_delivery)
          / nullif(count(*) filter (where o.is_delivered), 0), 2)
                                                      as late_delivery_pct,
    round(100.0 * count(*) / nullif(sum(o.order_value), 0) * 0
          + sum(o.order_value) / nullif(count(*), 0), 2)
                                                      as avg_order_value
from orders o
group by o.customer_unique_id