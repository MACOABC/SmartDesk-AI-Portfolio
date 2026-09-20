BEGIN;

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE OR REPLACE VIEW analytics.v_ticket_lifecycle AS
SELECT
    t.id AS ticket_id,
    t.requester_area,
    t.status AS ticket_status,
    t.created_at AS ticket_created_at,
    t.updated_at AS ticket_updated_at,
    d.id AS final_decision_id,
    d.category AS final_category,
    d.priority AS final_priority,
    d.decision_source,
    d.decided_at AS final_decision_at,
    dp.id AS decision_prediction_id,
    dp.status AS decision_prediction_status,
    dp.category AS decision_prediction_category,
    dp.priority AS decision_prediction_priority,
    dp.confidence AS decision_prediction_confidence,
    dp.review_required AS decision_prediction_review_required,
    dp.provider AS decision_prediction_provider,
    dp.model AS decision_prediction_model,
    dp.prompt_version AS decision_prediction_prompt_version,
    dp.schema_version AS decision_prediction_schema_version,
    dp.error_code AS decision_prediction_error_code,
    dp.failure_kind AS decision_prediction_failure_kind,
    dp.attempt_count AS decision_prediction_attempt_count,
    dp.created_at AS decision_prediction_created_at,
    dp.updated_at AS decision_prediction_updated_at,
    dp.last_attempt_at AS decision_prediction_last_attempt_at,
    s.id AS sla_id,
    s.policy_version AS sla_policy_version,
    s.priority AS sla_priority,
    s.status AS sla_status,
    s.started_at AS sla_started_at,
    s.due_at AS sla_due_at,
    s.resolved_at,
    s.breached_at,
    s.created_at AS sla_created_at,
    s.updated_at AS sla_updated_at,
    CASE
        WHEN s.resolved_at IS NULL THEN NULL
        ELSE EXTRACT(EPOCH FROM (s.resolved_at - t.created_at)) / 60.0
    END AS resolution_minutes
FROM public.tickets AS t
LEFT JOIN public.ticket_decisions AS d
       ON d.ticket_id = t.id
LEFT JOIN public.ticket_ai_predictions AS dp
       ON dp.id = d.prediction_id
LEFT JOIN public.ticket_sla AS s
       ON s.ticket_id = t.id;

COMMENT ON VIEW analytics.v_ticket_lifecycle IS
    'One row per ticket. Prediction columns describe only the prediction referenced by the final decision; no universal ticket prediction is inferred.';
COMMENT ON COLUMN analytics.v_ticket_lifecycle.resolution_minutes IS
    'Elapsed calendar minutes between persisted ticket creation and persisted SLA resolution.';

CREATE OR REPLACE VIEW analytics.v_ai_predictions AS
SELECT
    p.id AS prediction_id,
    p.ticket_id,
    t.requester_area,
    t.created_at AS ticket_created_at,
    p.status AS prediction_status,
    p.category AS prediction_category,
    p.priority AS prediction_priority,
    p.confidence AS prediction_confidence,
    p.review_required,
    p.provider AS prediction_provider,
    p.model AS prediction_model,
    p.prompt_version AS prediction_prompt_version,
    p.schema_version AS prediction_schema_version,
    p.error_code AS prediction_error_code,
    p.failure_kind AS prediction_failure_kind,
    p.attempt_count,
    p.last_attempt_at,
    p.created_at AS prediction_created_at,
    p.updated_at AS prediction_updated_at
FROM public.ticket_ai_predictions AS p
JOIN public.tickets AS t
  ON t.id = p.ticket_id;

COMMENT ON VIEW analytics.v_ai_predictions IS
    'One row per persisted AI prediction. Metrics from this view are prediction-level, not ticket-level.';
COMMENT ON COLUMN analytics.v_ai_predictions.prediction_confidence IS
    'Operational model confidence signal; not a calibrated probability of correctness.';

CREATE OR REPLACE VIEW analytics.v_hitl_reviews AS
SELECT
    r.id AS review_id,
    r.ticket_id,
    r.prediction_id,
    t.requester_area,
    t.created_at AS ticket_created_at,
    r.status AS review_status,
    r.created_at AS review_created_at,
    r.decided_at AS review_decided_at,
    r.updated_at AS review_updated_at,
    p.status AS prediction_status,
    p.category AS prediction_category,
    p.priority AS prediction_priority,
    p.confidence AS prediction_confidence,
    p.provider AS prediction_provider,
    p.model AS prediction_model,
    p.prompt_version AS prediction_prompt_version,
    p.schema_version AS prediction_schema_version,
    d.id AS final_decision_id,
    d.decision_source,
    d.category AS final_category,
    d.priority AS final_priority,
    d.decided_at AS final_decision_at,
    CASE
        WHEN d.id IS NULL THEN NULL
        ELSE d.category IS DISTINCT FROM p.category
    END AS category_changed,
    CASE
        WHEN d.id IS NULL THEN NULL
        ELSE d.priority IS DISTINCT FROM p.priority
    END AS priority_changed
FROM public.ticket_reviews AS r
JOIN public.tickets AS t
  ON t.id = r.ticket_id
JOIN public.ticket_ai_predictions AS p
  ON p.id = r.prediction_id
LEFT JOIN public.ticket_decisions AS d
       ON d.review_id = r.id;

COMMENT ON VIEW analytics.v_hitl_reviews IS
    'One row per persisted human review. Change flags compare the linked prediction with the final decision and do not represent accuracy.';

CREATE OR REPLACE VIEW analytics.v_automation_events AS
SELECT
    e.id AS event_id,
    e.ticket_id,
    e.prediction_id,
    e.decision_id,
    e.review_id,
    e.sla_breach_id,
    t.requester_area,
    t.created_at AS ticket_created_at,
    e.rule_code,
    e.event_type,
    e.status AS event_status,
    e.error_code AS event_error_code,
    e.created_at AS event_created_at,
    e.updated_at AS event_updated_at
FROM public.automation_events AS e
JOIN public.tickets AS t
  ON t.id = e.ticket_id;

COMMENT ON VIEW analytics.v_automation_events IS
    'One row per persisted automation event. No recipient identifiers, message bodies, credentials or secrets are exposed.';

COMMIT;
