# Evidencia de cierre — Gate 6

## Estado y trazabilidad

- **Fecha UTC de prueba:** 2026-09-20.
- **Gate 6:** **PASS**.
- **Phase 6:** **COMPLETE**.
- **Commit funcional probado y desplegado:**
  `ba9fd7b1d32c837a30afc1d35d05a018492e4392`.
- **Release V1 preservada:** `v1.0` continúa apuntando a
  `fc42c911725aa589e3b36207d0be5b95b9f08063`.
- **Entorno:** Oracle Cloud ARM64, Ubuntu 22.04, Docker Compose,
  PostgreSQL 17.11, n8n 2.39.6 y Caddy 2.11.4.

El commit documental posterior registra el cierre, pero no sustituye al commit
funcional realmente desplegado y probado.

## Arquitectura verificada

```text
POST /tickets
  → ticket persistido
  → OpenAI con retry selectivo
  → prediction v2 validada
      ├─ confidence >= 0.75 → decisión final IA
      └─ confidence < 0.75  → review pending
                                 → approve/override
  → SLA desde tickets.created_at y prioridad final
  → evento único de negocio
  → Telegram o skipped

schedule/5 min
  → recuperación de estados stale
  → claim transaccional de SLA vencido
  → breach único
  → escalamiento Telegram único
```

La predicción original permanece en `ticket_ai_predictions`; la decisión
operacional está separada en `ticket_decisions`. PostgreSQL crea review,
decisión, SLA y evento con restricciones y funciones transaccionales; n8n
orquesta las llamadas externas.

## G6.1 — Baseline

| Comprobación | Resultado | Evidencia |
| --- | --- | --- |
| Gates 0–5 y V1 | **PASS** | `STATUS.md`, `ROADMAP.md` y `docs/testing/GATE_5.md` revisados antes de implementar. |
| Árbol inicial | **PASS** | `main=57b3c37fee61389029b8a017f011cd41a04b3ffc`, limpio. |
| Release V1 | **PASS** | `v1.0=fc42c911725aa589e3b36207d0be5b95b9f08063`; no se movió ni recreó. |
| Deployment inicial | **PASS** | `DEPLOYED_COMMIT=fc42c911...`; Caddy, n8n y PostgreSQL `healthy`; conteos V1 `5|5|4`. |

## G6.2 — Migraciones y bootstrap

Se creó `db/migrations/004_phase6_reliability_hitl_sla.sql`. En una base
temporal se aplicaron `001→004` sobre la misma imagen PostgreSQL ARM64:

```text
tables=8
sla_policy_rows=4
phase6_functions=5
phase6_contract_tests=PASS
```

También se probó un bootstrap real con contenedor y data directory efímeros
usando `db/apply-migrations.sh`; produjo `8|4` (tablas|políticas) y
`fresh_bootstrap=PASS`.

La prueba de upgrade creó antes de `004` una fila V1 succeeded y un evento V1
skipped. Después de aplicar `004`:

```text
tickets=1
v1_predictions=1
automation_events=1
predictions_with_null_phase6_fields=1
v1_upgrade_preservation=PASS
```

La migración productiva terminó con `COMMIT`. La suite SQL transaccional se
repitió contra la base desplegada y terminó en `phase6_contract_tests=PASS` y
`ROLLBACK`, sin dejar fixtures.

## G6.3–G6.8 — Compatibilidad V1 e HITL

### Ruta sin review

El caso claro LOW respondió HTTP 201:

```text
ticket=5caf609d-d21d-4b59-84c0-89fb1a992fd5
prediction=succeeded/service_request/low
confidence=0.9900
review_required=false
decision_source=ai
sla_policy=sla-demo-v1
deadline=tickets.created_at + 1440 minutes
automation_event=skipped
```

Un smoke posterior a todas las pruebas temporales también respondió HTTP 201
con `succeeded/service_request/low`, `confidence=0.9800`, decisión IA y SLA.

### Review pending y approve

El ticket `24b90ca8-f705-456e-b2fe-f200531fa013` devolvió HTTP 202:

```text
prediction=other/medium
confidence=0.7000
review_required=true
review=cb7abd28-c8c6-46b3-b153-3763f1fb06e9/pending
decisions=0
sla=0
automation_events=0
```

Approve produjo exactamente una decisión `human_approved`, un SLA desde
`tickets.created_at` y un evento `skipped` por prioridad MEDIUM. Repetir la
misma decisión respondió `idempotent_replay=true`; se conservaron los mismos
IDs y no se creó otra acción.

### Override

El ticket `4400e0c2-fb46-4d30-9857-ff1937ca2c72` almacenó la predicción IA
original `network/medium`, `confidence=0.7000`. El override estableció
`network/critical` y generó:

```text
prediction_original=network|medium|0.7000|review_required=true
review=overridden|network|critical
decision=human_overridden|network|critical
sla=sla-demo-v1|critical|60 minutes from tickets.created_at
automation_events=1|succeeded
```

Telegram confirmó el envío. La predicción IA no fue modificada.

## G6.9–G6.10 — Reliability e integridad

Se levantó un Caddy efímero, sin puertos públicos, dentro de la red `app` para
responder de forma controlada. El workflow temporal cambió únicamente la URL
de los tres intentos; después se restauró y republicó el export versionado.

| Caso | Respuesta mock | Resultado persistido | Downstream |
| --- | --- | --- | --- |
| Transitorio | HTTP 503 | `AI_PROVIDER_TRANSIENT_EXHAUSTED`, `failure_kind=transient`, `attempt_count=3` | `0 review`, `0 decision`, `0 SLA`, `0 event`. |
| Permanente | HTTP 400 | `AI_PROVIDER_PERMANENT`, `failure_kind=permanent`, `attempt_count=1` | `0 review`, `0 decision`, `0 SLA`, `0 event`. |

