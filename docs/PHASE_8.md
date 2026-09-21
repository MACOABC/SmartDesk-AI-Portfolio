# SmartDesk AI — Phase 8: SQL Analytics + Power BI

## Estado

```text
Phase 8.1 = PASS
Phase 8.2 = PASS
Phase 8.3 = PASS
Phase 8.4 = PASS
Phase 8.5 = PASS
Phase 8.6 = PASS
Phase 8.7 = PASS
Gate 8 = PASS
Phase 8 = COMPLETE
Phase 9 = NOT STARTED
```

La auditoría 8.1 se ejecutó el 2026-09-20 contra el repositorio local y la
base PostgreSQL desplegada. No se creó el esquema `analytics`, no se aplicaron
migraciones y no se modificó el modelo transaccional.

`ticket_ai_predictions` permite físicamente varias filas para un mismo ticket
y no existe una FK, flag, secuencia ni restricción que seleccione una
prediction autoritativa para todos los tickets. El contrato analítico resuelve
este límite manteniendo predictions en su propio grain y exponiendo en el
lifecycle únicamente la prediction referenciada por una decisión final. No se
utilizará `MAX(created_at)`, la fila más reciente ni otra deduplicación por
conveniencia.

## Baseline verificado

| Comprobación | Resultado |
| --- | --- |
| `git status --short` inicial | limpio |
| `git rev-parse HEAD` | `812552f31ac7a65948a3ad4be135e12decda4d28` |
| `git rev-parse 'v1.0^{commit}'` | `fc42c911725aa589e3b36207d0be5b95b9f08063` |
| Servicios desplegados | PostgreSQL, n8n y Caddy healthy |
| PostgreSQL publicado en host | no; Compose muestra solo `5432/tcp` interno |
| Esquema `analytics` | inexistente al iniciar 8.1 |

El valor de `v1.0` queda registrado para la comprobación de cierre de Gate 8.

Se revisaron `AGENTS.md`, `STATUS.md`, `docs/PROJECT_CONTEXT.md`, `ROADMAP.md`,
`docs/PHASE_6.md`, `docs/PHASE_7.md`, `docs/testing/GATE_6.md`, las cuatro
migraciones existentes, los tres workflows vigentes y la documentación de
intake, automatización, HITL, decisiones, SLA y despliegue.

Discrepancia documental: el repositorio no contiene
`docs/testing/GATE_7.md`. El cierre de Gate 7 sí está registrado en
`docs/PHASE_7.md`, `STATUS.md` y `ROADMAP.md`. Esta auditoría no inventa el
archivo ausente.

## Mapa físico verificado

PostgreSQL desplegado contiene exactamente ocho tablas en `public`:

| Entidad física | Grain | PK | Relaciones y límites relevantes |
| --- | --- | --- | --- |
| `tickets` | 1 fila = 1 ticket | `id` | No contiene `resolved_at`. Estados permitidos: `processing`, `open`, `closed`. |
| `ticket_ai_predictions` | 1 fila = 1 ejecución/prediction persistida | `id` | FK `ticket_id → tickets.id`; no hay `UNIQUE(ticket_id)`. Estados: `pending`, `succeeded`, `failed`. |
| `ticket_reviews` | 1 fila = 1 revisión humana persistida | `id` | FK a ticket y prediction; `UNIQUE(prediction_id)`, pero no `UNIQUE(ticket_id)`. Estados: `pending`, `approved`, `overridden`. |
| `ticket_decisions` | 1 fila = 1 decisión operacional final | `id` | FK a ticket, prediction y review opcional; `UNIQUE(ticket_id)`, `UNIQUE(prediction_id)` y `UNIQUE(review_id)`. |
| `sla_policies` | 1 fila = 1 versión + prioridad | `(policy_version, priority)` | Cuatro filas de `sla-demo-v1`; minutos corridos. |
| `ticket_sla` | 1 fila = 1 SLA asignado | `id` | FK a ticket y decisión; `UNIQUE(ticket_id)` y `UNIQUE(decision_id)`. |
| `sla_breaches` | 1 fila = 1 breach persistido | `id` | FK a SLA, ticket y decisión; `UNIQUE(ticket_sla_id)` y `UNIQUE(ticket_id)`. |
| `automation_events` | 1 fila = 1 evaluación/acción automática persistida | `id` | FK obligatoria a ticket y prediction; FKs opcionales a decision, review y breach; unicidad por `(prediction_id, rule_code, event_type)`. |

