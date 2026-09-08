with source as (
    select * from {{ source('olist_raw', 'category_translation') }}
),

standardized as (
    select
        lower(trim(product_category_name))          as product_category_name,
        lower(trim(product_category_name_english))  as product_category_name_english
    from source
)

select * from standardized

union all

select
    'pc_gamer'::text                                       as product_category_name,
    'pc_gamer'::text                                       as product_category_name_english

union all

select
    'portateis_cozinha_e_preparadores_de_alimentos'::text  as product_category_name,
    'portable_kitchen_food_preparers'::text                as product_category_name_english