# Evidencia de cierre — Gate 5

## Estado y trazabilidad de release

- **Fecha local de cierre:** 2026-09-19 (ejecuciones en UTC el 2026-09-20).
- **Gate 5:** **PASS**.
- **Fase 5:** **COMPLETE**.
- **SmartDesk AI V1:** **COMPLETE**.
- **Tested/release commit:** `fc42c911725aa589e3b36207d0be5b95b9f08063`.

La matriz E2E se ejecutó sobre ese commit ya desplegado. El commit documental
posterior registra el cierre, pero no sustituye al commit probado como artefacto
de release. El tag Git local `v1.0` apunta deliberadamente al tested/release
commit `fc42c911725aa589e3b36207d0be5b95b9f08063`.

## Matriz E2E

| Caso | Resultado | Evidencia objetiva |
| --- | --- | --- |
| E2E-01 — entrada inválida | **PASS** | Ejecución 170: `POST {}` público por HTTPS respondió HTTP 400; cero tickets, predictions y eventos; cero OpenAI y Telegram. |
| E2E-02 — HIGH real | **PASS** | Ejecución 174: HTTP 201; prediction única `succeeded/network/high`; evento único `succeeded`; Telegram `ok=true`, `message_id=5`, un intento y cero retries. |
| E2E-03 — LOW/MEDIUM | **PASS** | Ejecución 171: HTTP 201; prediction única `succeeded/software/low`; evento único `skipped`; una llamada OpenAI y cero Telegram. |
| E2E-04 — fallo IA | **PASS** | Ejecución 172: HTTP 201; ticket conservado; prediction única `failed / AI_PROVIDER_ERROR`; cero eventos y cero Telegram; configuración normal restaurada inmediatamente. |
| E2E-05 — fallo Telegram | **PASS** | Ejecución 173: HTTP 201; prediction `succeeded/network/high` intacta; evento `failed / TELEGRAM_SEND_FAILED`; un intento, cero retries y cero duplicados; configuración real restaurada inmediatamente. |
| E2E-06 — redeploy y smoke | **PASS** | Ejecución 175: redeploy documentado sin borrar volúmenes, persistencia verificada y smoke HTTPS HTTP 201 con prediction `succeeded/software/low`, evento `skipped` y cero Telegram. |

Todas las ejecuciones 170–175 finalizaron con `retryOf IS NULL`. No se repitió
el caso inválido ya atribuible al commit probado y no se generaron solicitudes
adicionales para obtener ejemplos.

## Correlación SQL

| Caso | Ticket | Prediction | Automation event |
| --- | --- | --- | --- |
| E2E-02 | `a942db55-3623-4656-b3f9-3e8d064c7ccf` | `0e80b08d-a38f-4ee5-8c00-d0e37200091b` — `succeeded/network/high` | `937c0be2-e8d1-46c7-828b-cb959561346a` — `succeeded` |
| E2E-03 | `d9cf6459-19ec-4b6f-96b8-e7356cccf8c6` | `07197ca9-59c6-4942-8d80-b001c6e8bc85` — `succeeded/software/low` | `4fa51c20-efdd-4e7c-8afe-da3924243015` — `skipped` |
| E2E-04 | `ef6097a0-e939-4b6c-a737-ead3baa69b13` | `9efa0d63-94c5-484c-ad31-306469eb8ad6` — `failed / AI_PROVIDER_ERROR` | No creado, según contrato. |
| E2E-05 | `ec8c7d02-8c0b-465d-a62c-8c88ea398934` | `fb4223f4-9641-4408-bec4-51103672334f` — `succeeded/network/high` | `b7e21764-110c-4712-b622-6d9e33b123ce` — `failed / TELEGRAM_SEND_FAILED` |
| E2E-06 | `8cf9a5a1-adce-452a-ae75-ace2374b974d` | `156a905e-86ee-4b33-b28f-4d08fab0e649` — `succeeded/software/low` | `4eba7aa8-df85-4998-adf4-e0834d63c990` — `skipped` |