### Tickets

Campos analíticamente utilizables: `id`, `requester_area`, `status`,
`created_at`, `updated_at`. `updated_at` es una marca genérica de última
actualización y no representa resolución. La resolución real se persiste en
`ticket_sla.resolved_at`; la función `resolve_ticket` escribe ese timestamp y
cambia el ticket a `closed` en la misma operación.

Campos excluidos de analytics por PII o texto libre innecesario:
`requester_email`, `title`, `description`.

### AI predictions

Campos disponibles: `id`, `ticket_id`, `status`, `category`, `priority`,
`provider`, `model`, `prompt_version`, `schema_version`, `error_code`,
`created_at`, `updated_at`, `confidence`, `review_required`, `attempt_count`,
`last_attempt_at` y `failure_kind`.

`summary` y `review_reason` quedan excluidos por ser texto libre no necesario
para BI. Para schema v1, `confidence`, `review_required`, `last_attempt_at` y
`failure_kind` pueden ser NULL y `attempt_count` permanece en cero. Para
schema v2 succeeded, confidence está entre 0 y 1, `review_required` refleja el
routing productivo y `attempt_count` está entre 1 y 3. Confidence significa
**operational model confidence signal, not calibrated probability**.

El workflow actual inserta una prediction por ticket y actualiza esa misma
fila durante los retries. Esto explica la cardinalidad observada, pero la base
no impide que otro proceso inserte más de una prediction para el mismo ticket.

### HITL

`ticket_reviews` es la evidencia operacional de intervención humana. La fila
referencia exactamente el ticket y la prediction revisada. `created_at`
registra la creación de la revisión; `decided_at` registra la decisión humana.
`final_category` y `final_priority` contienen el resultado humano cuando el
estado es `approved` u `overridden`.

No se expondrán `final_summary`, `reviewer` ni `comment` en analytics. La
revisión ocurrida no se inferirá de un threshold de confidence.

Puede existir como máximo una review por prediction, pero el esquema permite
más de una review por ticket si ese ticket tiene varias predictions.

### Decisión final

`ticket_decisions` es la fuente autoritativa de la clasificación operacional
final. `category` y `priority` son los valores finales; `decision_source`
permite `ai`, `human_approved` o `human_overridden`; `prediction_id` identifica
la prediction concreta y `review_id` la revisión humana cuando aplica.

`UNIQUE(ticket_id)` garantiza como máximo una decisión final por ticket. El
campo `summary` queda excluido de analytics por ser texto libre.

### SLA y resolución

`ticket_sla` es la asignación autoritativa. Usa la prioridad de la decisión
final, guarda `policy_version`, `started_at`, `due_at`, `status`,
`resolved_at`, `breached_at`, `created_at` y `updated_at`. La restricción
`UNIQUE(ticket_id)` garantiza como máximo un SLA por ticket.

`sla-demo-v1` usa minutos corridos: critical 60, high 240, medium 480 y low
1440. `started_at` coincide con `tickets.created_at`. No representa horario
laboral ni un estándar sectorial.

La evidencia de breach es persistida: `ticket_sla.status='breached'` junto a
`breached_at`, y el registro único correlacionado en `sla_breaches`. No se
derivará un breach histórico con `NOW() > due_at`.

`ticket_sla.resolved_at` es el único timestamp de resolución real. El campo
`resolved_by` queda excluido de analytics.

### Automation events

Cada fila es un evento persistido. Los estados permitidos son `pending`,
`succeeded`, `failed` y `skipped`; los tipos observados son
`telegram_notification` y `sla_escalation`, con reglas
`notify_high_or_critical_v1` y `escalate_sla_breach_v1`.

La tabla no contiene chat IDs, cuerpos de mensajes, credenciales ni tokens.
La futura vista puede exponer IDs técnicos, regla, tipo, estado, error y
timestamps, sin recuperar textos desde tickets, predictions o reviews.

## Cardinalidades observadas en PostgreSQL

| Entidad | Filas | Cardinalidad observada por ticket |
| --- | ---: | --- |
| Tickets | 13 | 1 ticket base |
| Predictions | 13 | min 1, max 1; 0 grupos con más de una |
| Reviews | 2 | min 0, max 1; 0 grupos con más de una |
| Final decisions | 5 | min 0, max 1; 0 grupos con más de una |
| SLA records | 5 | min 0, max 1; 0 grupos con más de una |
| SLA breaches | 3 | min 0, max 1; 0 grupos con más de una |
| Automation events | 12 | min 0, max 2; 3 tickets con dos eventos |

