with source as (
    select * from {{ source('olist_raw', 'sellers') }}
)

select
    cast(seller_id as text)                     as seller_id,
    cast(seller_zip_code_prefix as integer)     as seller_zip_code_prefix,
    trim(seller_city)                           as seller_city,
    upper(trim(seller_state))                   as seller_state
from source