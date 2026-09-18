# Evidencia en progreso — Gate 3

## Estado

- **Fecha de la evidencia disponible:** 2026-09-17.
- **Gate 3 status: PASS.**
- **Alcance verificado:** contrato versionado, base de persistencia PostgreSQL, acceso read-only desde n8n, validación determinista, clasificación real aislada y primera integración end-to-end con el webhook de intake.

Gate 3 está aprobado y cerrado formalmente. Este documento registra únicamente la evidencia realmente ejecutada para su cierre.

## Base del contrato

El contrato V1 está versionado mediante:

- prompt `ticket-classification-v1` en `prompts/ticket-classification/v1.md`;
- schema `ticket-classification-schema-v1` en `prompts/ticket-classification/schema-v1.json`.

La salida contiene exactamente:

- `category`;
- `priority`;
- `summary`.

El schema exige `type: object`, los tres campos requeridos y `additionalProperties: false`.

Categorías aprobadas:

- `access`;
- `hardware`;
- `software`;
- `network`;
- `service_request`;
- `other`.

Prioridades aprobadas:

- `low`;
- `medium`;
- `high`;
- `critical`.

Las validaciones locales comprobaron sintaxis JSON, identificadores, campos requeridos, enums, límite de `summary`, ausencia de propiedades adicionales, reglas del prompt y ausencia de material sensible. Resultado: **PASS**.

## Base de persistencia

- **Migración:** `db/migrations/002_create_ticket_ai_predictions.sql`.
- **SHA-256 aplicado:** `95c3869b69509924700d3f030af1f141e4d6daabc0a2406fc15c2ab3d18a1203`.
- **Base objetivo:** `smartdesk_db`.
- **Tabla creada:** `public.ticket_ai_predictions`.

Resultado real de la aplicación:

```text
BEGIN
CREATE TABLE
CREATE INDEX
COMMIT
```

La estructura verificada en el catálogo de PostgreSQL contiene:

- 13 columnas;
- primary key sobre `id`;
- foreign key `ticket_id → public.tickets(id)` con `ON DELETE RESTRICT`;
- 10 restricciones `CHECK`;
- índice `(ticket_id, created_at DESC)`;
- múltiples predicciones permitidas por ticket, sin `UNIQUE(ticket_id)`.

Se ejecutaron 27 controles reales de integridad directamente contra PostgreSQL:

- 4 casos que debían aceptarse;
- 21 casos que debían rechazarse;
- protección `ON DELETE RESTRICT`;
- comprobación de que `updated_at` requiere actualización explícita.

Resultado: **27/27 PASS**.

Todos los datos usados fueron sintéticos. Las pruebas se ejecutaron dentro de una transacción que terminó con `ROLLBACK`.

Estado final comprobado:

```text
synthetic_tickets_remaining=0
synthetic_predictions_remaining=0
prediction_rows=0
predictions_table_exists=true
```

## Runtime del prompt

La carpeta `prompts/ticket-classification/` se montó en el contenedor n8n como read-only en:

`/opt/smartdesk/prompts/ticket-classification`

La configuración `N8N_RESTRICT_FILE_ACCESS_TO` limita el acceso del workflow a esa ruta. Desde el contenedor se comprobó que `v1.md` y `schema-v1.json` existen, son legibles y conservan sus identificadores versionados.

Los SHA-256 del checkout/host coincidieron exactamente con los calculados dentro del contenedor:

- `v1.md`: `bd75a0aede54a4c59c6711fd1107e6e7473e484767ae49bb571f9172f0819fee`;
- `schema-v1.json`: `b5dfbd52a07972ca33baac9763c9bc8dcf5e0a41634c52a5c1db6a801a19db33`.

Un intento controlado de crear un archivo desde n8n fue rechazado con `Read-only file system`. No apareció un archivo temporal y los hashes permanecieron sin cambios.

## Carga del contrato

La rama manual del workflow cargó y validó los artefactos locales con estos resultados:

```text
prompt_load=PASS
prompt_version=PASS
schema_load=PASS
schema_parse=PASS
schema_version=PASS
```

## Validador determinista

