WITH receipt_allocation_totals AS (
  SELECT
    rja.receipt_id,
    SUM(rja.amount) AS allocation_total,
    MAX(rja.id) AS last_allocation_id
  FROM receipt_job_allocation rja
  GROUP BY rja.receipt_id
),
receipts_to_scale AS (
  SELECT
    receipt.id AS receipt_id,
    receipt.total_excluding_tax,
    totals.allocation_total,
    totals.last_allocation_id
  FROM receipt
  JOIN receipt_allocation_totals totals
    ON totals.receipt_id = receipt.id
  WHERE totals.allocation_total = receipt.total_including_tax
    AND totals.allocation_total != receipt.total_excluding_tax
),
scaled_non_last AS (
  SELECT
    rja.id,
    CAST(
      ROUND(
        rja.amount * 1.0 * receipts_to_scale.total_excluding_tax
          / receipts_to_scale.allocation_total
      ) AS INTEGER
    ) AS scaled_amount
  FROM receipt_job_allocation rja
  JOIN receipts_to_scale
    ON receipts_to_scale.receipt_id = rja.receipt_id
  WHERE rja.id != receipts_to_scale.last_allocation_id
),
scaled_last AS (
  SELECT
    receipts_to_scale.last_allocation_id AS id,
    receipts_to_scale.total_excluding_tax
      - IFNULL(SUM(scaled_non_last.scaled_amount), 0) AS scaled_amount
  FROM receipts_to_scale
  LEFT JOIN scaled_non_last
    ON scaled_non_last.id IN (
      SELECT id
      FROM receipt_job_allocation
      WHERE receipt_id = receipts_to_scale.receipt_id
    )
  GROUP BY receipts_to_scale.receipt_id
),
scaled_allocations AS (
  SELECT id, scaled_amount FROM scaled_non_last
  UNION ALL
  SELECT id, scaled_amount FROM scaled_last
)
UPDATE receipt_job_allocation
SET
  amount = (
    SELECT scaled_amount
    FROM scaled_allocations
    WHERE scaled_allocations.id = receipt_job_allocation.id
  ),
  modified_date = datetime('now')
WHERE id IN (
  SELECT id
  FROM scaled_allocations
);
