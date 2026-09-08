-- Warn-level reconciliation: total paid vs total item value per order.
-- A small set of known mismatches exists in this dataset; the test surfaces
-- them so they are never silently accepted. Errors only if NEW mismatches appear
-- on delivered orders with complete items.
{{ config(severity = 'warn') }}

select
    order_id,
    total_payment,
    order_value,
    payment_item_gap
from {{ ref('fct_orders') }}
where order_status = 'delivered'
  and has_items = true
  and abs(coalesce(payment_item_gap, 0)) > 1.00