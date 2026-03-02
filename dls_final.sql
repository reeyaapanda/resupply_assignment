DROP VIEW IF EXISTS donation_level_summary;

CREATE VIEW donation_level_summary AS

WITH base AS (
    SELECT
        donation_id,

        CAST(initial_small_items AS INTEGER) AS init_s,
        CAST(initial_medium_items AS INTEGER) AS init_m,
        CAST(initial_large_items AS INTEGER) AS init_l,
        CAST(initial_extra_large_items AS INTEGER) AS init_xl,

        CAST(on_site_adjusted_small_items AS INTEGER) AS adj_s,
        CAST(on_site_adjusted_medium_items AS INTEGER) AS adj_m,
        CAST(on_site_adjusted_large_items AS INTEGER) AS adj_l,
        CAST(on_site_adjusted_extra_large_items AS INTEGER) AS adj_xl,

        CAST(on_site_additional_recycling_fees AS INTEGER) AS recycling_fees_raw

    FROM Completed_Webflow_Donations
),

deltas AS (
    SELECT
        donation_id,

        init_s, init_m, init_l, init_xl,
        adj_s, adj_m, adj_l, adj_xl,
        recycling_fees_raw,

        (adj_s - init_s) AS delta_s,
        (adj_m - init_m) AS delta_m,
        (adj_l - init_l) AS delta_l,
        (adj_xl - init_xl) AS delta_xl

    FROM base
)

SELECT
    donation_id,

    init_s, init_m, init_l, init_xl,
    adj_s, adj_m, adj_l, adj_xl,

    -- Totals
    (init_s + init_m + init_l + init_xl) AS total_initial,
    (adj_s + adj_m + adj_l + adj_xl) AS total_adjusted,

    (adj_s + adj_m + adj_l + adj_xl)
      - (init_s + init_m + init_l + init_xl) AS delta_total,

    -- Category deltas
    delta_s,
    delta_m,
    delta_l,
    delta_xl,

    --- Sum of positive deltas
(
    CASE WHEN delta_s > 0 THEN delta_s ELSE 0 END +
    CASE WHEN delta_m > 0 THEN delta_m ELSE 0 END +
    CASE WHEN delta_l > 0 THEN delta_l ELSE 0 END +
    CASE WHEN delta_xl > 0 THEN delta_xl ELSE 0 END
) AS sum_positive_deltas,

-- Sum of negative deltas (absolute)
(
    ABS(CASE WHEN delta_s < 0 THEN delta_s ELSE 0 END) +
    ABS(CASE WHEN delta_m < 0 THEN delta_m ELSE 0 END) +
    ABS(CASE WHEN delta_l < 0 THEN delta_l ELSE 0 END) +
    ABS(CASE WHEN delta_xl < 0 THEN delta_xl ELSE 0 END)
) AS sum_negative_deltas,

-- Effective recategorization count
MIN(
    (
        CASE WHEN delta_s > 0 THEN delta_s ELSE 0 END +
        CASE WHEN delta_m > 0 THEN delta_m ELSE 0 END +
        CASE WHEN delta_l > 0 THEN delta_l ELSE 0 END +
        CASE WHEN delta_xl > 0 THEN delta_xl ELSE 0 END
    ),
    (
        ABS(CASE WHEN delta_s < 0 THEN delta_s ELSE 0 END) +
        ABS(CASE WHEN delta_m < 0 THEN delta_m ELSE 0 END) +
        ABS(CASE WHEN delta_l < 0 THEN delta_l ELSE 0 END) +
        ABS(CASE WHEN delta_xl < 0 THEN delta_xl ELSE 0 END)
    )
) AS effective_recategorization_count,

    -- Recategorization flag
    CASE
        WHEN
            (
                delta_s < 0 OR
                delta_m < 0 OR
                delta_l < 0 OR
                delta_xl < 0
            )
        AND
            (
                delta_s > 0 OR
                delta_m > 0 OR
                delta_l > 0 OR
                delta_xl > 0
            )
        THEN 1 ELSE 0
    END AS recategorization_flag,

    -- Quantity underreporting
    CASE 
        WHEN (adj_s + adj_m + adj_l + adj_xl)
           - (init_s + init_m + init_l + init_xl) > 0
        THEN (adj_s + adj_m + adj_l + adj_xl)
           - (init_s + init_m + init_l + init_xl)
        ELSE 0
    END AS quantity_underreported_count,

    -- Quantity removal
    CASE
        WHEN (adj_s + adj_m + adj_l + adj_xl)
           - (init_s + init_m + init_l + init_xl) < 0
        THEN ABS(
            (adj_s + adj_m + adj_l + adj_xl)
          - (init_s + init_m + init_l + init_xl)
        )
        ELSE 0
    END AS quantity_removed_count,

    -- Exact match
    CASE
        WHEN adj_s = init_s
         AND adj_m = init_m
         AND adj_l = init_l
         AND adj_xl = init_xl
        THEN 1 ELSE 0
    END AS exact_match_flag,

    -- Recycling fees
    recycling_fees_raw,

    CASE
        WHEN recycling_fees_raw > 0 THEN 1 ELSE 0
    END AS recycling_fee_flag

FROM deltas;