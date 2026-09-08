with orders as (
    select * from {{ ref('stg_orders') }}
),

items_agg as (select * from {{ ref('int_order_items_agg') }}),
payments_agg as (select * from {{ ref('int_order_payments_agg') }}),
reviews_agg as (select * from {{ ref('int_order_reviews_agg') }}),
customers as (select * from {{ ref('stg_customers') }})

select
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,
    o.order_status,
    o.purchased_at,
    o.approved_at,
    o.shipped_at,
    o.delivered_at,
    o.estimated_delivery_at,
    o.purchased_at::date                                  as purchase_date,
    date_trunc('month', o.purchased_at)::date             as purchase_month_start,

    -- order-level economics (item grain collapsed, never joined raw-to-raw)
    (i.order_id is not null)                               as has_items,
    coalesce(i.item_count, 0)                              as item_count,
    coalesce(i.seller_count, 0)                           as seller_count,
    coalesce(i.product_revenue, 0)                         as product_revenue,
    coalesce(i.freight_revenue, 0)                         as freight_revenue,
    coalesce(i.order_value_from_items, 0)                  as order_value,
    case
        when coalesce(i.order_value_from_items, 0) > 0
        then round(100.0 * coalesce(i.freight_revenue,0)
                   / i.order_value_from_items, 2)
    end                                                    as freight_share_pct,

    -- payment behavior (one row per order, so safe to join)
    p.total_payment,
    p.payment_count,
    p.primary_payment_type,
    p.max_installments,
    p.has_credit_card,
    p.has_boleto,
    p.has_voucher,
    p.has_debit_card,
    case
        when p.total_payment is not null
         and coalesce(i.order_value_from_items, 0) > 0
        then p.total_payment - i.order_value_from_items
    end                                                    as payment_item_gap,

    -- review (averaged at order grain when multiple reviews exist)
    r.review_score                                         as avg_review_score,
    r.review_count                                         as review_count,
    r.has_comment                                          as has_review_comment,

    -- status flags
    (o.order_status = 'delivered')                         as is_delivered,
    (o.order_status = 'canceled')                          as is_cancelled,
    (o.order_status in ('created','approved','invoiced','processing','shipped'))
                                                           as is_in_progress,

    -- delivery performance (business logic lives HERE, not in Power BI)
    case
        when o.delivered_at is not null and o.purchased_at is not null
        then o.delivered_at::date - o.purchased_at::date
    end                                                    as delivery_days,
    case
        when o.estimated_delivery_at is not null
        then o.estimated_delivery_at - o.purchased_at::date
    end                                                    as estimated_delivery_days,
    case
        when o.delivered_at is not null and o.approved_at is not null
        then round(extract(epoch from (o.approved_at - o.purchased_at)) / 3600.0, 2)
    end                                                    as approval_hours,
    case
        when o.shipped_at is not null and o.approved_at is not null
        then o.shipped_at::date - o.approved_at::date
    end                                                    as days_to_ship,

    -- lateness, the headline logistics metric
    (o.delivered_at is not null
     and o.estimated_delivery_at is not null
     and o.delivered_at::date > o.estimated_delivery_at)   as is_late_delivery,
    case
        when o.delivered_at is not null and o.estimated_delivery_at is not null
        then o.delivered_at::date - o.estimated_delivery_at
    end                                                    as delay_days_vs_estimate

from orders o
left join customers c   on c.customer_id  = o.customer_id
left join items_agg i   on i.order_id     = o.order_id
left join payments_agg p on p.order_id    = o.order_id
left join reviews_agg r  on r.order_id   = o.order_id