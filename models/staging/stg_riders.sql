select
    rider_id,
    trim(rider_name) as rider_name,
    lower(trim(vehicle_type)) as vehicle_type,
    lower(trim(fleet)) as fleet,
    initcap(trim(base_city)) as base_city,
    joined_date
from {{ source('jara_raw', 'riders') }}
where rider_id is not null