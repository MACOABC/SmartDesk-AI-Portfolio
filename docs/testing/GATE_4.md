# Evidencia en progreso — Gate 4

## Estado

- **Fecha local:** 2026-09-17 (ejecuciones registradas en UTC el 2026-09-18).
- **Gate 4:** **NOT YET PASS**.
- **Razón:** verificación de entrega Telegram real pendiente por ausencia de
  credencial telegramApi y TELEGRAM_CHAT_ID configurados.

No se declara PASS porque no se recibió una notificación real y, por tanto, no
se verificó automation_events.status = succeeded contra Telegram.

## Migración y esquema

Se aplicó db/migrations/003_create_automation_events.sql en smartdesk_db.

    BEGIN
    CREATE TABLE
    CREATE INDEX
    COMMIT

La tabla verificada tiene PK UUID, FK ticket_id → tickets(id), FK
prediction_id → ticket_ai_predictions(id), cuatro estados exactos, semántica
de error_code, índice por ticket/fecha y unicidad por
(prediction_id, rule_code, event_type).

Una prueba transaccional aceptó pending, succeeded, failed y skipped; rechazó
estado inválido, outcome incoherente, ambas FK inválidas y duplicado. Terminó
con ROLLBACK y synthetic_rows_after_rollback=0.

## Workflow desplegado

El workflow publicado pasó de 56 a 65 nodos. La ruta añadida es:

    prediction succeeded
      → notify_high_or_critical_v1
      → LOW/MEDIUM: insert skipped
      → HIGH/CRITICAL: insert pending
          → solo si insert_rows = 1
          → Telegram, retryOnFail=false
              → success: update succeeded
              → error: update failed / TELEGRAM_SEND_FAILED

El fallo al insertar pending y los conflictos de unicidad no alcanzan
Telegram. Los errores al actualizar el evento después del intento no provocan
retry y no cambian la respuesta HTTP 201 ya ganada por ticket y predicción.

## Casos funcionales de Phase 4

Todos los datos fueron sintéticos.

| Caso | Resultado | Evidencia |
| --- | --- | --- |
| A — high con entrega real | **NOT TESTED** | Ejecución 119: prioridad high, un solo nodo Telegram y evento failed / TELEGRAM_SEND_FAILED; no había credencial para probar entrega ni succeeded. |
| B — critical con entrega real | **NOT TESTED** | Ejecución 120: prioridad critical, un solo nodo Telegram y evento failed / TELEGRAM_SEND_FAILED; no había credencial para probar entrega ni succeeded. |
| C — medium | **PASS** | Ejecución 117: telegram_runs=0, skipped_insert_runs=1, evento único skipped. |
| D — low | **PASS** | Ejecución 118: telegram_runs=0, skipped_insert_runs=1, evento único skipped. |
| E — predicción IA fallida | **PASS** | Ejecución 121: HTTP 201, AI_PROVIDER_ERROR, telegram_runs=0, automation_decision_runs=0, 0 eventos y exactamente una prediction. |
| F — fallo controlado de integración Telegram | **PASS** | Ejecuciones 119 y 120: un intento por ejecución, 0 retries, ticket/prediction intactos y evento failed / TELEGRAM_SEND_FAILED. El proveedor Telegram no fue alcanzado porque faltaba la credencial. |

Para los cuatro niveles el HTTP fue 201 y tickets.status permaneció
processing. Cada prediction quedó en succeeded con categoría, prioridad y
summary originales. HIGH y CRITICAL tuvieron exactamente un evento y una
ejecución del nodo Telegram; LOW y MEDIUM tuvieron exactamente un evento y
cero ejecuciones Telegram.

El control estático del export obtuvo 18/18 comprobaciones: nodo Telegram
único, retry desactivado, salida de error conectada, campos del mensaje
permitidos, campos prohibidos ausentes, texto plano, orden pending antes del
side effect, fallo de insert sin Telegram, transiciones correctas, conflicto
idempotente y ausencia de updates a tickets.status.

## Regresión Gate 2

Se reejecutaron los 30 escenarios originales:

    cases=30
    passed=30
    failed=0
    http_201=13
    http_400=16
    http_500_controlled=1
    openai_requests=13
    automatic_retries=0

Los 13 casos válidos persistieron ticket, prediction succeeded, metadata
correcta y evento skipped; los 16 inválidos no alcanzaron OpenAI; el fallo de
persistencia no creó ticket y devolvió TICKET_PERSISTENCE_ERROR. También
pasaron normalización, límites, SQL parametrizado, recuperación y solicitudes
posteriores a reinicios de n8n y PostgreSQL.

Diez ejecuciones duplicadas de la segunda mitad de la batería fueron
identificadas por email sintético, excluidas del conjunto exacto de 30 y
eliminadas durante la limpieza.

## Regresión Gate 3

    real_structured_successes=13
    prediction_metadata_correct=13
    provider_failure_controlled=PASS
    invalid_request_no_ai=PASS
    deterministic_validator=19/19 PASS
    automatic_retries=0

El fallo controlado del proveedor conservó el ticket, dejó una única
prediction failed / AI_PROVIDER_ERROR, no creó automation_event y no ejecutó
Telegram. El model id temporal fue restaurado antes de continuar.

## Limpieza

Después de capturar la evidencia se eliminaron por identificadores y emails
sintéticos 22 eventos, 23 predicciones y 23 tickets. También se eliminaron las
45 ejecuciones n8n 117–161: cinco casos Phase 4, treinta casos de regresión y
diez repeticiones excluidas.

    remaining_test_tickets=0
    remaining_execution_entities=0
    remaining_execution_data=0

La migración, el workflow, las credenciales existentes y los datos ajenos a la
prueba no fueron eliminados.

## Seguridad y estado final del despliegue

    docker_compose_config=PASS
    postgres=healthy
    n8n=healthy
    postgres_published_ports=none
    n8n_binding=127.0.0.1:5678
    workflow_active=true
    workflow_nodes=65
    workflow_functional_diff_count=0
    source_deployment_hashes_match=true

El escaneo de archivos versionados y del diff de Phase 4 no encontró claves
OpenAI, tokens Telegram, URLs PostgreSQL, chat id real ni rutas personales.
.env.example conserva placeholders y el único IPv4 versionado es loopback. El
export no contiene Authorization manual, accessToken, pinData, model id
temporal ni tabla temporal de fallo.

La lista de credenciales desplegadas contiene únicamente PostgreSQL y OpenAI;
no existe credencial Telegram. TELEGRAM_CHAT_ID está vacío en el contenedor.

## Limitación pendiente

La integración usa la credencial segura de n8n y configuración externa, pero
no existe una credencial Telegram usable en el despliegue actual. Quedan
pendientes exactamente:

1. crear SmartDesk Telegram con un token real en n8n y asignarla al nodo;
2. configurar TELEGRAM_CHAT_ID fuera de Git;
3. repetir un caso HIGH y uno CRITICAL;
4. comprobar recepción real y evento succeeded.

Hasta completar esos cuatro puntos, Phase 4 continúa en progreso y Gate 4 no
está aprobado.