El validador real de n8n se ejecutó con:

- 3 casos ACCEPT;
- 16 casos REJECT.

Todos los casos obtuvieron `PASS`. Los casos REJECT cubrieron JSON inválido, estructura incorrecta, campos ausentes o adicionales, enums desconocidos, diferencias de mayúsculas, `summary` inválido, `null`, objeto vacío y texto añadido antes del JSON.

El validador opera fail closed. No corrige categorías, no cambia mayúsculas/minúsculas, no rellena campos, no convierte tipos y no asigna valores predeterminados silenciosamente.

## Fallos del contrato

Sin modificar permanentemente los archivos versionados, se comprobaron dos entradas aisladas:

- JSON Schema inválido → `AI_CONTRACT_LOAD_ERROR`;
- `$id` inválido → `AI_CONTRACT_LOAD_ERROR`.

Ambas pruebas obtuvieron `PASS`.

## Integración real aislada con OpenAI

La rama manual utiliza:

- proveedor `openai`;
- modelo solicitado `gpt-5.6-luna`;
- Responses API;
- Structured Outputs con JSON Schema y `strict: true`;
- `store: false`;
- reasoning `none`;
- credencial administrada por n8n, sin escribir manualmente el header `Authorization`.

La arquitectura demostrada es:

```text
prompt/schema versionados
        ↓
mount read-only
        ↓
contrato validado
        ↓
OpenAI Responses API
        ↓
Structured Outputs strict
        ↓
validador determinista n8n
        ↓
resultado confiable
```

La rama continúa iniciándose con `Manual Trigger` y permanece desconectada del webhook productivo.

### Paso 7A — primera llamada real exitosa

```text
provider=openai
requested_model=gpt-5.6-luna
reported_model=gpt-5.6-luna

prompt_version=ticket-classification-v1
schema_version=ticket-classification-schema-v1

category=network
priority=medium

structured_output=PASS
deterministic_validator=PASS

input_tokens=1035
cached_input_tokens=0
output_tokens=40
total_tokens=1075

workflow_end_to_end_latency_ms=1697
estimated_cost_usd=0.000255
```

La latencia fue medida de extremo a extremo por el workflow; no es una métrica proporcionada por OpenAI. El coste se calculó con los tokens realmente reportados y los precios oficiales vigentes en el momento de la prueba. Este caso aislado no constituye un benchmark ni una medición de accuracy.

Antes de esta llamada exitosa existió una única petición que recibió HTTP 429 por ausencia de saldo API. No tuvo retries y no produjo ninguna clasificación, por lo que no se cuenta como clasificación exitosa.

### Paso 7B — batería real pequeña

```text
valid_requests=5
controlled_provider_failure_requests=1
automatic_retries=0
```

Resultados estructurales y observaciones semánticas:

```text
T1 structural=PASS category=access priority=high
T2 structural=PASS category=hardware priority=medium
T3 structural=PASS category=software priority=medium
T4 structural=PASS category=service_request priority=medium
T5 structural=PASS category=service_request priority=low
```

Las coincidencias de T1–T4 con sus expectativas conceptuales son observaciones experimentales, no una medición formal de accuracy. En T5, las palabras `URGENTE CRÍTICO` no provocaron por sí solas una prioridad alta o crítica. Estos cinco casos tampoco constituyen un benchmark.

Consumo real observado en las cinco llamadas exitosas de Paso 7B:

```text
total_input_tokens=5143
total_cached_input_tokens=0
total_output_tokens=204
total_tokens=5347

estimated_total_cost_usd=0.0012734
minimum_case_cost_usd=0.0002504
maximum_case_cost_usd=0.0002624
```

La suma estimada de las llamadas exitosas de 7A y 7B fue:

```text
successful_call_estimated_cost_to_date_usd=0.0015284
```

Esta suma no incluye costes desconocidos de peticiones fallidas para las que no se recibió información de `usage`. No se extrapola a volumen de producción.

### Fallo controlado del proveedor

Después de las cinco llamadas válidas se ejecutó una única petición manual con un modelo ficticio:

