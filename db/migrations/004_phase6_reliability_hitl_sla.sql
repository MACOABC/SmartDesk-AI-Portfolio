BEGIN;

ALTER TABLE public.ticket_ai_predictions
    ADD COLUMN confidence NUMERIC(5, 4),
    ADD COLUMN review_required BOOLEAN,
    ADD COLUMN review_reason TEXT,
    ADD COLUMN attempt_count SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN last_attempt_at TIMESTAMPTZ,
    ADD COLUMN failure_kind TEXT;

ALTER TABLE public.ticket_ai_predictions
    ADD CONSTRAINT ticket_ai_predictions_confidence_check
        CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
    ADD CONSTRAINT ticket_ai_predictions_review_reason_check
        CHECK (
            review_reason IS NULL
            OR (
                char_length(btrim(review_reason)) >= 1
                AND char_length(review_reason) <= 500
            )
        ),
    ADD CONSTRAINT ticket_ai_predictions_attempt_count_check
        CHECK (attempt_count BETWEEN 0 AND 3),
    ADD CONSTRAINT ticket_ai_predictions_failure_kind_check
        CHECK (failure_kind IS NULL OR failure_kind IN ('transient', 'permanent', 'internal')),
    ADD CONSTRAINT ticket_ai_predictions_phase6_outcome_check
        CHECK (
            schema_version <> 'ticket-classification-schema-v2'
            OR (
                status = 'pending'
                AND confidence IS NULL
                AND review_required IS NULL
                AND review_reason IS NULL
                AND failure_kind IS NULL
            )
            OR (
                status = 'succeeded'
                AND confidence IS NOT NULL
                AND review_required IS NOT NULL
                AND (
                    (review_required = FALSE AND review_reason IS NULL)
                    OR
                    (review_required = TRUE AND review_reason IS NOT NULL)
                )
                AND attempt_count BETWEEN 1 AND 3
                AND last_attempt_at IS NOT NULL
                AND failure_kind IS NULL
            )
            OR (
                status = 'failed'
                AND confidence IS NULL
                AND review_required IS NULL
                AND review_reason IS NULL
                AND attempt_count BETWEEN 0 AND 3
                AND failure_kind IS NOT NULL
            )
        );

CREATE TABLE public.ticket_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL,
    prediction_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    final_category TEXT,
    final_priority TEXT,
    final_summary TEXT,
    reviewer TEXT,
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ticket_reviews_ticket_id_fkey
        FOREIGN KEY (ticket_id) REFERENCES public.tickets (id) ON DELETE RESTRICT,
    CONSTRAINT ticket_reviews_prediction_id_fkey
        FOREIGN KEY (prediction_id) REFERENCES public.ticket_ai_predictions (id) ON DELETE RESTRICT,
    CONSTRAINT ticket_reviews_prediction_key UNIQUE (prediction_id),
    CONSTRAINT ticket_reviews_status_check
        CHECK (status IN ('pending', 'approved', 'overridden')),
    CONSTRAINT ticket_reviews_category_check
        CHECK (
            final_category IS NULL
            OR final_category IN ('access', 'hardware', 'software', 'network', 'service_request', 'other')
        ),
    CONSTRAINT ticket_reviews_priority_check
        CHECK (final_priority IS NULL OR final_priority IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT ticket_reviews_summary_check
        CHECK (
            final_summary IS NULL
            OR (char_length(btrim(final_summary)) >= 1 AND char_length(final_summary) <= 300)
        ),
    CONSTRAINT ticket_reviews_reviewer_check
        CHECK (reviewer IS NULL OR (char_length(btrim(reviewer)) >= 1 AND char_length(reviewer) <= 100)),
    CONSTRAINT ticket_reviews_comment_check
        CHECK (comment IS NULL OR char_length(comment) <= 1000),
    CONSTRAINT ticket_reviews_outcome_check
        CHECK (
            (
                status = 'pending'
                AND final_category IS NULL
                AND final_priority IS NULL
                AND final_summary IS NULL
                AND reviewer IS NULL
                AND decided_at IS NULL
            )
            OR (
                status IN ('approved', 'overridden')
                AND final_category IS NOT NULL
                AND final_priority IS NOT NULL
                AND final_summary IS NOT NULL
                AND reviewer IS NOT NULL
                AND decided_at IS NOT NULL
            )
        )
);

