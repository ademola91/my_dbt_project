

# Jara Logistics — Partner Fleet Cost Reconciliation

## Overview
End-to-end analytics engineering pipeline investigating an anomalous **NGN 127,983,042** partner fleet invoice in November 2025 against historical baselines (September–December 2025). Built using **MongoDB**, **PostgreSQL (Neon)**, and **dbt Core**.

## Architecture
1. **Unstructured Ingestion (`mongodb/ticket_volume_weekly_by_category.js`):** Aggregates raw customer support tickets by ISO week, category, priority, and escalation status, exported to CSV and loaded into `raw.support_tickets_weekly`.
2. **Staging Layer (`models/staging/` — Materialized as Views):**
   - `stg_customers`: Standardized customer records (`raw.customers`).
   - `stg_riders`: Standardized rider roster and fleet assignments (`raw.riders`).
   - `stg_deliveries`: Deduplicated delivery transactions with normalized status and fleet fallback (`raw.deliveries`).
   - `stg_support_tickets_weekly`: Weekly support ticket metrics (`raw.support_tickets_weekly`).
3. **Mart Layer (`models/marts/` — Materialized as Table):**
   - `mart_fleet_reconciliation`: Weekly reconciliation joining deliveries, rider fleet classifications, extreme-distance anomaly flags (>100km), customer delivery fees, and weekly support ticket volumes.
4. **Data Quality Tests (`schema.yml`):** 14 automated dbt schema tests (`unique`, `not_null`, `accepted_values`, `relationships`).

## Key Findings
- **Root Cause of November Invoice Spike:** November partner delivery volume (`439` trips) and customer fees (`NGN 896,814.67`) remained consistent with October (`404` trips, `NGN 876,469.05`). However, **107 partner deliveries** during the week of **2025-11-17** recorded corrupted distance values (≥100km), inflating November partner mileage from **3,715.30 km** (October) to **935,291.80 km** (~251x baseline) before normalizing in December (`3,976.00 km`).
- **Support Ticket Correlation:** Customer support volume spiked to **108 tickets** (`53` high-priority, `49` escalated) during the week of **2025-11-10** immediately preceding the **2025-11-17** distance telemetry anomaly (`42` tickets), indicating a mid-November system/routing incident.
- **Data Integrity Audit:** dbt relationship tests flagged **4 deliveries** assigned to placeholder `rider_id = 9999` (`1` own-fleet trip totaling `NGN 964.21`; `3` partner-fleet trips totaling `NGN 6,256.72`) missing from the master `riders` table.

## Recommendations
1. **Dispute & Recalculate November Partner Invoice:** Exclude or normalize the 107 outlier distance records from the week of `2025-11-17` using standard per-trip distance averages (~9.2 km/trip) before approving partner settlement.
2. **Enforce Ingestion Guardrails:** Add a staging/ingestion check capping single-trip intra-city distances (e.g., `< 100 km`) and enforce foreign-key validation against `riders` to eliminate placeholder `rider_id = 9999` assignments.
