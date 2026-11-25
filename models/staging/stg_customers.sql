select
    customer_id,
    trim(full_name) as full_name,
    initcap(trim(city)) as city,
    lower(trim(tier)) as tier,
    signup_date
from {{ source('jara_raw', 'customers') }}
where customer_id is not null