CREATE INDEX ticket_reviews_ticket_id_created_at_idx
    ON public.ticket_reviews (ticket_id, created_at DESC);

CREATE TABLE public.ticket_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL,
    prediction_id UUID NOT NULL,
    review_id UUID,
    decision_source TEXT NOT NULL,
    category TEXT NOT NULL,
    priority TEXT NOT NULL,
    summary TEXT NOT NULL,
    decided_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ticket_decisions_ticket_id_fkey
        FOREIGN KEY (ticket_id) REFERENCES public.tickets (id) ON DELETE RESTRICT,
    CONSTRAINT ticket_decisions_prediction_id_fkey
        FOREIGN KEY (prediction_id) REFERENCES public.ticket_ai_predictions (id) ON DELETE RESTRICT,
    CONSTRAINT ticket_decisions_review_id_fkey
        FOREIGN KEY (review_id) REFERENCES public.ticket_reviews (id) ON DELETE RESTRICT,
    CONSTRAINT ticket_decisions_ticket_key UNIQUE (ticket_id),
    CONSTRAINT ticket_decisions_prediction_key UNIQUE (prediction_id),
    CONSTRAINT ticket_decisions_review_key UNIQUE (review_id),
    CONSTRAINT ticket_decisions_source_check
        CHECK (decision_source IN ('ai', 'human_approved', 'human_overridden')),
    CONSTRAINT ticket_decisions_category_check
        CHECK (category IN ('access', 'hardware', 'software', 'network', 'service_request', 'other')),
    CONSTRAINT ticket_decisions_priority_check
        CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT ticket_decisions_summary_check
        CHECK (char_length(btrim(summary)) >= 1 AND char_length(summary) <= 300),
    CONSTRAINT ticket_decisions_source_review_check
        CHECK (
            (decision_source = 'ai' AND review_id IS NULL)
            OR (decision_source IN ('human_approved', 'human_overridden') AND review_id IS NOT NULL)
        )
);

CREATE TABLE public.sla_policies (
    policy_version TEXT NOT NULL,
    priority TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT sla_policies_pkey PRIMARY KEY (policy_version, priority),
    CONSTRAINT sla_policies_version_check CHECK (char_length(btrim(policy_version)) >= 1),
    CONSTRAINT sla_policies_priority_check CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT sla_policies_duration_check CHECK (duration_minutes > 0),
    CONSTRAINT sla_policies_description_check CHECK (char_length(btrim(description)) >= 1)
);

INSERT INTO public.sla_policies (policy_version, priority, duration_minutes, description)
VALUES
    ('sla-demo-v1', 'critical', 60, 'Política interna demostrativa: 60 minutos corridos.'),
    ('sla-demo-v1', 'high', 240, 'Política interna demostrativa: 240 minutos corridos.'),
    ('sla-demo-v1', 'medium', 480, 'Política interna demostrativa: 480 minutos corridos.'),
    ('sla-demo-v1', 'low', 1440, 'Política interna demostrativa: 1440 minutos corridos.');

