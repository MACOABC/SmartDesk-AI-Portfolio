\set ON_ERROR_STOP on
\pset pager off

BEGIN TRANSACTION READ ONLY;

\echo === G8-04 ticket grain ===
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT ticket_id) AS distinct_tickets,
    COUNT(*) = COUNT(DISTINCT ticket_id) AS grain_ok
FROM analytics.v_ticket_lifecycle;

\echo === G8-05 ticket coverage ===
SELECT
    (SELECT COUNT(*) FROM analytics.v_ticket_lifecycle)
    =
    (SELECT COUNT(*) FROM public.tickets) AS ticket_coverage_ok;

\echo === duplicate ticket rows; expected 0 rows ===
SELECT ticket_id, COUNT(*)
FROM analytics.v_ticket_lifecycle
GROUP BY ticket_id
HAVING COUNT(*) <> 1;

\echo === G8-06 prediction grain ===
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT prediction_id) AS distinct_predictions,
    COUNT(*) = COUNT(DISTINCT prediction_id) AS grain_ok
FROM analytics.v_ai_predictions;

\echo === G8-07 prediction coverage ===
SELECT
    (SELECT COUNT(*) FROM analytics.v_ai_predictions)
    =
    (SELECT COUNT(*) FROM public.ticket_ai_predictions) AS prediction_coverage_ok;

\echo === G8-08 review grain and coverage ===
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT review_id) AS distinct_reviews,
    COUNT(*) = COUNT(DISTINCT review_id) AS grain_ok,
    COUNT(*) = (SELECT COUNT(*) FROM public.ticket_reviews) AS coverage_ok
FROM analytics.v_hitl_reviews;

\echo === G8-09 automation grain and coverage ===
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT event_id) AS distinct_events,
    COUNT(*) = COUNT(DISTINCT event_id) AS grain_ok,
    COUNT(*) = (SELECT COUNT(*) FROM public.automation_events) AS coverage_ok
FROM analytics.v_automation_events;

\echo === G8-10 orphan detection ===
SELECT 'ai_predictions' AS entity, COUNT(*) AS orphan_rows
FROM analytics.v_ai_predictions a
LEFT JOIN public.tickets t ON t.id = a.ticket_id
WHERE t.id IS NULL
UNION ALL
SELECT 'hitl_reviews', COUNT(*)
FROM analytics.v_hitl_reviews a
LEFT JOIN public.tickets t ON t.id = a.ticket_id
WHERE t.id IS NULL
UNION ALL
SELECT 'automation_events', COUNT(*)
FROM analytics.v_automation_events a
LEFT JOIN public.tickets t ON t.id = a.ticket_id
WHERE t.id IS NULL;

\echo === G8-11 prohibited PII names; expected 0 rows ===
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND lower(column_name) IN (
      'requester_email',
      'title',
      'description',
      'summary',
      'final_summary',
      'review_reason',
      'reviewer',
      'comment',
      'resolved_by',
      'telegram_chat_id',
      'chat_id',
      'recipient',
      'message',
      'message_text',
      'password',
      'credential',
      'credentials',
      'secret',
      'token'
  )
ORDER BY table_name, column_name;

\echo === G8-12 temporal validity ===
SELECT COUNT(*) AS negative_resolution_rows
FROM analytics.v_ticket_lifecycle
WHERE resolution_minutes < 0;

\echo === NULL semantics ===
SELECT
    COUNT(*) FILTER (
        WHERE sla_id IS NULL
          AND (sla_status IS NOT NULL OR resolved_at IS NOT NULL OR resolution_minutes IS NOT NULL)
    ) AS no_sla_misrepresented,
    COUNT(*) FILTER (
        WHERE final_decision_id IS NULL
          AND (
              final_category IS NOT NULL
              OR final_priority IS NOT NULL
              OR decision_source IS NOT NULL
              OR decision_prediction_id IS NOT NULL
              OR decision_prediction_status IS NOT NULL
          )
    ) AS no_decision_misrepresented,
    COUNT(*) FILTER (
        WHERE resolved_at IS NULL AND resolution_minutes IS NOT NULL
    ) AS no_resolution_misrepresented
FROM analytics.v_ticket_lifecycle;

SELECT
    COUNT(*) FILTER (
        WHERE final_decision_id IS NULL
          AND (category_changed IS NOT NULL OR priority_changed IS NOT NULL)
    ) AS no_decision_change_flags
FROM analytics.v_hitl_reviews;