```text
model=smartdesk-invalid-model-for-test
http_status=404

provider_failure_handled=PASS
classification_not_trusted=PASS
validator_not_reached_as_valid=PASS
prediction_persisted=false
```

El modelo inválido se restauró inmediatamente a `gpt-5.6-luna` y no quedó en el workflow versionado.

### Persistencia durante 7A y 7B

```text
ticket_ai_predictions_before=0
ticket_ai_predictions_after=0
```

La integración real todavía no persiste resultados en `ticket_ai_predictions`.

### Seguridad de la integración

```text
store=false
API key no versionada
Authorization header no escrito manualmente
credencial administrada por n8n
sin datos personales reales
sin raw provider responses persistidos
sin execution data versionada
```

## Paso 8 — persistencia controlada de predicciones

La rama manual demostró por primera vez la máquina de estados de `public.ticket_ai_predictions` con datos completamente sintéticos:

```text
ticket
  ↓
prediction pending
  ↓
IA / fallo controlado
  ↓
validator
  ↓
succeeded | failed
```

La identidad se conservó durante todo el flujo mediante `ticket_id` y el `prediction_id` devuelto explícitamente por PostgreSQL. Las actualizaciones terminales utilizaron conjuntamente:

```text
prediction_id
ticket_id
status = pending
```

De esta forma, una predicción que ya alcanzó un estado terminal no se sobrescribe. El estado del ticket permanece separado del estado de clasificación y `tickets.status` no fue modificado. Un fallo produce una fila terminal coherente con `error_code`, no una predicción parcial.

### SUCCESS path

```text
ticket_created=PASS
pending_insert=PASS
pending_verified_before_openai=PASS
openai_requests=1
structured_output=PASS
validator=PASS
terminal_update_rows=1
final_status=succeeded

category=network
priority=medium

input_tokens=1028
cached_input_tokens=0
output_tokens=40
total_tokens=1068
workflow_end_to_end_latency_ms=1621
estimated_cost_usd=0.0002536
```

La latencia fue medida de extremo a extremo por el workflow, no por OpenAI. El coste estimado se calculó con el `usage` realmente reportado y las tarifas oficiales vigentes durante la prueba. Esta ejecución aislada no constituye un benchmark.

### FAILED path

```text
ticket_created=PASS
pending_insert=PASS
pending_verified=PASS
openai_requests=0
simulated_error_code=AI_PROVIDER_ERROR
terminal_update_rows=1
final_status=failed
prediction_fields_null=PASS
```

Este resultado provino de una simulación local de la transición de persistencia. No se realizó una segunda llamada al proveedor y la rama de fallo no alcanzó el nodo OpenAI.

### Integridad de estados

```text
succeeded_transition_only_from_pending=PASS
failed_transition_only_from_pending=PASS
terminal_update_rows_exactly_one=PASS
prediction_identity_preserved=PASS
created_at_preserved=PASS
updated_at_assigned_explicitly=PASS
ticket_status_unchanged=PASS
```

### Limpieza de datos sintéticos

Después de capturar la evidencia se eliminaron exclusivamente las dos predicciones sintéticas por sus UUID y, posteriormente, sus tickets asociados, respetando `ON DELETE RESTRICT`.

```text
prediction_count_before=0
prediction_count_after=0
synthetic_predictions_remaining=0
synthetic_tickets_remaining=0
```

También se eliminaron los registros temporales correspondientes a las dos ejecuciones CLI controladas. El export conserva `pinData` vacío y no contiene API key, header `Authorization` manual, passwords, tickets sintéticos, respuestas del proveedor ni datos de ejecución. La petición real mantuvo `store=false`.

## Paso 9 — integración end-to-end con el webhook

La rama productiva de `POST /webhook/tickets` quedó conectada con este orden:

```text
validar/normalizar
  ↓
INSERT ticket
  ↓
INSERT prediction pending
  ↓
cargar y validar prompt/schema read-only
  ↓
OpenAI Responses API
  ↓
validador determinista
  ↓
UPDATE prediction succeeded | failed
  ↓
HTTP 201
```

