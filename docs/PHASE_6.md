# SmartDesk AI — Phase 6: Reliability, HITL y SLA

## Alcance y decisiones

Phase 6 extiende V1 sin sustituir sus entidades ni introducir servicios nuevos.
PostgreSQL conserva la autoridad transaccional sobre estados e idempotencia y
n8n continúa orquestando las integraciones. La predicción de IA y la decisión
operacional final son registros separados.

```text
ticket
  → prediction v2
      ├─ review_required=false → final decision → SLA → business action
      └─ review_required=true  → pending review
                                  → approve/override
                                  → final decision → SLA → business action

schedule/5 min → stale-state recovery → due SLA claim → one escalation event
```

No se incorporan Redis, colas, microservicios, frontend ni dependencias de
runtime adicionales.

## Contrato de IA v2

Los archivos `prompts/ticket-classification/v2.md` y `schema-v2.json` añaden:

- `confidence`: señal operacional entre 0 y 1; no es probabilidad calibrada;
- `review_required`: `true` cuando `confidence < 0.75`;
- `review_reason`: razón breve obligatoria solo si se requiere revisión.

El threshold `0.75` es una política provisional de routing. Phase 7 deberá
medir su comportamiento con un dataset; Phase 6 no afirma accuracy ni
calibración.

La fila de `ticket_ai_predictions` conserva siempre la salida original. Las
decisiones humanas se escriben en `ticket_reviews` y el resultado usado por el
negocio en `ticket_decisions`.

## Reliability

La llamada a OpenAI admite tres intentos totales:

| Intento | Espera previa | Elegibilidad |
| --- | ---: | --- |
| 1 | 0 s | Siempre. |
| 2 | 2 s | Solo timeout/error de red o HTTP 408, 425, 429, 500, 502, 503 o 504. |
| 3 | 4 s | Solo si el segundo resultado también es transitorio. |

Errores HTTP permanentes, contrato inválido y validación inválida no se
reintentan. `attempt_count`, `failure_kind`, `error_code` y
`last_attempt_at` dejan evidencia terminal.

Telegram no tiene retry automático. Primero se crea un `automation_event`
único; solo el workflow que creó ese evento intenta el envío. Esto evita que
SmartDesk duplique deliberadamente acciones. Como ninguna API externa ofrece
una transacción atómica con PostgreSQL, no se afirma exactamente-una-vez fuera
del sistema. Si un proceso se interrumpe después del envío pero antes del
update terminal, el evento queda pendiente y el recovery lo marca
`DELIVERY_STATE_UNKNOWN` sin reenviarlo automáticamente.

El scheduler marca como fallidas las predictions v2 y acciones Phase 6 que
permanezcan `pending` más de 15 minutos. No elimina tickets ni resultados ya
válidos.

## HITL

Una prediction con `review_required=true` crea una sola revisión `pending` y
no crea decisión, SLA ni acción empresarial. El intake responde HTTP 202 con
el `review.id`.

La operación administrativa mínima es:

```text
POST /webhook/admin/reviews/decide
X-SmartDesk-Admin-Token: <secret externo a Git>
```

Approve requiere `review_id`, `action=approve` y `reviewer`. Override requiere
además `category` y `priority`; `summary` es opcional. Una segunda llamada para
la misma review devuelve el resultado existente con `idempotent_replay=true`
y no crea ni ejecuta otra acción.

Los endpoints administrativos no atraviesan Caddy. Solo responden en el
listener `127.0.0.1:5678` de n8n y requieren, adicionalmente, el token de
administración. Su uso se realiza desde la VM o mediante túnel SSH.

## SLA

`sla-demo-v1` es una política interna demostrativa de minutos corridos:

| Prioridad final | Duración |
| --- | ---: |
| critical | 60 min |
| high | 240 min |
| medium | 480 min |
| low | 1440 min |

No representa un estándar del sector. Cada SLA usa la prioridad de la decisión
final, pero `started_at` siempre es `tickets.created_at`. Si HITL cambia la
prioridad, el deadline se calcula desde ese origen con la nueva duración.

La resolución controlada usa:

```text
POST /webhook/admin/tickets/resolve
X-SmartDesk-Admin-Token: <secret externo a Git>
```

El scheduler se ejecuta cada cinco minutos. Reclama únicamente SLAs `active`,
sin resolución y vencidos; crea un `sla_breach` y un evento de escalamiento en
la misma transacción. Las restricciones únicas impiden otro breach o evento
para el mismo caso lógico.

## Modelo de datos

La migración `004_phase6_reliability_hitl_sla.sql`:

- amplía `ticket_ai_predictions` con señal HITL y trazabilidad de intentos;
- crea `ticket_reviews`;
- crea `ticket_decisions`;
- crea `sla_policies` y carga `sla-demo-v1`;
- crea `ticket_sla` y `sla_breaches`;
- amplía `automation_events` con relaciones a decision, review y breach;
- crea funciones transaccionales e idempotentes para routing, review,
  resolución, breach y recovery.

`db/apply-migrations.sh` aplica las migraciones en orden durante un bootstrap
de PostgreSQL desde cero. En una base existente, la migración nueva se aplica
una sola vez de forma explícita antes de importar los workflows.