La ausencia actual de predictions duplicadas no sustituye una regla de
selección. En contraste, decision, SLA y breach sí tienen unicidad por ticket
persistida en PostgreSQL.

Las comprobaciones cruzadas devolvieron cero inconsistencias entre:

- decision y su prediction/review;
- SLA, ticket, decisión y prioridad;
- SLA `started_at` y ticket `created_at`;
- automation event y sus prediction/decision/review/breach relacionados.

## Estados realmente persistidos

| Campo | Valores observados |
| --- | --- |
| `tickets.status` | `processing` 8, `open` 4, `closed` 1 |
| `ticket_ai_predictions.status` | `succeeded` 9, `failed` 4 |
| `ticket_reviews.status` | `approved` 1, `overridden` 1 |
| `ticket_decisions.decision_source` | `ai` 3, `human_approved` 1, `human_overridden` 1 |
| `ticket_sla.status` | `active` 1, `met` 1, `breached` 3 |
| `sla_breaches.status` | `escalated` 3 |
| `automation_events.status` | `succeeded` 6, `failed` 1, `skipped` 5 |

No se observaron predictions, reviews, breaches ni automation events en
`pending` al momento de la auditoría. Esto es un estado de los datos, no una
eliminación de esos valores permitidos por contrato.

## Respuestas a las preguntas bloqueantes

1. **¿Cómo identificar la prediction autoritativa?** Para un ticket con
   decisión final, exclusivamente mediante
   `ticket_decisions.prediction_id`. Para una review, mediante
   `ticket_reviews.prediction_id`. Para los ocho tickets sin decisión ni
   review no existe selector autoritativo persistido; cuatro son predictions
   succeeded v1 y cuatro failed. Este punto bloquea una selección global a
   grain ticket.
2. **¿Puede existir más de una revisión HITL?** Por prediction no, debido a
   `UNIQUE(prediction_id)`. Por ticket sí lo permite el esquema si existen
   varias predictions. En los datos actuales el máximo es una.
3. **¿Puede existir más de una decisión final?** No por ticket;
   `UNIQUE(ticket_id)` lo impide.
4. **¿Puede existir más de un SLA?** No por ticket;
   `UNIQUE(ticket_id)` lo impide.
5. **¿Qué timestamp representa resolución real?**
   `ticket_sla.resolved_at`. No `tickets.updated_at`.
6. **¿Qué dato demuestra un breach?** `ticket_sla.status='breached'` y
   `ticket_sla.breached_at`; `sla_breaches` agrega el registro operacional de
   detección/escalamiento.
7. **¿Qué confidence existe y qué significa?** Solo schema v2 succeeded tiene
   confidence persistida: cinco filas observadas, entre 0.7000 y 0.9900. Es
   una señal operacional no calibrada, no probabilidad de corrección ni
   accuracy.
8. **¿Qué estados están persistidos?** Se enumeran en la tabla anterior; los
   CHECK constraints permiten además los estados pending documentados aunque
   hoy no existan filas en ellos.

## Catálogo analítico seguro

### Fuentes autoritativas

| Concepto | Fuente |
| --- | --- |
| Ticket, área, estado, creación | `tickets` |
| Clasificación operacional final | `ticket_decisions` |
| Prediction asociada a una decisión | `ticket_decisions.prediction_id` |
| Intervención y resultado humano | `ticket_reviews` |
| SLA asignado, resolución y breach | `ticket_sla` |
| Registro de breach/escalamiento | `sla_breaches` |
| Resultado de automatización | `automation_events` |

### Campos descartados

No deben pasar a la capa BI: `requester_email`, `title`, `description`,
`ticket_ai_predictions.summary`, `review_reason`, `final_summary`, `reviewer`,
`comment`, `ticket_decisions.summary`, `resolved_by`, ni ningún texto o
identificador externo recuperado desde n8n/Telegram.

## Analytics grains aprobados

| Vista | Grain | Fuente base |
| --- | --- | --- |
| `analytics.v_ticket_lifecycle` | 1 fila por ticket | `public.tickets` |
| `analytics.v_ai_predictions` | 1 fila por prediction persistida | `public.ticket_ai_predictions` |
| `analytics.v_hitl_reviews` | 1 fila por review humana persistida | `public.ticket_reviews` |
| `analytics.v_automation_events` | 1 fila por evento persistido | `public.automation_events` |