El `prediction_id` devuelto por PostgreSQL y el `ticket_id` permanecen explícitos durante toda la ejecución. Las dos actualizaciones terminales exigen conjuntamente `prediction_id`, `ticket_id` y `status = pending`, y deben afectar exactamente una fila. `tickets.status` permaneció en `processing` en ambos casos E2E.

### E2E-S1 — success real

Se envió un ticket completamente sintético al endpoint real. Antes de la petición se comprobó que un único item alcanzaría el nodo HTTP y que `retryOnFail=false`.

```text
openai_requests=1
http_status=201
ticket_status=processing
pending_insert=PASS
contract_load=PASS
response_status=completed
structured_output=PASS
deterministic_validator=PASS
terminal_update_rows=1
final_status=succeeded

category=network
priority=medium

input_tokens=1035
cached_input_tokens=0
output_tokens=40
total_tokens=1075
workflow_ai_latency_ms=2329
http_end_to_end_latency_ms=2656
estimated_cost_usd=0.000255
```

`workflow_ai_latency_ms` fue medido por el workflow desde la construcción de la petición hasta la extracción de la respuesta. `http_end_to_end_latency_ms` fue medido externamente sobre el webhook completo. El coste se estimó con el `usage` real y los precios oficiales vigentes durante la prueba. Estas mediciones aisladas no constituyen un benchmark ni una medición formal de accuracy.

La respuesta pública conservó todos los campos existentes de Gate 2 y añadió únicamente:

```json
"classification": {
  "status": "succeeded",
  "category": "network",
  "priority": "medium",
  "summary": "..."
}
```

### E2E-F1 — provider failure real y controlado

Se publicó temporalmente un model id ficticio exclusivamente para una petición E2E. No se modificó ni expuso la credencial y no hubo retries. El model id válido `gpt-5.6-luna` fue restaurado inmediatamente después y es el único presente en el export final.

```text
openai_requests=1
automatic_retries=0
http_status=201
provider_failure_handled=PASS
validator_executed=false
terminal_update_rows=1
final_status=failed
error_code=AI_PROVIDER_ERROR
prediction_fields_null=PASS
ticket_status=processing
provider_details_exposed=false
```

La respuesta pública añadió únicamente:

```json
"classification": {
  "status": "failed"
}
```

No expuso `error_code`, status o mensajes de OpenAI, stack trace, `prediction_id` ni detalles internos.

### Regresión de entrada inválida

Antes de las llamadas a OpenAI se envió una solicitud sintética sin `title`:

```text
http_status=400
ticket_created=false
prediction_created=false
openai_called=false
```

La acumulación y forma de los errores de Gate 2 se conservaron.

### Manejo de fallos internos

Los errores internos controlables ocurridos después de crear `pending` se enrutan a un intento de transición terminal con `AI_INTERNAL_ERROR`. Si falla la propia escritura terminal en PostgreSQL, el workflow devuelve HTTP 500 y no afirma que la clasificación fue persistida. Por decisión de alcance de Fase 3 no se añadieron retries, workers ni infraestructura adicional; por tanto, ese fallo de base de datos puede dejar una fila `pending` que requiere intervención operativa.

### Limpieza de Paso 9

Tras capturar la evidencia se eliminaron exclusivamente las dos predicciones y sus dos tickets sintéticos mediante sus UUID exactos, respetando `ON DELETE RESTRICT`. También se eliminaron por ID las tres ejecuciones sintéticas de n8n —entrada inválida, success y provider failure— para que no permanecieran tickets ni respuestas del proveedor en execution data.

```text
prediction_count_before=0
prediction_count_after=0
synthetic_predictions_remaining=0
synthetic_tickets_remaining=0
synthetic_execution_entities_remaining=0
synthetic_execution_data_remaining=0
```

El presupuesto de este paso fue respetado exactamente: dos requests reales a OpenAI, uno exitoso y uno fallido mediante model id temporal inválido, sin llamadas adicionales y sin retries.

## Regresión final de Fase 3

Se recuperó y reejecutó la batería original exacta de Gate 2: 28 casos de contrato/persistencia más los casos posteriores a reinicio de n8n y PostgreSQL. No se sustituyó por una batería nueva con el mismo número.