CREATE TABLE public.ticket_sla (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL,
    decision_id UUID NOT NULL,
    policy_version TEXT NOT NULL,
    priority TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    due_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    resolved_at TIMESTAMPTZ,
    resolved_by TEXT,
    breached_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ticket_sla_ticket_id_fkey
        FOREIGN KEY (ticket_id) REFERENCES public.tickets (id) ON DELETE RESTRICT,
    CONSTRAINT ticket_sla_decision_id_fkey
        FOREIGN KEY (decision_id) REFERENCES public.ticket_decisions (id) ON DELETE RESTRICT,
    CONSTRAINT ticket_sla_policy_fkey
        FOREIGN KEY (policy_version, priority) REFERENCES public.sla_policies (policy_version, priority) ON DELETE RESTRICT,
    CONSTRAINT ticket_sla_ticket_key UNIQUE (ticket_id),
    CONSTRAINT ticket_sla_decision_key UNIQUE (decision_id),
    CONSTRAINT ticket_sla_status_check CHECK (status IN ('active', 'met', 'breached')),
    CONSTRAINT ticket_sla_time_check CHECK (due_at > started_at),
    CONSTRAINT ticket_sla_resolved_by_check
        CHECK (resolved_by IS NULL OR (char_length(btrim(resolved_by)) >= 1 AND char_length(resolved_by) <= 100)),
    CONSTRAINT ticket_sla_outcome_check
        CHECK (
            (status = 'active' AND resolved_at IS NULL AND resolved_by IS NULL AND breached_at IS NULL)
            OR (status = 'met' AND resolved_at IS NOT NULL AND resolved_by IS NOT NULL AND breached_at IS NULL)
            OR (status = 'breached' AND breached_at IS NOT NULL)
        )
);

CREATE INDEX ticket_sla_due_active_idx
    ON public.ticket_sla (due_at)
    WHERE status = 'active' AND resolved_at IS NULL;

CREATE TABLE public.sla_breaches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_sla_id UUID NOT NULL,
    ticket_id UUID NOT NULL,
    decision_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    error_code TEXT,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    escalated_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT sla_breaches_ticket_sla_id_fkey
        FOREIGN KEY (ticket_sla_id) REFERENCES public.ticket_sla (id) ON DELETE RESTRICT,
    CONSTRAINT sla_breaches_ticket_id_fkey
        FOREIGN KEY (ticket_id) REFERENCES public.tickets (id) ON DELETE RESTRICT,
    CONSTRAINT sla_breaches_decision_id_fkey
        FOREIGN KEY (decision_id) REFERENCES public.ticket_decisions (id) ON DELETE RESTRICT,
    CONSTRAINT sla_breaches_ticket_sla_key UNIQUE (ticket_sla_id),
    CONSTRAINT sla_breaches_ticket_key UNIQUE (ticket_id),
    CONSTRAINT sla_breaches_status_check CHECK (status IN ('pending', 'escalated', 'failed')),
    CONSTRAINT sla_breaches_error_code_check
        CHECK (error_code IS NULL OR error_code IN ('TELEGRAM_SEND_FAILED', 'DELIVERY_STATE_UNKNOWN')),
    CONSTRAINT sla_breaches_outcome_check
        CHECK (
            (status = 'pending' AND error_code IS NULL AND escalated_at IS NULL)
            OR (status = 'escalated' AND error_code IS NULL AND escalated_at IS NOT NULL)
            OR (status = 'failed' AND error_code IS NOT NULL AND escalated_at IS NULL)
        )
);

ALTER TABLE public.automation_events
    ADD COLUMN decision_id UUID,
    ADD COLUMN review_id UUID,
    ADD COLUMN sla_breach_id UUID;

ALTER TABLE public.automation_events
    ADD CONSTRAINT automation_events_decision_id_fkey
        FOREIGN KEY (decision_id) REFERENCES public.ticket_decisions (id) ON DELETE RESTRICT,
    ADD CONSTRAINT automation_events_review_id_fkey
        FOREIGN KEY (review_id) REFERENCES public.ticket_reviews (id) ON DELETE RESTRICT,
    ADD CONSTRAINT automation_events_sla_breach_id_fkey
        FOREIGN KEY (sla_breach_id) REFERENCES public.sla_breaches (id) ON DELETE RESTRICT;

