BEGIN;

DO $$
DECLARE
    v_ticket_id UUID;
    v_prediction_id UUID;
    v_review_id UUID;
    v_created_at TIMESTAMPTZ;
    v_row RECORD;
    v_original_priority TEXT;
    v_count INTEGER;
BEGIN
    INSERT INTO public.tickets (requester_email, requester_area, title, description)
    VALUES ('phase6-direct@example.com', 'TI', 'Caso directo de prueba', 'Solicitud sintética para validar la ruta directa de Phase 6.')
    RETURNING id, created_at INTO v_ticket_id, v_created_at;

    INSERT INTO public.ticket_ai_predictions (
        ticket_id, status, category, priority, summary, provider, model,
        prompt_version, schema_version, confidence, review_required,
        review_reason, attempt_count, last_attempt_at
    )
    VALUES (
        v_ticket_id, 'succeeded', 'software', 'low', 'Caso directo sintético.',
        'test', 'test-model', 'ticket-classification-v2',
        'ticket-classification-schema-v2', 0.9000, FALSE, NULL, 1, CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_prediction_id;

    SELECT * INTO STRICT v_row FROM public.initialize_ticket_outcome(v_prediction_id);
    IF v_row.routing_state <> 'ready'
       OR v_row.automation_event_status <> 'skipped'
       OR NOT v_row.action_created THEN
        RAISE EXCEPTION 'DIRECT_ROUTE_FAILED';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.ticket_sla s
        WHERE s.ticket_id = v_ticket_id
          AND s.started_at = v_created_at
          AND s.due_at = v_created_at + INTERVAL '1440 minutes'
          AND s.priority = 'low'
    ) THEN
        RAISE EXCEPTION 'DIRECT_SLA_FAILED';
    END IF;

    SELECT * INTO STRICT v_row FROM public.initialize_ticket_outcome(v_prediction_id);
    IF v_row.action_created THEN
        RAISE EXCEPTION 'DIRECT_IDEMPOTENCY_FAILED';
    END IF;

    SELECT count(*) INTO v_count
    FROM public.automation_events
    WHERE prediction_id = v_prediction_id;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'DIRECT_EVENT_DUPLICATED';
    END IF;

    SELECT * INTO STRICT v_row FROM public.resolve_ticket(v_ticket_id, 'gate6-test');
    IF NOT v_row.changed OR v_row.ticket_status <> 'closed' OR v_row.sla_status <> 'met' THEN
        RAISE EXCEPTION 'RESOLUTION_FAILED';
    END IF;

    SELECT * INTO STRICT v_row FROM public.resolve_ticket(v_ticket_id, 'gate6-test');
    IF v_row.changed THEN
        RAISE EXCEPTION 'RESOLUTION_IDEMPOTENCY_FAILED';
    END IF;

    INSERT INTO public.tickets (requester_email, requester_area, title, description)
    VALUES ('phase6-approve@example.com', 'Finanzas', 'Caso approve de prueba', 'Solicitud sintética ambigua para validar aprobación humana.')
    RETURNING id INTO v_ticket_id;

    INSERT INTO public.ticket_ai_predictions (
        ticket_id, status, category, priority, summary, provider, model,
        prompt_version, schema_version, confidence, review_required,
        review_reason, attempt_count, last_attempt_at
    )
    VALUES (
        v_ticket_id, 'succeeded', 'access', 'high', 'Caso para aprobación humana.',
        'test', 'test-model', 'ticket-classification-v2',
        'ticket-classification-schema-v2', 0.5000, TRUE,
        'Clasificación ambigua.', 1, CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_prediction_id;

    SELECT * INTO STRICT v_row FROM public.initialize_ticket_outcome(v_prediction_id);
    v_review_id := v_row.review_id;
    IF v_row.routing_state <> 'review_pending'
       OR v_review_id IS NULL
       OR v_row.decision_id IS NOT NULL THEN
        RAISE EXCEPTION 'REVIEW_PENDING_FAILED';
    END IF;

    PERFORM public.initialize_ticket_outcome(v_prediction_id);
    SELECT count(*) INTO v_count
    FROM public.ticket_reviews
    WHERE prediction_id = v_prediction_id;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'REVIEW_PENDING_DUPLICATED';
    END IF;

    SELECT * INTO STRICT v_row
    FROM public.decide_ticket_review(v_review_id, 'approve', NULL, NULL, NULL, 'gate6-reviewer', 'Aprobación sintética.');
    IF NOT v_row.processed
       OR v_row.review_status <> 'approved'
       OR v_row.automation_event_status <> 'pending'
       OR NOT v_row.action_created THEN
        RAISE EXCEPTION 'REVIEW_APPROVE_FAILED';
    END IF;

    SELECT priority INTO STRICT v_original_priority
    FROM public.ticket_ai_predictions
    WHERE id = v_prediction_id;
    IF v_original_priority <> 'high' THEN
        RAISE EXCEPTION 'AI_PREDICTION_NOT_PRESERVED_AFTER_APPROVE';
    END IF;

    SELECT * INTO STRICT v_row
    FROM public.decide_ticket_review(v_review_id, 'approve', NULL, NULL, NULL, 'gate6-reviewer', NULL);
    IF v_row.processed OR v_row.action_created THEN
        RAISE EXCEPTION 'REVIEW_APPROVE_IDEMPOTENCY_FAILED';
    END IF;

    INSERT INTO public.tickets (requester_email, requester_area, title, description)
    VALUES ('phase6-override@example.com', 'Operaciones', 'Caso override de prueba', 'Solicitud sintética para validar override humano y recálculo de SLA.')
    RETURNING id, created_at INTO v_ticket_id, v_created_at;

    INSERT INTO public.ticket_ai_predictions (
        ticket_id, status, category, priority, summary, provider, model,
        prompt_version, schema_version, confidence, review_required,
        review_reason, attempt_count, last_attempt_at
    )
    VALUES (
        v_ticket_id, 'succeeded', 'other', 'low', 'Predicción original preservada.',
        'test', 'test-model', 'ticket-classification-v2',
        'ticket-classification-schema-v2', 0.4000, TRUE,
        'Categoría y prioridad ambiguas.', 1, CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_prediction_id;

    SELECT review_id INTO STRICT v_review_id
    FROM public.initialize_ticket_outcome(v_prediction_id);

    SELECT * INTO STRICT v_row
    FROM public.decide_ticket_review(
        v_review_id,
        'override',
        'network',
        'critical',
        'Decisión final humana.',
        'gate6-reviewer',
        'Impacto confirmado.'
    );
    IF NOT v_row.processed OR v_row.review_status <> 'overridden' OR v_row.priority <> 'critical' THEN
        RAISE EXCEPTION 'REVIEW_OVERRIDE_FAILED';
    END IF;

    SELECT priority INTO STRICT v_original_priority
    FROM public.ticket_ai_predictions
    WHERE id = v_prediction_id;
    IF v_original_priority <> 'low' THEN
        RAISE EXCEPTION 'AI_PREDICTION_NOT_PRESERVED_AFTER_OVERRIDE';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.ticket_sla s
        WHERE s.ticket_id = v_ticket_id
          AND s.started_at = v_created_at
          AND s.due_at = v_created_at + INTERVAL '60 minutes'
          AND s.priority = 'critical'
    ) THEN
        RAISE EXCEPTION 'OVERRIDE_SLA_RECALCULATION_FAILED';
    END IF;

    INSERT INTO public.tickets (
        requester_email, requester_area, title, description, created_at, updated_at
    )
    VALUES (
        'phase6-breach@example.com', 'TI', 'Caso breach de prueba',
        'Solicitud sintética vencida para validar escalamiento idempotente.',
        CURRENT_TIMESTAMP - INTERVAL '2 hours', CURRENT_TIMESTAMP - INTERVAL '2 hours'
    )
    RETURNING id INTO v_ticket_id;

    INSERT INTO public.ticket_ai_predictions (
        ticket_id, status, category, priority, summary, provider, model,
        prompt_version, schema_version, confidence, review_required,
        review_reason, attempt_count, last_attempt_at
    )
    VALUES (
        v_ticket_id, 'succeeded', 'network', 'critical', 'Caso vencido sintético.',
        'test', 'test-model', 'ticket-classification-v2',
        'ticket-classification-schema-v2', 0.9500, FALSE, NULL, 1, CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_prediction_id;

    PERFORM public.initialize_ticket_outcome(v_prediction_id);
    SELECT count(*) INTO v_count FROM public.claim_due_sla_escalations();
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'BREACH_CLAIM_FAILED';
    END IF;

    SELECT count(*) INTO v_count FROM public.claim_due_sla_escalations();
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'BREACH_IDEMPOTENCY_FAILED';
    END IF;

    IF (SELECT count(*) FROM public.sla_breaches WHERE ticket_id = v_ticket_id) <> 1
       OR (SELECT count(*) FROM public.automation_events WHERE prediction_id = v_prediction_id AND rule_code = 'escalate_sla_breach_v1') <> 1 THEN
        RAISE EXCEPTION 'BREACH_EVIDENCE_FAILED';
    END IF;

    INSERT INTO public.tickets (
        requester_email, requester_area, title, description, created_at, updated_at
    )
    VALUES (
        'phase6-recovery@example.com', 'TI', 'Caso recovery de prueba',
        'Solicitud sintética para validar recuperación de estado pendiente.',
        CURRENT_TIMESTAMP - INTERVAL '20 minutes', CURRENT_TIMESTAMP - INTERVAL '20 minutes'
    )
    RETURNING id INTO v_ticket_id;

    INSERT INTO public.ticket_ai_predictions (
        ticket_id, status, provider, model, prompt_version, schema_version, created_at, updated_at
    )
    VALUES (
        v_ticket_id, 'pending', 'test', 'test-model', 'ticket-classification-v2',
        'ticket-classification-schema-v2', CURRENT_TIMESTAMP - INTERVAL '20 minutes',
        CURRENT_TIMESTAMP - INTERVAL '20 minutes'
    )
    RETURNING id INTO v_prediction_id;

    PERFORM public.recover_stale_phase6_states();
    IF NOT EXISTS (
        SELECT 1
        FROM public.ticket_ai_predictions
        WHERE id = v_prediction_id
          AND status = 'failed'
          AND error_code = 'AI_EXECUTION_INTERRUPTED'
          AND failure_kind = 'internal'
    ) THEN
        RAISE EXCEPTION 'STALE_RECOVERY_FAILED';
    END IF;
END;
$$;

SELECT 'phase6_contract_tests=PASS' AS result;

ROLLBACK;