La consulta agregada sobre los datos de la matriz produjo:

    tickets=5
    predictions=5
    automation_events=4
    duplicate_predictions=0
    duplicate_automation_events=0
    pending_predictions=0
    pending_automation_events=0
    priority_action_inconsistencies=0

E2E-01 no generó filas. Los cinco tickets válidos conservaron
`tickets.status = processing`. La evidencia sintética no se eliminó antes de
documentar el cierre.

## Llamadas externas

    total OpenAI calls=5
    successful OpenAI calls=4
    failed OpenAI calls=1
    total Telegram attempts=2
    successful Telegram sends=1
    failed Telegram sends=1

El fallo controlado de IA utilizó el mecanismo previamente aprobado: modelo
ficticio en una copia temporal del workflow, una única ejecución y restauración
inmediata del workflow versionado. El fallo controlado de Telegram utilizó un
destino temporal inválido sin revocar ni alterar el token real; la configuración
real fue restaurada antes de comprobar el envío HIGH exitoso.

## HTTPS, routing y seguridad

- DNS A del hostname productivo resolvió hacia la IPv4 reservada de la VM.
- Caddy `2.11.4` permaneció `healthy` y publicó únicamente 80 y 443.
- El certificado Let's Encrypt para `smartdesk.example.com` fue válido;
  la comprobación registró expiración UTC `2026-12-19T02:28:14Z`.
- HTTP redirigió a HTTPS con estado 308.
- El único endpoint público de aplicación fue
  `POST https://smartdesk.example.com/webhook/tickets`.
- `/`, `/home`, `/login`, `/rest/workflows`, `/api/v1/workflows`,
  `/workflows`, `/executions` y `GET /webhook/tickets` respondieron 404.
- n8n conservó el binding `127.0.0.1:5678`; su health local respondió 200 y
  `5678` permaneció cerrado externamente.
- PostgreSQL no publicó puerto al host y `5432` permaneció cerrado
  externamente; `9000` tampoco estuvo accesible.
- UFW permaneció activo con OpenSSH, 80/tcp y 443/tcp permitidos. SSH continuó
  escuchando en 22 con la configuración de hardening previamente aprobada.
- No se imprimieron ni versionaron claves, tokens, passwords o el chat ID real.

## Redeploy y persistencia

Se siguió el procedimiento de `docs/DEPLOYMENT.md`: se recreó únicamente n8n,
sin ejecutar `docker compose down -v` ni eliminar datos o volúmenes. Caddy y
PostgreSQL conservaron sus contenedores. Después del redeploy:

    caddy=healthy
    n8n=healthy
    postgres=healthy
    workflow_active=true
    workflow_nodes=65
    normal_model_refs=5
    temporary_model_refs=0
    prompts_available=true
    deployed_commit=fc42c911725aa589e3b36207d0be5b95b9f08063

Los hashes desplegados de `compose.yaml`, `Caddyfile`, workflow y prompts
coincidieron con los archivos del commit probado. Los cuatro tickets, cuatro
predictions y tres eventos creados antes del redeploy persistieron; E2E-06
añadió después el único smoke válido previsto.

## Limitaciones fuera de V1

Este cierre no acredita accuracy del clasificador, rendimiento, disponibilidad,
SLA, ahorro ni impacto empresarial. V1 tampoco incorpora retries avanzados,
recuperación automática de estados indeterminados, HITL, evaluación con dataset,
SQL analítico o Power BI, CI/CD, monitoreo, alertas, backups ensayados, alta
disponibilidad, rate limiting ni WAF.

La VM única sigue siendo un punto único de fallo. Permanece la limitación
documentada de que una caída de PostgreSQL entre la creación de una prediction
`pending` y su actualización terminal puede dejarla pendiente; su recuperación
pertenece a una fase posterior. El webhook público tampoco sustituye un portal
autenticado o una plataforma ITSM completa.

Las fases 6–10 continúan pendientes. Completar V1 no constituye el cierre
integral del proyecto de portafolio.

## Cierre

E2E-01 a E2E-06 cuentan con evidencia real y aprobación explícita. Gate 5 queda
aprobado, Phase 5 completada y SmartDesk AI V1 completada. La documentación de
cierre no añade funcionalidad ni cambia el deployment probado.
