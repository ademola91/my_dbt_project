select
    date_trunc('week', ticket_week)::date as ticket_week,
    lower(trim(category)) as category,
    coalesce(ticket_count, 0) as ticket_count,
    coalesce(high_priority_count, 0) as high_priority_count,
    coalesce(escalated_count, 0) as escalated_count
from {{ source('jara_raw', 'support_tickets_weekly') }}