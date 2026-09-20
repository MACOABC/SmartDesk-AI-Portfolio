# SmartDesk AI — Reglas de automatización V1

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

La IA produce exclusivamente category, priority y summary. La decisión de
notificar pertenece al workflow y es una comparación determinista de la
prioridad validada. La IA no puede activar Telegram directamente.

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

## Errores y límites V1

Un fallo de Telegram no modifica el ticket, la predicción ni su clasificación.
El webhook continúa respondiendo HTTP 201 si ticket y predicción ya quedaron
persistidos correctamente.

No existen retries automáticos. Si Telegram acepta el mensaje pero PostgreSQL
falla al cambiar pending → succeeded, el evento puede permanecer pending. Ese
estado es evidencia de resultado indeterminado: V1 no reenvía el mensaje ni
intenta recuperación automática.

V1 no incorpora SLA, escalamiento, HITL, reglas por categoría, asignación,
colas, deduplicación de tickets, monitoreo avanzado ni recuperación de eventos
pendientes.

## Configuración del despliegue

El despliegue usa la credencial n8n `SmartDesk Telegram` y un
`TELEGRAM_CHAT_ID` suministrado desde el `.env` privado del servidor. La
entrega real y las transiciones a `succeeded` para HIGH y CRITICAL fueron
verificadas durante el cierre de Gate 4; la evidencia saneada se conserva en
`docs/testing/GATE_4.md`.