Resultado global:

```text
cases_executed=30
passed=30
failed=0
openai_requests_expected=13
openai_requests_observed=13
automatic_retries=0
```

Los 13 casos válidos crearon exactamente un ticket y una prediction cada uno, devolvieron HTTP 201 y terminaron en `succeeded`. Los 16 casos inválidos devolvieron HTTP 400, no crearon ticket ni prediction y no alcanzaron OpenAI. El caso de fallo PostgreSQL devolvió el HTTP 500 genérico aprobado, sin ticket, prediction, llamada a OpenAI ni detalles internos.

Matriz de los 30 casos originales:

```text
happy_path=PASS
normalization=PASS
missing_email=PASS
invalid_email=PASS
area_spaces=PASS
title_under_5=PASS
description_under_10=PASS
empty_payload=PASS
wrong_types=PASS
null_fields=PASS
multiple_errors=PASS
boundary_area_2=PASS
boundary_area_80=PASS
boundary_area_1=PASS
boundary_area_81=PASS
boundary_title_5=PASS
boundary_title_150=PASS
boundary_title_4=PASS
boundary_title_151=PASS
boundary_description_10=PASS
boundary_description_5000=PASS
boundary_description_9=PASS
boundary_description_5001=PASS
boundary_email_254=PASS
boundary_email_255=PASS
special_characters=PASS
persistence_failure=PASS
recovery_after_500=PASS
after_n8n_restart=PASS
after_postgres_restart=PASS
```

Para cada success se comprobó que la clasificación pública coincidiera con la fila de PostgreSQL y que la metadata fuera exactamente `openai`, `gpt-5.6-luna`, `ticket-classification-v1` y `ticket-classification-schema-v1`. En al menos el caso `happy_path` se verificó además:

```text
http_status=201
ticket_persisted=true
prediction_persisted=true
prediction_status=succeeded
category_valid=true
priority_valid=true
summary_valid=true
public_classification_equals_database=true
ticket_status=processing
```

### AI_RESPONSE_INVALID productivo

Se desplegó temporalmente un único nodo de simulación entre la aserción de petición y el validador determinista. Durante esa versión temporal el nodo OpenAI no era alcanzable desde el webhook. La simulación entregó una categoría fuera del enum aprobado y recorrió la rama productiva real desde la creación del ticket y `pending` hasta la actualización terminal.

```text
openai_requests=0
validator=REJECT
prediction_final_status=failed
error_code=AI_RESPONSE_INVALID
prediction_fields_null=PASS
http_status=201
public_classification_status=failed
error_code_exposed_to_client=false
```

La versión normal fue restaurada inmediatamente. El export final contiene 56 nodos, no contiene el nodo temporal, la categoría simulada ni el model id inválido de Paso 9, y vuelve a conectar la rama productiva con OpenAI.

### Integridad PostgreSQL de la regresión

Antes de limpiar se observaron 14 tickets y 14 predictions: 13 success reales de la batería y un failure simulado para `AI_RESPONSE_INVALID`.

```text
tickets_processing=14
predictions_succeeded=13
predictions_failed=1
test_pending_predictions=0
metadata_correct=14
succeeded_consistent=13
failed_consistent=1
foreign_key_validated=true
on_delete=RESTRICT
```

No existió ningún `succeeded` con `error_code`, ningún `failed` con `category`, `priority` o `summary`, ni cambios de estado de ticket provocados por IA.

### Limpieza de la regresión final

Se validaron primero los UUID exactos y luego se eliminaron las 14 predictions, seguidas por sus 14 tickets. También se eliminaron exclusivamente las 31 ejecuciones webhook de esta regresión —30 casos originales y la simulación inválida—, identificadas como ejecuciones 86–116 del workflow probado.

```text
synthetic_tickets_remaining=0
synthetic_predictions_remaining=0
synthetic_execution_entities_remaining=0
synthetic_execution_data_remaining=0
test_pending_predictions=0
```

### Seguridad, infraestructura y sincronización final

