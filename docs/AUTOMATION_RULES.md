# SmartDesk AI — Reglas de automatización y escalamiento

## Regla implementada

La regla **notify_high_or_critical_v1** se evalúa únicamente después de
persistir una predicción con estado **succeeded**.

| Estado de predicción | Prioridad | Resultado |
| --- | --- | --- |
| succeeded | critical | Crear evento pending e intentar Telegram. |
| succeeded | high | Crear evento pending e intentar Telegram. |
| succeeded | medium | Crear evento skipped; no ejecutar Telegram. |
| succeeded | low | Crear evento skipped; no ejecutar Telegram. |
| failed | cualquiera | No evaluar la regla, no crear evento y no ejecutar Telegram. |

La IA produce la clasificación y, desde Phase 6, la señal HITL. La decisión de
notificar pertenece al workflow y es una comparación determinista de la
prioridad final validada. La IA no puede activar Telegram directamente.

## Evento y lifecycle

Cada evaluación utiliza rule_code **notify_high_or_critical_v1** y event_type
**telegram_notification**.

automation_events admite exactamente pending, succeeded, failed y skipped. La
combinación (prediction_id, rule_code, event_type) es única. Los inserts usan
ON CONFLICT DO NOTHING, por lo que una ejecución repetida no vuelve a producir
el side effect.

    LOW / MEDIUM  → skipped
    HIGH / CRITICAL
      → pending
      → Telegram OK    → succeeded
      → Telegram error → failed / TELEGRAM_SEND_FAILED

Telegram solo es alcanzable después de que el insert pending devuelva
exactamente una fila. Si ese insert falla o encuentra el evento existente, el
workflow conserva la respuesta HTTP de ticket/predicción y no envía el
mensaje.

## Mensaje Telegram

El mensaje usa texto plano, sin modo Markdown o HTML, y normaliza caracteres
de control y espacios internos. Incluye únicamente:

- ticket_id;
- requester_area;
- title;
- category;
- priority;
- summary.

Quedan deliberadamente excluidos el email del solicitante, la descripción
completa, respuestas crudas del proveedor, prompt, schema, razonamiento,
credenciales, token, chat_id y metadatos internos.

El token se referencia mediante una credencial telegramApi administrada por
n8n. El destino se inyecta como TELEGRAM_CHAT_ID desde configuración externa;
el export contiene solo la expresión y .env.example solo un placeholder.
Como n8n 2 bloquea por defecto el acceso de las expresiones a variables de
entorno, Compose establece `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` para que la
expresión aprobada pueda resolver el destino. El valor continúa únicamente en
el `.env` privado y no forma parte del workflow ni del repositorio.

## Comportamiento de Phase 6

Un fallo de Telegram no modifica el ticket, la predicción, la review, la
decisión ni el SLA ya persistidos. La operación conserva su resultado interno
y registra `TELEGRAM_SEND_FAILED`.

Telegram no tiene retries automáticos. Si acepta el mensaje pero PostgreSQL
falla al cambiar `pending → succeeded`, el evento representa un resultado
indeterminado. El recovery de Phase 6 lo marca `DELIVERY_STATE_UNKNOWN` después
de 15 minutos y no lo reenvía a ciegas.

OpenAI sí admite hasta dos retries, exclusivamente para los errores transitorios
documentados en `docs/PHASE_6.md`. Los errores permanentes no se reintentan.

La regla `escalate_sla_breach_v1` se ejecuta cada cinco minutos sobre SLA
`active`, sin resolución y vencidos. La transacción crea exactamente un
`sla_breach` y un `automation_event` `sla_escalation`; solo el evento nuevo
puede intentar Telegram. Repetir el checker no crea otra escalación.

Phase 6 no incorpora reglas por categoría, asignación, colas, deduplicación de
tickets ni monitoreo avanzado.

## Configuración del despliegue

El despliegue usa la credencial n8n `SmartDesk Telegram` y un
`TELEGRAM_CHAT_ID` suministrado desde el `.env` privado del servidor. La
entrega real y las transiciones a `succeeded` para HIGH y CRITICAL fueron
verificadas durante el cierre de Gate 4; la evidencia saneada se conserva en
`docs/testing/GATE_4.md`. Phase 6 verificó además notificación post-review y
escalamiento SLA; su evidencia está en `docs/testing/GATE_6.md`.