\echo === KPI reference: ticket cards ===
SELECT
    COUNT(*) AS total_tickets,
    COUNT(*) FILTER (WHERE resolved_at IS NOT NULL) AS resolved_tickets,
    COUNT(*) FILTER (WHERE sla_id IS NOT NULL) AS sla_assigned,
    COUNT(*) FILTER (WHERE sla_status = 'breached') AS sla_breached,
    ROUND(
        COUNT(*) FILTER (WHERE sla_status = 'breached')::numeric
        / NULLIF(COUNT(*) FILTER (WHERE sla_id IS NOT NULL), 0),
        6
    ) AS sla_breach_rate,
    ROUND(AVG(resolution_minutes), 6) AS average_resolution_minutes,
    ROUND(
        percentile_cont(0.5) WITHIN GROUP (ORDER BY resolution_minutes)::numeric,
        6
    ) AS median_resolution_minutes
FROM analytics.v_ticket_lifecycle;

\echo === KPI reference: ticket distributions ===
SELECT requester_area, COUNT(*) AS tickets
FROM analytics.v_ticket_lifecycle
GROUP BY requester_area
ORDER BY requester_area;

SELECT ticket_status, COUNT(*) AS tickets
FROM analytics.v_ticket_lifecycle
GROUP BY ticket_status
ORDER BY ticket_status;

SELECT final_category, COUNT(*) AS tickets
FROM analytics.v_ticket_lifecycle
WHERE final_category IS NOT NULL
GROUP BY final_category
ORDER BY final_category;

SELECT final_priority, COUNT(*) AS tickets
FROM analytics.v_ticket_lifecycle
WHERE final_priority IS NOT NULL
GROUP BY final_priority
ORDER BY final_priority;

\echo === KPI reference: prediction cards ===
SELECT
    COUNT(*) AS prediction_attempts,
    COUNT(*) FILTER (WHERE prediction_status = 'succeeded') AS successful_predictions,
    COUNT(*) FILTER (WHERE prediction_status = 'failed') AS failed_predictions,
    COUNT(*) FILTER (WHERE prediction_status = 'pending') AS pending_predictions,
    COUNT(*) FILTER (WHERE prediction_status IN ('succeeded', 'failed')) AS terminal_prediction_attempts,
    ROUND(
        COUNT(*) FILTER (WHERE prediction_status = 'succeeded')::numeric
        / NULLIF(COUNT(*) FILTER (WHERE prediction_status IN ('succeeded', 'failed')), 0),
        6
    ) AS prediction_success_rate
FROM analytics.v_ai_predictions;

SELECT
    prediction_provider,
    prediction_model,
    prediction_prompt_version,
    prediction_schema_version,
    prediction_status,
    COUNT(*) AS predictions,
    MIN(prediction_confidence) AS minimum_confidence,
    MAX(prediction_confidence) AS maximum_confidence,
    AVG(prediction_confidence) AS average_confidence
FROM analytics.v_ai_predictions
GROUP BY
    prediction_provider,
    prediction_model,
    prediction_prompt_version,
    prediction_schema_version,
    prediction_status
ORDER BY
    prediction_provider,
    prediction_model,
    prediction_prompt_version,
    prediction_schema_version,
    prediction_status;

\echo === KPI reference: HITL cards ===
SELECT
    COUNT(*) AS persisted_reviews,
    COUNT(*) FILTER (WHERE review_status IN ('approved', 'overridden')) AS completed_reviews,
    COUNT(*) FILTER (WHERE review_status = 'pending') AS pending_reviews,
    COUNT(*) FILTER (WHERE category_changed) AS category_overrides,
    COUNT(*) FILTER (WHERE priority_changed) AS priority_overrides,
    COUNT(*) FILTER (WHERE review_status = 'overridden') AS overridden_reviews,
    ROUND(
        COUNT(*) FILTER (WHERE review_status = 'overridden')::numeric
        / NULLIF(COUNT(*) FILTER (WHERE review_status IN ('approved', 'overridden')), 0),
        6
    ) AS override_rate
FROM analytics.v_hitl_reviews;

\echo === KPI reference: automation cards ===
SELECT
    COUNT(*) AS automation_events,
    COUNT(*) FILTER (WHERE event_status = 'succeeded') AS succeeded_events,
    COUNT(*) FILTER (WHERE event_status = 'failed') AS failed_events,
    COUNT(*) FILTER (WHERE event_status = 'skipped') AS skipped_events,
    COUNT(*) FILTER (WHERE event_status = 'pending') AS pending_events
FROM analytics.v_automation_events;

ROLLBACK;
