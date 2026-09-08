with source as (
    select * from {{ source('olist_raw', 'order_reviews') }}
),

deduplicated as (
    -- Assessment finding #2: 789 duplicate review_id values in the source.
    -- Keep one row per review_id; most recent record wins ties.
    select distinct on (review_id)
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp
    from source
    order by review_id, review_creation_date desc
)

select
    cast(review_id as text)                                    as review_id,
    cast(order_id as text)                                     as order_id,
    cast(review_score as integer)                              as review_score,
    nullif(trim(review_comment_title), '')                     as comment_title,
    nullif(trim(review_comment_message), '')                   as comment_message,
    cast(review_creation_date as timestamp)                   as review_created_at,
    cast(review_answer_timestamp as timestamp)                as review_answered_at,
    (nullif(trim(review_comment_message), '') is not null)    as has_comment,
    case
        when review_creation_date is not null
         and review_answer_timestamp is not null
        then round(
            extract(epoch from (review_answer_timestamp - review_creation_date)) / 86400.0,
            2
        )
    end                                                        as review_response_days
from deduplicated