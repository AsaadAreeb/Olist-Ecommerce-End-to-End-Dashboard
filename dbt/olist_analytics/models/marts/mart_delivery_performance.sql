with orders as (
    select * from {{ ref('fct_orders') }}
)

select
    o.purchase_month_start                              as month_start,
    o.customer_state,
    count(*)                                            as orders,
    count(*) filter (where o.is_delivered)              as delivered_orders,
    count(*) filter (where o.is_cancelled)             as cancelled_orders,
    round(avg(o.delivery_days), 2)                      as avg_delivery_days,
    round(avg(o.estimated_delivery_days), 2)            as avg_estimated_days,
    count(*) filter (where o.is_late_delivery)          as late_orders,
    round(100.0 * count(*) filter (where o.is_late_delivery)
          / nullif(count(*) filter (where o.is_delivered), 0), 2)
                                                        as late_delivery_pct,
    round(avg(o.delay_days_vs_estimate) filter (where o.is_late_delivery), 2)
                                                        as avg_delay_days_when_late,
    round(avg(o.days_to_ship), 2)                       as avg_days_to_ship
from orders o
group by o.purchase_month_start, o.customer_state