{{ config(severity = 'warn') }}

-- Assessment finding #11: exactly 8 delivered orders are missing
-- order_delivered_customer_date. Documented disposition: retained as received;
-- delivery metrics stay NULL for them. Baseline = 8 rows — if this count grows
-- on a future refresh, investigate at source.

select
    order_id,
    order_status,
    purchased_at
from {{ ref('fct_orders') }}
where order_status = 'delivered'
  and delivered_at is null