Los backoffs fueron 2 s y 4 s. No existen loops ni retry ilimitado. Tras la
restauración, el mock quedó eliminado, n8n volvió a `healthy` y el smoke real
con OpenAI pasó.

La primera ejecución válida de Phase 6 detectó además un error de contrato
local (`AI_CONTRACT_LOAD_ERROR`) porque el prompt v2 no declaraba su ID exacto.
El ticket y la prediction failed se conservaron, no hubo downstream y se
corrigió el archivo sin debilitar el validador. El caso válido repetido pasó.

## G6.11–G6.17 — SLA, resolución, breach y escalamiento

La política versionada y demostrativa `sla-demo-v1` contiene:

| Prioridad | Minutos corridos |
| --- | ---: |
| critical | 60 |
| high | 240 |
| medium | 480 |
| low | 1440 |

No se presenta como estándar del sector. La suite SQL verificó de forma
determinista que `started_at=tickets.created_at` y que un override recalcula
`due_at` con la prioridad final, manteniendo el origen.

La resolución del caso LOW produjo `ticket=closed`, `sla=met` y timestamp
`resolved_at`. Repetirla devolvió `idempotent_replay=true` con el mismo
timestamp. Después del checker:

```text
resolved_before_due: breaches=0|sla_status=met
```

Para el breach controlado se adelantó exclusivamente el deadline de un ticket
sintético CRITICAL ya persistido. La ejecución manual del mismo workflow
programado produjo:

```text
sla_status=breached
sla_breaches=1|status=escalated
escalation_events=1|status=succeeded
telegram_ok=true
event_rows=1
breach_rows=1
```

Una segunda ejecución completa del checker finalizó correctamente y mantuvo
exactamente un breach y una escalación.

## G6.18 — Restart y persistencia

n8n fue recreado después del despliegue, después de publicar los workflows,
durante la ejecución controlada del scheduler y después de restaurar el
workflow normal. Al cierre:

```text
caddy=healthy
n8n=healthy
postgres=healthy
ticket-intake=active
phase6-admin=active
phase6-sla-scheduler=active
pending_predictions=0
pending_reviews=0
pending_automation_events=0
pending_breaches=0
```

Reviews approved/overridden, decisiones, SLA y breach persistieron. El replay
del scheduler reconoció el estado previo y no duplicó la escalación.

## G6.19 — Regresión V1

| Caso | Resultado |
| --- | --- |
| Intake inválido | **PASS** — HTTP 400, sin fila. |
| Intake válido / IA normal | **PASS** — HTTP 201, prediction v2, decisión y SLA. |
| LOW/MEDIUM | **PASS** — evento `skipped`, cero Telegram. |
| HIGH/CRITICAL | **PASS** — evento único `succeeded` y Telegram real. |
| Telegram | **PASS** — entrega real directa, post-review y escalamiento. |
| Persistencia | **PASS** — correlación SQL después de recrear n8n. |
| HTTPS | **PASS** — endpoint productivo usado en toda la matriz. |

La batería Gate 2 histórica de 30 casos no se repitió completa; se ejecutó la
regresión proporcional requerida por Gate 6.

## G6.20 — Seguridad

- `.env` permanece ignorado y no versionado.
- `SMARTDESK_ADMIN_TOKEN` se generó en la VM, tiene al menos 32 caracteres y
  no se imprimió ni exportó; `.env.example` contiene solo placeholder.
- Los exports contienen referencias de credenciales `id/name`, no secretos.
- El scan de archivos no encontró API keys, tokens Telegram ni private keys.
- Los endpoints admin devolvieron 404 por Caddy y 401 en loopback sin token.
- Desde el exterior: `80=open`, `443=open`, `5678=closed`, `5432=closed` y
  `9000=closed`.
- PostgreSQL continúa sin puerto publicado; n8n conserva
  `127.0.0.1:5678:5678`.
- El backup privado previo a migración se guardó fuera de Git. No constituye
  todavía el sistema de backups/restores de Phase 9.

## G6.21–G6.22 — Estado final y resumen SQL

Después de la matriz, incluyendo las cinco filas V1 históricas:

```text
tickets=13
predictions=13
reviews=2
decisions=5
ticket_sla=5
automation_events=10
sla_breaches=1

pending predictions|reviews|events|breaches = 0|0|0|0
duplicate reviews|decisions|sla|breaches|events = 0|0|0|0|0
```

Los hashes SHA-256 de Compose, migración `004`, tres workflows y contrato v2
coincidieron entre el repositorio y `/home/ubuntu/smartdesk-ai`. El archivo
`DEPLOYED_COMMIT` quedó en el commit funcional probado.

## Limitaciones conocidas

- `confidence` es una señal de routing no calibrada; su threshold debe
  evaluarse en Phase 7.
- Los SLA son minutos corridos y no implementan calendarios laborales.
- La garantía de idempotencia es interna. No se afirma exactly-once frente a
  Telegram; un resultado externo indeterminado se marca y no se reenvía a
  ciegas.
- Repetir una decisión, breach o escalamiento no duplica acciones, pero Phase
  6 no deduplica dos submissions HTTP que representan el mismo ticket.
- HITL usa endpoints administrativos por loopback+túnel SSH y token; no existe
  frontend completo.
- La VM única sigue siendo un punto único de fallo. CI/CD, monitoring y
  backups con restore probado permanecen en Phase 9.

## Cierre

Todos los criterios G6.1–G6.22 fueron ejecutados con evidencia real y
resultaron **PASS**. Gate 6 queda aprobado, Phase 6 completada y la siguiente
fase indicada por el roadmap es Phase 7 — dataset sintético y evaluación
cuantitativa de IA. No se implementó Phase 7.
