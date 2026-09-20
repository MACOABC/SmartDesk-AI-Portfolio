# Evidencia de progreso — Gate 8

## Estado

```text
Gate 8 = NOT YET PASS
Phase 8 = IN PROGRESS
```

La capa SQL, sus pruebas, el rol BI y el túnel están implementados y
verificados. La ejecución real de Power BI Desktop continúa pendiente; por
ello este documento no declara el gate cerrado.

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
| G8-17 Power BI refresh | PENDING MANUAL VALIDATION | Power BI Desktop no está instalado en este entorno. |
| G8-18 Power BI relationships | PENDING MANUAL VALIDATION | Contrato preparado; requiere inspección del modelo real. |
| G8-19 KPI reconciliation | PENDING POWER BI RECONCILIATION | Valores PostgreSQL preparados; falta compararlos con cards reales. |
| G8-20 HITL semantics | PASS | Derivadas exclusivamente de `ticket_reviews` y sus FKs. |
| G8-21 Confidence semantics | PASS | Documentada como señal operacional no calibrada. |
| G8-22 SLA semantics | PASS | Assignment, status, due, resolution y breach son persistidos. |
| G8-23 Gate 7 separation | PASS | Benchmark experimental no aparece en vistas ni KPIs operacionales. |
| G8-24 Secret scan | PASS | 0 claves, tokens, private keys o URLs PostgreSQL con credenciales versionadas. |
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

## Seguridad

- `smartdesk_bi_reader` no posee privilegios administrativos ni DML/DDL.
- Su password no forma parte de Git, documentación o outputs conservados.
- PostgreSQL permanece inaccesible desde el exterior.
- El túnel probado no requiere abrir firewall para 5432.
- Una exposición accidental de tres passwords de base durante la inspección
  se remedió con rotación inmediata, actualización de n8n, recreación y pruebas
  3/3; no quedan vigentes los valores expuestos.

## Pendientes para cerrar Gate 8

1. Instalar o usar Power BI Desktop en una estación autorizada.
2. Abrir el túnel y construir `SmartDeskAI.pbit` desde las cuatro vistas.
3. Ejecutar Refresh y verificar las relaciones descritas en `MODEL.md`.
4. Reconciliar todos los cards y varios filtros contra
   `sql/analytics/gate8_checks.sql`.
5. Guardar evidencia saneada y actualizar G8-17, G8-18 y G8-19 a PASS.

Hasta completar esos pasos, Gate 8 no puede aprobarse ni Phase 8 declararse
completa.
