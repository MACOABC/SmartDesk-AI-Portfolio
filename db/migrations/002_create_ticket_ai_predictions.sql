BEGIN;

CREATE TABLE public.ticket_ai_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    category TEXT,
    priority TEXT,
    summary TEXT,
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    prompt_version TEXT NOT NULL,
    schema_version TEXT NOT NULL,
    error_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ticket_ai_predictions_ticket_id_fkey
        FOREIGN KEY (ticket_id)
        REFERENCES public.tickets (id)
        ON DELETE RESTRICT,
    CONSTRAINT ticket_ai_predictions_status_check
        CHECK (status IN ('pending', 'succeeded', 'failed')),
    CONSTRAINT ticket_ai_predictions_category_check
        CHECK (
            category IS NULL
            OR category IN (
                'access',
                'hardware',
                'software',
                'network',
                'service_request',
                'other'
            )
        ),
    CONSTRAINT ticket_ai_predictions_priority_check
        CHECK (
            priority IS NULL
            OR priority IN ('low', 'medium', 'high', 'critical')
        ),
    CONSTRAINT ticket_ai_predictions_summary_check
        CHECK (
            summary IS NULL
            OR (
                char_length(summary) <= 300
                AND char_length(btrim(summary)) >= 1
            )
        ),
    CONSTRAINT ticket_ai_predictions_provider_not_blank_check
        CHECK (char_length(btrim(provider)) >= 1),
    CONSTRAINT ticket_ai_predictions_model_not_blank_check
        CHECK (char_length(btrim(model)) >= 1),
    CONSTRAINT ticket_ai_predictions_prompt_version_not_blank_check
        CHECK (char_length(btrim(prompt_version)) >= 1),
    CONSTRAINT ticket_ai_predictions_schema_version_not_blank_check
        CHECK (char_length(btrim(schema_version)) >= 1),
    CONSTRAINT ticket_ai_predictions_error_code_not_blank_check
        CHECK (
            error_code IS NULL
            OR char_length(btrim(error_code)) >= 1
        ),
    CONSTRAINT ticket_ai_predictions_outcome_check
        CHECK (
            (
                status = 'pending'
                AND category IS NULL
                AND priority IS NULL
                AND summary IS NULL
                AND error_code IS NULL
            )
            OR (
                status = 'succeeded'
                AND category IS NOT NULL
                AND priority IS NOT NULL
                AND summary IS NOT NULL
                AND error_code IS NULL
            )
            OR (
                status = 'failed'
                AND category IS NULL
                AND priority IS NULL
                AND summary IS NULL
                AND error_code IS NOT NULL
                AND char_length(btrim(error_code)) >= 1
            )
        )
);

CREATE INDEX ticket_ai_predictions_ticket_id_created_at_idx
    ON public.ticket_ai_predictions (ticket_id, created_at DESC);

COMMIT;