No existe una prediction universal autoritativa para todos los tickets y la
capa analítica no fabricará una. Cuando existe
`ticket_decisions.prediction_id`, el lifecycle puede exponer exclusivamente
esa fila con el prefijo `decision_prediction_*`. Esta relación demuestra qué
prediction sustentó la decisión, pero no la convierte en prediction universal
del ticket.

## Contrato de vistas — Checkpoint 8.2

### `analytics.v_ticket_lifecycle`

Parte de `public.tickets` y solo usa relaciones 0..1 demostradas:
`ticket_decisions` por su `UNIQUE(ticket_id)`, la prediction referenciada por
la decisión y `ticket_sla` por su `UNIQUE(ticket_id)`. No une reviews ni
automation events 1:N.

Columnas contratadas:

- ticket: `ticket_id`, `requester_area`, `ticket_status`,
  `ticket_created_at`, `ticket_updated_at`;
- decisión: `final_decision_id`, `final_category`, `final_priority`,
  `decision_source`, `final_decision_at`;
- prediction de la decisión: `decision_prediction_id`, estado, categoría,
  prioridad, confidence, provider, model, prompt/schema version, error,
  attempt count y timestamps;
- SLA: `sla_id`, policy version, priority, status, start, due, resolution,
  breach y timestamps;
- `resolution_minutes`, solo cuando existe `resolved_at`.

`resolution_minutes` significa exclusivamente **elapsed calendar time between
persisted ticket creation and persisted SLA resolution**. No significa agent
handling time, work time ni business-hours time.

### `analytics.v_ai_predictions`

Refleja directamente cada fila de `ticket_ai_predictions`, incluida su
cardinalidad 1:N potencial por ticket. Añade únicamente `requester_area` y
`ticket_created_at` desde la relación N:1 con `tickets`. Expone estado,
clasificación, confidence, provider/model, versiones, error, intentos y
timestamps. Excluye summary y review reason.

### `analytics.v_hitl_reviews`

Parte de `ticket_reviews`; usa sus FKs exactas a ticket y prediction, y la
relación 0..1 `ticket_decisions.review_id`. Expone estado/timestamps de la
review, prediction original, decisión final y los booleanos nullable
`category_changed` y `priority_changed`. Estos booleanos solo existen cuando
hay decisión; son comparaciones, no accuracy.

### `analytics.v_automation_events`

Parte de `automation_events`; conserva un evento por fila y añade únicamente
área/fecha del ticket mediante N:1. Expone IDs técnicos, regla, tipo, estado,
error y timestamps. No contiene datos de entrega externos ni texto.

### Exclusiones PII y texto libre

Quedan expresamente excluidos de las cuatro vistas:

```text
requester_email
title
description
summary / final_summary
review_reason
reviewer
review comment
resolved_by
Telegram chat/recipient identifiers
message bodies
credentials, tokens and secrets
```

## Diccionario de KPIs

