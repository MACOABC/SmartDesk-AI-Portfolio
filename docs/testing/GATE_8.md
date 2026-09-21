# Evidencia de cierre — Gate 8

## Estado

```text
Gate 8 = PASS
Phase 8 = COMPLETE
Phase 9 = NOT STARTED
```

La capa SQL, sus pruebas, el rol BI, el túnel y el reporte real de Power BI
Desktop están implementados y verificados. El template reproducible se conserva
en `powerbi/SmartDeskAI.pbit` sin datos importados.

## Matriz G8

| ID | Estado | Evidencia |
| --- | --- | --- |
| G8-01 Baseline integrity | PASS | Baseline `812552f...`; `v1.0=fc42c911...` se mantiene intacto. |
| G8-02 Productive schema unchanged | PASS | Snapshots `public` restaurados y normalizados: mismo SHA-256 `ee6a31...`, diff vacío. |
| G8-03 Analytics views exist | PASS | Existen las cuatro vistas; un bootstrap temporal limpio `001→005` reprodujo las cuatro. |
| G8-04 Ticket grain | PASS | 13 filas, 13 `ticket_id` distintos. |
| G8-05 Ticket coverage | PASS | 13 analytics = 13 public. |
| G8-06 Prediction grain | PASS | 13 filas, 13 `prediction_id` distintos. |
| G8-07 Prediction coverage | PASS | 13 analytics = 13 public. |
| G8-08 Review reconciliation | PASS | 2 analytics = 2 public; `review_id` única. |
| G8-09 Automation reconciliation | PASS | 12 analytics = 12 public; `event_id` única. |
| G8-10 No orphan analytics rows | PASS | 0 predictions, 0 reviews y 0 events huérfanos. |
| G8-11 No prohibited PII | PASS | 0 nombres prohibidos; SQL revisado manualmente sin texto libre equivalente. |
| G8-12 Temporal validity | PASS | 0 `resolution_minutes < 0`; NULL preservado. |
| G8-13 BI reader SELECT | PASS | Login real pudo consultar lifecycle. |
| G8-14 BI reader writes fail | PASS | SELECT directo public, UPDATE, INSERT, DELETE y CREATE denegados. |
| G8-15 PostgreSQL not public | PASS | Solo `127.0.0.1:5432`; prueba externa TCP devolvió false. |
| G8-16 SSH tunnel | PASS | Listener local y handshake PostgreSQL real mediante `localhost:15432`. |
| G8-17 Power BI refresh | PASS | Refresh manual real: 0 errores de query, credenciales o PostgreSQL; los valores permanecieron reconciliados. |
| G8-18 Power BI relationships | PASS | Inspección del modelo real: tres relaciones activas 1:* desde `FactTickets[ticket_id]`, filtro simple y ninguna many-to-many entre facts. |
| G8-19 KPI reconciliation | PASS | Cards comparadas con PostgreSQL y consulta DAX directa al modelo: coincidencia exacta para tickets, SLA, predictions, HITL y automatización. |
| G8-20 HITL semantics | PASS | Derivadas exclusivamente de `ticket_reviews` y sus FKs. |
| G8-21 Confidence semantics | PASS | Documentada como señal operacional no calibrada. |
| G8-22 SLA semantics | PASS | Assignment, status, due, resolution y breach son persistidos. |
| G8-23 Gate 7 separation | PASS | Benchmark experimental no aparece en vistas ni KPIs operacionales. |
| G8-24 Secret scan | PASS | Scan final, incluido el `.pbit`: 0 API keys, tokens, private keys, URLs PostgreSQL con password o coincidencias con la contraseña BI vigente. |
| G8-25 Scope control | PASS | Sin Phase 9/10, ETL, warehouse, dbt, Airflow, Fabric ni monitoring nuevo. |

## Objetos creados

```text
analytics.v_ticket_lifecycle
analytics.v_ai_predictions
analytics.v_hitl_reviews
analytics.v_automation_events
role smartdesk_bi_reader
loopback bind 127.0.0.1:5432
```

No se alteraron objetos transaccionales de `public`.

## KPI reference actual

| KPI | PostgreSQL |
| --- | ---: |
| Total Tickets | 13 |
| Resolved Tickets | 1 |
| SLA Assigned | 5 |
| SLA Breached | 3 |
| SLA Breach Rate | 0.600000 |
| Average Resolution Minutes | 2.256423 |
| Median Resolution Minutes | 2.256423 |
| Prediction Attempts | 13 |
| Successful Predictions | 9 |
| Failed Predictions | 4 |
| Prediction Success Rate | 0.692308 |
| Persisted Reviews | 2 |
| Completed Reviews | 2 |
| Pending Reviews | 0 |
| Category Overrides | 0 |
| Priority Overrides | 1 |
| Override Rate | 0.500000 |
| Automation Events | 12 |
| Succeeded Events | 6 |
| Failed Events | 1 |
| Skipped Events | 5 |

Los valores deben recalcularse inmediatamente antes del refresh manual si la
base cambia.

## Evidencia Power BI

- Artefacto: `powerbi/SmartDeskAI.pbit`, 793761 bytes, SHA-256
  `7c7a7319030fc0360cd5d02528b54f346e3c5706b7e8804a84b04414d375d1cc`.
- Estructura: `DataModelSchema` presente y `DataModel` importado ausente.
- Páginas: Operations Overview, AI & Human Review y SLA & Automation.
- Refresh: PASS, sin errores de query, credenciales ni PostgreSQL.
- Relaciones: `FactTickets` en el lado 1 y las tres facts hijas en el lado *,
  activas y sin many-to-many accidental.
- Filtros: una selección manual redujo 13 tickets a 2 y propagó el filtro a
  visuales y cards relacionados.
- Screenshots: no se versionaron capturas con las filas operacionales.

La inspección directa del `.pbit` confirmó que `Prediction Success Rate`
divide Successful Predictions entre Successful Predictions + Failed
Predictions. Las métricas de prediction conservan grain prediction; Completed
Reviews usa `review_decided_at` persistido y Override Rate usa
`review_status = "overridden"`.

## Seguridad

- `smartdesk_bi_reader` no posee privilegios administrativos ni DML/DDL.
- Su password no forma parte de Git, documentación o outputs conservados.
- PostgreSQL permanece inaccesible desde el exterior.
- El túnel probado no requiere abrir firewall para 5432.
- Los `.pbix` con datos importados están ignorados; solo el `.pbit` sin
  `DataModel` forma parte del cierre versionable.
- Una exposición accidental de tres passwords de base durante la inspección
  se remedió con rotación inmediata, actualización de n8n, recreación y pruebas
  3/3; no quedan vigentes los valores expuestos.

## Cierre

Los 25 criterios están en PASS. Prediction metrics permanecen separadas a
grain prediction; HITL proviene de reviews persistidas; confidence no es una
probabilidad calibrada; resolution time son minutos corridos basados en
timestamps persistidos; y el benchmark experimental de Gate 7 no se mezcla con
BI operacional. Gate 8 queda aprobado y Phase 8 completa. Phase 9 no se inició.
