with payments as (
    select * from {{ ref('stg_order_payments') }}
)

select
    order_id,
    sum(payment_value)                          as total_payment,
    count(*)                                    as payment_count,
    count(distinct payment_type)                as payment_type_count,
    max(payment_installments)                   as max_installments,
    (array_agg(payment_type order by payment_value desc))[1] as primary_payment_type,
    bool_or(payment_type = 'credit_card')       as has_credit_card,
    bool_or(payment_type = 'boleto')            as has_boleto,
    bool_or(payment_type = 'voucher')           as has_voucher,
    bool_or(payment_type = 'debit_card')        as has_debit_card
from payments
group by order_id