| KPI | Grain | Numerador | Denominador | Fuente | Definición y limitaciones |
| --- | --- | --- | --- | --- | --- |
| Total Tickets | ticket | tickets | — | lifecycle | Número de tickets persistidos. |
| Resolved Tickets | ticket | `resolved_at IS NOT NULL` | — | lifecycle | Resolución persistida en SLA; un ticket sin SLA/resolution no cuenta. |
| Tickets by Area | ticket | tickets por `requester_area` | — | lifecycle | Área normalizada persistida. |
| Tickets by Final Category | ticket | decisiones por `final_category` | — | lifecycle | Solo tickets con decisión final. |
| Tickets by Final Priority | ticket | decisiones por `final_priority` | — | lifecycle | Solo tickets con decisión final. |
| Tickets by Status | ticket | tickets por `ticket_status` | — | lifecycle | Estado transaccional persistido. |
| SLA Assigned | ticket/SLA | `sla_id IS NOT NULL` | — | lifecycle | Un SLA máximo por ticket. |
| SLA Breached | ticket/SLA | `sla_status='breached'` | — | lifecycle | Usa estado de breach persistido, no el reloj actual. |
| SLA Breach Rate | ticket/SLA | SLA breached | SLA assigned | lifecycle | Ratio sobre SLA realmente asignados. |
| Average Resolution Minutes | ticket/SLA | promedio de `resolution_minutes` no NULL | tickets resueltos | lifecycle | Minutos corridos desde creación hasta resolución persistida. |
| Median Resolution Minutes | ticket/SLA | mediana de `resolution_minutes` no NULL | tickets resueltos | lifecycle | Misma semántica temporal; NULL no se vuelve cero. |
| Prediction Attempts | prediction | filas de predictions | — | AI predictions | Métrica de filas/attempt records, no de tickets. |
| Successful Predictions | prediction | `prediction_status='succeeded'` | — | AI predictions | Resultado terminal persistido por prediction. |
| Failed Predictions | prediction | `prediction_status='failed'` | — | AI predictions | Resultado terminal persistido por prediction. |
| Prediction Success Rate | prediction | succeeded | succeeded + failed | AI predictions | Excluye pending del denominador; es attempt-level, no ticket-level. |
| Confidence Distribution | prediction | predictions con confidence no NULL | — | AI predictions | Señal operacional no calibrada; no es probability ni accuracy. |
| Predictions by Model | prediction | predictions por provider/model | — | AI predictions | Metadatos persistidos. |
| Predictions by Prompt Version | prediction | predictions por prompt/schema | — | AI predictions | Metadatos persistidos. |
| Persisted Reviews | review | filas de reviews | — | HITL reviews | Evidencia humana persistida; no se infiere por confidence. |
| Completed Reviews | review | approved + overridden | — | HITL reviews | Estados terminales humanos persistidos. |
| Pending Reviews | review | pending | — | HITL reviews | Reviews aún no decididas. |
| Category Overrides | review | `category_changed=true` | — | HITL reviews | Cambio explícito frente a prediction asociada; no accuracy. |
| Priority Overrides | review | `priority_changed=true` | — | HITL reviews | Cambio explícito frente a prediction asociada; no accuracy. |
| Override Rate | review | reviews overridden | completed reviews | HITL reviews | Override de cualquier campo según estado persistido. |
| Automation Events | event | filas de eventos | — | automation events | Una fila por evento persistido. |
| Succeeded Events | event | status succeeded | — | automation events | Outcome persistido. |
| Failed Events | event | status failed | — | automation events | Outcome persistido. |
| Skipped Events | event | status skipped | — | automation events | Regla evaluada sin side effect. |

No están soportados: accuracy operacional, confidence como probabilidad,
handling/work/business-hours time, breach calculado solo con `NOW()`, ni KPIs
que mezclen la evaluación experimental de Gate 7 con datos operacionales.

## Checkpoints de diseño

- **Checkpoint 8.1: PASS.** Los grains separados resuelven el bloqueo sin
  modificar `public` ni seleccionar predictions arbitrariamente.
- **Checkpoint 8.2: PASS.** Las cuatro vistas, exclusiones y definiciones KPI
  tienen fuentes físicas y denominadores demostrados.

## Implementación y validación

### Checkpoint 8.3 — PASS

La migración `005_phase8_analytics_views.sql` creó `analytics` y las cuatro
vistas contratadas. Se aplicó como `smartdesk_app`; no alteró tablas, columnas,
constraints ni datos de `public`.

El `pg_dump --schema-only --schema=public` textual cambió de orden porque las
nuevas vistas introdujeron dependencias externas y PostgreSQL 17 genera tokens
`\restrict` aleatorios. Para comparar estructura y no ruido de serialización,
ambos snapshots se restauraron en bases temporales aisladas, se volvieron a
exportar sin `analytics`, se eliminaron los tokens aleatorios y se compararon.
Los dos artefactos canónicos produjeron:

```text
sha256 = ee6a31fb0a361f5d7b45d731c9b90728bb917a07148c72bcffca2617effbf477
diff = empty
```

Las bases temporales se eliminaron al terminar.

Una prueba adicional creó una base temporal limpia, aplicó en orden las
migraciones `001→005` y confirmó cuatro vistas analytics. La base temporal se
eliminó al finalizar.

### Checkpoint 8.4 — PASS

`sql/analytics/gate8_checks.sql` validó:

| Prueba | Resultado |
| --- | --- |
| Ticket grain | 13 filas = 13 tickets distintos |
| Ticket coverage | 13 analytics = 13 public |
| Prediction grain | 13 filas = 13 predictions distintas |
| Prediction coverage | 13 analytics = 13 public |
| HITL grain/coverage | 2 = 2, PK única |
| Automation grain/coverage | 12 = 12, PK única |
| Orphans | 0 en predictions, reviews y events |
| Columnas PII prohibidas | 0 |
| Resolution time negativo | 0 |
| Violaciones de NULL semantics | 0 |

Referencias SQL actuales:

```text
Total Tickets = 13
Resolved Tickets = 1
SLA Assigned = 5
SLA Breached = 3
SLA Breach Rate = 0.600000
Prediction Attempts = 13
Successful Predictions = 9
Failed Predictions = 4
Prediction Success Rate = 0.692308
Persisted / Completed / Pending Reviews = 2 / 2 / 0
Override Rate = 0.500000
Automation succeeded / failed / skipped = 6 / 1 / 5
```

### Checkpoint 8.5 — PASS

Se creó `smartdesk_bi_reader` con login y password generado fuera del
repositorio. El secreto reside únicamente en la configuración privada del
despliegue, con modo 0600. El rol es `NOSUPERUSER`, `NOCREATEDB`,
`NOCREATEROLE`, `NOINHERIT`, `NOREPLICATION` y `NOBYPASSRLS`; recibe solo
CONNECT, USAGE de `analytics` y SELECT sobre las cuatro vistas.

Pruebas reales mediante login del rol:

```text
analytics SELECT = PASS
direct public SELECT = permission denied
UPDATE public = permission denied
INSERT public = permission denied
DELETE public = permission denied
CREATE in analytics = permission denied
```

PostgreSQL publica únicamente `127.0.0.1:5432`. Conserva la red interna
`database` y añade `bi_access`, una red puente exclusiva del servicio
PostgreSQL necesaria para materializar el bind de loopback. La prueba externa
de TCP/5432 devolvió `False`. Un túnel local en el puerto 15432 abrió
correctamente y completó un handshake real del protocolo PostgreSQL.

Durante la inspección de Docker, una salida demasiado amplia mostró tres
contraseñas de base de datos. Se rotaron inmediatamente bootstrap, n8n y
SmartDesk; se actualizó también la credencial PostgreSQL cifrada de n8n, se
recrearon los contenedores afectados y se verificaron tres logins, modo 0600 y
salud de PostgreSQL/n8n/Caddy. No se expusieron claves SSH, OpenAI, Telegram ni
el token administrativo.

## Power BI — Checkpoint 8.6 PASS

Power BI Desktop se conectó por el túnel SSH existente a
`localhost:15432`, usando `smartdesk_bi_reader` y modo Import. Se importaron y
renombraron exclusivamente las cuatro vistas contratadas como `FactTickets`,
`FactAIPredictions`, `FactHITLReviews` y `FactAutomationEvents`.

El reporte real contiene tres páginas: Operations Overview, AI & Human Review
y SLA & Automation. Las tres relaciones desde `FactTickets[ticket_id]` hacia
las tablas hijas están activas, son 1:* y no existe una relación many-to-many
entre facts. Los slicers se probaron de forma interactiva; una selección de
control redujo la población de 13 a 2 tickets y actualizó los visuales
relacionados de forma consistente.

Refresh terminó con cero errores de query, credenciales o PostgreSQL. Una
consulta DAX directa al modelo abierto confirmó 13 tickets, 1 resuelto, 5 SLA
asignados, 3 breaches, 13 predictions (9 succeeded y 4 failed), 2 reviews
completadas y eventos de automatización 6/1/5. `Prediction Success Rate` usa
como denominador únicamente succeeded + failed y devolvió 0.6923076923.

Se exportó `powerbi/SmartDeskAI.pbit`. Su inspección confirmó
`DataModelSchema`, ausencia de `DataModel` importado, las tres páginas, las
cuatro tablas y la fórmula corregida. SHA-256:
`7c7a7319030fc0360cd5d02528b54f346e3c5706b7e8804a84b04414d375d1cc`.

## Evidencia Gate 8 — Checkpoint 8.7 PASS

La matriz completa está en `docs/testing/GATE_8.md`. G8-17, G8-18 y G8-19
quedaron validados con Power BI Desktop real, inspección directa del modelo y
reconciliación contra PostgreSQL. No se añadieron screenshots con datos
operacionales ni datos demo. Gate 8 queda **PASS** y Phase 8 **COMPLETE**;
Phase 9 permanece **NOT STARTED**.