```text
api_key_in_git=false
authorization_manual=false
password_in_git=false
raw_openai_response_versioned=false
execution_data_versioned=false
synthetic_ticket_versioned=false
pinData_empty=true
store=false
automatic_retries=false

postgres=healthy
n8n=healthy
postgres_published_ports=none
n8n_binding=127.0.0.1:5678
workflow_active=true
```

El export publicado y `n8n/workflows/ticket-intake.json` coincidieron funcionalmente: 56 nodos, cero diferencias de configuración de nodos, conexiones iguales y settings iguales. La importación CLI de n8n generó un `versionId` nuevo para la versión publicada; esa identidad de despliegue difiere del artefacto fuente, sin diferencia funcional.

La evidencia real de `AI_PROVIDER_ERROR` del Paso 9 sigue vigente y su lógica continúa presente en el workflow final. No se repitió deliberadamente otra llamada fallida al proveedor.

### Limitación conocida de escritura terminal

Si PostgreSQL falla después de crear `pending` pero antes de persistir la transición terminal, el workflow puede devolver HTTP 500 y la prediction puede permanecer `pending`. El ticket original permanece persistido y el workflow no inventa un estado terminal. Gate 3 no incorpora retries, workers ni recuperación automática; esa recuperación pertenece a una fase posterior.

## Regresión mínima histórica de Gate 2

En el Paso 6 se había ejecutado una regresión mínima de exactamente dos casos; esa evidencia histórica no corresponde a la regresión final anterior:

- solicitud sintética válida → HTTP 201 y ticket persistido;
- solicitud inválida sin `title` → HTTP 400 y sin persistencia adicional.

No se creó ninguna predicción para el ticket sintético y el conteo de predicciones permaneció sin cambios. El ticket sintético fue eliminado mediante su UUID al finalizar.

## Workflow

- La rama de pruebas continúa comenzando con un `Manual Trigger` y permanece desconectada de la rama iniciada por el webhook.
- La rama productiva del webhook contiene su propia carga del contrato read-only, llamada a OpenAI, validación determinista y persistencia terminal.
- El workflow desplegado y exportado contiene 56 nodos.
- El export versionado quedó sincronizado con el workflow publicado.
- La llamada real utiliza un nodo HTTP Request contra OpenAI Responses API porque permite cargar dinámicamente el schema versionado y controlar `strict`, `store`, usage y errores sin duplicar el contrato.
- La rama manual inserta y verifica `pending`, conserva `prediction_id` y aplica transiciones terminales condicionadas por `prediction_id`, `ticket_id` y estado `pending`.
- El workflow contiene únicamente una referencia a la credencial administrada por n8n; no contiene el secreto.
- El export mantiene `pinData` vacío y no contiene datos de ejecución.

## Conclusión de Gate 3

Gate 3 fue aprobado porque el intake de Gate 2 conservó una regresión 30/30 sobre el workflow final; los tickets válidos se clasifican mediante IA; el output se valida determinísticamente; y las predicciones se persisten mediante la transición `pending → succeeded/failed`. Los fallos del proveedor conservan el ticket y responden HTTP 201, las respuestas inválidas del modelo no se utilizan y las solicitudes inválidas no alcanzan OpenAI.

La limpieza no dejó datos sintéticos, la revisión de seguridad pasó y el workflow desplegado coincide funcionalmente con el export versionado.

## Límites de esta evidencia

- La clasificación IA ya forma parte del webhook productivo; Telegram, email, routing, SLA, HITL, retries, fallback model y reglas de negocio de Fase 4 continúan fuera de alcance.
- Las predicciones del Paso 8 fueron persistidas temporalmente para verificar la máquina de estados y eliminadas al finalizar; no permanecen datos sintéticos.
- La regresión final cubrió los 30 casos originales de Gate 2, 13 clasificaciones reales exitosas y una simulación productiva sin API de `AI_RESPONSE_INVALID`. No constituye un benchmark ni una medición formal de accuracy.
- La evidencia versionada no contiene secrets, API keys, tokens, IP pública, datos personales ni datos de ejecución.
- La batería real es evidencia experimental y no mide formalmente accuracy, rendimiento, disponibilidad ni impacto de producción.
