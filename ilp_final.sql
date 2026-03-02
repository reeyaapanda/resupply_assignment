 DROP VIEW IF EXISTS item_level_performance;

CREATE VIEW item_level_performance AS

WITH exploded_items AS (
    SELECT
        d.donation_id,
        CAST(json_extract(j.value, '$.id') AS TEXT) AS item_id,
        CAST(NULLIF(d.on_site_additional_recycling_fees, '') AS INTEGER)
            AS recycling_fee_amount
    FROM completed_webflow_donations d
    JOIN json_each(d.item_data) j
    WHERE json_extract(j.value, '$.type') = 'Item'
      AND json_extract(j.value, '$.id') IS NOT NULL
),

-- Deduplicate item within donation
unique_donation_items AS (
    SELECT DISTINCT
        donation_id,
        item_id,
        recycling_fee_amount
    FROM exploded_items
)

SELECT
    i.item_id,
    i.item_name,
    i.item_description,
    i.resale_value,
    i.sellthrough_rate,
    i.small_specification,
    i.medium_specification,
    i.large_specification,
    i.extra_large_specification,

    COUNT(DISTINCT u.donation_id) AS total_donations,

    -- Total recycling fees without double counting
    COALESCE(SUM(u.recycling_fee_amount), 0) AS total_recycling_fees,

    COALESCE(AVG(
        CASE WHEN dls.recategorization_flag = 1 THEN 1 ELSE 0 END
    ), 0) AS recategorization_rate,

    COALESCE(AVG(
        dls.effective_recategorization_count
    ), 0) AS avg_recategorization_count,

    COALESCE(AVG(
        CASE WHEN dls.recycling_fee_flag = 1 THEN 1 ELSE 0 END
    ), 0) AS recycling_rate

FROM item_database i

LEFT JOIN unique_donation_items u
    ON i.item_id = u.item_id

LEFT JOIN donation_level_summary dls
    ON u.donation_id = dls.donation_id

GROUP BY
    i.item_id,
    i.item_name,
    i.item_description,
    i.resale_value,
    i.sellthrough_rate,
    i.small_specification,
    i.medium_specification,
    i.large_specification,
    i.extra_large_specification;