ALTER TABLE public.automation_events
    DROP CONSTRAINT automation_events_rule_code_check,
    DROP CONSTRAINT automation_events_event_type_check,
    DROP CONSTRAINT automation_events_error_code_check,
    DROP CONSTRAINT automation_events_outcome_check;

ALTER TABLE public.automation_events
    ADD CONSTRAINT automation_events_rule_code_check
        CHECK (rule_code IN ('notify_high_or_critical_v1', 'escalate_sla_breach_v1')),
    ADD CONSTRAINT automation_events_event_type_check
        CHECK (event_type IN ('telegram_notification', 'sla_escalation')),
    ADD CONSTRAINT automation_events_error_code_check
        CHECK (error_code IS NULL OR error_code IN ('TELEGRAM_SEND_FAILED', 'DELIVERY_STATE_UNKNOWN')),
    ADD CONSTRAINT automation_events_outcome_check
        CHECK (
            (status IN ('pending', 'succeeded', 'skipped') AND error_code IS NULL)
            OR (status = 'failed' AND error_code IS NOT NULL)
        ),
    ADD CONSTRAINT automation_events_phase6_links_check
        CHECK (
            (decision_id IS NULL AND review_id IS NULL AND sla_breach_id IS NULL)
            OR (
                decision_id IS NOT NULL
                AND (
                    (rule_code = 'notify_high_or_critical_v1' AND sla_breach_id IS NULL)
                    OR (rule_code = 'escalate_sla_breach_v1' AND sla_breach_id IS NOT NULL)
                )
            )
        );

CREATE INDEX automation_events_decision_id_created_at_idx
    ON public.automation_events (decision_id, created_at DESC)
    WHERE decision_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.initialize_ticket_outcome(p_prediction_id UUID)
