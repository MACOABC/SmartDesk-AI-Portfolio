# Evidencia en progreso — Gate 3

## Estado

- **Fecha de la evidencia disponible:** 2026-09-17.
- **Gate 3 status: IN PROGRESS.**
- **Alcance verificado:** contrato versionado, base de persistencia PostgreSQL, acceso read-only desde n8n y validación determinista de respuestas simuladas.

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

## Regresión mínima de Gate 2

Se ejecutó una regresión mínima de exactamente dos casos; no se repitieron los 30 casos completos de Gate 2:

- solicitud sintética válida → HTTP 201 y ticket persistido;
- solicitud inválida sin `title` → HTTP 400 y sin persistencia adicional.

No se creó ninguna predicción para el ticket sintético y el conteo de predicciones permaneció sin cambios. El ticket sintético fue eliminado mediante su UUID al finalizar.

## Workflow

- La rama de pruebas comienza con un `Manual Trigger` y permanece desconectada del webhook productivo.
- El workflow desplegado y exportado contiene 18 nodos.
- El export versionado quedó sincronizado con el workflow publicado.
- No se añadieron nodos externos ni nodos de IA.
- No se añadieron credenciales.
- El export no contiene `pinData` ni datos de ejecución.

## Pendiente para cerrar Gate 3

- Seleccionar y configurar de forma segura el proveedor y el modelo.
- Ejecutar una llamada real a la API de IA.
- Persistir predicciones desde n8n.
- Manejar de forma controlada fallos del proveedor, respuestas inválidas y fallos de persistencia.
- Ejecutar y documentar las pruebas end-to-end de Fase 3.

## Límites de esta evidencia

- No se llamó ninguna API de IA.
- No se seleccionó proveedor ni modelo.
- No se configuraron credenciales de IA.
- No se persistieron predicciones simuladas.
- La regresión de Gate 2 fue mínima y no acredita la repetición de sus 30 casos.
- La evidencia versionada no contiene secrets, API keys, tokens, IP pública, datos personales ni datos de ejecución.
- Esta evidencia no mide precisión, rendimiento, disponibilidad ni impacto de producción.
