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

## Configuración pendiente del despliegue

El despliegue inspeccionado no dispone todavía de una credencial Telegram ni
de un TELEGRAM_CHAT_ID real. El workflow, la persistencia y la rama de error
están desplegados, pero la entrega real y la transición a succeeded no pueden
aprobarse hasta crear la credencial, asignarla al nodo Send Telegram
Notification y configurar el destino fuera de Git.
