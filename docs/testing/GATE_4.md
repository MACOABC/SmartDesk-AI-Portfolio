# Evidencia de cierre — Gate 4

## Estado

- **Fecha local de cierre:** 2026-09-19 (ejecuciones en UTC el 2026-09-20).
- **Gate 4:** **PASS**.
- **Fase 4:** **COMPLETE**.

La entrega real de Telegram fue verificada para HIGH y CRITICAL. La evidencia
incluye persistencia SQL, una sola ejecución del nodo por caso, respuesta
`ok=true` de Telegram Bot API, identificador de mensaje y ausencia de retries.

## Migración y regla

`db/migrations/003_create_automation_events.sql` permanece aplicada en
`smartdesk_db`. La tabla tiene FK a `tickets` y `ticket_ai_predictions`, los
estados exactos `pending`, `succeeded`, `failed` y `skipped`, restricciones de
outcome, índice por ticket/fecha y unicidad por
`(prediction_id, rule_code, event_type)`.

La regla `notify_high_or_critical_v1` se mantiene determinista:

    prediction succeeded + high/critical → pending → Telegram
    prediction succeeded + low/medium    → skipped
    prediction failed                    → no regla, evento ni Telegram

## Sincronización y corrección de despliegue

La primera repetición de HIGH detectó dos diferencias de configuración, no de
lógica: n8n bloqueaba el acceso de expresiones a variables de entorno y la
versión publicada aún referenciaba el ID de credencial anterior, aunque el
draft ya mostraba `SmartDesk Telegram`.

Se estableció `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`, se publicó la versión
actual y se reinició únicamente n8n. El workflow activo quedó con la
credencial `SmartDesk Telegram` y `={{ $env.TELEGRAM_CHAT_ID }}`. El valor del
destino y el token permanecen fuera de Git. El workflow local y el desplegado
producen el mismo hash después de normalizar defaults omitidos por la UI y
posiciones visuales.

## Pruebas funcionales

Todos los datos fueron sintéticos y se eliminaron después de registrar la
evidencia.

| Caso | Resultado | Evidencia objetiva |
| --- | --- | --- |
| HIGH real | **PASS** | Ejecución 165: HTTP 201; una prediction `succeeded/access/high`; un evento `succeeded` con `error_code IS NULL`; nodo Telegram 1 vez, rama exitosa 1, rama de error 0 y `retryOf IS NULL`. |
| CRITICAL real | **PASS** | Ejecución 164: HTTP 201; una prediction `succeeded/access/critical`; un evento `succeeded` con `error_code IS NULL`; nodo Telegram 1 vez, rama exitosa 1, rama de error 0 y `retryOf IS NULL`. |
| MEDIUM | **PASS** | Ejecución 166: HTTP 201; evento único `skipped`; `telegram_runs=0`, `pending_insert_runs=0`. |
| LOW | **PASS** | Ejecución 167: HTTP 201; evento único `skipped`; `telegram_runs=0`, `pending_insert_runs=0`. |
| IA failed | **PASS** | Ejecución controlada 168: una prediction `failed / AI_PROVIDER_ERROR`, campos de clasificación nulos, cero eventos, cero reglas, cero llamadas OpenAI y cero Telegram. |
| Fallo Telegram | **PASS** | Ejecución 163: HTTP 201; una prediction `succeeded/access/high` intacta; un evento `failed / TELEGRAM_SEND_FAILED`; una rama Telegram de error, un update failed, cero update succeeded y `retryOf IS NULL`. |

En HIGH y CRITICAL la salida observable de Telegram Bot API fue `ok=true` y
contenía `message_id`, fecha, chat y texto. El texto devuelto coincidió con el
mensaje construido. Cada mensaje tuvo exactamente el encabezado y estas seis
líneas: Ticket, Área, Categoría, Prioridad, Título y Resumen IA.

La comprobación dinámica confirmó ausencia de email, descripción completa,
raw de OpenAI, prompt, schema, reasoning, nombres de variables sensibles,
credenciales y patrones de token. No se registraron el texto completo, el
destino ni identificadores del chat en esta evidencia.

## Fallo secundario y conservación de datos

El fallo controlado ocurrió después de persistir ticket y prediction. SQL
confirmó exactamente un ticket `processing`, una prediction `succeeded` con
category, priority y summary conservados, y un evento
`failed / TELEGRAM_SEND_FAILED`. La ejecución tuvo una llamada de clasificación
original, un intento Telegram, cero retries y ninguna prediction adicional.

También se conserva la evidencia histórica de las ejecuciones 119 y 120, que
verificaron la misma rama de error antes de configurar Telegram. No se revocó
ni alteró el token real para repetir el fallo.

## Regresión Gate 2

La regresión relevante posterior al despliegue fue **PASS**:

- cuatro entradas válidas devolvieron HTTP 201 y persistieron ticket y
  prediction antes de evaluar la regla;
- ejecución 169, sin `title`, devolvió HTTP 400, no insertó ticket y ejecutó
  cero nodos OpenAI y Telegram;
- se mantuvieron el contrato, la normalización, el SQL parametrizado y las
  respuestas aprobadas. La batería completa anterior continúa documentada
  como 30/30 sin modificar sus pruebas.

## Regresión Gate 3

La regresión relevante posterior al despliegue fue **PASS**:

    structured_successes=4
    prediction_metadata_correct=4
    deterministic_validator=19/19 PASS
    controlled_failed_prediction=PASS
    failed_case_openai_requests=0
    automatic_retries=0

HIGH, CRITICAL, MEDIUM y LOW produjeron salida estructurada válida y una sola
prediction. La suite determinista aceptó 3 casos válidos, rechazó 16 inválidos
y volvió a comprobar carga y versión de prompt/schema. El caso failed conservó
el ticket y no alcanzó la regla de automatización.

## Limpieza

Se eliminaron por emails sintéticos exactos 6 eventos, 7 predictions y 7
tickets. También se eliminaron `execution_entity` y `execution_data` para las
ejecuciones 162–169.

    remaining_test_tickets=0
    remaining_test_execution_entities=0
    remaining_test_execution_data=0
    remaining_test_pending_events=0

No se eliminaron datos ajenos, credenciales, migraciones ni configuración.

## Seguridad y deployment

    docker_compose_config=PASS
    postgres=healthy
    n8n=healthy
    postgres_published_ports=none
    n8n_binding=127.0.0.1:5678
    workflow_active=true
    workflow_nodes=65
    telegram_credential_reference=SmartDesk Telegram
    telegram_api_live=PASS
    workflow_functional_equivalence=PASS

El escaneo de archivos versionados, diff, workflow, `.env.example` y
documentación no encontró tokens Telegram, claves OpenAI, passwords
PostgreSQL, connection strings sensibles, chat ID real, IP innecesarias ni
rutas personales. `.env` permanece ignorado y no versionado.

## Cierre

Todos los criterios obligatorios de Gate 4 cuentan con evidencia real. Gate 4
queda aprobado y Phase 4 completada. La siguiente fase documental es Phase 5;
este cierre no implementa ninguna funcionalidad de esa fase.
