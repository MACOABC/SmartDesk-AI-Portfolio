BEGIN;

CREATE TABLE public.automation_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL,
    prediction_id UUID NOT NULL,
    rule_code TEXT NOT NULL,
    event_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    error_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT automation_events_ticket_id_fkey
        FOREIGN KEY (ticket_id)
        REFERENCES public.tickets (id)
        ON DELETE RESTRICT,
    CONSTRAINT automation_events_prediction_id_fkey
        FOREIGN KEY (prediction_id)
        REFERENCES public.ticket_ai_predictions (id)
        ON DELETE RESTRICT,
    CONSTRAINT automation_events_rule_code_check
        CHECK (rule_code = 'notify_high_or_critical_v1'),
    CONSTRAINT automation_events_event_type_check
        CHECK (event_type = 'telegram_notification'),
    CONSTRAINT automation_events_status_check
        CHECK (status IN ('pending', 'succeeded', 'failed', 'skipped')),
    CONSTRAINT automation_events_error_code_check
        CHECK (
            error_code IS NULL
            OR error_code = 'TELEGRAM_SEND_FAILED'
        ),
    CONSTRAINT automation_events_outcome_check
        CHECK (
            (
                status IN ('pending', 'succeeded', 'skipped')
                AND error_code IS NULL
            )
            OR (
                status = 'failed'
                AND error_code = 'TELEGRAM_SEND_FAILED'
            )
        ),
    CONSTRAINT automation_events_prediction_rule_event_key
        UNIQUE (prediction_id, rule_code, event_type)
);

CREATE INDEX automation_events_ticket_id_created_at_idx
    ON public.automation_events (ticket_id, created_at DESC);

COMMIT;
