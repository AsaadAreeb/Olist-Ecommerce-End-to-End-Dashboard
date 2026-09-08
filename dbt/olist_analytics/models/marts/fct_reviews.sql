with reviews as (
    select * from {{ ref('stg_order_reviews') }}
),

order_context as (
    select
        order_id,
        customer_state,
        order_status,
        purchase_date,
        is_delivered,
        is_late_delivery,
        delivery_days,
        primary_payment_type
    from {{ ref('fct_orders') }}
)

select
    r.review_id,
    r.order_id,
    r.review_score,
    r.comment_title,
    r.comment_message,
    r.has_comment,
    r.review_created_at,
    r.review_answered_at,
    r.review_response_days,

    oc.customer_state,
    oc.order_status,
    oc.purchase_date,
    oc.is_delivered,
    oc.is_late_delivery,
    oc.delivery_days,
    oc.primary_payment_type
from reviews r
left join order_context oc on oc.order_id = r.order_id
-- LEFT join on purpose: a small number of reviews reference orders
-- outside the orders file (assessment finding #7). Keep the review
-- signal, leave the order columns NULL.