RETURNS TABLE (
    routing_state TEXT,
    ticket_id UUID,
    prediction_id UUID,
    review_id UUID,
    decision_id UUID,
    category TEXT,
    priority TEXT,
    summary TEXT,
    sla_id UUID,
    sla_due_at TIMESTAMPTZ,
    automation_event_id UUID,
    automation_event_status TEXT,
    action_created BOOLEAN,
    requester_area TEXT,
    title TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_prediction public.ticket_ai_predictions%ROWTYPE;
    v_ticket public.tickets%ROWTYPE;
    v_review_id UUID;
    v_decision_id UUID;
    v_sla_id UUID;
    v_due_at TIMESTAMPTZ;
    v_event_id UUID;
    v_event_status TEXT;
    v_event_created BOOLEAN := FALSE;
    v_duration_minutes INTEGER;
BEGIN
    SELECT p.* INTO v_prediction
    FROM public.ticket_ai_predictions p
    WHERE p.id = p_prediction_id
    FOR UPDATE;

    IF NOT FOUND OR v_prediction.status <> 'succeeded' THEN
        RAISE EXCEPTION 'PHASE6_SUCCEEDED_PREDICTION_REQUIRED';
    END IF;

    SELECT t.* INTO STRICT v_ticket
    FROM public.tickets t
    WHERE t.id = v_prediction.ticket_id
    FOR UPDATE;

    IF v_prediction.review_required THEN
        INSERT INTO public.ticket_reviews (ticket_id, prediction_id)
        VALUES (v_ticket.id, v_prediction.id)
        ON CONFLICT ON CONSTRAINT ticket_reviews_prediction_key DO NOTHING
        RETURNING id INTO v_review_id;

        IF v_review_id IS NULL THEN
            SELECT r.id INTO STRICT v_review_id
            FROM public.ticket_reviews r
            WHERE r.prediction_id = v_prediction.id;
        END IF;

        RETURN QUERY SELECT
            'review_pending'::TEXT,
            v_ticket.id,
            v_prediction.id,
            v_review_id,
            NULL::UUID,
            v_prediction.category,
            v_prediction.priority,
            v_prediction.summary,
            NULL::UUID,
            NULL::TIMESTAMPTZ,
            NULL::UUID,
            NULL::TEXT,
            FALSE,
            v_ticket.requester_area,
            v_ticket.title;
        RETURN;
    END IF;

    INSERT INTO public.ticket_decisions (
        ticket_id, prediction_id, review_id, decision_source, category, priority, summary
    )
    VALUES (
        v_ticket.id, v_prediction.id, NULL, 'ai', v_prediction.category, v_prediction.priority, v_prediction.summary
    )
    ON CONFLICT ON CONSTRAINT ticket_decisions_prediction_key DO NOTHING
    RETURNING id INTO v_decision_id;

    IF v_decision_id IS NULL THEN
        SELECT d.id INTO STRICT v_decision_id
        FROM public.ticket_decisions d
        WHERE d.prediction_id = v_prediction.id;
    END IF;

    SELECT sp.duration_minutes INTO STRICT v_duration_minutes
    FROM public.sla_policies sp
    WHERE sp.policy_version = 'sla-demo-v1'
      AND sp.priority = v_prediction.priority;

    INSERT INTO public.ticket_sla (
        ticket_id, decision_id, policy_version, priority, started_at, due_at
    )
    VALUES (
        v_ticket.id,
        v_decision_id,
        'sla-demo-v1',
        v_prediction.priority,
        v_ticket.created_at,
        v_ticket.created_at + make_interval(mins => v_duration_minutes)
    )
    ON CONFLICT ON CONSTRAINT ticket_sla_ticket_key DO NOTHING
    RETURNING id, due_at INTO v_sla_id, v_due_at;

    IF v_sla_id IS NULL THEN
        SELECT s.id, s.due_at INTO STRICT v_sla_id, v_due_at
        FROM public.ticket_sla s
        WHERE s.ticket_id = v_ticket.id;
    END IF;

    UPDATE public.tickets
    SET status = 'open', updated_at = CURRENT_TIMESTAMP
    WHERE id = v_ticket.id AND status = 'processing';

    INSERT INTO public.automation_events (
        ticket_id, prediction_id, decision_id, review_id, rule_code, event_type, status
    )
    VALUES (
        v_ticket.id,
        v_prediction.id,
        v_decision_id,
        NULL,
        'notify_high_or_critical_v1',
        'telegram_notification',
        CASE WHEN v_prediction.priority IN ('high', 'critical') THEN 'pending' ELSE 'skipped' END
    )
    ON CONFLICT ON CONSTRAINT automation_events_prediction_rule_event_key DO NOTHING
    RETURNING id, status INTO v_event_id, v_event_status;

    IF v_event_id IS NOT NULL THEN
        v_event_created := TRUE;
    ELSE
        SELECT e.id, e.status INTO STRICT v_event_id, v_event_status
        FROM public.automation_events e
        WHERE e.prediction_id = v_prediction.id
          AND e.rule_code = 'notify_high_or_critical_v1'
          AND e.event_type = 'telegram_notification';
    END IF;

    RETURN QUERY SELECT
        'ready'::TEXT,
        v_ticket.id,
        v_prediction.id,
        NULL::UUID,
        v_decision_id,
        v_prediction.category,
        v_prediction.priority,
        v_prediction.summary,
        v_sla_id,
        v_due_at,
        v_event_id,
        v_event_status,
        v_event_created,
        v_ticket.requester_area,
        v_ticket.title;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_ticket_review(
    p_review_id UUID,
    p_action TEXT,
    p_category TEXT,
    p_priority TEXT,
    p_summary TEXT,
    p_reviewer TEXT,
    p_comment TEXT DEFAULT NULL
)
RETURNS TABLE (
    processed BOOLEAN,
    review_status TEXT,
    ticket_id UUID,
    prediction_id UUID,
    review_id UUID,
    decision_id UUID,
    category TEXT,
    priority TEXT,
    summary TEXT,
    sla_id UUID,
    sla_due_at TIMESTAMPTZ,
    automation_event_id UUID,
    automation_event_status TEXT,
    action_created BOOLEAN,
    requester_area TEXT,
    title TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_review public.ticket_reviews%ROWTYPE;
    v_prediction public.ticket_ai_predictions%ROWTYPE;
    v_ticket public.tickets%ROWTYPE;
    v_status TEXT;
    v_category TEXT;
    v_priority TEXT;
    v_summary TEXT;
    v_decision_id UUID;
    v_sla_id UUID;
    v_due_at TIMESTAMPTZ;
    v_event_id UUID;
    v_event_status TEXT;
    v_duration_minutes INTEGER;
BEGIN
    SELECT r.* INTO v_review
    FROM public.ticket_reviews r
    WHERE r.id = p_review_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'REVIEW_NOT_FOUND';
    END IF;

    SELECT p.* INTO STRICT v_prediction
    FROM public.ticket_ai_predictions p
    WHERE p.id = v_review.prediction_id;

    SELECT t.* INTO STRICT v_ticket
    FROM public.tickets t
    WHERE t.id = v_review.ticket_id
    FOR UPDATE;

    IF v_review.status <> 'pending' THEN
        SELECT d.id, d.category, d.priority, d.summary
        INTO v_decision_id, v_category, v_priority, v_summary
        FROM public.ticket_decisions d
        WHERE d.review_id = v_review.id;

        SELECT s.id, s.due_at INTO v_sla_id, v_due_at
        FROM public.ticket_sla s
        WHERE s.decision_id = v_decision_id;

        SELECT e.id, e.status INTO v_event_id, v_event_status
        FROM public.automation_events e
        WHERE e.prediction_id = v_prediction.id
          AND e.rule_code = 'notify_high_or_critical_v1'
          AND e.event_type = 'telegram_notification';

        RETURN QUERY SELECT
            FALSE,
            v_review.status,
            v_ticket.id,
            v_prediction.id,
            v_review.id,
            v_decision_id,
            v_category,
            v_priority,
            v_summary,
            v_sla_id,
            v_due_at,
            v_event_id,
            v_event_status,
            FALSE,
            v_ticket.requester_area,
            v_ticket.title;
        RETURN;
    END IF;

    IF p_reviewer IS NULL OR char_length(btrim(p_reviewer)) < 1 THEN
        RAISE EXCEPTION 'REVIEWER_REQUIRED';
    END IF;

    IF p_action = 'approve' THEN
        v_status := 'approved';
        v_category := v_prediction.category;
        v_priority := v_prediction.priority;
        v_summary := v_prediction.summary;
    ELSIF p_action = 'override' THEN
        IF p_category NOT IN ('access', 'hardware', 'software', 'network', 'service_request', 'other')
           OR p_priority NOT IN ('low', 'medium', 'high', 'critical') THEN
            RAISE EXCEPTION 'REVIEW_OVERRIDE_INVALID';
        END IF;
        v_status := 'overridden';
        v_category := p_category;
        v_priority := p_priority;
        v_summary := COALESCE(NULLIF(btrim(p_summary), ''), v_prediction.summary);
    ELSE
        RAISE EXCEPTION 'REVIEW_ACTION_INVALID';
    END IF;

    UPDATE public.ticket_reviews
    SET
        status = v_status,
        final_category = v_category,
        final_priority = v_priority,
        final_summary = v_summary,
        reviewer = btrim(p_reviewer),
        comment = NULLIF(btrim(p_comment), ''),
        decided_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_review.id;

    INSERT INTO public.ticket_decisions (
        ticket_id, prediction_id, review_id, decision_source, category, priority, summary
    )
    VALUES (
        v_ticket.id,
        v_prediction.id,
        v_review.id,
        CASE WHEN v_status = 'approved' THEN 'human_approved' ELSE 'human_overridden' END,
        v_category,
        v_priority,
        v_summary
    )
    RETURNING id INTO v_decision_id;

    SELECT sp.duration_minutes INTO STRICT v_duration_minutes
    FROM public.sla_policies sp
    WHERE sp.policy_version = 'sla-demo-v1'
      AND sp.priority = v_priority;

    INSERT INTO public.ticket_sla (
        ticket_id, decision_id, policy_version, priority, started_at, due_at
    )
    VALUES (
        v_ticket.id,
        v_decision_id,
        'sla-demo-v1',
        v_priority,
        v_ticket.created_at,
        v_ticket.created_at + make_interval(mins => v_duration_minutes)
    )
    RETURNING id, due_at INTO v_sla_id, v_due_at;

    UPDATE public.tickets
    SET status = 'open', updated_at = CURRENT_TIMESTAMP
    WHERE id = v_ticket.id AND status = 'processing';

    INSERT INTO public.automation_events (
        ticket_id, prediction_id, decision_id, review_id, rule_code, event_type, status
    )
    VALUES (
        v_ticket.id,
        v_prediction.id,
        v_decision_id,
        v_review.id,
        'notify_high_or_critical_v1',
        'telegram_notification',
        CASE WHEN v_priority IN ('high', 'critical') THEN 'pending' ELSE 'skipped' END
    )
    RETURNING id, status INTO v_event_id, v_event_status;

    RETURN QUERY SELECT
        TRUE,
        v_status,
        v_ticket.id,
        v_prediction.id,
        v_review.id,
        v_decision_id,
        v_category,
        v_priority,
        v_summary,
        v_sla_id,
        v_due_at,
        v_event_id,
        v_event_status,
        TRUE,
        v_ticket.requester_area,
        v_ticket.title;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_ticket(
    p_ticket_id UUID,
    p_resolved_by TEXT
)
RETURNS TABLE (
    changed BOOLEAN,
    ticket_id UUID,
    ticket_status TEXT,
    sla_status TEXT,
    resolved_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sla public.ticket_sla%ROWTYPE;
    v_resolved_at TIMESTAMPTZ;
    v_sla_status TEXT;
BEGIN
    IF p_resolved_by IS NULL OR char_length(btrim(p_resolved_by)) < 1 THEN
        RAISE EXCEPTION 'RESOLVED_BY_REQUIRED';
    END IF;

    SELECT s.* INTO v_sla
    FROM public.ticket_sla s
    WHERE s.ticket_id = p_ticket_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TICKET_SLA_NOT_FOUND';
    END IF;

    IF v_sla.resolved_at IS NOT NULL THEN
        RETURN QUERY SELECT FALSE, p_ticket_id, 'closed'::TEXT, v_sla.status, v_sla.resolved_at;
        RETURN;
    END IF;

    v_resolved_at := CURRENT_TIMESTAMP;
    v_sla_status := CASE
        WHEN v_sla.status = 'breached' THEN 'breached'
        WHEN v_resolved_at <= v_sla.due_at THEN 'met'
        ELSE 'breached'
    END;

    UPDATE public.ticket_sla
    SET
        status = v_sla_status,
        resolved_at = v_resolved_at,
        resolved_by = btrim(p_resolved_by),
        breached_at = CASE
            WHEN v_sla_status = 'breached' THEN COALESCE(breached_at, v_resolved_at)
            ELSE NULL
        END,
        updated_at = v_resolved_at
    WHERE id = v_sla.id;

    UPDATE public.tickets
    SET status = 'closed', updated_at = v_resolved_at
    WHERE id = p_ticket_id;

    RETURN QUERY SELECT TRUE, p_ticket_id, 'closed'::TEXT, v_sla_status, v_resolved_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_due_sla_escalations()
RETURNS TABLE (
    ticket_id UUID,
    prediction_id UUID,
    decision_id UUID,
    sla_id UUID,
    breach_id UUID,
    automation_event_id UUID,
    category TEXT,
    priority TEXT,
    summary TEXT,
    requester_area TEXT,
    title TEXT,
    due_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row RECORD;
    v_breach_id UUID;
    v_event_id UUID;
BEGIN
    FOR v_row IN
        SELECT
            s.id AS sla_id,
            s.ticket_id,
            s.decision_id,
            s.due_at,
            d.prediction_id,
            d.category,
            d.priority,
            d.summary,
            t.requester_area,
            t.title
        FROM public.ticket_sla s
        JOIN public.ticket_decisions d ON d.id = s.decision_id
        JOIN public.tickets t ON t.id = s.ticket_id
        WHERE s.status = 'active'
          AND s.resolved_at IS NULL
          AND s.due_at <= CURRENT_TIMESTAMP
        ORDER BY s.due_at
        FOR UPDATE OF s SKIP LOCKED
    LOOP
        UPDATE public.ticket_sla
        SET status = 'breached', breached_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE id = v_row.sla_id;

        INSERT INTO public.sla_breaches (ticket_sla_id, ticket_id, decision_id)
        VALUES (v_row.sla_id, v_row.ticket_id, v_row.decision_id)
        ON CONFLICT ON CONSTRAINT sla_breaches_ticket_sla_key DO NOTHING
        RETURNING id INTO v_breach_id;

        IF v_breach_id IS NULL THEN
            CONTINUE;
        END IF;

        INSERT INTO public.automation_events (
            ticket_id,
            prediction_id,
            decision_id,
            sla_breach_id,
            rule_code,
            event_type,
            status
        )
        VALUES (
            v_row.ticket_id,
            v_row.prediction_id,
            v_row.decision_id,
            v_breach_id,
            'escalate_sla_breach_v1',
            'sla_escalation',
            'pending'
        )
        RETURNING id INTO v_event_id;

        RETURN QUERY SELECT
            v_row.ticket_id,
            v_row.prediction_id,
            v_row.decision_id,
            v_row.sla_id,
            v_breach_id,
            v_event_id,
            v_row.category,
            v_row.priority,
            v_row.summary,
            v_row.requester_area,
            v_row.title,
            v_row.due_at;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.recover_stale_phase6_states()
RETURNS TABLE (
    predictions_failed INTEGER,
    automation_events_failed INTEGER,
    breaches_failed INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_predictions INTEGER;
    v_events INTEGER;
    v_breaches INTEGER;
BEGIN
    UPDATE public.ticket_ai_predictions
    SET
        status = 'failed',
        error_code = 'AI_EXECUTION_INTERRUPTED',
        failure_kind = 'internal',
        updated_at = CURRENT_TIMESTAMP
    WHERE schema_version = 'ticket-classification-schema-v2'
      AND status = 'pending'
      AND created_at < CURRENT_TIMESTAMP - INTERVAL '15 minutes';
    GET DIAGNOSTICS v_predictions = ROW_COUNT;

    WITH stale AS (
        UPDATE public.automation_events
        SET
            status = 'failed',
            error_code = 'DELIVERY_STATE_UNKNOWN',
            updated_at = CURRENT_TIMESTAMP
        WHERE status = 'pending'
          AND created_at < CURRENT_TIMESTAMP - INTERVAL '15 minutes'
          AND decision_id IS NOT NULL
        RETURNING sla_breach_id
    )
    SELECT count(*)::INTEGER INTO v_events FROM stale;

    UPDATE public.sla_breaches b
    SET
        status = 'failed',
        error_code = 'DELIVERY_STATE_UNKNOWN',
        updated_at = CURRENT_TIMESTAMP
    WHERE b.status = 'pending'
      AND EXISTS (
          SELECT 1
          FROM public.automation_events e
          WHERE e.sla_breach_id = b.id
            AND e.status = 'failed'
            AND e.error_code = 'DELIVERY_STATE_UNKNOWN'
      );
    GET DIAGNOSTICS v_breaches = ROW_COUNT;

    RETURN QUERY SELECT v_predictions, v_events, v_breaches;
END;
$$;

COMMIT;
