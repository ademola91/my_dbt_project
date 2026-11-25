-- checking for duplicates in deliveries

WITH dupes AS (
    SELECT
        delivery_id,
        COUNT(*) AS row_count,
        SUM(distance_km) AS total_km_all_rows,
        SUM(distance_km) - MIN(distance_km) AS excess_km_if_deduped
    FROM raw.deliveries
    GROUP BY delivery_id
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_delivery_ids,
    SUM(row_count) AS total_rows_involved_in_dupes,
    SUM(excess_km_if_deduped) AS excess_km,
    SUM(excess_km_if_deduped) * 220 AS excess_ngn_at_220_per_km
FROM dupes;

-- checking for Missing Customers & Orphaned Rider IDs

SELECT
    COUNT(*) FILTER (WHERE d.customer_id IS NULL) AS missing_customer_id_rows,
    COUNT(*) FILTER (WHERE r.rider_id IS NULL) AS orphaned_rider_id_rows,
    SUM(d.distance_km) FILTER (WHERE r.rider_id IS NULL) AS orphaned_rider_km,
    SUM(d.distance_km) FILTER (WHERE r.rider_id IS NULL) * 220 AS orphaned_rider_ngn_at_220
FROM raw.deliveries d
LEFT JOIN raw.riders r
    ON d.rider_id = r.rider_id;

--- all data values and see how they behave across months (for example, completed vs. delivered, casing, or typos).
SELECT
    status,
    COUNT(*) AS row_count,
    SUM(distance_km) AS total_km
FROM raw.deliveries
GROUP BY status
ORDER BY row_count DESC;

-- looking for Impossible Distances & Vehicle Mismatches
SELECT
    d.delivery_id,
    d.rider_id,
    r.fleet,
    r.vehicle_type,
    d.status,
    d.distance_km,
    d.distance_km * 220 AS implied_ngn_at_220
FROM raw.deliveries d
LEFT JOIN raw.riders r
    ON d.rider_id = r.rider_id
WHERE d.distance_km IS NULL
   OR d.distance_km <= 0
   OR (r.vehicle_type = 'bike' AND d.distance_km > 100)
   OR d.distance_km > 200
ORDER BY d.distance_km DESC NULLS LAST;

-- above result from outlier distance cover shows that All 107 flagged rows belong to partner riders (rider_id 721–734) 
-- and range from 1,400.00 km to 26,100.00 km—every one is an exact multiple of 100 km 
-- (impossible for single last-mile deliveries, especially on bikes) and 
--totals 942,300.00 km (NGN 207,306,000.00 across all statuses including NGN 127,424,000.00 on the 72 delivered rows alone).


-- checking Monthly Breakdown (Oct, Nov, Dec) & Where NGN 127,983,042 Comes From
SELECT
    DATE_TRUNC('month', d.created_at::timestamp) AS month_bucket,
    COALESCE(r.fleet, 'UNKNOWN_RIDER') AS fleet,
    d.status,
    COUNT(*) AS delivery_rows,
    SUM(d.distance_km) AS total_km,
    SUM(d.distance_km) * 220 AS raw_ngn_at_220
FROM raw.deliveries d
LEFT JOIN raw.riders r
    ON d.rider_id = r.rider_id
GROUP BY 1, 2, 3
ORDER BY 1, 2, raw_ngn_at_220 DESC NULLS LAST;

-- findings from the queries shows that on 01 November, partner rows with status = 'delivered' (372 rows, 581,731.70 km) 
-- generate NGN 127,980,974.00 at NGN 220/km, and adding the 1 UNKNOWN_RIDER row with status = 'delivered' in November (9.40 km = NGN 2,068.00)
-- equals NGN 127,983,042.00 to the exact naira.

