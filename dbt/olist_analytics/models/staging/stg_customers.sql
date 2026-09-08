with source as (
    select * from {{ source('olist_raw', 'customers') }}
)

select
    cast(customer_id as text)                     as customer_id,
    cast(customer_unique_id as text)             as customer_unique_id,
    cast(customer_zip_code_prefix as integer)   as customer_zip_code_prefix,
    trim(customer_city)                          as customer_city,
    upper(trim(customer_state))                  as customer_state
from source