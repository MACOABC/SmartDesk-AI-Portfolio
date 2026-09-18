# Evidencia en progreso — Gate 3

## Estado

- **Fecha de la evidencia disponible:** 2026-09-17.
- **Gate 3 status: IN PROGRESS.**
- **Alcance verificado:** contrato versionado, base de persistencia PostgreSQL, acceso read-only desde n8n, validación determinista y clasificación real aislada mediante OpenAI.

Gate 3 no está aprobado ni cerrado. Este documento registra únicamente la evidencia ejecutada hasta este checkpoint.

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

## Regresión mínima de Gate 2

Se ejecutó una regresión mínima de exactamente dos casos; no se repitieron los 30 casos completos de Gate 2:

- solicitud sintética válida → HTTP 201 y ticket persistido;
- solicitud inválida sin `title` → HTTP 400 y sin persistencia adicional.

No se creó ninguna predicción para el ticket sintético y el conteo de predicciones permaneció sin cambios. El ticket sintético fue eliminado mediante su UUID al finalizar.

## Workflow

- La rama de pruebas comienza con un `Manual Trigger` y permanece desconectada del webhook productivo.
- El workflow desplegado y exportado contiene 25 nodos.
- El export versionado quedó sincronizado con el workflow publicado.
- La llamada real utiliza un nodo HTTP Request contra OpenAI Responses API porque permite cargar dinámicamente el schema versionado y controlar `strict`, `store`, usage y errores sin duplicar el contrato.
- El workflow contiene únicamente una referencia a la credencial administrada por n8n; no contiene el secreto.
- El export mantiene `pinData` vacío y no contiene datos de ejecución.

## Pendiente para cerrar Gate 3

- Implementar la persistencia controlada `pending → succeeded/failed` desde n8n.
- Integrar de forma controlada el resultado validado con el intake real.
- Completar el manejo de respuestas inválidas y fallos de persistencia.
- Ejecutar y documentar la regresión y las pruebas end-to-end finales de Fase 3.
- Realizar el cierre formal de Gate 3.

## Límites de esta evidencia

- La rama de IA continúa aislada del webhook productivo.
- No se persistieron predicciones reales ni simuladas.
- La regresión de Gate 2 fue mínima y no acredita la repetición de sus 30 casos.
- La evidencia versionada no contiene secrets, API keys, tokens, IP pública, datos personales ni datos de ejecución.
- La batería real es evidencia experimental y no mide formalmente accuracy, rendimiento, disponibilidad ni impacto de producción.
